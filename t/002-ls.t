# -*- perl -*-
# t/002-ls.t
use strict;
use warnings;

use CPAN::Download::FTP;
use Test::More;
unless ($ENV{PERL_ALLOW_NETWORK_TESTING}) {
    plan 'skip_all' => "Set PERL_ALLOW_NETWORK_TESTING to conduct live tests";
}
else {
    plan tests =>  5;
}
use Test::RequiresInternet ('ftp.cpan.org' => 21);
use List::Compare::Functional qw(
    is_LsubsetR
);
use Capture::Tiny qw( capture_stdout );
use Data::Dump qw( dd pp );

my ($self, $host, $dir);
my (@all_archives, @exp_archives, $all_archives, %exp_archives);
my $default_host = 'ftp.cpan.org';
my $default_dir  = '/pub/CPAN/modules/by-module';

$self = CPAN::Download::FTP->new( {
    host        => $default_host,
    dir         => $default_dir,
    Passive     => 1,
} );
ok(defined $self, "Constructor returned defined object when using default values");
isa_ok ($self, 'CPAN::Download::FTP');

@exp_archives = (
    "List-Compare-0.45.tar.gz",
    "List-Compare-0.53.tar.gz",
);

$all_archives = $self->ls('List-Compare');
#pp(\@all_archives);
ok(scalar(@{$all_archives}), "ls(): returned >0 elements");
is_deeply($all_archives, \@exp_archives,
    "Got expected tarballs: single distribution");

%exp_archives = (
    'List-Compare'          => [
        "List-Compare-0.45.tar.gz",
        "List-Compare-0.53.tar.gz",
    ],
    'Data-Presenter'        => [
        "Data-Presenter-1.03.tar.gz",
    ],
);
$all_archives = $self->ls( [ 'List-Compare', 'Data-Presenter' ] );
#pp($all_archives);
is_deeply($all_archives, \%exp_archives,
    "Got expected tarballs: multiple distributions");


#
############################################################
#
## Tests for verbose output
#
#my ($self1, $stdout);
#
