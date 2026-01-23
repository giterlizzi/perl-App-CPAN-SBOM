#!/usr/bin/env perl

use strict;
use warnings;

use Capture::Tiny qw( capture );
use Cpanel::JSON::XS qw( decode_json );
use File::Temp qw( tempfile );
use Test::File;
use Test::More;

use App::CPAN::SBOM;

my ($cp_fh, $cpanfile) = tempfile(
    DIR    => '.',     # Create it in the current directory
    UNLINK => 1        # IMPORTANT: Deletes the file automatically on exit
);

my ($bom_fh, $bomfile) = tempfile(
    "bom_XXXXXX",      # Template for the filename
    DIR    => '.',     # Create it in the current directory
    SUFFIX => '.json', # Add a .json extension
    UNLINK => 1        # IMPORTANT: Deletes the file automatically on exit
);

print $cp_fh <<CPANFILE;
requires 'CGI', '4.64';
requires 'CGI::Session', '4.48';
CPANFILE
$cp_fh->flush();

# Capture STDOUT and STDERR
my ($stdout, $stderr, $exit) = capture {
  App::CPAN::SBOM->run( "--file",  $cpanfile, "--output", $bomfile );
};

# 1. Decode the JSON file
my $bom_data = eval {
    my $bom_json = do { local $/; <$bom_fh> };
    decode_json($bom_json);
};
is($@, '', 'JSON file decoded without errors');
ok($bom_data, 'Successfully parsed BOM data structure');

my %component_names;
if (isa_ok($bom_data->{components}, 'ARRAY')) {
    %component_names = map { $_->{name} => 1 } @{$bom_data->{components}};
}

# 3. Check for the specific components
ok($component_names{'CGI'}, 'Component "CGI" is present');
ok($component_names{'CGI-Session'}, 'Component "CGI-Session" is present');

done_testing();

diag("App::CPAN::SBOM $App::CPAN::SBOM::VERSION, Perl $], $^X");
