#!/usr/bin/perl
use warnings;
use strict;
use 5.010;

use PPI;
use PPI::Dumper;
use Data::Dumper;
use PPI::Analysis ;
use GPRM::PPI::Analysis ;

my $str= << 'ENDQ';
{
$mm1->sum($GPRM::A,$GPRM::B,$i);
$mm2->sum($GPRM::A,$GPRM::B,$i);
}
# -----------------------------
do {
$mm1->sum($GPRM::A,$GPRM::B,$i);
$mm2->sum($GPRM::A,$GPRM::B,$i);
};
# -----------------------------

my $res = do {
$mm1->sum($GPRM::A,$GPRM::B,$i);
$mm2->sum($GPRM::A,$GPRM::B,$i);
};
# -----------------------------
while (1) {
$mm3->sum($GPRM::A,$GPRM::B,$i);
$mm4->sum($GPRM::A,$GPRM::B,$i);
}
# -----------------------------

$ctrl->par(
$mm1->sum($GPRM::A,$GPRM::B,$i),
$mm2->sum($GPRM::A,$GPRM::B,$i)
);
ENDQ

my $snip =PPI::Document->new(\$str);
my $pp = PPI::Dumper->new($snip);
$pp->print;
#say Dumper($snip);
die;
my $node = $snip->schild(0);
say ref($node);
PPI::Dumper->new($node)->print;

#say $node->schild(2)->content;

#my $node2= $snip->schild(1);
#say ref($node2);#->schild(2)->content;


#my @res= grep { is_assign_op($_) } @{ $node->{children} };
say is_assignment($node);
say is_gprm_var_write($node);
say is_bare_block($node);
#say is_do_block($node2);
