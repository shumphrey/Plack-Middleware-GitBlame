#!/usr/bin/env perl

=head1 NAME

email.t

=head1 DESCRIPTION

Runs through a couple of dies, croaks, confesses etc.
Check that emails are sent.

=cut

use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use File::Basename qw/dirname/;
use File::Spec;
use Git::Repository;

BEGIN {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
}

my $file = __FILE__;
my $dir = File::Spec->catdir(dirname($file), '..');

my $USER  = 'testuser';
my $EMAIL = 'testemail@email.fake';

##############################################################################
## Init git repo
## These tests depend on git, so we need to make sure they are in a git repo
## Should be safe to re-init an existing repo?
##############################################################################
if ( !-d File::Spec->catdir($dir, '.git') ) {
    Git::Repository->run( init => $dir );
    my $r = Git::Repository->new(work_tree => $dir);
    $r->run('add', 't/email.t');
    $r->run('commit',
             '-m', 'test commit',
             '--author', "$USER <$EMAIL>");
}

test_psgi 
    app => builder {
        enable 'GitBlame::Email', dir => $dir, sender => 'noreply@fakeemail.com';
        sub { die "force die\n" };
    },
    client => sub {
        my $res = shift->(HTTP::Request->new(GET => "/"));
        is($res->content, "force die\n", 'Correct error');
        my @deliveries = Email::Sender::Simple->default_transport->deliveries;
        ok(@deliveries, 'Delivered email');
        is($deliveries[0]->{successes}->[0], $EMAIL, 'Email matches');
    };

done_testing();

