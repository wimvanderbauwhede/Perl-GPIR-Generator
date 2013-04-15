use warnings;
use strict;
use 5.010;
=pod
This package provides a number of handy tests for the key PPI nodes and some often-used compound statements
I call it "Analysis" rather than "Tests" to avoid confusion.
All of these are context-free to keep them generic.
=cut
package PPI::Analysis;
use PPI;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@PPI::Analysis::ISA = qw(Exporter);

@PPI::Analysis::EXPORT = qw(
is_lexical_decl_with_assignment
is_assignment
var_name
lhs
rhs
is_method_call
method_name
instance_name
is_bare_block
is_do_block
nchildren
has_children
is_leaf
isnon_leaf
is_assign_op
is_arrow_op
);

sub is_lexical_decl_with_assignment { (my $node) = @_;
	my $node_type = ref($node);
	if ($node_type eq 'PPI::Statement::Variable') {
		# variable declaration, can be 'our' or 'my' or 'local'
		if ($node->schild(0)->content eq 'my') {
			# it's a lexical
			if (has_children($node) && $node->schild(2)->content eq '=') {
				# it's an assignment
				return 1;
			} 
		} 
	} 
	return 0;
}

sub is_assignment { (my $node) = @_;
    my $node_type = ref($node);
    if ($node_type eq 'PPI::Statement') {
    	my @res= grep { is_assign_op($_) } @{ $node->{children} };
    	return (scalar @res == 1);
    } 
    return 0;
}

sub var_name { (my $node) = @_;
	if (ref($node->schild(0) ) eq 'PPI::Token::Symbol') {
		return $node->schild(0)->content;
	} elsif (
	   ref( $node->schild(0) ) eq 'PPI::Token::Word' and 
	   ref( $node->schild(1) ) eq 'PPI::Token::Symbol') {
	   	return $node->schild(1)->content;
	}
}

sub lhs { (my $node) = @_;
	my $node_type = ref($node);
	my $lhs_elts=[];
	for my $child (@{ $node->children }) {
		last if ($child->content eq '=');
		push @{$lhs_elts}, $child;
	}
    return $lhs_elts;
}

sub rhs { (my $node) = @_;
    my $node_type = ref($node);
    my $rhs_elts=[];
    my $skip=1;
    for my $child (@{ $node->children }) {
    	
        if ($child->content eq '=') {$skip=0; next}
        next if $skip;
        push @{$rhs_elts}, $child;
    }
    return $rhs_elts;    
}

sub is_method_call { (my $node) = @_;
	  my $node_type = ref($node);
    if ($node_type eq 'PPI::Statement') {
    	if (is_arrow_op($node->child(1))
    	or is_arrow_op($node->child(2))
    	) {
    		return 1;
    	}
    }
    return 0;
}


sub method_name { (my $node) = @_;
	return $node->schild(2)->content;
}

sub instance_name { (my $node) = @_;
	return $node->schild(0)->content;
}


sub is_bare_block { (my $node) = @_;
    my $node_type = ref($node);
    if ($node_type eq 'PPI::Statement::Compound'
    and ref($node->schild(0) ) eq 'PPI::Structure::Block') {
    	return 1;
    }
    return 0;
}

sub is_do_block { (my $node) = @_;
    my $node_type = ref($node);
    if ($node_type eq 'PPI::Statement'
    and ref($node->schild(0) ) eq 'PPI::Token::Word'
    and $node->schild(0)->content eq 'do'
    ) {
        return 1;
    }
    return 0;
}

# --------------------------------------------------------------------------------
sub nchildren {
	(my $node) = @_;
	if (exists $node->{children} ) {
	   return scalar @{ $node->{children} };
	}
}

sub has_children {
    (my $node) = @_;
    return (nchildren($node)>0);
}

sub is_leaf {
    (my $node) = @_;
    return (not exists $node->{children} );
}

sub is_non_leaf {
    (my $node) = @_;
    return (exists $node->{children} );
}

sub is_assign_op {
	 (my $node) = @_;
	return (ref($node) eq 'PPI::Token::Operator' && $node->content eq '=');
}

sub is_arrow_op {
     (my $node) = @_;
    return (ref($node) eq 'PPI::Token::Operator' && $node->content eq '->');
}