package Test::MockPackages;
use strict;
use warnings;
use utf8;

our $VERSION = '0.1';

use Carp qw(croak);
use English qw(-no_match_vars);
use Test::MockPackages::Package();

sub new {
    my ($pkg) = @ARG;

    return bless {
        '_packages' => {},
    }, $pkg;
}

sub package {
    my ($self, $package_name) = @ARG;

    if ( !$package_name || ref($package_name) ) {
        croak('$package_name is required and must be a SCALAR');
    }
    
    if ( my $package = $self->{_packages}{$package_name} ) {
        return $package;
    }

    return $self->{_packages}{$package_name} = Test::MockPackages::Package->new($package_name);
}

1;
