#!perl
use 5.14.2;
use warnings;
use Data::Dumper;

use lib 'lib';
use ASM qw(:all);

my $asm = asm {
    memsize 1000;

    emit_addconst 0, 1e8;

    make_label 'loop_start';
    emit_addconst 1, 2;
    emit_subconst 0, 1;

    make_label 'jumpz_patch_pos', position + 1; # will need to patch jump target, so after the type byte
    emit_jumpz 0xdeadbeef, 0;
    emit_jump resolve_label('loop_start');
    make_label 'done';
    emit_print 1;

    backpatch 'jumpz_patch_pos', uint32(resolve_label('done'));

    emit_exit;
};
warn Dumper $asm;
print $asm->generate;

__END__
addconst(0, 100000000);
my $loop_lbl = make_jump_target();
addconst(1, 2);
subconst(0, 1);

my $tmp = jumpz(2e9, 0);
jump($loop_lbl);
my $done_lbl = emit_print(0);
emit_print(1);

# backpatching
substr($Output, $tmp+1, 4, uint32($done_lbl));

emit_exit();
print pack("L", $mem_size) . $Output;

