package Games::Solitaire::Verify::App::CmdLine::From_ShirlHartSolver;

use strict;
use warnings;
use autodie;

use parent 'Games::Solitaire::Verify::FromOtherSolversBase';

use List::Util qw(first);

__PACKAGE__->mk_acc_ref(
    [
        qw(
            _input_move_index
            _st
            _filename
            _sol_filename
            _variant_params
            _buffer_ref
            )
    ]
);

sub _perform_move
{
    my ( $self, $move_line ) = @_;

    my @fields = ( split /\|/, $move_line, -1 );
    if ( @fields != 5 )
    {
        die "Wrong $move_line";
    }
    my $idx = shift @fields;
    if ( $idx ne $self->_input_move_index )
    {
        die "wrong move index - $move_line";
    }

    my ( $move_s, $src_card, $dest, $found_moves ) = @fields;

    my %fc = ( a => 0, b => 1, c => 2, d => 3 );
DETECT_MOVE:
    {
        my $is_valid_dest_col = sub {
            my ($dest_col_idx) = @_;
            my $dcol = $self->_st->get_column($dest_col_idx);
            return (
                $dest eq 'e'
                ? ( $dcol->len() > 0 )
                : ( $dest ne $dcol->top->to_string )
            );
        };

        if ( my ( $src_col_idx, $dest_fc_idx ) =
            $move_s =~ /\A([1-8])([abcd])\z/ )
        {
            --$src_col_idx;
            $dest_fc_idx = $fc{$dest_fc_idx};
            if ( $dest ne 'f' )
            {
                die "wrong move to freecell - $move_line";
            }
            if ( $src_card ne
                $self->_st->get_column($src_col_idx)->top->to_string )
            {
                die "wrong move to freecell - $move_line";
            }

            $self->_perform_and_output_move(
                sprintf(
                    "Move a card from stack %d to freecell %d",
                    $src_col_idx, $dest_fc_idx,
                ),
            );
            last DETECT_MOVE;
        }
        if ( my ( $src_col_idx, $dest_col_idx ) =
            $move_s =~ /\A([1-8])([1-8])\z/ )
        {
            --$src_col_idx;
            --$dest_col_idx;
            $src_card = substr( $src_card, 0, 2 );
            my $col = $self->_st->get_column($src_col_idx);
            my $idx = first { $col->pos($_)->to_string eq $src_card }
            ( 0 .. $col->len - 1 );
            if ( !defined $idx )
            {
                die "wrong move stack to stack - $move_line";
            }
            if ( $is_valid_dest_col->($dest_col_idx) )
            {
                die "wrong move stack to stack - $move_line";
            }

            $self->_perform_and_output_move(
                sprintf(
                    "Move %d cards from stack %d to stack %d",
                    $col->len() - $idx,
                    $src_col_idx, $dest_col_idx,
                ),
            );
            last DETECT_MOVE;
        }

        if ( my ( $src_col_idx, ) = $move_s =~ /\A([1-8])(?:h)\z/ )
        {
            --$src_col_idx;
            if ( $src_card ne
                $self->_st->get_column($src_col_idx)->top->to_string )
            {
                die "wrong move stack to foundations - $move_line";
            }
            if ( $dest ne 'h' )
            {
                die "wrong move stack to foundations - $move_line";
            }

            $self->_perform_and_output_move(
                sprintf( "Move a card from stack %d to the foundations",
                    $src_col_idx ),
            );
            last DETECT_MOVE;
        }

        if ( my ( $src_fc_idx, ) = $move_s =~ /\A([a-d])(?:h)\z/ )
        {
            $src_fc_idx = $fc{$src_fc_idx};
            if ( $src_card ne $self->_st->get_freecell($src_fc_idx)->to_string )
            {
                die "wrong move fc to foundations - $move_line";
            }
            if ( $dest ne 'h' )
            {
                die "wrong move fc to foundations - $move_line";
            }

            $self->_perform_and_output_move(
                sprintf( "Move a card from freecell %d to the foundations",
                    $src_fc_idx ),
            );
            last DETECT_MOVE;
        }

        if ( my ( $src_fc_idx, $dest_col_idx ) =
            $move_s =~ /\A([a-d])([1-8])\z/ )
        {
            $src_fc_idx = $fc{$src_fc_idx};
            --$dest_col_idx;
            if ( $src_card ne $self->_st->get_freecell($src_fc_idx)->to_string )
            {
                die "wrong move freecell to stack - $move_line";
            }
            if ( $is_valid_dest_col->($dest_col_idx) )
            {
                die "wrong move freecell to stack - $move_line";
            }

            $self->_perform_and_output_move(
                sprintf(
                    "Move a card from freecell %d to stack %d",
                    $src_fc_idx, $dest_col_idx,
                ),
            );
            last DETECT_MOVE;
        }
        die "wrong move - $move_line";
    }

    if ( length $found_moves )
    {
        my $map;
        my %suits;
        $map = sub {
            my $s = shift;
            if ( length($s) == 2 )
            {
                return $map->("$s-$s");
            }
            my ( $start, $end ) = $s =~ /\A(\S\S)-(\S\S)\z/
                or die "wrong found_moves <<$s>>!";
            my $sc =
                Games::Solitaire::Verify::Card->new( { string => $start } );
            my $ec = Games::Solitaire::Verify::Card->new( { string => $end } );
            if ( $sc->suit ne $ec->suit )
            {
                die "uiui";
            }
            if ( exists $suits{ $sc->suit } )
            {
                die "duplicate";
            }
            if ( $sc->rank > $ec->rank )
            {
                die "foo";
            }
            $suits{ $sc->suit } = { start => $sc, end => $ec };
            return;
        };
        foreach my $f ( split /;/, $found_moves, -1 )
        {
            $map->($f);
        }
        my $count = 1;
    FOUNDATION:
        while ( $count > 0 )
        {
            $count = 0;
            foreach my $suit ( sort( keys %suits ) )
            {
                my @src_s;
                eval {
                    @src_s =
                        $self->_find_card_src_string(
                        $suits{$suit}->{start}->to_string );
                };
                if ( !$@ )
                {
                    ++$count;
                    my $rank = $suits{$suit}->{start}->rank;
                    if ( $rank == $suits{$suit}->{end}->rank )
                    {
                        delete $suits{$suit};
                    }
                    else
                    {
                        $suits{$suit}->{start}->rank( 1 + $rank );
                    }
                    $self->_perform_and_output_move(
                        sprintf( "Move a card from %s to the foundations",
                            $src_s[1] ),
                    );
                    next FOUNDATION;
                }
            }
        }
        if (%suits)
        {
            die "cannot move to foundations - $move_line";
        }
    }
    $self->_input_move_index( $self->_input_move_index + 1 );
    return;
}

