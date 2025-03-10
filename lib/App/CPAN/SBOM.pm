package App::CPAN::SBOM;

use 5.010001;
use strict;
use warnings;
use utf8;

use CPAN::Meta;
use Data::Dumper;
use Getopt::Long qw(GetOptionsFromArray :config gnu_compat);
use MetaCPAN::Client;
use Pod::Usage qw(pod2usage);
use URI::PackageURL;

use SBOM::CycloneDX;
use SBOM::CycloneDX::Component;
use SBOM::CycloneDX::ExternalReference;
use SBOM::CycloneDX::Hash;
use SBOM::CycloneDX::License;
use SBOM::CycloneDX::Metadata;
use SBOM::CycloneDX::OrganizationalContact;
use SBOM::CycloneDX::Util qw(cpan_meta_to_spdx_license cyclonedx_tool cyclonedx_component);

our $VERSION = '1.00';

sub cli_error {
    my ($error) = @_;
    $error =~ s/ at .* line \d+.*//;
    print STDERR "ERROR: $error\n";
}

sub run {

    my (@args) = @_;

    my %options = ();

    GetOptionsFromArray(
        \@args, \%options, qw(
            help|h
            man
            v

            meta=s
            author=s
            distribution=s
            maxdepth=i
        )
    ) or pod2usage(-verbose => 0);

    pod2usage(-exitstatus => 0, -verbose => 2) if defined $options{man};
    pod2usage(-exitstatus => 0, -verbose => 0) if defined $options{help};

    if (defined $options{v}) {

        (my $progname = $0) =~ s/.*\///;

        say <<"VERSION";
$progname version $VERSION

Copyright 2025, Giuseppe Di Terlizzi <gdt\@cpan.org>

This program is part of the "App-CPAN-SBOM" distribution and is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

Complete documentation for $progname can be found using 'man $progname'
or on the internet at <https://metacpan.org/dist/App-CPAN-SBOM>.
VERSION

        return 0;

    }

    unless ($options{meta} && $options{author}) {
        pod2usage(-exitstatus => 0, -verbose => 0);
    }

    my $bom = SBOM::CycloneDX->new;

    $options{maxdepth} //= 1;

    if (defined $options{meta}) {
        make_sbom_from_meta(
            bom      => $bom,
            meta     => $options{meta},
            author   => $options{author},
            maxdepth => $options{maxdepth}
        );
    }

    if (defined $options{distribution}) {
        my ($distribution, $version) = split '@', $options{distribution};
        make_sbom_from_dist(
            bom          => $bom,
            distribution => $distribution,
            version      => $version,
            maxdepth     => $options{maxdepth}
        );
    }

    $bom->metadata->tools->push(cyclonedx_tool());

    say $bom->to_string;

    my @errors = $bom->validate;
    say STDERR $_ foreach (@errors);

}


sub make_sbom_from_meta {

    my (%options) = @_;

    return cli_error('META not found') unless -f $options{meta};

    my $bom  = $options{bom};
    my $meta = CPAN::Meta->load_file($options{meta});

    my @authors = make_authors([$meta->author]);

    my $purl = URI::PackageURL->new(
        type      => 'cpan',
        namespace => $options{author},
        name      => $meta->name,
        version   => $meta->version
    );

    my @external_references = make_external_references($meta->{resources});

    my $spdx_license = cpan_meta_to_spdx_license($meta->license);

    my $root_component = SBOM::CycloneDX::Component->new(
        type                => 'library',
        name                => $meta->name,
        version             => $meta->version,
        licenses            => [SBOM::CycloneDX::License->new(id => $spdx_license)],
        authors             => \@authors,
        bom_ref             => $purl->to_string,
        purl                => $purl,
        external_references => \@external_references
    );

    $bom->metadata->component($root_component);

    my $prereqs = $meta->effective_prereqs;
    my $reqs    = $prereqs->requirements_for("runtime", "requires");

    for my $module (sort $reqs->required_modules) {

        next if $module eq 'perl';

        make_dep_compoment(
            module           => $module,
            bom              => $bom,
            parent_component => $root_component,
            maxdepth         => $options{maxdepth}
        );

    }

    return $root_component;

}

sub make_sbom_from_dist {

    my (%options) = @_;

    my $distribution = $options{distribution};
    my $version      = $options{version};
    my $bom          = $options{bom};

    my $mcpan        = MetaCPAN::Client->new;
    my $release_data = $mcpan->release({all => [{distribution => $distribution}, {version => $version}]});

    my $dist_data = $release_data->next;

    unless ($dist_data) {
        Carp::carp("Unable to find release ($distribution\@$version) in Meta::CPAN");
        return;
    }

    my $metadata = $dist_data->metadata;

    my @authors = make_authors($metadata->{author});

    my $purl = URI::PackageURL->new(
        type      => 'cpan',
        namespace => $dist_data->author,
        name      => $dist_data->distribution,
        version   => $dist_data->version
    );

    my @external_references = make_external_references($dist_data->metadata->{resources});

    my $license      = join ' AND ', @{$metadata->{license}};
    my $spdx_license = cpan_meta_to_spdx_license($license);

    my $bom_license = SBOM::CycloneDX::License->new(($spdx_license) ? {id => $spdx_license} : {name => $license});

    my $root_component = SBOM::CycloneDX::Component->new(
        type                => 'library',
        name                => $dist_data->name,
        version             => $dist_data->version,
        licenses            => [$bom_license],
        authors             => \@authors,
        bom_ref             => $purl->to_string,
        purl                => $purl,
        external_references => \@external_references
    );

    $bom->metadata->component($root_component);

    foreach my $dependency (@{$dist_data->dependency}) {
        if ($dependency->{phase} eq 'runtime' and $dependency->{relationship} eq 'requires') {
            next if ($dependency->{module} eq 'perl');

            make_dep_compoment(
                module           => $dependency->{module},
                bom              => $bom,
                parent_component => $root_component,
                maxdepth         => $options{maxdepth}
            );

        }
    }

    return $root_component;

}

