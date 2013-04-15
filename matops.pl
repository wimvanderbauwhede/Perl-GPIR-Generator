#!/usr/bin/perl
use warnings;
use strict;

=pod
(A+B).(C+D)

(begin

(reg.write '2 (mat))
(reg.write '3 (mat))
(reg.write '4 (mat))
(reg.write '5 (mat))

'(reg.write '0 
(begin
map idx 1 .. N (partsum A B idx)
)
)
'(reg.write '1 
(begin
map idx 1 .. N (partsum C D idx)
)
)
'(begin
map idx 1 .. N (partmult (reg.read '0) (reg.read '1) idx)
)
=cut

my $NTH=8;
my $SZ=1024;

use GPRM;
use GPRM::Mat;

my $mm=new GPRM::Mat($SZ,$NTH);

$GPRM::A = $mm->rnd();
$GPRM::B = $mm->rnd();
$GPRM::C = $mm->rnd();
$GPRM::D = $mm->rnd();


use seq;
{
	{
		$GPRM::AB = do {
			foreach my $i (1..$NTH) {
				$mm->sum($GPRM::A,$GPRM::B,$i);
			}
		};
#		$GPRM::AB = $ab;

		my $cd = do {
			foreach my $i (1..$NTH) {
				$mm->sum($GPRM::C,$GPRM::D,$i);
			}
		};
		$GPRM::CD = $cd;
	}

	foreach my $i (1..$NTH) {
		$mm->mult($GPRM::AB,$GPRM::CD,$i);
	}

}

