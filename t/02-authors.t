#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test2::V0;

use App::CPAN::SBOM;

use Data::Dumper;

sub test_authors {
  my ($auth, $result) = @_;

  my @test = App::CPAN::SBOM::make_authors( $auth );
  Dumper( @test );

  is( \@test, $result, "Testing authors $auth->[0]" );
 }

test_authors( [ 'Mike Doherty <doherty@cpan.org>' ], [ { name => 'Mike Doherty', email => 'doherty@cpan.org' } ] );

test_authors( [ 'Steffen Ullrich <sullr@cpan.org>, Peter Behroozi, Marko Asplund' ], [ 
	{ name => 'Steffen Ullrich', email => 'sullr@cpan.org' } ] );

test_authors( [ 'unknown' ], [ { name => 'unknown' } ] );

test_authors( [ 'Gurusamy Sarathy        gsar@umich.edu' ], [ { name => 'Gurusamy Sarathy', email => 'gsar@umich.edu' } ] );

test_authors( [ 'Steffen Mueller <smueller@cpan.org>, Yves Orton <yves@cpan.org>' ], [ 
	{ name => 'Steffen Mueller', email => 'smueller@cpan.org' } ] );

test_authors( [ 'Christian Hansen C<chansen@cpan.org>' ], [ { name => 'Christian Hansen', email => 'chansen@cpan.org' } ] );

test_authors( [ 'Marcel Grunauer, C<<marcel@cpan.org> >' ], [ { name => 'Marcel Grunauer', email => 'marcel@cpan.org' } ] );

test_authors( [ 'Torsten Raudssus <torsten@raudss.us> L<https://raudss.us/>' ], [ { name => 'Torsten Raudssus', email => 'torsten@raudss.us' } ] );

test_authors( [ 'Best Practical Solutions, LLC <modules@bestpractical.com>' ], [ { name => 'Best Practical Solutions, LLC', email => 'modules@bestpractical.com' } ] );

done_testing();

diag("App::CPAN::SBOM $App::CPAN::SBOM::VERSION, Perl $], $^X");
