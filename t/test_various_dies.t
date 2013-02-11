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
use File::Basename qw/dirname/;
use File::Spec;

my $file = __FILE__;
my $dir = File::Spec->catdir(dirname($file), '..');
if ( !-d $dir ) {
    plan skip_all => __PACKAGE__ . ' must be installed from a git repo for these tests to work';
}

use_ok('Plack::Middleware::GitBlame');

## Try not to change the line numbers of these subs...

sub named_app_die { die 'Named sub' }

my $app_die = sub { die 'Anon sub' };

my $app_die_nested = sub {
    named_app_die();
};

sub named_app_croak { croak 'Croak in named' }
sub croak_nested { named_app_croak() }

## name, coderef, description, line number, git user
my @TESTS = (
    ['Anon sub',     $app_die,        undef,            39, 'shumphrey'],
    ['Named sub',    \&named_app_die, undef,            37, 'shumphrey'],
    ['Nested sub',   $app_die_nested, 'Named sub',      37, 'shumphrey'],
    ['Croak nested', \&croak_nested,  'Croak in named', 46, 'shumphrey'],
);

foreach my $test (@TESTS) {
    my ( $name, $app, $description, $expected ) = @$test;
    $description ||= $name;
    test_psgi 
        app => builder {
            enable 'GitBlame', dir => $dir;
            $app
        },
        client => sub {
            my $cb = shift;
            my $res = $cb->(HTTP::Request->new(GET => "/"));
            is($res->code, 500, $name);
            like($res->content, qr/^$description/, 'Correct error string');
            my ($package, $file, $line) = @{$Plack::Middleware::GitBlame::line_that_died || []};
            
            like($file, qr/$file$/, 'Error happened in this file');
            is($expected, $line, 'Error happens on right line')
                or note(explain($Plack::Middleware::GitBlame::line_that_died));
        };
}

done_testing();

