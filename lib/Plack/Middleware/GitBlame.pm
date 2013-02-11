use strict;
use warnings;
package Plack::Middleware::GitBlame;
use parent qw(Plack::Middleware);
use Carp;

our $line_that_died;

## Make all dies stack traces
sub _die {
    my @line = caller(0);
    ## If caller line is carp, then we actually want the line
    ## that called the sub containing croak/carp/confess
    ## since that error indicated the caller made a mistake, not the die-er
    if ( $line[0] eq 'Carp' ) {
        @line = caller(2);
    }
    my $package = $line[0];
    my $line    = $line[2];
    my $file    = $line[1];

    $line_that_died = \@line;

    die @_;
}

sub call {
    my ( $self, $env ) = @_;
    
    ## just die for now, but we might want warn at some point
    local $SIG{__DIE__} = \&_die;
    
    return $self->app->($env);
}

1;
