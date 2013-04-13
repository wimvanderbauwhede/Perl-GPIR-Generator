#!/usr/bin/perl
use warnings;
use strict;
# Example script to generate GPIR using the GPRM class

# A simplifying assumption: every library contains one class of the same name
use GPRM;
use GPRM::DocFilter;

my @dfs = map {new GPRM::DocFilter($_)} 1..8;
my $df2 = new GPRM::DocFilter(9);

    {
        my @vals;
        for my $i (1..8) {
            push @vals, $dfs[$i-1]->score($i)
        }   
        $df2->aggregate(@vals);
    }

