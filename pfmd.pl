#!/usr/bin/perl
# $Id: pfmd.pl,v 1.20 2014/10/21 20:31:46 jepace Exp $
use strict;
use Getopt::Std;
use DBI;
use POSIX qw{strftime};
use Sys::Syslog qw{:standard :macros};
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Sender::Transport::Sendmail qw();
use Try::Tiny;
use Data::Dumper;
use WWW::PushBullet;

# TODO
#   - Add time used

my ($debug, $verbose);
my $done = 0;   # TODO: Implement some sort of handler to exit program
my %runChange;
my $dbh;        # Database handle
my $dbname = "pfm";
my $dbtable = "pfm";
my $dbuser = "pgsql";   # XXX: Fix this
my $dbpass = "";        # XXX: Fix this
my $notifyAddress = "parents\@pacehouse.com";

# PushButtlet
# Get your key from your profile at pushbullet.com
# Get the device id by running WWW::PushBulet's pushbullet devices -k # key
my $pb;         # PushBullet handle
my $pbkey = "v1WjvMLivfaQz334MwSQc4KrzgKN5tOv4rujzboV370AS";
my $pbdevice = "ujzboV370ASdjzWIEVDzOK";

sub Setup;
sub Shutdown;
sub StartNet;
sub StopNet;
sub AddTime;
sub CheckForChanges;

&Setup();
while (!$done)
{
    sleep 1;

    # Decrease time remaining for running users
    $dbh->do("UPDATE $dbtable SET timeleft = timeleft - 1 WHERE isrunning = TRUE");
    $dbh->do("UPDATE $dbtable SET today = today - 1 WHERE isrunning = TRUE");
    $dbh->do("UPDATE $dbtable SET last_login = CURRENT_TIMESTAMP WHERE isrunning = TRUE");

    # XXX: isrunning is in the other table...?
#    $dbh->do("UPDATE $dbtable SET curr_time_day = curr_time_day + 1 WHERE p fm  .isrunning = TRUE"); gin = pfm_policy.login AND
#    $dbh->do("UPDATE pfm_policy SET curr_time_day = curr_time_day + 1 WHERE isrunning = TRUE");

    # Did something happen?
    &CheckForChanges();
}

sub Shutdown()
{
    print "[" . localtime() . "] Shutting down pfmd." if $verbose;
    syslog(LOG_NOTICE, "Shutting down pfmd.");
    $pb->push_note( { device_id => $pbdevice, 
                    title => "PFMonster: Shutting down pfmd.", 
                    body => "[" . localtime() . "] We're out of here." } );

    # Disable network for all
    my $sth = $dbh->prepare("SELECT login FROM $dbtable WHERE isrunning = TRUE ORDER BY login ASC");
    $sth->execute();

    while(my $ref = $sth->fetchrow_hashref())
    {
        my $user = $ref->{'login'};
        print "[" . localtime() . "] Shutdown: Stopping '$user'\n" if $verbose;
        &StopNet($user) unless $debug;
    }

    # Clean Up and exit
    $dbh->disconnect();

    closelog(); # Done with syslog

    # XXX: Do we need to shutdown pushbullet?

    print "[" . localtime() . "] Done. Exiting.\n" if $verbose;
    exit 0;
}

###################################################################

