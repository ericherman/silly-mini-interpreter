package ASM::Tools;
use 5.14.2;
use warnings;
use Carp ();

use ASM qw(uint32);

use Exporter qw(import);

our @EXPORT_OK = qw(
    loop
    loop_counter
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $LoopCounterMemorySlot;

=head2 loop

Emits asm for a simply countdown loop with a jumpz to test for end.

Starts a loop block.

Must contain a C<loop_counter> verb.

=cut

sub loop (&) {
    my ($obj, @data) = &ASM::intuit_params;
    local $LoopCounterMemorySlot;

    my $loop_start = $obj->position;

    $data[0]->();

    if (not defined $LoopCounterMemorySlot) {
        Carp::croak("You need to set the 'loop_counter' for the loop");
    }

    $obj->emit_subconst($LoopCounterMemorySlot, 1);

    my $backpatch_pos = $obj->position+1;
    $obj->emit_jumpz(0xdeadbeef, $LoopCounterMemorySlot);
    $obj->emit_jump($loop_start);

    my $done_pos = $obj->position;
    $obj->backpatch($backpatch_pos, uint32($done_pos));

    return;
}

=head2 loop_counter

Verb for use in loop {} block.

=cut

sub loop_counter ($) { 
    my ($obj, @data) = &ASM::intuit_params;

    if (defined $LoopCounterMemorySlot) {
        Carp::croak("Cannot set 'loop_counter' twice for the same loop!");
    }

    $LoopCounterMemorySlot = $data[0];
}

1;
