use strict;
use warnings;
package Plack::Middleware::GitBlame;
use parent qw(Plack::Middleware);
use Carp;

our $line_that_died;
our $git_directory;

sub _get_git_author {
    my ( $package, $line ) = @_;


}

## Make all dies stack traces
sub _die {
    my @line = caller(0);
    ## If caller line is carp, then we actually want the line
    ## that called the sub containing croak/carp/confess
    ## since that error indicated the caller made a mistake, not the die-er
    if ( $line[0] eq 'Carp' ) {
        @line = caller(2);
    }
    $line[1] = File::Spec->rel2abs($line[1]);
    if ( $line[1] =~ /^$git_directory/ ) {
        my $blame = _get_git_author($line[1], $line[2]);
    }

    $line_that_died = \@line;

    die @_;
}

sub call {
    my ( $self, $env ) = @_;
    
    $git_directory = $self->{dir} or croak 'Must supply root git directory';

    ## just die for now, but we might want warn at some point
    local $SIG{__DIE__} = \&_die;
    
    return $self->app->($env);
}

1;
