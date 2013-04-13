Perl-GPIR-Generator
===================

Generates GPRM IR code from a Perl script.

## Purpose

GPIR (GPRM IR) is an S-expression based intermediate representation language that runs on the Glasgow Parallel Reduction Machine (GPRM) framework for task-level parallel programming. The purpose of the Perl GPIR generator is, as the name
suggests, to generate GPIR from Perl.

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

And the following .yml configuration:

    --- # GPRM Configuration for docfilter
     System:
     Version: 3.0
     Libraries: [Ctrl,DocFilter]
     NServiceNodes: 10
     ServiceNodes:
        c0: [ 0, [ Ctrl.Ctrl ] ]
        c1: [ 1, [ DocFilter.DocFilter ] ]
        c2: [ 2, [ DocFilter.DocFilter ] ]
        c3: [ 3, [ DocFilter.DocFilter ] ]
        c4: [ 4, [ DocFilter.DocFilter ] ]
        c5: [ 5, [ DocFilter.DocFilter ] ]
        c6: [ 6, [ DocFilter.DocFilter ] ]
        c7: [ 7, [ DocFilter.DocFilter ] ]
        c8: [ 8, [ DocFilter.DocFilter ] ]
        c9: [ 9, [ DocFilter.DocFilter ] ]

## Implementation

The `use GPRM` reads the source, transforms it, and then uses exec() to call perl on the new code. The GPRM::* modules do not exist, stubs are created to keep Perl happy.
What happens is that a call to any method of any GPRM::* class uses GPRM's AUTOLOAD to generate the code in the GPIR language.

The Perl source is parsed and transformed using [PPI](https://metacpan.org/module/PPI).
The modules `PPI::Visitors` and `PPI::Generators` are general-purpose. The first provides a tree walker that takes a hash of node transformations and a context. The second provides a number of functions to generate PPI nodes and often-used compounds like method calls. 

The Perl source code transformations required for GPRM are in `GPRM::Transformer`. The GPIR and .yml generations is done in `GPRM`.


