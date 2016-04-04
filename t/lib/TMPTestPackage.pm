package TMPTestPackage;
use strict;
use warnings;
use utf8;

use English qw(-no_match_vars);

sub new {
    return bless { }, shift;
}

sub method {
    my ( $self, $arg1, $arg2 ) = @ARG;

    return "method return: $arg1, $arg2";
}

sub subroutine {
    my ( $arg1, $arg2 ) = @ARG;

    return "subroutine return: $arg1, $arg2";
}

1;
