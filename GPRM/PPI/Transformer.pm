use warnings;
use strict;
use 5.010;

package GPRM::PPI::Transformer;

use PPI;
use PPI::Visitors qw(visit_tree visit_toplevel $verbose );
use PPI::Generators;
use PPI::Analysis qw( nchildren );

use PPI::Dumper;
use Data::Dumper;
$Data::Dumper::Indent=1;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@GPRM::PPI::Transformer::ISA = qw(Exporter);

@GPRM::PPI::Transformer::EXPORT_OK = qw(
  transform
);

#die "FIXME: bare blocks must actually be converted into lists, not do blocks!
#same for do blocks, assigned or not. Basically, every ';' must become a ','
#";


sub transform { 
	(my $src, my $pp)=@_;
	my $doc= PPI::Document->new($src);
	my $ctxt = {
		parent => $doc,
		child_index => 0,
		count=>0,
		reg_counter=>1,
		reg_write=>{},
		reg_read=>{},
		scope=>0,
		is_pre=>0,
		is_post=>0,
		is_leaf=>0,
		seq=>0,
        in_main =>0,
        is_statement_list=>0,
		visit_children =>1,
		pars_seq=>{},
		reg_table=>{},
		var_table=>{},
		extra_classes=>{},
		service_instances => {},
		
	};

# First pass it to replace all GPRM:: package vars with registers
# Second pass is to create a BEGIN around all for/foreach/while loops
# Third pass is to add extra modules and instances at top level

	my $node_ops_pass1 = {
        'PPI::Token::Comment' => sub {
        	(my $node, my $ctxt) = @_;
            return ([],$ctxt);
        },

        'PPI::Token::Pod' => sub {
        	(my $node, my $ctxt) = @_;
            return ([],$ctxt);
        },
       
		'PPI::Token::Symbol' => sub {
			(my $node, my $ctxt) = @_;
#            say '';
#			if ( $ctxt->{is_pre}==1) {
				if($node->content =~/GPRM\:\:/) {
					my $new_node=$node;
					my $parent = $ctxt->{parent};
					my $idx =$ctxt->{child_index};
#					say 'CONTENT:', $node->content;
#					say 'CALL test_reg';
					(my $reg_status,$ctxt) = test_reg($parent,$node,$idx,$ctxt);
#					say "TEST";
	# what needs to happen is that the parent needs to be transformed
	# so this must be done in POST
	# we just set a global flag
					if ($reg_status == 0 ) { # write reg; 
					   my $reg=$node->content;
						$ctxt->{reg_write}{$reg}=1;
						$ctxt->{reg_read}{$reg}=0;
					} elsif ($reg_status == 1) { # read reg
					my $reg=$node->content;
						$ctxt->{reg_write}{$reg}=0;
						$ctxt->{reg_read}{$reg}=1;
                           $ctxt->{reg_read}{$reg}=0;
                           say "CALL create_reg_read" if $verbose;
                           ($new_node,$ctxt) = create_reg_read($node,$ctxt);	
                           $ctxt->{visit_children}=0;
#                           say Dumper($new_node);					
					} else { # not a reg
#						$ctxt->{reg_write}=0;
#						$ctxt->{reg_read}=0;
					}
					return ([$new_node],$ctxt); # because of this, all transforms must return a list!
				} else {
					return ([$node],$ctxt);
				}
#			} else {# seems we never come here
#                die;
#				if($node->content =~/GPRM::/ && $ctxt->{reg_read}==1) {
#					say 'CREATE REG READ HERE? '.node->content;die;
#				}
#
#				return ([$node],$ctxt);
#			}
		},

		'PPI::Statement' => sub { 
			(my $node, my $ctxt)=@_;
			if ($ctxt->{is_pre}) {
# do nothing
			} else {
				if (exists $node->{children} && @{ $node->{children} } ) {
					if (ref($node->child(0)) eq 'PPI::Token::Symbol') {		
						my $sym=$node->child(0)->content;						
						if (exists $ctxt->{reg_write}{$sym} && $ctxt->{reg_write}{$sym}==1) {
							$ctxt->{reg_write}{$sym}=0;
							($node,$ctxt) = create_reg_write($node, $ctxt);	
							$ctxt->{reg_counter}++;
						}
#						if ($ctxt->{reg_read}==1) {
#							my $child = 
#							$ctxt->{reg_read}=0;
#							($node,$ctxt) = create_reg_read($node,$ctxt);
#						}
					} elsif ($node->child(0)->content eq 'print') {
						$ctxt->{extra_classes}->{IO}=1;
						($node, $ctxt)=create_gprm_print($node,$ctxt);
					} 
				}
			}
			return ([$node],$ctxt);
		},
	};

	my $node_ops_pass2 = {
         'PPI::Statement::Sub' => sub {
        	(my $node, my $ctxt) = @_;
            if ($ctxt->{is_pre}==1) {
                if ($node->schild(1) eq 'GPRM::main') {
                    $ctxt->{in_main}=1;
                }
            } else {
                 $ctxt->{in_main}=0;
            }
            return ([$node],$ctxt);
        },

		'PPI::Statement::Include' => sub { (my $node, my $ctxt)=@_;
			if ($ctxt->{is_post}==1) {
				if ($node->schild(1)->content eq 'seq') {
#					say 'SEQ @ ',$ctxt->{count} ;
                    $node = _comment($node->content);
					$ctxt->{seq}=1;
				}
			}
			return ([$node,_nl()],$ctxt);
		},
		'PPI::Structure::Block' => sub {
			(my $node, my $ctxt)=@_;
			if ($ctxt->{is_pre}==1) {
#				say 'SEQ/PAR for ',$ctxt->{count},':',$ctxt->{seq};
				$ctxt->{par_seq}->{$ctxt->{count}}=$ctxt->{seq};
				$ctxt->{seq}=0;
			} else {
                if ($ctxt->{is_statement_list}==1) {
                    $ctxt->{is_statement_list}=0;
					if (ref($node->{parent}) eq 'PPI::Statement::Compound'
                            and ref($node->{parent}->schild(0)) eq 'PPI::Structure::Block'
                            ) {
					say '--------';
					my $idx = $node->{child_index};
#					PPI::Dumper->new($node->{parent}->child($idx-2))->print;
#					die;
                    my $args=[];
					if ($node->{children}->[-1]->content eq ',') {
						pop @{ $node->{children} };
					}
					my $j=-1;
					while (ref($node->{children}->[$j]) eq 'PPI::Token::Whitespace')  {
						pop @{ $node->{children} };
					}
					if ($node->{children}->[-1]->content eq ',') {
						pop @{ $node->{children} };
					}
                    for my $child (@{ $node->{children} }) {
#                       print '*** ';
#                     PPI::Dumper->new($child)->print;
                     push @{$args}, $child->clone();
                    }                                        
					my $seq = $ctxt->{par_seq}->{$ctxt->{count}};
					my $par_or_seq = $seq ? 'seq':'par';
					$ctxt->{seq}=0;
                     $ctxt->{extra_classes}->{Ctrl}=1;
                    my $new_node=_method_call('$_GPRM_ctrl',$par_or_seq,$args);                    
#  PPI::Dumper->new($new_node)->print;
#say $new_node->content; 
                    return ([$new_node,_comma()],$ctxt);
					}
                }
            }
			return ([$node],$ctxt);
		},
		'PPI::Statement::Compound' => sub {
			(my $node, my $ctxt)=@_;        
            if ($ctxt->{is_pre}==1) {
				$ctxt->{par_seq}->{$ctxt->{count}}=$ctxt->{seq};
#$ctxt->{seq}=0;
			}
			if ($ctxt->{is_post}==1) {
				if (ref($node->schild(0)) eq 'PPI::Statement::Expression'
						and nchildren($node)==1) {
					return ([$node->schild(0)->clone()],$ctxt);
				} else {
				(my $tf_node,$ctxt) = wrap_foreach($node,$ctxt);
				$ctxt->{seq}=0;
				return ([$tf_node,_comma()],$ctxt);
				}
			} else {
				return ([$node],$ctxt);
			}
		},
        'PPI::Statement' => sub {	
            (my $node, my $ctxt)=@_;
    	if ($ctxt->{is_post}==1 and $ctxt->{in_main}==1) {
			
            # PPI::Statement is always a 'Simple Statement' 
			# We can 
            if ($node->{children}->[-1] eq ';') {
                $node->{children}->[-1] = _comma();                
            }
            $ctxt->{is_statement_list}=1;
#            say 'LIST: '; map { PPI::Dumper->new($_)->print } @{$node->{children} };say '--------';
            my $new_nodes = [  map { $_->clone() } @{$node->{children} } ];
            return ($new_nodes,$ctxt);
        } else {
        	return ([$node],$ctxt);
        }
        },

        'PPI::Statement::Variable' => sub {
         (my $node, my $ctxt)=@_;
    	if ($ctxt->{is_post}==1 and $ctxt->{in_main}==1) {
			
            # PPI::Statement::Variable, OK to put into list?
            if ($node->{children}->[-1] eq ';') {
                $node->{children}->[-1] = _comma();                
            }
            $ctxt->{is_statement_list}=1;
#            say 'LIST: '; map { PPI::Dumper->new($_)->print } @{$node->{children} };say '--------';
            my $new_nodes = [  map { $_->clone() } @{$node->{children} } ];
            return ($new_nodes,$ctxt);
        } else {
        	return ([$node],$ctxt);
        }
        },


	};

	my $node_ops_pass3 = {

		'PPI::Statement::Variable::OFF' => sub { 
			(my $node, my $ctxt)=@_;
			print Dumper($node);
			return ([$node],$ctxt);
		},
		'PPI::Statement::OFF' => sub {
			(my $node, my $ctxt)=@_;

			if ($node->content =~/GPRM::/) {
				print Dumper($node);
			}
			return ([$node],$ctxt);
		},
		'PPI::Statement::Include' => sub { (my $node, my $ctxt)=@_;
			my $new_toplevel_nodes = [ $node->clone() ];
			if ($node->schild(1)->content eq 'GPRM') {
				for my $class ( keys %{ $ctxt->{extra_classes} }) {
					push @{$new_toplevel_nodes}, _nl();
					my $use_decl_node=$node->clone();
					$use_decl_node->{children}[2]->{content}='GPRM::'.$class;
					push @{$new_toplevel_nodes}, $use_decl_node;
					push @{$new_toplevel_nodes}, _nl();
					my $var_node = _var('$_GPRM_'.lc($class), __inst('GPRM::'.$class) );
					if (not -e "GPRM/$class.pm") {
						gen_class($class);
					}
					push @{$new_toplevel_nodes}, $var_node;
				}
			} elsif ($node->schild(1)->content=~/GPRM::(\w+)/) {
				my $obj=$1;
				if (not -e "GPRM/$obj.pm") {
					gen_class($obj);
				}
			}
			return ($new_toplevel_nodes, $ctxt);
		},
	};

	(my $newdocl, $ctxt) = visit_tree($doc, $node_ops_pass1, $ctxt);
	my $newdoc=$newdocl->[0];

	(my $newdocl2, $ctxt) = visit_tree($newdoc, $node_ops_pass2, $ctxt);
	my $newdoc2=$newdocl2->[0];

	(my $newdoc3,$ctxt)=visit_toplevel($newdoc2,$node_ops_pass3,$ctxt);

	if (defined $pp and $pp) {
		PPI::Dumper->new($newdoc3)->print;
		exit;
	}
	my $tf_src = $newdoc3->content;

	return $tf_src;
} # END of transform()

