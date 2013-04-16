use GPRM;

use GPRM::Ctrl;
use GPRM::List;
use GPRM::ListProc;

my $NTH=8;
my $lst = GPRM::List->new($NTH+1);
my @proc = map { GPRM::ListProc->new($_) } 1..$NTH;
my $ctrl = new GPRM::Ctrl;
#use seq;
$ctrl->seq( 
$GPRM::ptr = $lst->init(),
do {
my @vals= map {
    my $i=$_-1;
    $proc[$i]->process($GPRM::ptr,$i);
} (1..$NTH);
push @vals, $GPRM::ptr;
$ctrl->par( @vals );
}
}
);
