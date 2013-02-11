#!/usr/bin/env perl

=head1 NAME

test_various_dies.t

=head1 DESCRIPTION

Runs through a couple of dies, croaks, confesses etc.
Make sure we can capture it all

=head1 AUTHOR

Steven Humphrey

=cut

use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use Carp;

use_ok('Plack::Middleware::GitBlame');

## Try not to change the line numbers of these subs...

sub named_app_die { die 'named_app_die'; }

my $app_die = sub { die 'ref_app_die'; };

my $app_die_nested = sub {
    named_app_die();
};

sub named_app_croak { croak 'named_app_croak' }
sub croak_nested { named_app_croak() }

my @TESTS = (
    [$app_die,          'Dies in anon sub',     31],
    [\&named_app_die,   'Dies in named sub',    29],
    [$app_die_nested,   'Dies in nested sub',   29],
    [\&croak_nested,    'Croaks in nested sub', 38],
);

foreach my $test (@TESTS) {
    my ( $app, $description, $expected ) = @$test;
    test_psgi 
        app => builder {
            enable 'GitBlame';
            $app
        },
        client => sub {
            my $cb = shift;
            my $res = $cb->(HTTP::Request->new(GET => "/"));
            is($res->code, 500, $description);
            my ($package, $file, $line) = @{$Plack::Middleware::GitBlame::line_that_died};
            
            is($file, __FILE__, 'Error happened in this file');
            is($expected, $line, 'Error happens on right line')
                or note(explain($Plack::Middleware::GitBlame::line_that_died));
        };
}

done_testing();

