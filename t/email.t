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
use Carp;
use File::Basename qw/dirname/;
use File::Spec;

BEGIN {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
}

my $file = __FILE__;
my $dir = File::Spec->catdir(dirname($file), '..');
if ( !-d $dir ) {
    plan skip_all => __PACKAGE__ . ' must be installed from a git repo for these tests to work';
}

use_ok('Plack::Middleware::GitBlame::Email');

## Try not to change the line numbers of these subs...

my $app_die = sub { die 'Anon sub' };

my ( $caller, $blames ) = @_;
test_psgi 
    app => builder {
        enable 'GitBlame::Email',
            dir   => $dir, 
        $app_die
    },
    client => sub {
        my $res = shift->(HTTP::Request->new(GET => "/"));
        is(scalar(@$blames), 1, '1 blame line');
        my @deliveries = Email::Sender::Simple->default_transport->deliveries;
        diag(explain(@deliveries));
    };

done_testing();

