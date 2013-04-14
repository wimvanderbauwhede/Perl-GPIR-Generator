#!/usr/bin/perl
use warnings;
use strict;
use 5.010;

use GPRM;
use GPRM::MatrixOps;

my @mops = map { new GPRM::MatrixOps($_) } 1..4;

my $W=1024;

my $A=$mops[0]->rnd($W);
my $B=$mops[1]->rnd($W);
my $C=$mops[2]->zero($W);

$mops[3]->mult($A,$B,$C,$W);
