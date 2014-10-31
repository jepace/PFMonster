#!/usr/bin/perl -w
use strict;
use DBI;
use Sys::Syslog qw(:standard :macros);

# $Id: pfm-mail.pl,v 1.2 2014/07/20 23:06:06 jepace Exp $
#
# Take the email and update the database

my $addltime;   # Additional time to add
my $user;       # User getting more time
my $dbh;        # Database handle
my $debug = 0;

openlog("pfm-mail.pl", "pid", LOG_LOCAL2);
syslog (LOG_INFO, "Running");
while (<>)
{
    chomp;
    print "Line: $_\n" if $debug;
    if (/^(\d+) minutes of Internet freedom/)
    {
        die "Already found a time! ($addltime) vs ($1) [$_]" if $addltime;
        $addltime = $1;
        $addltime *= 60;
        print "Found time: $addltime secs [$_]\n" if $debug;
    }
    if (/^(\w+) wants:$/)
    {
        die "Already found a user! ($user) vs ($1) [$_]" if $user;
        $user = $1;
        $user = lc($user);
        print "Found user: '$user' [$_]\n" if $debug;
    }
}

die "No time found"  unless ($addltime);
die "No user found" unless ($user);
die "software not written" if $debug;

# Connect to database
$dbh = DBI->connect("DBI:Pg:dbname=pfm;host=localhost", "pgsql", "", {'RaiseError' => 1});
$dbh->do("UPDATE pfm SET timeleft = timeleft + $addltime WHERE login = '$user'");
syslog (LOG_INFO, "$user: Added $addltime seconds");
$dbh->disconnect();
