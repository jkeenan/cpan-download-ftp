use ExtUtils::MakeMaker;
require 5.008;

my $mm_ver = ExtUtils::MakeMaker->VERSION;

WriteMakefile(
    NAME         => 'CPAN::Download::FTP',
    VERSION_FROM => 'lib/CPAN/Download/FTP.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Identify CPAN distribution releases and download the most recent via FTP',
    MIN_PERL_VERSION => '5.10.1',
    PREREQ_PM    => {
                     'Net::FTP'     => 0,
                     'Carp'         => 0,
                     'Cwd'          => 0,
                     'File::Copy'   => 0,
                     'File::Spec'   => 0,
    },
    ( $mm_ver < 6.63_03 ? 'BUILD_REQUIRES' : 'TEST_REQUIRES' )
                    =>  {
                            'Test::Simple' => 0.44,
                            'List::Compare' => 0.51,
                            'Test::RequiresInternet' => 0,
                            'Capture::Tiny' => 0,
                            'File::Path' => 2.06,
                        },
    ($mm_ver < 6.46 ? () : (META_MERGE => {
        'meta-spec' => { version => 2 },
        dynamic_config => 1,
        resources => {
            homepage => 'http://thenceforward.net/perl/modules/CPAN-Download-FTP/',
            repository => {
                url => 'https://github.com/jkeenan/cpan-download-ftp.git',
                web => 'https://github.com/jkeenan/cpan-download-ftp',
                type => 'git',
            },
            bugtracker => {
                web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Download-FTP',
            },
        },
    })),
    ($mm_ver < 6.31 ? () : (LICENSE => 'perl_5')),
);
