#!/usr/bin/perl -w
use strict;
use Getopt::Std;

# $Id: pfm.pl,v 1.2 2014/07/06 17:57:11 jepace Exp $
#
# pfm.pl - PF Monster command line utility
#
# Usage:
#	pfm.pl <user> <on|off> - Turn on or off full Internet access for user <user>
#
# TODO
#	Display state of database
#	Add or reduce time for a user
#	Destroy and regenerate database

# $1 is user
# $2 is on or off

# echo "pass from <ip_jepaceace> to any keep state" | pfctl -a pfm_jepace -f -
# to close: pfctl -a pfm_jepaceace -Fr
# to see status: pfctl -a pfm_jepaceace -sr

my $user;
my $state;
my $cmd;
my %arg;
my ($verbose, $debug);

getopts ("dvh", \%arg);
$verbose++ if $arg{v};
$debug++ if $arg{d};

$user = shift;
$state = shift;
print "$0: User: '$user' State: '$state'\n";

die "Usage: $0 <user> <on|off>" unless (($state =~ "on") || ($state =~ "off"));

if ($state =~ "on")
{
    $cmd = "echo \"pass from <ip_$user> to any keep state\" | pfctl -a pfm_$user -f -";
} elsif ($state =~ "off" )
{
    $cmd = "pfctl -a pfm_$user -Fr"
}
else
{
    die "Usage: $0 <user> <on|off>";
}
print "Cmd: $cmd\n";
`$cmd` unless $debug;
