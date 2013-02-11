=head1 NAME

Plack::Middleware::GitBlame::Email

=head1 DESCRIPTION

When an exception is thrown, send an email to the author of the line of code.

=head1 SYNOPSIS

  enable 'Plack::Middleware::GitBlame::Email',
    dir       => '/path/to/git/repo',
    transport => $transport;

Wrapper around L<Plack::Middleware::GitBlame>,
enables the Plack::Middleware::GitBlame module with an email callback.

An optional L<Email::Sender::Transport> as can be supplied as 'transport'
to specify how the email will get sent.

=cut

package Plack::Middleware::GitBlame::Email;
use strict;
use warnings;

use parent qw(Plack::Middleware::GitBlame);

use Email::Simple;
use Email::Sender::Simple qw/sendmail/;
use List::Util qw/first/;

sub call {
    my ( $self, $env ) = @_;
    return $self->setup($env, sub {
        my ( $caller, $blames ) = @_;

        my $blame = first { $_->{final_line_number} == $caller->[2] } @$blames;
        my $to = $blame->{'committer-mail'};

        ## User has no email address
        ## Or the line hasn't been committed
        if ( !$to || $to =~ /not.committed/ ) {
            return;
        }
        my $plain_template = <<'EOF';
Hello %s

An error has been thrown at line %d of file %s

%s
EOF
        my @lines = map {
            sprintf('%3d: %s', $_->{final_line_number}, $_->{line})
        } @$blames;

        my $msg = sprintf($plain_template, $blame->{committer},
                                           $blame->{final_line_number},
                                           $blame->{filename},
                                           join("\n", @lines));

        my $email = Email::Simple->create(
            header => [
                To      => $to,
                Subject => 'Plack::Middleware::GitBlame - Error'
            ],
            body => $msg
        );
        my %options;
        if ( $self->{transport} ) {
            $options{transport} = $self->{transport};
        }
        sendmail($email, \%options);
    });
}

1;

