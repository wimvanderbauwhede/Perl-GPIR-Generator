package GPRM;

use GPRM::Buf;
use GPRM::Const;

#BEGIN {
use GPRM::PPI::Transformer qw( transform );
	my $caller = $0;
	my @objs = ();
	my %vars=();
	my $regcounter=0;
	if ($caller!~/_PROC_GPRM_/) {
		my $tf_src=transform($caller);	
#		die 'BOO!';
#		print $tf_src;	die;
		my @caller_path=split(/\//,$caller);
		$caller_path[-1]='_PROC_GPRM_'.$caller_path[-1];
		my $proc_caller = join('/',@caller_path);
		open my $PSCR,'>',$proc_caller ;
		print $PSCR $tf_src;		
		close $PSCR;
        print "EXEC\n";
		exec("perl $proc_caller");

	} # END of test if source had been preprocessed
#}
our $counter = 0;
our $code='';
our %tiles = ();
our %libs=();

sub new {
	my $that  = shift;
	my $id = (@_)?(shift @_):0;
	my $class = ref($that) || $that;
	my $self  = {
		id => $id               
	};
	my $lib=$class;
	$lib=~s/GPRM:://;        
		$libs{$lib}=1;
	bless $self, $class;
	return $self;
}

sub AUTOLOAD {
	my $self = shift;        
	my $name = $AUTOLOAD;
    my $lib = 'OclGPRM'; # TODO: find some way of providing the library name
    print "NAME: $name\n";
	(my $gprm,my $class, my $method)=split('::',$name);
    my $uc_class=uc($class);
    my $lib_class="$lib.$uc_class";
	my @args=@_;
	my @proc_args;
	if ($class eq 'Ctrl' && $method eq 'seq') {
		for my $arg (@args) {
			push @proc_args, "'$arg";
		}
	} else {
		for my $arg (@args) {
			push @proc_args, ($arg=~/^\d/)? "'$arg":$arg;
		}
	}
	my $tid=$self->{id};
	my $fqn="c$tid.$lib_class.$method";
	$counter++;
	if (not exists $tiles{"c$tid"} ) { 
		$tiles{"c$tid"}=[$tid,{$lib_class => 1}];
	} else {
		$tiles{"c$tid"}->[1]->{$lib_class}=1;            
	}
	$code.= "(label L_$counter ($fqn ".join(' ',@proc_args).'))'."\n";

	return 'L_'.$counter;
}

sub DESTROY {
	if ($counter!=0) {
		$counter=0;
		genAppConfig ();
	}
}

sub genAppConfig () {
	my $fn=$0;
	$fn=~s/\.pl//;
	$fn=~s/_PROC_GPRM_//;

	open my $TD, '>',"$fn.td";
	print $TD "; $fn.yml\n";
	print $TD $GPRM::code;
	close $TD;

	my $ntiles = scalar keys %tiles;
	my $libs = join(',',keys %libs);

	open my $YML, '>',"$fn.yml";
	print $YML "--- # GPRM Configuration for $fn\n System:\n Version: 3.0\n Libraries: [$libs]\n NServiceNodes: $ntiles\n ServiceNodes:\n";         
	for my $k (sort keys %tiles) {
		my $v = $tiles{$k};
		print $YML "    $k: [ ".$v->[0].", [ ".join(', ',keys %{$v->[1]} )." ] ]\n";
	} 
	print $YML "\n";
	close $YML;    

	unlink $0 if $0=~/_PROC_GPRM_/;
}

1;
