#!/usr/bin/perl
# The script transforms Perl into GPRM-compatible Perl
# It's mainly for debugging the transformations

use warnings;
use strict;
use 5.010;
use GPRM::PPI::Transformer qw( transform );

use Getopt::Std;
    
my %opts;
getopts( 'hvdp', \%opts );

if ( $opts{'h'} ) {
die " $0 [-v -d <Perl source file>]
	-v : verbose
	-d : print source with PPI::Dumper and exit
	-p : print final source with PPI::Dumper
";
}

$PPI::Visitors::verbose= ($opts{'v'}) ? 1: 0;
my $pp = ($opts{'p'})?1:0;
my $srcfile='matops.pl';
if (@ARGV && $ARGV[0] =~/\.pl$/) {
	$srcfile=$ARGV[0];
} elsif (@ARGV && $ARGV[1] =~/\.pl$/) {
	$srcfile=$ARGV[1];
}

if ($opts{'d'} ) {
	use PPI;
	my $doc= PPI::Document->new($srcfile);
	use PPI::Dumper;
	my $dumper = PPI::Dumper->new($doc);
	$dumper->print;
	exit;
}
say '=off';
my $tf_src=transform($srcfile,$pp);	
say '=cut';
say '#' x 80;
say $tf_src;
