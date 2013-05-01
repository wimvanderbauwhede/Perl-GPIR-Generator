use warnings;
use strict;
use 5.010;

package GPRM::Buf;

use vars qw( $VERSION );
$VERSION = "1.0.0";

use Exporter;

@GPRM::Buf::ISA = qw(Exporter);

@GPRM::Buf::EXPORT = qw();

sub new {
	my $that  = shift;
	my $id = (@_)?(shift @_):0;
#	my $class = ref($that) || $that;
#	my $self  = {
#		id => $id               
#	};
#bless $self, $class;
    return "(c0.OclGPRM.MEM.ptr '$id)";
}

1;