#--------------------------------------------------------------------------------
sub test_reg {
    (my $newnode, my $child, my $i, my $ctxt)= @_;
    my $dbg=0;
    if ($dbg) {
	say '------------';
	PPI::Dumper->new($child)->print;
	say 'PARENT';
	say 'CONTENT: ',$newnode->content;
	print 'DUMPER: ';PPI::Dumper->new($newnode)->print;
    }
    my $nchildren  = scalar @{ $newnode->{children}}; 
    my $reg_status=-1;
    if (ref($child) eq 'PPI::Token::Symbol' && $child->{content} =~/GPRM::/) {
		$ctxt->{extra_classes}{Reg}=1;
		if (not exists $ctxt->{reg_table}->{ $child->{content} } ) {
			say "ADD TO REG TABLE ",$child->{content} if $dbg;
			$ctxt->{reg_table}->{ $child->{content} } = $ctxt->{reg_counter};
		} 
		else {
			say $child->{content} , ' exists in REG TABLE ' if $dbg;
		}
		if ($dbg) {
	say '------------';
		say $i,'<>',$nchildren,' REF:',ref($child),', VAR:',$child->{content};
	say '------------';
		}
		if ($nchildren==1) {
# $i must be the only child!
			die '$i != 0: '.$i,Dumper($child) unless $i==0;
			say "ONLY CHILD, REG READ!" if $dbg;
			$reg_status=1;

		} elsif ($i<$nchildren-1) {
			my $j=1;
			my $child2= ${$newnode->{children}}[$i+$j]; 
			while ($child2->content eq ' ' && $i+$j<$nchildren-1)  {                
				$j++;
				$child2= ${$newnode->{children}}[$i+$j];
#				print "$i SKIP \n";
			}
			if ($child2->content eq '=') { 
				say 'REG WRITE ', $child->content if $dbg;
# This is a GPRM register in write mode, replace the parent! 
				$reg_status=0;
# i.e. set a flag, break out of the loop, and replace $newnode by the actual new code
			} else {
# This is a GPRM register in read mode, replace in-place 
# i.e. replace $child by a different $new_child
                    say "REG READ ",  $child->{content}  if $dbg;
#				say "REG_READ <",  $ctxt->{reg_table}->{ $child->{content} },">:<",$child->{content},">";
				if (not defined  $ctxt->{reg_table}->{ $child->{content} } ) { die Dumper(  $ctxt->{reg_table} ); }
#                    $child->{content}=$child->{content}.'BOOM!!!';
				$reg_status=1;
#                    die;
			}
		}
	}
#	die if $child->content=~/AB/;
	return ($reg_status,$ctxt);
} # END of test_reg()

