#!perl
use 5.14.2;
use warnings;

SCOPE: {
  our $x;
  BEGIN { $x = 0; }
  use constant {
    map { $_ => $x++ }
    qw(
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
    )
  };
  $x = undef;
}

my $Output = "";

sub uint32 { pack("L", shift) }
sub int32 { pack("l", shift) }
sub uint8 { pack("C", shift) }

sub write_uint32 {
  $Output .= uint32(shift);
}

sub write_int32 {
  $Output .= int32(shift);
}

sub write_uint8 {
  $Output .= uint8(shift);
}

sub pad {
  my $pos = length($Output);
  write_uint8(IC_PADDING);
  return $pos;
}

sub addconst {
  my $pos = length($Output);
  write_uint8(IC_ADDCONST);
  write_uint32(shift);
  write_int32(shift);
  return $pos;
}

sub addrel {
  my $pos = length($Output);
  write_uint8(IC_ADDREL);
  write_uint32(shift);
  write_uint32(shift);
  return $pos;
}

sub subconst {
  my $pos = length($Output);
  write_uint8(IC_SUBCONST);
  write_uint32(shift);
  write_int32(shift);
  return $pos;
}

sub subrel {
  my $pos = length($Output);
  write_uint8(IC_SUBREL);
  write_uint32(shift);
  write_uint32(shift);
  return $pos;
}

sub movconst {
  my $pos = length($Output);
  write_uint8(IC_MOVCONST);
  write_uint32(shift);
  write_int32(shift);
  return $pos;
}

sub movrel {
  my $pos = length($Output);
  write_uint8(IC_MOVREL);
  write_uint32(shift);
  write_uint32(shift);
  return $pos;
}

sub jump {
  my $pos = length($Output);
  write_uint8(IC_JUMP);
  write_uint32(shift);
  return $pos;
}

sub jumpz {
  my $pos = length($Output);
  write_uint8(IC_JUMPZ);
  write_uint32(shift);
  write_uint32(shift);
  return $pos;
}

sub emit_print {
  my $pos = length($Output);
  write_uint8(IC_PRINT);
  write_uint32(shift);
  return $pos;
}

sub make_jump_target {
  return length($Output);
}

my $mem_size = 1000;

addconst(0, 100);
my $loop_lbl = make_jump_target();
addconst(1, 2);
subconst(0, 1);

my $tmp = jumpz(2e9, 0);
jump($loop_lbl);
my $done_lbl = emit_print(0);
emit_print(1);

# backpatching
substr($Output, $tmp+1, 4, uint32($done_lbl));

print pack("L", $mem_size) . $Output;

