#!perl -T

use strict;
use warnings;

use Test::More;
use Test::File;
use Capture::Tiny qw( capture );
use File::Temp    qw( tempfile );

use_ok('App::CPAN::SBOM');

my ($fh, $filename) = tempfile("bom_XXXXXX", DIR => '.', SUFFIX => '.json', UNLINK => 1);

# Capture STDOUT and STDERR
my ($stdout, $stderr, $exit) = capture {
    App::CPAN::SBOM->run(qw( --distribution libwww-perl@6.78 --output ), $filename);
};

file_not_empty_ok($filename, "BOM file successfully created");

done_testing();
