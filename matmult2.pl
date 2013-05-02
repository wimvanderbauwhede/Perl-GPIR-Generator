#!/usr/bin/perl
use warnings;
use strict;

my $NTH=8;
my $SZ=1024;

use GPRM;
use GPRM::Mat;
my @mm=  map { new GPRM::Mat($_) } 0 .. $NTH -1 ;


my $A = new GPRM::Buf(0);
my $B =  new GPRM::Buf(1);
my $C = new GPRM::Const(2);
GPRM::main();


sub GPRM::main {
    map { $mm[$_]->mult($A, $B, $C, $SZ) } 0.. $NTH -1;
#    $mm[0]->add($A, $B, $C, $SZ);
}