sub _process_main
{
    my $self = shift;

    $self->_read_initial_state;
    $self->_input_move_index(1);

    open my $in_fh, '<', $self->_sol_filename;

    my $l;
FIRST_lines:
    while ( $l = <$in_fh> )
    {
        chomp($l);
        last FIRST_lines if ( $l =~ /\|/ );
    }

    while ( $l =~ /\|/ )
    {
        $self->_perform_move($l);
        $l = <$in_fh>;
        chomp $l;
    }
    close($in_fh);

    $self->_append("This game is solveable.\n");

    return;
}

1;

=head1 NAME

Games::Solitaire::Verify::App::CmdLine::From_ShirlHartSolver - a modulino for
converting from Shirl Hart's solver's solutions to fc-solve ones.

=head1 SYNOPSIS

    $ perl -MGames::Solitaire::Verify::App::CmdLine::From_Patsolve -e 'Games::Solitaire::Verify::App::CmdLine::From_Patsolve->new({argv => \@ARGV})->run()' -- [ARGS]

=head1 DESCRIPTION

This is a a modulino for
converting from Shirl Hart's solver's solutions to fc-solve ones.

L<https://github.com/shlomif/shirl-hart-freecell-solver/> .

=head1 METHODS

=head2 run()

Actually execute the command-line application.

=cut