sub CheckForChanges()
{
    # BUG #4 FIX: Don't let today go negative
    $dbh->do("UPDATE $dbtable SET today = 0 WHERE today < 0");

    # Display running users' time
    my $sth = $dbh->prepare("SELECT login, timeleft, today FROM
                            $dbtable WHERE isrunning = TRUE ORDER BY login ASC");
    $sth->execute();

    while(my $ref = $sth->fetchrow_hashref()) 
    {
        my $time = $ref->{'timeleft'};
        my $today = $ref->{'today'};
        my $state = "User '$ref->{'login'}' has " .
            strftime("\%H:\%M:\%S", gmtime($time)) .
            " remaining [$today sec today]";
        syslog(LOG_DEBUG, $state) if ($time % 300 == 0);
        print "[" . localtime(). "] $state\n" if ($verbose && ($time % 30 == 0));
    }

    # CASE 1: Time is up!
    my $sth = $dbh->prepare("SELECT login, timeleft FROM $dbtable WHERE isrunning = TRUE AND timeleft <= 0 ORDER BY login ASC");
    $sth->execute();
    while(my $ref = $sth->fetchrow_hashref()) 
    {
        my $user = $ref->{'login'};
        print "[" . localtime() . "] CHANGE: User $user: OUT OF TIME\n" if $verbose;
        syslog(LOG_NOTICE, "$user is out of time");
        &StopNet ($user);
        # BUG FIX: Allow negative time
        # $dbh->do("UPDATE $dbtable SET timeleft = 0 WHERE timeleft < 0");
        # A little tolerance for timing issues
        $dbh->do("UPDATE $dbtable SET timeleft = 0 WHERE timeleft = -1");
    }

    # CASE 3: Today's time is used up
    my $sth = $dbh->prepare("SELECT login, today FROM $dbtable WHERE
                            isrunning = TRUE AND today <= 0 ORDER BY login ASC");
    $sth->execute();
    while(my $ref = $sth->fetchrow_hashref()) 
    {
        my $user = $ref->{'login'};
        print "[" . localtime() . "] CHANGE: User $user: OUT OF TIME TODAY\n" if $verbose;
        syslog(LOG_NOTICE, "$user is out of time for today");
        &StopNet ($user);
    }

    # CASE 2: Switched on or off
    my $sth = $dbh->prepare("SELECT login,isrunning FROM $dbtable ORDER BY login ASC");
    $sth->execute();

    # Display the runChange array
    foreach (keys %runChange)
    {
        # syslog(LOG_DEBUG, "$_: $runChange{$_}");
        print "[" . localtime() . "] Previous: User $_: $runChange{$_}\n" if ($verbose>1);
    }

    while(my $ref = $sth->fetchrow_hashref()) {
        my $user = $ref->{'login'};
        my $running = $ref->{'isrunning'};
        print "[" . localtime() . "] User $user: Running = '$running' [was $runChange{$user}]\n" if ($verbose>1);

        if ($runChange{$user} != $running)
        {
            print "[" . localtime() . "] CHANGE: User $user: Changed State to $running\n" if $verbose;
            # A change has occurred...
            if ($running)
            {
                # just changed to running .. enable the net
                &StartNet($user);
            }
            else
            {
                &StopNet($user);
            }
            $runChange{$user} = $running;  # Record the change
        }
    }
}

sub StartNet()
{
    my $user = shift (@_);
    print "[" . localtime() . "] Entering StartNet ($user)\n" if $verbose;
    $runChange{$user} = 1;

    $dbh->do("UPDATE $dbtable SET isrunning = TRUE WHERE login = '$user'");

    # Change firewall
#    my $cmd = "echo \"pass from <ip_$user> to any keep state\" | sudo pfctl -a pfm_$user -f -";
#    print "[" . localtime() . "] $cmd\n" if $verbose;
#    my $ret = `$cmd 2>&1`;
#    warn ("$cmd: $ret\n") if $?;

    # Allow shared devices too
    my $cmd = "echo \"pass from <ip_shared> to any keep state\npass from <ip_$user> to any keep state\" | sudo pfctl -a pfm_$user -f -";
    print "[" . localtime() . "] $cmd\n" if $verbose;
    my $ret = `$cmd 2>&1`;
    warn ("$cmd: $ret\n") if $?;

    syslog (LOG_NOTICE, "Starting '$user'");
    $pb->push_note( { device_id => $pbdevice, 
                    title => "PFMonster: Starting $user", 
                    body => "[" . localtime() . "] Starting '$user'" } );
}

sub StopNet()
{
    my $user = shift (@_);
    print "[" . localtime() . "] Entering StopNet ($user)\n" if $verbose;
    $runChange{$user} = 0;

    # Tell database that we're no longer running
    $dbh->do("UPDATE $dbtable SET isrunning = FALSE WHERE login = '$user'");

    # Change firewall
    # Bug #2: Use '-F all' instead of '-F rules' so that currently
    # running streams get killed too.
    my $cmd = "sudo pfctl -a pfm_$user -Fa";
    print "[" . localtime() . "] $cmd\n" if $verbose;
    my $ret = `$cmd 2>&1`;
    warn ("$cmd: $ret\n") if $?;

    my $cmd = "sudo pfctl -Fs";
    print "[" . localtime() . "] $cmd\n" if $verbose;
    my $ret = `$cmd 2>&1`;
    warn ("$cmd: $ret\n") if $?;

    syslog (LOG_NOTICE, "Stopping '$user'");
    $pb->push_note( { device_id => 0, 
                    title => "PFMonster: Stopped $user", 
                    body => "[" . localtime() . "] Stopping '$user'" } );

    my $from = "pfmonster\@pacehouse.com";
    my $body = "User $user: Stopping network access at ".  localtime() . "\n";

    my $email = Email::Simple->create (header=>[To=>$notifyAddress,
                                       From=>$from,
                                       Subject=>"PFMonster: $user stopped"], body=>$body,);

    try {
            sendmail($email, {from=>$from, transport=>Email::Sender::Transport::Sendmail->new});
    } catch {
            print "Can't send mail: $_" if $verbose;
    }

    return;
}

sub AddTime
{
    my $user = shift (@_);
    my $time = shift (@_);

    # Display updated value
    my $sth = $dbh->prepare("SELECT login,timeleft FROM $dbtable WHERE login = '$user'");
    $sth->execute();
    if ($verbose)
    {
        while(my $ref = $sth->fetchrow_hashref()) {
            print "[" . localtime() . "] $ref->{'login'} Time left is $ref->{'timeleft'}\n";
        }
    }

    # Make the change
    $dbh->do("UPDATE $dbtable SET timeleft = timeleft + $time WHERE login = '$user'");

    # Display updated value
    my $sth = $dbh->prepare("SELECT login,timeleft FROM $dbtable WHERE login = '$user'");
    $sth->execute();

    if ($verbose)
    {
        while(my $ref = $sth->fetchrow_hashref()) {
            print "[" . localtime() . "] User $ref->{'login'}: Time left is $ref->{'timeleft'}\n";
        }
    }
}

sub Setup
{
    my %arg;
    getopts ("dvh", \%arg);
    $verbose++ if $arg{v};
    $debug++ if $arg{d};

    # Play with dummy data when debugging.
    $dbname = "pfm_test" if $debug;
    $dbtable = "pfm_test" if $debug;

    # Catch signals
    $SIG{INT} = \&Shutdown;
    $SIG{TERM} = \&Shutdown;

    # Set up syslog connection
    openlog("pfmd", "pid", LOG_LOCAL2);
    print "[" . localtime() . "] Starting up...\n" if $verbose;
    syslog (LOG_DEBUG, "Starting up");

    # Initialize PushBullet
    $pb = WWW::PushBullet->new({apikey => $pbkey});
    if ($debug)
    {
        $pb->debug_mode($debug);
        my $devices = $pb->devices();
        print Data::Dumper->Dump([$devices], [qw(devices *ary)]);
    }
    $pb->push_note ( { device_id => $pbdevice, 
                    title => "Starting PFMonster Daemon", 
                    body => "[" . localtime() ."] Starting up pfmd" } );

    # Connect to database
    $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=localhost", $dbuser, $dbpass, {'RaiseError' => 1});
    print "[" . localtime() . "] Database '$dbname' connection established.\n" if $verbose;
    syslog (LOG_INFO, "Database '$dbname' connection open");

    # Establish the runChange hash
    my $sth = $dbh->prepare("SELECT login,isrunning FROM $dbtable ORDER BY login ASC");
    $sth->execute();

    while(my $ref = $sth->fetchrow_hashref())
    {
        my $running = $ref->{'isrunning'};
        my $user = $ref->{'login'};
        $runChange{$user} = $running;
        print "[" . localtime() . "] Setup: User $user: Running: $runChange{$user}\n" if $verbose;
        if ($running)
        {
            &StartNet($user) unless $debug;
        }
        else
        {
            &StopNet($user) unless $debug;
        }
    }
}
