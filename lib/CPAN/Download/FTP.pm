package CPAN::Download::FTP;
use strict;
use warnings;
use 5.10.1;
use Carp;
use Net::FTP;
use File::Copy;
use Cwd;
use File::Spec;
our $VERSION = '0.01';

=head1 NAME

CPAN::Download::FTP - Identify CPAN distribution releases and download the most recent via FTP

=head1 SYNOPSIS

    use CPAN::Download::FTP;

    $self = CPAN::Download::FTP->new( {
        host        => 'ftp.cpan.org',
        dir         => '/pub/CPAN/modules/by-module',
        verbose     => 1,
    } );

=head1 DESCRIPTION

This library provides (a) methods for obtaining a list of all CPAN
distribution tarballs which are available for FTP download; and (b) methods
for obtaining a specific or the most recent release.

This library is similar to the same author's F<Perl-Download-FTP> distribution.

=head2 Compression Formats

This library assumes that CPAN distributions are available in C<gz>
compression format.  While some distributions may be available in other
compressions such as C<bz2> and C<xz>, they are very few in number and not
currently supported by this library.

=head2 Testing

This library can only be truly tested by attempting live FTP connections and
downloads of CPAN distribution tarballs.  Since testing over the internet
can be problematic when being conducted in an automatic manner or when the
user is behind a firewall, the test files under F<t/> will only be run live
when you say:

    export PERL_ALLOW_NETWORK_TESTING=1 && make test

Each test file further attempts to confirm the possibility of making an FTP
connection by using CPAN library Test::RequiresInternet.

=head1 METHODS

=head2 C<new()>

=over 4

=item * Purpose

CPAN::Download::FTP constructor.

=item * Arguments

    $self = CPAN::Download::FTP->new();

    $self = CPAN::Download::FTP->new( {
        host        => 'ftp.cpan.org',
        dir         => '/pub/CPAN/modules/by-module',
        verbose     => 1,
    } );

    $self = CPAN::Download::FTP->new( {
        host        => 'ftp.cpan.org',
        dir         => '/pub/CPAN/modules/by-module',
        Timeout     => 5,
    } );

