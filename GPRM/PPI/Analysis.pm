use warnings;
use strict;
use 5.010;
=pod
This package provides a number of handy tests for the key PPI nodes and some often-used compound statements
I call it "Analysis" rather than "Tests" to avoid confusion.
Not all of these are context-free.
=cut
package GPRM::PPI::Analysis;
use PPI;
use PPI::Analysis;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@GPRM::PPI::Analysis::ISA = qw(Exporter);

@GPRM::PPI::Analysis::EXPORT = qw(
is_gprm_var_write
is_gprm_var
is_reg_write
is_reg_read
is_service_call
service_class
);


sub is_gprm_var_write { (my $node) = @_;
    my $node_type = ref($node);
    if (is_assignment($node) and
    var_name($node) =~/GPRM::/
    ) {
    	return 1;
    }
    return 0;
}

sub is_gprm_var { (my $node) = @_;
    my $node_type = ref($node);
    if ($node_type eq 'PPI::Token::Symbol'
    and $node->content =~/GPRM::/
    ) {
    	return 1;
    }
    return 0;
}


sub is_reg_write { (my $node, my $ctxt) = @_;
    my $node_type = ref($node);
    if (is_service_call($node,$ctxt) and
    service_class($node,$ctxt) eq 'Reg' and
    method_name($node) eq 'write'     
    ) {
    	return 1;
    }
    return 0;
}

sub is_reg_read { (my $node, my $ctxt) = @_;
    my $node_type = ref($node);
 if (is_service_call($node,$ctxt) and
   service_class($node,$ctxt) eq 'Reg' and
    method_name($node) eq 'read'     
    ) {
        return 1;
    }   
    return 0;
}

sub is_service_call { (my $node, my $ctxt) = @_;
	if (is_method_call($node) ){
		if (exists $ctxt->{service_instances}->{instance_name($node)}) {
			return 1;
		}
	}  
    return 0;
}

sub service_class { (my $node, my $ctxt) = @_;
    return $ctxt->{service_instances}=>{instance_name($node)}	
}