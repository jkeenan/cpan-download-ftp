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
    plan tests =>  4;
}
use Test::RequiresInternet ('ftp.cpan.org' => 21);
use List::Compare::Functional qw(
    is_LsubsetR
);
use Capture::Tiny qw( capture_stdout );
use Data::Dump qw( dd pp );

my ($self, $host, $dir);
my (@allarchives);
my $default_host = 'ftp.cpan.org';
my $default_dir  = '/pub/CPAN/modules/by-module';

$self = CPAN::Download::FTP->new( {
    host        => $default_host,
    dir         => $default_dir,
    Passive     => 1,
} );
ok(defined $self, "Constructor returned defined object when using default values");
isa_ok ($self, 'CPAN::Download::FTP');

my @exp_archives = (
    "List-Compare-0.45.tar.gz",
    "List-Compare-0.53.tar.gz",
);

@allarchives = $self->ls('List-Compare');
#pp(\@allarchives);
ok(scalar(@allarchives), "ls(): returned >0 elements");
is_deeply(\@allarchives, \@exp_archives, "Got expected tarballs");

#ok(is_LsubsetR( [
#    \@exp_gzips,
#    \@allarchives,
#] ), "ls(): No argument: Spot check .gz")
#    or diag explain (\@exp_gzips,\@allarchives);
#
#ok(is_LsubsetR( [
#    \@exp_bzips,
#    \@allarchives,
#] ), "ls(): No argument: Spot check .bz2")
#    or diag explain (\@exp_bzips,\@allarchives);
#
#ok(is_LsubsetR( [
#    \@exp_xzs,
#    \@allarchives,
#] ), "ls(): No argument: Spot check .xz")
#    or diag explain (\@exp_xzs,\@allarchives);
#
#@allarchives = $self->ls('gz');
#
#ok(is_LsubsetR( [
#    \@exp_gzips,
#    \@allarchives,
#] ), "ls(): Request 'gz' only: Spot check .gz")
#    or diag explain (\@exp_gzips,\@allarchives);
#
#ok(! is_LsubsetR( [
#    \@exp_bzips,
#    \@allarchives,
#] ), "ls(): Request 'gz' only: Spot check .bz2")
#    or diag explain (\@exp_bzips,\@allarchives);
#
#ok(! is_LsubsetR( [
#    \@exp_xzs,
#    \@allarchives,
#] ), "ls(): Request 'gz' only: Spot check .xz")
#    or diag explain (\@exp_xzs,\@allarchives);
#
#
#@allarchives = $self->ls('bz2');
#
#ok(! is_LsubsetR( [
#    \@exp_gzips,
#    \@allarchives,
#] ), "ls(): Request 'bz2' only: Spot check .gz")
#    or diag explain (\@exp_gzips,\@allarchives);
#
#ok(is_LsubsetR( [
#    \@exp_bzips,
#    \@allarchives,
#] ), "ls(): Request 'bz2' only: Spot check .bz2")
#    or diag explain (\@exp_bzips,\@allarchives);
#
#ok(! is_LsubsetR( [
#    \@exp_xzs,
#    \@allarchives,
#] ), "ls(): Request 'bz2' only: Spot check .xz")
#    or diag explain (\@exp_xzs,\@allarchives);
#
#
#@allarchives = $self->ls('xz');
#
#ok(! is_LsubsetR( [
#    \@exp_gzips,
#    \@allarchives,
#] ), "ls(): Request 'xz' only: Spot check .gz")
#    or diag explain (\@exp_gzips,\@allarchives);
#
#ok(! is_LsubsetR( [
#    \@exp_bzips,
#    \@allarchives,
#] ), "ls(): Request 'xz' only: Spot check .bz2")
#    or diag explain (\@exp_bzips,\@allarchives);
#
#ok(is_LsubsetR( [
#    \@exp_xzs,
#    \@allarchives,
#] ), "ls(): Request 'xz' only: Spot check .xz")
#    or diag explain (\@exp_xzs,\@allarchives);
#
#{
#    local $@;
#    my $bad_compression = 'foo';
#    eval { @allarchives = $self->ls($bad_compression); };
#    like($@, qr/ls\(\):\s+Bad compression format:\s+$bad_compression/,
#        "ls(): Got expected error message for bad compression format");
#}
#
############################################################
#
## Tests for verbose output
#
#my ($self1, $stdout);
#
#$self1 = CPAN::Download::FTP->new( {
#    host        => $default_host,
#    dir         => $default_dir,
#    Passive     => 1,
#    verbose     => 1,
#} );
#ok(defined $self1, "Constructor returned defined object when using default values");
#isa_ok ($self1, 'CPAN::Download::FTP');
#
#$stdout = capture_stdout { @allarchives = $self1->ls(); };
#ok(scalar(@allarchives), "ls(): returned >0 elements");
#like(
#    $stdout,
#    qr/Identified \d+ perl releases at ftp:\/\/\Q${default_host}${default_dir}\E/,
#    "ls(): Got expected verbose output"
#);
