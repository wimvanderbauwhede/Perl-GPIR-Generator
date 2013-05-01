use warnings;
use strict;
use 5.010;

package GPRM::Const;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@GPRM::Const::ISA = qw(Exporter);

@GPRM::Const::EXPORT = qw();

sub new {
	my $that  = shift;
	my $id = (@_)?(shift @_):0;
# This is very ad-hoc, and also the naming is different from the other services
# Also, I'd like to be able to set the instance index ...    
    return "(c0.OclGPRM.MEM.const '$id)";
}

1;


