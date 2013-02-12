# ABSTRACT: git blame on thrown errors
=head1 NAME

Plack::Middleware::GitBlame

=head1 SYNOPSIS

  use Term::ANSIColor;

  enable 'GitBlame', 
    dir => '/path/to/gitrepo',
    cb => sub {
        my ( $caller, $blames ) = @_;
        print $caller->[0];
        print $blames->[0]->{author};
        foreach my $blame (@$blames) {
            print color('red') if $blame->{error};
            print $blame->{author};
        }
    };

=head1 DESCRIPTION

A middleware that captures errors and gets the git blame data for the
surrounding lines.

Takes a directory to the git repo and a callback for the data.
See L<Plack::Middleware::GitBlame::Email> for a module that emails the person
who wrote the line.

You can also provide an integer number of 'lines' (defaults to the single line)
to get that number of blame lines above and below
(negative number gives entire file)

The callback receives two arguments, the first is the caller array.
The second is an array of hashrefs corresponding to information produced
by git blame.
The caller array is the standard array returned by caller(expr) and will
contain the line number at index 2

=head1 PLUGINS

This distribution comes with L<Plack::Middleware::GitBlame::Email>
which is a plugin that sends emails.

You can write you own plugin by calling the setup method.
Create a new module that inherits from L<Plack::Middleware::GitBlame>
and calls the setup method.

  use parent qw(Plack::Middleware::GitBlame);

  sub call {
    return setup(@_, sub {
        my ( $caller, $blames ) = @_;
    });    
  }

See L<Plack::Middleware> for documentation on creating middlewares.

=head1 SEE ALSO

L<Plack::Middleware::GitBlame::Email>,
L<Git::Repository>

=cut

package Plack::Middleware::GitBlame;
use strict;
use warnings;
use parent qw(Plack::Middleware);
use Carp;
use File::Spec;
use Git::Repository;

my $git_directory;
my $callback;
my $num_lines;
my %orig_sig_handler;

sub _get_git_data {
    my ( $file, $line_num ) = @_;

    if ( !-d $git_directory ) {
        croak "$git_directory does not exist";
    }

    my $repo = Git::Repository->new(work_tree => $git_directory);
    my @args = ('-p');
    if ( defined $num_lines && $num_lines >= 0 ) {
        push @args, sprintf('-L%d,%d', $line_num - $num_lines, 
                                       $line_num + $num_lines);
    }
    my @output = $repo->run(
        'blame',
        @args,
        $file
    );

    my (%data, @lines);

    for my $line (@output) {
        if ( $line =~ /^\t/ ) {
            $data{line} = $line;
            push @lines, { %data };
        }
        elsif ( $line =~ /^([0-9a-f]+)\s(\d+)\s(\d+)\s*(\d*)$/x ) {
            $data{commit}               = $1;
            $data{original_line_number} = $2;
            $data{final_line_number}    = $3;
            $data{lines_count_in_group} = $4;
            if ( $line_num == $3 ) {
                $data{error} = 1;
            }
        }
        elsif ( $line =~ m/^([\w\-]+)\s*(.*)$/x ) {
            $data{$1} = $2;
        }
    }
    return \@lines;
}

## Make all dies stack traces
sub _die {
    my @caller = caller(0);
    ## If caller line is carp, then we actually want the line
    ## that called the sub containing croak/carp/confess
    ## since that error indicated the caller made a mistake, not the die-er
    if ( $caller[0] eq 'Carp' ) {
        @caller = caller(2);
    }
    $caller[1] = File::Spec->rel2abs($caller[1]);

    if ( $caller[1] =~ /^$git_directory/ ) {
        my $blames = _get_git_data($caller[1], $caller[2]);
        $callback->(\@caller, $blames)
    }

    ## We don't want to break the original sig handler
    ## So we use that also.
    ## i.e. we want Plack::Middleware::Stacktrace to still work
    if ( ref($orig_sig_handler{__DIE__}) eq 'CODE' ) {
        return $orig_sig_handler{__DIE__}->(@_);
    }
    else {
        die @_;
    }
}

sub setup {
    my ( $self, $env, $cb ) = @_;

    $git_directory = $self->{dir} or croak 'Must supply root git directory';
    $num_lines     = $self->{lines} || 0;
    $callback      = $cb || $self->{cb} || croak 'Must supply callback';
    $git_directory = File::Spec->rel2abs($git_directory);

    ## just die for now, but we might want warn at some point
    $orig_sig_handler{__DIE__} = $SIG{__DIE__};
    local $SIG{__DIE__} = \&_die;
    
    return $self->app->($env);
}

sub call {
    return setup(@_);
}

1;
