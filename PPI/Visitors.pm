use warnings;
use strict;
use 5.010;
=pod
This package provides a tree-visitor and toplevel-visitor for the PPI document tree.

Both visitors take as argument a PPI:: node, a hash ref to a hash defining the operations to perform on each node, and a hash ref to a hash containing the context for the operations.

The context must at least contain following fields, as they are used by the visitors:

my $ctxt = {
# parent node of the current node
	parent => '',

# index of the child node in the list of children
    child_index => 0, 

# this is a count of the level in the tree, incremented at every recursion, decremented on exit	
    count=>0,	 

# there are two hooks for the code, one is 'PRE', i.e. before recursive descent into the child nodes, and the other is 'POST', i.e. after recursive descent into the child nodes. They are of course mutually exclusive.
	is_post=>0,	
	is_pre=>0,
# Leaf nodes can be checked via this field	
	is_leaf=>0,
}

You can use "create_context" to create this minimal context.

The node operations must have the signature 

     sub {
		 (my $node, my $ctxt)=@_;
		# Your code here
		 return ([$node],$ctxt);
	 }

For example:

$node_ops = {

# print out every symbol
     'PPI::Token::Symbol' => sub {
		 (my $node, my $ctxt)=@_;
		 say '****','    ' x $ctxt->{count} ,ref($node),': ',$node ;
		 return ([$node],$ctxt);
	 },
# increment every integer
	 'PPI::Token::Number' => sub {
		 (my $node, my $ctxt)=@_;
		 $node->{content}++;
		 return ([$node],$ctxt);
	 }

}
=cut

=damn_vim
=cut

package PPI::Visitors;
#use PPI;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@PPI::Visitors::ISA = qw(Exporter);

@PPI::Visitors::EXPORT_OK = qw(
	&visit_tree
	&visit_toplevel
	&create_context	
	$verbose
);

our $verbose=0;
#--------------------------------------------------------------------------------
sub visit_tree {
    (my $node, my $node_ops, my $ctxt)=@_;
    my $dbg=1;		
    say '>> NODE: ',$node->content, ' PARENT: ',$ctxt->{parent}->content if $dbg;
    my $current=$node->clone();
 
	(my $tf_parent_l, $ctxt) = transform_node_pre($node,$node_ops,$ctxt);	
	
	my $tf_parent_l2=[];
	for my $tf_parent (@{$tf_parent_l}) {
		if (exists $tf_parent->{children}) {
			$ctxt->{is_leaf}=0;
			if($ctxt->{visit_children}==1) {
				say $ctxt->{count},' >>>',"-" x (4*$ctxt->{count}) ,
					  "Visiting all child nodes for NODE ",ref($tf_parent),
					  '-' x (80 - 4*$ctxt->{count} - length(ref($tf_parent))),$ctxt->{count} if $verbose;
#				say "PARENT: ",$tf_parent->content;
				my $i=0; # for look-ahead and look-back
				for my $child ( $tf_parent->children ) {
	                $ctxt->{child_index}=$i;
					say "$i SET PARENT TO ",$current->content if $dbg;
					$ctxt->{parent}=$current; 
					    $ctxt->{count}++;
	                    (my $new_children,$ctxt)=visit_tree($child,$node_ops, $ctxt);
					    $ctxt->{count}--;
					    say "$i POST SET PARENT TO ",$current->content if $dbg;
					    $ctxt->{parent}=$current; 
					$tf_parent->remove_child($child);
					for my $new_child ( @{$new_children} ){
                        print 'ADD: ';PPI::Dumper->new($new_child)->print;
						$tf_parent->add_element($new_child);
					}
					$i++;
				}
				say $ctxt->{count},' <<<'," -" x (2*$ctxt->{count}) ,
					"Visited all child nodes for NODE ",ref($tf_parent),
					' -' x ( (81 - 4*$ctxt->{count} -length(ref($tf_parent)) )/2) ,$ctxt->{count} if $verbose;
			}
			$ctxt->{visit_children}=1;
#            if ( $ctxt->{is_statement_list} == 1 ) {
#                 PPI::Dumper->new($tf_parent)->print ;die;
#                        }
#            say ' BEFORE transform_node_post ';

			(my $tf_parent2, $ctxt) = transform_node_post($tf_parent,$node_ops,$ctxt);
#            say ' AFTER transform_node_post ';
#            map {PPI::Dumper->new($_)->print } @{$tf_parent2};
			$tf_parent_l2 = [@{$tf_parent_l2},@{$tf_parent2}];
		} else {
			$ctxt->{is_leaf}=1;
			push @{$tf_parent_l2},$tf_parent;
		}
	}
	return ($tf_parent_l2,$ctxt);

} # END of visit_tree()
#--------------------------------------------------------------------------------
sub visit_toplevel {
    (my $doc, my $node_ops, my $ctxt)=@_;
    
    my @toplevel_nodes=@{ $doc->{children} };
    my @new_toplevel_nodes=();
    for my $node (@toplevel_nodes) {
        print "TNODE:",ref($node),':',((defined $node) ? $node->content : 'UNDEFINED'),"\n" if $verbose;
        (my $tf_node_l,$ctxt)=transform_node($node,$node_ops,$ctxt);
		for my $tf_node (@{$tf_node_l}) {
	        push @new_toplevel_nodes, $tf_node->clone();
		}
    }
    my $newdoc->{children}=[ @new_toplevel_nodes ];
    bless($newdoc, 'PPI::Document');
    return $newdoc;
}
#--------------------------------------------------------------------------------

sub create_context{ 
	return {
		parent => '',
		child_index => 0, 
		count=>0,	 
		is_post=>0,	
		is_pre=>0,
		is_leaf=>0,
	};

}

#--------------------------------------------------------------------------------
sub transform_node {
	(my $node, my $node_ops, my $ctxt)=@_;
	my $node_type=ref($node);
	my $tf_node=[$node];
	if (exists $node_ops->{$node_type}) {
		($tf_node,$ctxt) = $node_ops->{$node_type}->($node,$ctxt);
	} 
    if ($verbose) {
    map { 	print ' ' x (4*$ctxt->{count}), ref($_), $_->content,"\n" }  @{$tf_node};
    }
	return ($tf_node,$ctxt);
}

sub transform_node_pre {
    (my $node, my $node_ops, my $ctxt)=@_;
	say 'PRE '.ref($node) if $verbose;
    $ctxt->{is_pre}=1;
    $ctxt->{is_post}=0;    
	my $parent = $ctxt->{parent};
	$node->{parent}=$parent;
	$node->{child_index}=$ctxt->{child_index};
	return transform_node($node, $node_ops, $ctxt);
}

sub transform_node_post{
    (my $node, my $node_ops, my $ctxt)=@_;
	say 'POST '.ref($node) if $verbose;
    $ctxt->{is_post}=1;    
    $ctxt->{is_pre}=0;  
	return transform_node($node, $node_ops, $ctxt);
}

1;