Takes a hash reference with, typically, two elements:  C<host> and C<dir>.
Any options which can be passed to F<Net::FTP::new()> may also be passed as
key-value pairs.  When no argument is provided, the values shown above for
C<host> and C<dir> will be used.  You may enter values for any CPAN mirror
which provides FTP access.  (See L<https://www.cpan.org/SITES.html> and
L<http://mirrors.cpan.org/>.)  You may also pass C<verbose> for more
descriptive output; by default, this is off.

=item * Return Value

CPAN::Download::FTP object.

=item * Comment

The method establishes an FTP connection to <host>, logs you in as an
anonymous user, and changes directory to C<dir>.

Wrapper around Net::FTP object.  You will get Net::FTP error messages at any
point of failure.  Uses FTP C<Passive> mode.

=back

=cut

sub new {
    my ($class, $args) = @_;
    $args //= {};
    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';

    my %default_args = (
        host    => 'ftp.cpan.org',
        dir     => '/pub/CPAN/modules/by-module',
        verbose => 0,
    );
    my $default_args_string = join('|' => keys %default_args);
    my %netftp_options = (
        Firewall        => undef,
        FirewallType    => undef,
        BlockSize       => 10240,
        Port            => undef,
        SSL             => undef,
        Timeout         => 120,
        Debug           => 0,
        Passive         => 1,
        Hash            => undef,
        LocalAddr       => undef,
        Domain          => undef,
    );
    my %permitted_args = map {$_ => 1} (
        keys %default_args,
        keys %netftp_options,
    );

    for my $k (keys %{$args}) {
        croak "Argument '$k' not permitted in constructor"
            unless $permitted_args{$k};
    }

    my $data;
    # Populate object starting with default host and directory
    while (my ($k,$v) = each %default_args) {
        $data->{$k} = $v;
    }
    # Then add Net::FTP plausible defaults
    while (my ($k,$v) = each %netftp_options) {
        $data->{$k} = $v;
    }
    # Then override with key-value pairs passed to new()
    while (my ($k,$v) = each %{$args}) {
        $data->{$k} = $v;
    }

    # For the Net::FTP constructor, we don't need 'dir' and 'host'
    my %passed_netftp_options;
    for my $k (keys %{$data}) {
        $passed_netftp_options{$k} = $data->{$k}
            unless ($k =~ m/^($default_args_string)$/);
    }

    my $ftp = Net::FTP->new($data->{host}, %passed_netftp_options)
        or croak "Cannot connect to $data->{host}: $@";

    $ftp->login("anonymous",'-anonymous@')
        or croak "Cannot login ", $ftp->message;

    $ftp->cwd($data->{dir})
        or croak "Cannot change to working directory $data->{dir}", $ftp->message;

    $data->{ftp} = $ftp;

    my @compressions = (qw| gz |);
    $data->{eligible_compressions}  = { map { $_ => 1 } @compressions };
    $data->{compression_string}     = join('|' => @compressions);

    return bless $data, $class;
}

=head2 C<ls()>

=over 4

=item * Purpose

Identify all versions of given CPAN distributions available for download.

=item * Arguments

=over 4

=item 1 Single distribution

    $distribution = 'List-Compare';
    $all_releases_ref = $self->ls($distribution);

String holding name of a single CPAN distribution.

or:

=item 2 Multiple distributions

    $distributions = [ 'List-Compare', 'Data-Presenter' ];
    $all_releases_ref  = $self->ls($distributions);

Reference to an array holding a list of CPAN distributions.

=back

=item * Return Value

=over 4

=item 1 Single distribution

Reference to an array holding a list of strings like:
List of strings like:

    [
        "List-Compare-0.45.tar.gz",
        "List-Compare-0.53.tar.gz",
    ]

=item 2 Multiple distributions

Reference to a hash keyed on distribution name with corresponding value being
reference to an array hholding a list of releases available for download.

    {
        'List-Compare'          => [
            "List-Compare-0.45.tar.gz",
            "List-Compare-0.53.tar.gz",
        ],
        'Data-Presenter'        => [
            "Data-Presenter-1.03.tar.gz",
        ],
    }

=back

=back

=cut

sub ls {
    my ($self, $dist) = @_;
    unless (ref($dist) eq 'ARRAY') {
        my $these_releases_aref = $self->_single_ls($dist);
        $self->{all_releases} = $these_releases_aref;
        return $these_releases_aref;
    }
    else {  # array ref
        my $these_releases_href;
        for my $d (@{$dist}) {
            #my $these_releases_aref = $self->_single_ls($d);
            #$these_releases_href->{$d} = $these_releases_aref;
            $these_releases_href->{$d} = $self->_single_ls($d);
        }
        $self->{all_releases} = $these_releases_href;
        return $these_releases_href;
    }
}

sub _single_ls {
    my ($self, $d) = @_;
    my $top_dist_dir = (split /-/, $d)[0];
    croak "Could not identify top-level in $d" unless defined $top_dist_dir;
    my $search_dir = File::Spec->catdir($self->{dir}, $top_dist_dir);
    $self->{ftp}->cwd($search_dir)
        or croak "Cannot change to working directory $search_dir", $self->{ftp}->message;
    my @these_releases = grep { /^$d.*\.gz$/ } $self->{ftp}->ls()
        or croak "Unable to perform FTP 'ls' call to host: $!";
    return \@these_releases;
}

1;
__END__


=pod

TODO:  To identify the latest release, I first have to extract the version
number from the distro and then sort them, returning only one.

=cut

=head2 C<get_latest_release()>

=over 4

=item * Purpose

Download the latest release via FTP.

=item * Arguments

    $latest_release = $self->get_latest_release( {
        path            => '/path/to/download',
        verbose         => 1,
    } );

=item * Return Value

Scalar holding path to download of tarball.

=back

=cut

sub get_latest_release {
    my ($self, $args) = @_;
    croak "Argument to method must be hashref"
        unless ref($args) eq 'HASH';
#    my %eligible_types = (
#        production      => 'prod',
#        prod            => 'prod',
#        development     => 'dev',
#        dev             => 'dev',
#        rc              => 'rc',
#    );
#    my $type;
#    if (defined $args->{type}) {
#        croak "Bad value for 'type': $args->{type}"
#            unless $eligible_types{$args->{type}};
#        $type = $eligible_types{$args->{type}};
#    }
#    else {
#        $type = 'dev';
#    }
#
#    my $compression = 'gz';
#    if (exists $args->{compression}) {
#        $compression = $self->_compression_check($args->{compression});
#    }
#    my $cache = "${compression}_${type}_releases";

    my $path = cwd();
    if (exists $args->{path}) {
        croak "Value for 'path' not found" unless (-d $args->{path});
        $path = $args->{path};
    }
    my $latest;
#    if (exists $self->{$cache}) {
#        say "Identifying latest $type release from cache" if $self->{verbose};
#        $latest = $self->{$cache}->[0];
#    }
#    else {
    #say "Identifying latest $type release" if $self->{verbose};
        my @releases = $self->list_releases( {
            compression     => $compression,
            type            => $type,
        } );
        $latest = $releases[0];
        #    }
    say "Performing FTP 'get' call for: $latest" if $self->{verbose};
    my $starttime = time();
    $self->{ftp}->get($latest)
        or croak "Unable to perform FTP get call: $!";
    my $endtime = time();
    say "Elapsed time for FTP 'get' call: ", $endtime - $starttime, " seconds"
        if $self->{verbose};
    my $rv = File::Spec->catfile($path, $latest);
    move $latest, $rv or croak "Unable to move $latest to $path";
    say "See: $rv" if $self->{verbose};
    return $rv;
}

=head2 C<get_specific_release()>

=over 4

=item * Purpose

Download a specific release via FTP.

=item * Arguments

    $specific_release = $self->get_specific_release( {
        release         => 'perl-5.27.2.tar.xz',
        path            => '/path/to/download',
    } );

=item * Return Value

Scalar holding path to download of tarball.

=back

=cut

sub get_specific_release {
    my ($self, $args) = @_;
    croak "Argument to method must be hashref"
        unless ref($args) eq 'HASH';

    my $path = cwd();
    if (exists $args->{path}) {
        croak "Value for 'path' not found" unless (-d $args->{path});
        $path = $args->{path};
    }

    my @all_releases = $self->ls;
    my %all_releases = map {$_ => 1} @all_releases;
    croak "$args->{release} not found among releases at ftp://$self->{host}$self->{dir}"
        unless $all_releases{$args->{release}};

    say "Performing FTP 'get' call for: $args->{release}" if $self->{verbose};
    my $starttime = time();
    $self->{ftp}->get($args->{release})
        or croak "Unable to perform FTP get call: $!";
    my $endtime = time();
    say "Elapsed time for FTP 'get' call: ", $endtime - $starttime, " seconds"
        if $self->{verbose};
    my $rv = File::Spec->catfile($path, $args->{release});
    move $args->{release}, $rv
        or croak "Unable to move $args->{release} to $path";
    say "See: $rv" if $self->{verbose};
    return $rv;
}

=head1 BUGS AND SUPPORT

Please report any bugs by mail to C<bug-CPAN-Download-FTP@rt.cpan.org>
or through the web interface at L<http://rt.cpan.org>.

=head1 AUTHOR

    James E Keenan
    CPAN ID: JKEENAN
    jkeenan@cpan.org
    http://thenceforward.net/perl

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

Copyright James E Keenan 2018.  All rights reserved.

=head1 SEE ALSO

perl(1).  Net::FTP(3).  Test::RequiresInternet(3).

=cut

1;
