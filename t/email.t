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

BEGIN {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
}

my $file = __FILE__;
my $dir = File::Spec->catdir(dirname($file), '..');

## Todo, make these tests create a git repo
if ( !-d $dir ) {
    plan skip_all => __PACKAGE__ . ' must be installed from a git repo for these tests to work';
}

test_psgi 
    app => builder {
        enable 'GitBlame::Email', dir => $dir, sender => 'noreply@fakeemail.com';
        sub { die "force die\n" };
    },
    client => sub {
        my $res = shift->(HTTP::Request->new(GET => "/"));
        is($res->content, "force die\n");
        my @deliveries = Email::Sender::Simple->default_transport->deliveries;
        ok(@deliveries, 'Delivered email');
        ## Todo, add an email check here.
    };

done_testing();

