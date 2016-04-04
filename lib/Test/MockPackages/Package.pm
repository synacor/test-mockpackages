package Test::MockPackages::Package;
use strict;
use warnings;
use utf8;

use Carp qw(croak);
use English qw(-no_match_vars);
use Test::MockPackages::Mock();

sub new {
    my ($pkg, $package_name) = @ARG;

    if (!$package_name || ref($package_name)) {
        croak('$package_name is required and must be a SCALAR');
    }

    return bless {
        _package_name => $package_name,
        _mocks => {},
    }, $pkg;
}

sub mock {
    my ($self, $name) = @ARG;

    if (!$name || ref($name)) {
        croak('$name is required and must be a SCALAR');
    }

    if ( my $mock = $self->{_mocks}{$name} ) {
        return $mock;
    }

    return $self->{_mocks}{$name} = Test::MockPackages::Mock->new( $self->{_package_name}, $name );
}

1;