sub create_reg_write {
	(my $node, my $ctxt)=@_;
	my $var_name = $node->child(0)->content;
	my $reg_counter = $ctxt->{reg_counter};
	if (not exists $ctxt->{reg_table}->{$var_name}) {
		# create an entry, increment the reg counter
		 $ctxt->{reg_table}->{$var_name} = $ctxt->{reg_counter};
		 $ctxt->{reg_counter}++;
	} else {
		$reg_counter= $ctxt->{reg_table}->{$var_name};
	}
	my $args=[_num($reg_counter)];
	my $nchildren = scalar @{ $node->{children} };
#	say "CREATE_REG_WRITE: $nchildren";
	my $statement= new PPI::Statement::Expression;
	$statement->{children}=[];
	if ($nchildren > 3 ) { # rhs is a list 
		my $skip=3;
		for my $child (@{ $node->{children} } ) {
# skip first 2 at least
			if ($skip>1) {
				$skip--;next;
			}
			if (ref($child) ne 'PPI::Token::Whitespace' and ref($child) ne 'PPI::Token::Operator') {
					if ($skip!=0) {
					$skip =0;				
					}
			} else {
				next unless $skip==0;
			}
            if (ref($child) eq 'PPI::Token::Structure' && $child->content eq ';') {
                next;
            }
			push @{$statement->{children}},$child;
		}
		$args=[_num($reg_counter),$statement];
	} else { 
# rhs is a single expression
        die "create_reg_write(): rhs is a single expression";
		$args=[_num($reg_counter), _expression( $node->{children}[2]) ];
	}
	my $new_node=_simple_statement(_method_call('$_GPRM_reg','write',$args));
#	die Dumper($new_node);
#    PPI::Dumper->new($new_node)->print;
#die;
# instead of $v = rhs_expr, we need  $reg->write($reg_count,rhs_expr)
	return ($new_node,$ctxt)
} # END of create_reg_write