sub make_external_references {

    my $resources = shift;

    my @external_references = ();

    if (defined $resources->{repository} && $resources->{repository}->{url}) {
        my $external_reference
            = SBOM::CycloneDX::ExternalReference->new(type => 'vcs', url => $resources->{repository}->{url});
        push @external_references, $external_reference;
    }

    if (defined $resources->{bugtracker} && $resources->{bugtracker}->{web}) {
        my $external_reference
            = SBOM::CycloneDX::ExternalReference->new(type => 'issue-tracker', url => $resources->{bugtracker}->{web});
        push @external_references, $external_reference;
    }

    return @external_references;

}

sub make_authors {

    my $metadata_authors = shift;

    my @authors = ();

    foreach my $metadata_author (@{$metadata_authors}) {
        if ($metadata_author =~ /(.*) <(.*)>/) {
            my ($name, $email) = $metadata_author =~ /(.*) <(.*)>/;
            push @authors, SBOM::CycloneDX::OrganizationalContact->new(name => $name, email => $email);
        }
        elsif ($metadata_author =~ /(.*), (.*)/) {
            my ($name, $email) = $metadata_author =~ /(.*), (.*)/;
            push @authors, SBOM::CycloneDX::OrganizationalContact->new(name => $name, email => $email);
        }
        else {
            push @authors, SBOM::CycloneDX::OrganizationalContact->new(name => $metadata_author);
        }
    }

    return @authors;

}

sub make_dep_compoment {

    my (%options) = @_;

    my $module           = $options{module};
    my $bom              = $options{bom};
    my $parent_component = $options{parent_component};
    my $depth            = $options{depth}    || 1;
    my $maxdepth         = $options{maxdepth} || 1;

    say STDERR sprintf '%s[%d] Collect %s@%s info (parent component %s)', ("    " x ($depth - 1)), $depth, $module,
        ($options{version} || '0'), $parent_component->bom_ref;

    my $mcpan       = MetaCPAN::Client->new;
    my $module_data = $mcpan->module($module);

    unless ($module_data) {
        Carp::carp("Unable to find module ($module) in Meta::CPAN");
        return;
    }

    my $author       = $module_data->author;
    my $release      = $module_data->release;
    my $distribution = $module_data->distribution;
    my $version      = $options{version} || $module_data->version;

    my $release_data = $mcpan->release({all => [{distribution => $distribution}, {version => $version}]});

    my $dist_data = $release_data->next;

    unless ($dist_data) {
        Carp::carp("Unable to find release ($distribution\@$version) in Meta::CPAN");
        return;
    }

    my $metadata = $dist_data->metadata;

    my @authors = make_authors($metadata->{author});

    my $license      = join ' AND ', @{$dist_data->metadata->{license}};
    my $spdx_license = cpan_meta_to_spdx_license($license);

    my $bom_license = SBOM::CycloneDX::License->new(($spdx_license) ? {id => $spdx_license} : {name => $license});

    my $purl = URI::PackageURL->new(type => 'cpan', namespace => $author, name => $distribution, version => $version);

    my @ext_refs = make_external_references($dist_data->metadata->{resources});

    my $hashes = SBOM::CycloneDX::List->new;

    if (my $checksum = $dist_data->checksum_sha256) {
        $hashes->add(SBOM::CycloneDX::Hash->new(alg => 'sha-256', content => $checksum));
    }

    if (my $checksum = $dist_data->checksum_md5) {
        $hashes->add(SBOM::CycloneDX::Hash->new(alg => 'md5', content => $checksum));
    }

    my $component = SBOM::CycloneDX::Component->new(
        type                => 'library',
        name                => $distribution,
        version             => $version,
        licenses            => [$bom_license],
        authors             => \@authors,
        bom_ref             => $purl->to_string,
        purl                => $purl,
        hashes              => $hashes,
        external_references => \@ext_refs,
    );

    if (!$bom->get_component_by_bom_ref($purl->to_string)) {
        $bom->components->push($component);
    }

    $bom->add_dependency($parent_component, [$component]);

    if ($depth < $maxdepth) {

        $depth++;

        foreach my $dependency (@{$dist_data->dependency}) {
            if ($dependency->{phase} eq 'runtime' and $dependency->{relationship} eq 'requires') {
                next if ($dependency->{module} eq 'perl');
                make_dep_compoment(
                    module           => $dependency->{module},
                    bom              => $bom,
                    parent_component => $component,
                    depth            => $depth
                );
            }
        }

    }

    return $component;

}

1;

__END__

=encoding utf-8

=head1 NAME

App::CPAN::SBOM - CPAN SBOM (Software Bill of Materials) generator

=head1 SYNOPSIS

    use App::CPAN::SBOM qw(run);

    run(\@ARGV);

=head1 DESCRIPTION

L<App::CPAN::SBOM> is a "Command Line Interface" helper module for C<cpan-sbom(1)> command.

=head2 METHODS

=over

=item App::CPAN::SBOM->run(@args)

=back

Execute the command

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/giterlizzi/perl-App-CPAN-SBOM/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/giterlizzi/perl-App-CPAN-SBOM>

    git clone https://github.com/giterlizzi/perl-App-CPAN-SBOM.git


=head1 AUTHOR

=over 4

=item * Giuseppe Di Terlizzi <gdt@cpan.org>

=back


=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2025 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
