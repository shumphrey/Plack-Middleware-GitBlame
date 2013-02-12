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

##############################################################################
## Init git repo
## These tests depend on git, so we need to make sure they are in a git repo
## Should be safe to re-init an existing repo?
##############################################################################
if ( !-d File::Spec->catdir($dir, '.git') ) {
    Git::Repository->run( init => $dir );
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
        ## Todo, add an email check here.
    };

done_testing();