sub create_reg_read {
    (my $child, my $ctxt)=@_;
#	say 'CREATE REG READ for '. ref($child).':<'.$child->{content}.'>';
    my $reg = $ctxt->{reg_table}->{ $child->{content} };
    my $reg_read_expr = PPI::Statement::Expression->new();
#    my $new_child=#    die Dumper($new_child);
    $reg_read_expr->{children}=[_sym('$_GPRM_reg'),_arrow(),_method('read'),_arglist(_num($reg))];

    bless($reg_read_expr,'PPI::Statement::Expression');
    return ($reg_read_expr,$ctxt);
} # END of create_reg_read

sub create_gprm_print {
 (my $node, my $ctxt)=@_;
# my $new_node=$node;
#PPI::Dumper->new($node)->print;die;
#remove 'print'
shift @{ $node->{children} };
# anything separated by commas becomes an expression unless it is only a single elt
my @argl=();
my $args=[];
for my $elt (@{ $node->{children} } ) {
#       
    if ( ref($elt) eq 'PPI::Token::Whitespace' ){ 
        next;
    }
    if (
            (ref($elt) eq 'PPI::Token::Operator' && $elt->content eq ',')
            or
             (ref($elt) eq 'PPI::Token::Structure' && $elt->content eq ';')
            ) {
#        say 'PROC ARG';
        if (scalar @argl >1) {
            my $arg = PPI::Statement::Expression->new();
            $arg->{children}=[@argl];
            bless($arg,'PPI::Statement::Expression');
#PPI::Dumper->new($arg)->print;
            push @{$args},$arg;
        } else {
            push @{$args},$argl[0];
        }
            @argl=();
    } else {
#             say 'ARG:', ref($elt),' <',$elt->content,'>';
        push @argl,$elt;
    }
}
#for my $arg (@{$args}) {
#PPI::Dumper->new($arg)->print;
#}
#die;

my $new_node = _simple_statement( _method_call('$_GPRM_io','display',$args));
#PPI::Dumper->new($new_node)->print;
#die;

	return ($new_node,$ctxt)

}

