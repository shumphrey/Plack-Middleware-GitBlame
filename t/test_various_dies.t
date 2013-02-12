#!/usr/bin/env perl

=head1 NAME

test_various_dies.t

=head1 DESCRIPTION

Runs through a couple of dies, croaks, confesses etc.
Make sure we can capture it all

=cut

use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use Carp;
use File::Basename qw/dirname/;
use File::Spec;
use Git::Repository;

my $file = __FILE__;
my $dir = File::Spec->catdir(dirname($file), '..');

##############################################################################
## Init git repo
## These tests depend on git, so we need to make sure they are in a git repo
## Should be safe to re-init an existing repo?
##############################################################################
if ( !-d File::Spec->catdir($dir, '.git') ) {
    Git::Repository->run( init => $dir );
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
    ['Anon sub',     $app_die,        undef,            42, 'Steven Humphrey'],
    ['Named sub',    \&named_app_die, undef,            40, 'Steven Humphrey'],
    ['Nested sub',   $app_die_nested, 'Named sub',      40, 'Steven Humphrey'],
    ['Croak nested', \&croak_nested,  'Croak in named', 49, 'Steven Humphrey'],
);

foreach my $test (@TESTS) {
    my ( $name, $app, $description, $expected, $committer ) = @$test;
    $description ||= $name;
    my ( $caller, $blames );

    test_psgi 
        app => builder {
            enable 'GitBlame', dir   => $dir, 
                               cb    => sub { ( $caller, $blames ) = @_; };
            $app
        },
        client => sub {
            my $cb = shift;
            my $res = $cb->(HTTP::Request->new(GET => "/"));
            is($res->code, 500, $name);
            like($res->content, qr/^$description/, 'Correct error string');
            my ($package, $file, $line) = @{$caller || []};
            
            like($file, qr/$file$/, 'Error happened in this file');
            is($expected, $line, 'Error happens on right line')
                or note(explain($caller));
            
            is(scalar(@$blames), 1);
            is($blames->[0]->{final_line_number}, $expected, 'blame has line num');
            ok($blames->[0]->{error}, 'blame has error flag');
            is($blames->[0]->{committer}, $committer, 'Committed by author');
        };
}

my ( $caller, $blames ) = @_;
test_psgi 
    app => builder {
        enable 'GitBlame',
            dir   => $dir, 
            lines => 3,
            cb    => sub { ( $caller, $blames ) = @_; };
        $app_die
    },
    client => sub {
        my $res = shift->(HTTP::Request->new(GET => "/"));
        is(scalar(@$blames), 7, 'there are 7 lines of blame');
    };

done_testing();

