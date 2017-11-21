package ASM;
use 5.14.2;
use warnings;
use Scalar::Util qw(blessed);
use Carp ();

our @Constants;
BEGIN {
    @Constants = qw(
        IC_PADDING
        IC_ADDCONST
        IC_ADDREL
        IC_SUBCONST
        IC_SUBREL
        IC_MOVCONST
        IC_MOVREL
        IC_JUMP
        IC_JUMPZ
        IC_PRINT
        IC_EXIT
    );
}

SCOPE: {
    our $i;
    BEGIN { $i = 0 }
    use constant {
        map { $_ => $i++ }
        @Constants
    };
    undef($i);
}

our @EXPORT_OK = (qw(
        uint32
        int32
        uint8
        asm
        memsize
        position
        write_uint32
        write_int32
        write_uint8
        emit_padding
        emit_addconst
        emit_addrel
        emit_subconst
        emit_subrel
        emit_movconst
        emit_movrel
        emit_jump
        emit_jumpz
        emit_print
        emit_exit
        make_label
        resolve_label
        backpatch
    ),
    @Constants
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use Exporter 'import';

our $Obj;

sub new {
    my $class = shift;
    return bless {
        memsize => 100,
        @_,
        output => "",
        labels => {},
    } => $class;
}

sub generate {
    my ($self) = @_;
    return uint32($self->memsize) . $self->{output};
}

sub len {
    my ($self) = @_;
    return length($self->{output});
}

sub asm (&) {
    local $Obj = ASM->new;
    $_[0]->();
    return $Obj;
}

sub uint32 { pack("L", shift) }
sub int32 { pack("l", shift) }
sub uint8 { pack("C", shift) }

sub intuit_params {
    my ($obj, @data) = @_;

    if (!blessed($obj) || !$obj->isa('ASM')) {
        unshift @data, $obj;
        $obj = $Obj;
    }

    return($obj, @data);
}

sub position () {
    my ($obj) = &intuit_params;
    return $obj->len;
}

sub memsize (;$) {
    my ($obj, @data) = &intuit_params;
    $obj->{memsize} = shift @data if @data;
    return $obj->{memsize};
}

sub write_uint32 ($) {
    my ($obj, @data) = &intuit_params;
    my $pos = $obj->len;
    $obj->{output} .= uint32($data[0]);
    return $pos;
}

sub write_int32 ($) {
    my ($obj, @data) = &intuit_params;
    my $pos = $obj->len;
    $obj->{output} .= int32($data[0]);
    return $pos;
}

sub write_uint8 ($) {
    my ($obj, @data) = &intuit_params;
    my $pos = $obj->len;
    $obj->{output} .= uint8($data[0]);
    return $pos;
}

sub emit_padding () {
    my ($obj, @data) = &intuit_params;
    return $obj->write_uint8(IC_PADDING);
}

sub emit_addconst ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_ADDCONST);
    write_uint32(shift @data);
    write_int32(shift @data);
    return $pos;
}

sub emit_addrel ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_ADDREL);
    write_uint32(shift @data);
    write_uint32(shift @data);
    return $pos;
}

sub emit_subconst ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_SUBCONST);
    write_uint32(shift @data);
    write_int32(shift @data);
    return $pos;
}

sub emit_subrel ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_SUBREL);
    write_uint32(shift @data);
    write_uint32(shift @data);
    return $pos;
}

sub emit_movconst ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_MOVCONST);
    write_uint32(shift @data);
    write_int32(shift @data);
    return $pos;
}

sub emit_movrel ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_MOVREL);
    write_uint32(shift @data);
    write_uint32(shift @data);
    return $pos;
}

sub emit_jump ($) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_JUMP);
    write_uint32(shift @data);
    return $pos;
}

sub emit_jumpz ($$) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_JUMPZ);
    write_uint32(shift @data);
    write_uint32(shift @data);
    return $pos;
}

sub emit_print ($) {
    my ($obj, @data) = &intuit_params;
    my $pos = write_uint8(IC_PRINT);
    write_uint32(shift @data);
    return $pos;
}

sub emit_exit () {
    my ($obj, @data) = &intuit_params;
    return write_uint8(IC_EXIT);
}

sub make_label ($;$) {
    my ($obj, @data) = &intuit_params;
    my $label = shift @data;
    my $pos = shift @data // $obj->len;

    if (exists $obj->{labels}{$label}) {
        Carp::croak("Trying to redefine label '$label'");
    }
    $obj->{labels}{$label} = $pos;

    return $pos;
}

sub resolve_label ($) {
    my ($obj, @data) = &intuit_params;
    my $label = shift @data;
    if (not exists $obj->{labels}{$label}) {
        Carp::croak("Trying to used unknown label '$label'");
    }
    return $obj->{labels}{$label};
}

sub backpatch ($$) {
    my ($obj, @data) = &intuit_params;
    my ($lbl, $data) = @data;
    my $pos = $obj->resolve_label($lbl);
    substr($obj->{output}, $pos, length($data), $data);
    return();
}


1;