# Create an inventory of all variables, per scope

sub find_variables {
	 (my $node, my $ctxt)=@_;
	 if (ref($node) eq 'PPI::Statement::Variable') {
			my $varname=$node->schild(1);
			my @statement = $node->schildren;
			my $rhs= [@statement[3 .. ((scalar @statement)-1)]];
			$ctxt->{vartable}->{$ctxt->{count}}{$varname}=$rhs;
	 } elsif (ref($node) eq 'PPI::Statement::Compound') {
	   if ($node->schild(0) eq 'for' or $node->schild(0) eq 'foreach') {
			my $varname=$node->schild(2);
			my @statement = $node->schildren;
			my $rhs= [@statement[3 .. ((scalar @statement)-1)]];
			$ctxt->{vartable}->{$ctxt->{count}+1}{$varname}=$rhs;	       
       }	  
	 }     
}


# Find all foreach-loops and wrap a (seq ) or (par ) around them
sub wrap_foreach {
	(my $node, my $ctxt)=@_;
#	say 'PAR_SEQ: ',join(' ', %{$ctxt->{par_seq} }); 

		my $seq = $ctxt->{par_seq}->{$ctxt->{count}};
		
#	say 'SEQ/PAR COUNT:',$ctxt->{count},':',$seq;
    	if ( $node->schild(0) eq 'for' or $node->schild(0) eq 'foreach' or $node->schild(0) eq 'while' ) {
#            die $ctxt->{seq};
#		print 'Found '.$node->schild(0).", creating wrapper\n" if $verbose;
        $ctxt->{extra_classes}->{Ctrl}=1;
		my $str="\t{\n". '$_GPRM_ctrl->'. ($seq==1 ? 'seq' : 'par' ) .'( do {'."\n".$node->content."\n} \n);\n}\n";
#		my $new_doc= new PPI::Document::Fragment(\$str);	  
        my $new_node=_method_call('$_GPRM_ctrl', ($seq==1 ? 'seq' : 'par' ) ,[_do($node)]);
#		my $new_node=$new_doc->schild()->clone();
#        PPI::Dumper->new($new_node)->print;
#        die ref($new_node);
    	return ($new_node,$ctxt);
    } else {
        my $is_bare_block=0;
        my $block;
        for my $child (@{ $node->{children} }) {
            last if ref($child) eq 'PPI::Token::Word';
            next if ref($child) eq 'PPI::Token::Whitespace';
            if (ref($child) eq 'PPI::Structure::Block') {
#            die "BARE BLOCK". $child->content;
            $is_bare_block=1;
            $block=$child->clone();
            last;
            }
        }
        if ($is_bare_block) {
            my @block_content = map { $_->clone() } @{$block->{children}};

# generate a begin/seq around the bare block
# 1. replace the bare block by a do block
#        PPI::Statement::Compound
# whatever
#    PPI::Structure::Block  
#    becomes
#   PPI::Statement
#        PPI::Token::Word  	'do'
#        PPI::Token::Whitespace  	'  '
#        PPI::Structure::Block  	{ ... }
#        my $new_node = PPI::Statement->new();
#        $new_node->{children}=[_word('do'),_ws(),$block,_semi()];
#        bless($new_node,'PPI::Statement');
# 2. wrap this node in a begin/do
        $ctxt->{extra_classes}->{Ctrl}=1;
#		my $str="\t{\n". '$_GPRM_ctrl->'. ($seq==1 ? 'seq' : 'par' ) .'( do {'."\n".$block->content."\n} \n);\n}\n";
#		my $new_doc= new PPI::Document::Fragment(\$str);	  
#		my $new_node=$new_doc->schild()->clone();
        my $new_node=_method_call('$_GPRM_ctrl', ($seq==1 ? 'seq' : 'par' ) ,[@block_content]);
		return ($new_node,$ctxt);
        } else {
		return ($node,$ctxt);
        }
    }
}

	sub gen_class {
		(my $obj)=@_;
		open my $CL,'>', "GPRM/$obj.pm";
		print $CL "package GPRM::${obj};\nuse GPRM;\n\@ISA=(GPRM);\n1;\n";
		close $CL;
	}

1;
