use warnings;
use strict;
use 5.010;
=pod
This package provides a number of handy generators for the key PPI nodes and some often-used compound statements
=cut
package PPI::Generators;
use PPI;
use Data::Dumper;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@PPI::Generators::ISA = qw(Exporter);

@PPI::Generators::EXPORT = qw(
_word 
_method 
_my 
_new 
_nl 
_ws 
_semi 
_struct 
_sym 
_is 
_arrow 
_comma 
_var 
_num 
_arglist 
_do
_block
__inst 
_method_call 
_operator_expr 
_simple_statement 
_expression 
_comment
		);		

sub _word {
	my $kw=shift;
	return PPI::Token::Word->new($kw);			
}

sub _method {
    return _word(@_);
}

sub _my {
	return PPI::Token::Word->new('my');			
}

sub _new {
	return _word('new');
}

sub _nl {
	return PPI::Token::Whitespace->new("\n");
}

sub _ws {
return  PPI::Token::Whitespace->new(' ');
}

sub _semi {
	return PPI::Token::Structure->new(';');
	}

sub _struct {
	(my $char) = @_;
	return PPI::Token::Structure->new($char);

}	

sub _sym {
	my $name = shift;
	return PPI::Token::Symbol->new($name);
}			

sub _is {
	return PPI::Token::Operator->new('=');
}

sub _arrow {
	return PPI::Token::Operator->new('->');
}

sub _comma {
	return PPI::Token::Operator->new(',');
}

sub _var {
	(my $name, my $rhs) = @_;
			my $var_node = PPI::Statement::Variable->new();			
			$var_node->{children}=[_my(),_ws(),_sym($name),_is(),@{$rhs},_semi()];
	return $var_node;
}

sub _num {
    my $val = shift;
    return PPI::Token::Number->new($val);
}

sub _comment {
	my $str = shift;
	return PPI::Token::Comment->new('# '.$str);
}

## Compound generators
# PPI::Structure::List, argument list
# If @arg contains PPI::Token::Operator ',' the @args will be used as-is
sub _arglist {
    my @args=@_;
    my $arglist = PPI::Structure::List->new(); # NOTE: this does not work! That's why there is the call to bless() later on. Why?
    $arglist->{start}=_struct('(');
    $arglist->{finish}=_struct(')');
    my @operators = grep {ref($_) eq 'PPI::Token::Operator' } @args; 
    my @commas = grep { $_->content eq ',' } @operators;
    if (@commas) {
        $arglist->{children}=[@args];
    } else {
        $arglist->{children}=(scalar @args  > 1) ? [ _operator_expr(_comma(),[@args]) ] :(scalar @args == 1) ? [ $args[0] ] : [];
    }
    bless($arglist,'PPI::Structure::List');
    return $arglist;
}

sub _do { (my @args)=@_; # a list of nodes
    my $do_block = PPI::Statement::Expression->new();
    $do_block->{children}=[ _word('do'),_ws(),_block(@args)];
    bless($do_block,'PPI::Statement::Expression');
    return $do_block;
}

sub _block { (my @statements)=@_;  # a list of nodes, should be simple statements
    my $bare_block = new PPI::Structure::Block;
    $bare_block->{start} = _struct('{');
    $bare_block->{finish}= _struct('}');
    $bare_block->{children }=[@statements];
    bless($bare_block,'PPI::Structure::Block');
#        die Dumper($bare_block);

    return $bare_block;
}

# this is not a node! it returns a list of nodes, hence __ instead of _
sub __inst {
	(my $class, my $args)=@_;
    my $argl =  defined $args ? _arglist($args) : _arglist();
	my $lstref= [_new(),_ws(),_word($class),$argl];
	return $lstref;
}
# PPI::Statement::Expression, method call
sub _method_call {
	(my $inst, my $meth, my $args) = @_;
    my $argl =  defined $args ? _arglist(@{$args}) : _arglist();
	my $lstref= [_sym($inst),_arrow(),_word($meth),$argl];
	my $meth_call = PPI::Statement::Expression->new();
	$meth_call->{children}=$lstref;
	bless($meth_call,'PPI::Statement::Expression');
	return $meth_call;
}

# PPI::Statement::Expression, operator expression, i.e. fold operator args
sub _operator_expr {
    (my $op, my $args) = @_; # so args is a list ref
    my $op_expr= PPI::Statement::Expression->new();
    $op_expr->{children}->[0]=shift @{$args};
    for my $arg ( @{ $args }) {
        push @{ $op_expr->{children} }, $op;
        push @{ $op_expr->{children} }, $arg;
    }
    bless($op_expr,'PPI::Statement::Expression');
    return $op_expr;
}

# Convert PPI::Statement::Expression to PPI::Statement
sub _simple_statement { (my $expr)=@_;
	my $simple_stat = PPI::Statement->new();
	$simple_stat->{children}=[ @{ $expr->{children} }];
	push @{$simple_stat->{children}},_semi();
    bless($simple_stat,'PPI::Statement');
	return $simple_stat->clone();
}

# Convert PPI::Statement to PPI::Statement::Expression 
sub _expression { (my $simple_stat)=@_;
    my $expr={};
    $expr->{children}= [ @{ $simple_stat->{children} } ];
    if ($expr->{children}[-1]->content eq ';') {
        pop @{$expr->{children}};
    }
    bless($expr,'PPI::Statement::Expression');
    return $expr->clone();
}

1;
