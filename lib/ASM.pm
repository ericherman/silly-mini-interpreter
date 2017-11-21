package ASM;
use 5.14.2;
use warnings;
use Scalar::Util qw(blessed);
use Carp ();

our @Constants;
use ASM::Enum;

SCOPE: {
    our $i;
    BEGIN { $i = 0 }
    use constant {
        map { $_ => $i++ }
        @Constants
    };
    undef($i);
}

our @EXPORT_OK;
BEGIN {
    # also added to futher down
    push @EXPORT_OK, (qw(
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
            emit_exit
            make_label
            resolve_label
            backpatch
        ),
        @Constants
    );
}
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

sub _emit_cmd_uint {
    my ($obj, $cmd, @data) = @_;
    my $pos = write_uint8($cmd);
    write_uint32(shift @data);
    return $pos;
}

sub _emit_cmd_uint_int {
    my ($obj, $cmd, @data) = @_;
    my $pos = write_uint8($cmd);
    write_uint32(shift @data);
    write_int32(shift @data);
    return $pos;
}

sub _emit_cmd_uint_uint {
    my ($obj, $cmd, @data) = @_;
    my $pos = write_uint8($cmd);
    write_uint32(shift @data);
    write_uint32(shift @data);
    return $pos;
}

sub _emit_cmd_uint_uint_int {
    my ($obj, $cmd, @data) = @_;
    my $pos = write_uint8($cmd);
    write_uint32(shift @data) for 1..2;
    write_int32(shift @data);
    return $pos;
}

sub _emit_cmd_uint_uint_uint {
    my ($obj, $cmd, @data) = @_;
    my $pos = write_uint8($cmd);
    write_uint32(shift @data) for 1..3;
    return $pos;
}

# TODO replace with proper code gen from an instruction spec at some point
BEGIN {
    for (["addconst", "uint_int"],
         ["addrel", "uint_uint"],
         ["subconst", "uint_int"],
         ["subrel", "uint_uint"],
         ["mulconst", "uint_int"],
         ["mulrel", "uint_uint"],
         ["divconst", "uint_int"],
         ["divrel", "uint_uint"],
         ["modconst", "uint_int"],
         ["modrel", "uint_uint"],
         ["movconst", "uint_int"],
         ["movrel", "uint_uint"],
         ["jump", "uint"],
         ["jumpz", "uint_uint"],
         ["jumpnz", "uint_uint"],
         ["jumpeqconst", "uint_uint_int"],
         ["eqconst", "uint_uint_int"],
         ["eqrel", "uint_uint_uint"],
         ["print", "uint"],
    ) {
        my ($name, $types) = @$_;
        my $caps = uc($name);
        my $count =()=  $types =~ /_/g;
        $count++;
        my $proto = '$' x $count;

        my $code = qq{
            sub emit_$name ($proto) {
                my (\$obj, \@data) = \&intuit_params;
                return \$obj->_emit_cmd_$types(IC_$caps, \@data);
            }
            push \@EXPORT_OK, 'emit_$name';
            1
        };
        eval $code or die "Failed to eval code: $@";
    }
}

sub emit_padding () {
    my ($obj, @data) = &intuit_params;
    return $obj->write_uint8(IC_PADDING);
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

    return $label if defined $label and $label =~ /^[0-9]+$/;

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
