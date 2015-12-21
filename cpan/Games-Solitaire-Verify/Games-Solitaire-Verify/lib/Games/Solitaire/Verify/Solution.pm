package Games::Solitaire::Verify::Solution;

use warnings;
use strict;

use 5.008;

=head1 NAME

Games::Solitaire::Verify::Solution - verify an entire solution
of Freecell Solver (or a similar solve)

=cut

our $VERSION = '0.1500';

use parent 'Games::Solitaire::Verify::Solution::Base';

use Games::Solitaire::Verify::Exception;
use Games::Solitaire::Verify::Card;
use Games::Solitaire::Verify::Column;
use Games::Solitaire::Verify::Move;
use Games::Solitaire::Verify::State;

=head1 SYNOPSIS

    use Games::Solitaire::Verify::Solution;

    my $input_filename = "freecell-24-solution.txt";

    open (my $input_fh, "<", $input_filename)
        or die "Cannot open file $!";

    # Initialise a column
    my $solution = Games::Solitaire::Verify::Solution->new(
        {
            input_fh => $input_fh,
            variant => "freecell",
        },
    );

    my $ret = $solution->verify();

    close($input_fh);

    if ($ret)
    {
        die $ret;
    }
    else
    {
        print "Solution is OK";
    }

=head1 METHODS

=head2 Games::Solitaire::Verify::Solution->new({variant => $variant, input_fh => $input_fh})

Constructs a new solution verifier with the variant $variant (see
L<Games::Solitaire::Verify::VariantsMap> ), and the input file handle
$input_fh.

If $variant is C<"custom">, then the constructor also requires a
C<'variant_params'> key which should be a populated
L<Games::Solitaire::Verify::VariantParams> object.

=cut

sub _init
{
    my ($self, $args) = @_;

    $self->_variant($args->{variant});

    if ($self->_variant() eq "custom")
    {
        $self->_variant_params($args->{variant_params});
    }
    $self->_i($args->{input_fh});
    $self->_state(undef);
    $self->_ln(0);
    $self->_reached_end(0);

    return 0;
}

sub _calc_variant_args
{
    my $self = shift;

    my @ret;
    if ($self->_variant() eq "custom")
    {
        push @ret, ('variant_params' => $self->_variant_params());
    }
    push @ret, (variant => $self->_variant());
    return \@ret;
}

sub _read_state
{
    my $self = shift;

    my $line = $self->_l();

    if ($line ne "\n")
    {
        die "Non empty line before state";
    }

    my $str = "";

    while (($line = $self->_l()) && ($line ne "\n"))
    {
        $str .= $line;
    }


    if (!defined($self->_state()))
    {
        my $new_state = Games::Solitaire::Verify::State->new(
                {
                    string => $str,
                    @{$self->_calc_variant_args()},
                }
            );

        $self->_state($new_state);
    }
    else
    {
        if ($self->_state()->to_string() ne $str)
        {
            die "States don't match";
        }
    }

    while (defined($line = $self->_l()) && ($line eq "\n"))
    {
    }

    if ($line !~ m{\A={3,}\n\z})
    {
        die "No ======== separator";
    }

    return;
}

sub _read_move
{
    my $self = shift;

    my $line = $self->_l();

    if ($line ne "\n")
    {
        die "No empty line before move";
    }

    $line = $self->_l();

    if ($line eq "This game is solveable.\n")
    {
        $self->_reached_end(1);

        return "END";
    }

    chomp($line);

    $self->_move(Games::Solitaire::Verify::Move->new(
            {
                fcs_string => $line,
                game => $self->_variant(),
            }
        )
    );

    return;
}

sub _apply_move
{
    my $self = shift;

    if (my $verdict = $self->_state()->verify_and_perform_move($self->_move()))
    {
        Games::Solitaire::Verify::Exception::VerifyMove->throw(
            error => "Wrong Move",
            problem => $verdict,
        );
    }

    return;
}


=head2 $solution->verify()

Traverse the solution verifying it.

=cut

sub verify
{
    my $self = shift;

    eval {

        my $line = $self->_l();

        if ($line !~ m{\A(-=)+-\n\z})
        {
            die "Incorrect start";
        }

        $self->_read_state();

        while (!defined(scalar($self->_read_move())))
        {
            $self->_apply_move();
            $self->_read_state();
        }
    };

    my $err;
    if (! $@)
    {
        # Do nothing - no exception was thrown.
    }
    elsif ($err =
        Exception::Class->caught('Games::Solitaire::Verify::Exception::VerifyMove'))
    {
        return { error => $err, line_num => $self->_ln(), };
    }
    else
    {
        $err = Exception::Class->caught();
        ref $err ? $err->rethrow : die $err;
    }

    return;
}

1; # End of Games::Solitaire::Verify::Solution
