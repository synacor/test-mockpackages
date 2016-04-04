package Test::MockPackages::Mock;
use strict;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast qw(const);
use English qw(-no_match_vars);
use Lingua::EN::Inflect qw(PL);
use Scalar::Util qw(looks_like_number weaken);
use Test::More;

const my @GLOB_TYPES => qw(SCALAR HASH ARRAY HANDLE FORMAT IO);

sub new {
    my ($pkg, $package_name, $name) = @ARG;

    my $full_name = "${package_name}::$name";
    my $original = exists &$full_name ? \&$full_name : undef;

    my $self = bless {
        _called => undef,
        _expects => undef,
        _full_name => $full_name,
        _invoke_count => 0,
        _is_method => 0,
        _name => $name,
        _never => 0,
        _original_coderef => $original,
        _package_name => $package_name,
        _returns => [],
    }, $pkg;

    $self->_setup();

    return $self;
}

sub _setup {
    my ( $self ) = @ARG;

    weaken $self;
    my $mock = sub {
        my (@got) = @ARG;

        my $invoke_number = ++$self->{_invoke_count};
        my $i = $invoke_number - 1;

        if ( $self->{_is_method} ) {
            shift @got;
        }

        if ( my $expects = $self->{_expects} ) {
            my $n_expects = scalar( @$expects );
            my $expected;
            if ( $n_expects == 1 && defined( $self->{_called} ) ) {
                $expected = $expects->[0];
            }
            elsif ( $i >= $n_expects ) {
                croak(sprintf '%s was called %d %s. Only %d %s defined', $self->{_full_name}, $invoke_number, PL('time', $invoke_number), $n_expects, PL('expectation', $n_expects) );
            }
            else {
                $expected = $expects->[ $i ];
            }

            is_deeply( \@got, $expected, "$self->{_full_name} called correctly" ); 
        }

        my @returns;
        if ( my $returns = $self->{_returns} ) {
            my $n_returns = scalar @$returns;

            if ($n_returns == 1 && defined( $self->{_called} ) ) {
                @returns = @{ $returns->[0] };
            }
            elsif ( $i >= $n_returns ) {
                croak(sprintf '%s was called %d %s. Only %d %s defined', $self->{_full_name}, $invoke_number, PL('time', $invoke_number), $n_returns, PL('returns', $n_returns) );
            }
            else {
                @returns = @{ $returns->[ $i ] };
            }
        }
        else {
            @returns = (1);
        }

        return !wantarray && scalar(@returns) == 1 ? $returns[0] : @returns;
    };

    no strict qw(refs);
    no warnings qw(redefine);
    my $full_name = $self->{_full_name};
    *$full_name = $mock;
    use strict;
    use warnings;

    return 1;
}

sub called {
    my ( $self, $called ) = @ARG;

    if ( !looks_like_number($called) || $called < 0 ) {
        croak('$called must be an integer >= 0');
    }

    $self->{_called} = $called;

    return $self;
}

sub never {
    my ( $self ) = @ARG;

    $self->{_never} = 1;

    return $self;
}

sub method {
    my ( $self ) = @ARG;

    $self->{_is_method} = 1;

    return $self;
}

sub expects {
    my ( $self, @expects ) = @ARG;

    push @{ $self->{_expects} }, \@expects;

    return $self;
}

sub returns {
    my ( $self, @returns ) = @ARG;

    push @{ $self->{_returns} }, \@returns;

    return $self;
}

sub DESTROY {
    no strict qw(refs);
    no warnings qw(redefine);

    my ( $self ) = @ARG;

    my $full_name = $self->{_full_name};

    if ( my $original = $self->{_original_coderef} ) {
        *$full_name = $original;
    }
    else {
        my %copy;
        $copy{$ARG} = *$full_name{$ARG} for grep { defined *$full_name{$ARG} } @GLOB_TYPES;
        undef *$full_name;
        *$full_name = $copy{$ARG} for keys %copy;
    }
}

1;
