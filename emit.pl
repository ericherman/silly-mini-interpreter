#!perl
use 5.14.2;
use warnings;
use Data::Dumper;

use lib 'lib';
use ASM qw(:all);
use ASM::Tools qw(:all);

sub generate_by_hand {
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

    print $asm->generate;
}

sub generate_with_loop {
    my $asm = asm {
        memsize 1000;

        my $loop_slot = 0;
        emit_addconst $loop_slot, 1e8;

        loop {
            loop_counter $loop_slot;
            emit_addconst 1, 2;
        };

        emit_print 1;
        emit_exit;
    };

    print $asm->generate;
}

#generate_by_hand();
generate_with_loop();

