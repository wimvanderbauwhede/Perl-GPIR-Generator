Perl-GPIR-Generator
===================

Generates GPRM IR code from a Perl script.

## Purpose

GPRM IR is an S-expression language that runs on the Glasgow Parallel Reduction Machine (GPRM) framework for task-level parallel programming.

For example, the following script is used for a parallel document filtering application: 

  use GPRM;
  use GPRM::DocFilter;

  my @dfs = map {new GPRM::DocFilter($_)} 1..8;
  my $df2 = new GPRM::DocFilter(9);
  my $NTH = 8;
  
  {
        my @vals;
        for my $i (1..$NTH) {
            push @vals, $dfs[$i-1]->score($i)
        }
        $df2->aggregate(@vals);
  }
  
Running the script produces following GPIR code:

  ; docfilter.yml
  (label L_1 (c1.DocFilter.DocFilter.score '1))
  (label L_2 (c2.DocFilter.DocFilter.score '2))
  (label L_3 (c3.DocFilter.DocFilter.score '3))
  (label L_4 (c4.DocFilter.DocFilter.score '4))
  (label L_5 (c5.DocFilter.DocFilter.score '5))
  (label L_6 (c6.DocFilter.DocFilter.score '6))
  (label L_7 (c7.DocFilter.DocFilter.score '7))
  (label L_8 (c8.DocFilter.DocFilter.score '8))
  (label L_9 (c0.Ctrl.Ctrl.begin ))
  (label L_10 (c9.DocFilter.DocFilter.aggregate L_1 L_2 L_3 L_4 L_5 L_6 L_7 L_8))
  (label L_11 (c0.Ctrl.Ctrl.begin L_10))

