[![Release](https://img.shields.io/github/release/giterlizzi/perl-App-CPAN-SBOM.svg)](https://github.com/giterlizzi/perl-App-CPAN-SBOM/releases) [![Actions Status](https://github.com/giterlizzi/perl-App-CPAN-SBOM/workflows/linux/badge.svg)](https://github.com/giterlizzi/perl-App-CPAN-SBOM/actions) [![License](https://img.shields.io/github/license/giterlizzi/perl-App-CPAN-SBOM.svg)](https://github.com/giterlizzi/perl-App-CPAN-SBOM) [![Starts](https://img.shields.io/github/stars/giterlizzi/perl-App-CPAN-SBOM.svg)](https://github.com/giterlizzi/perl-App-CPAN-SBOM) [![Forks](https://img.shields.io/github/forks/giterlizzi/perl-App-CPAN-SBOM.svg)](https://github.com/giterlizzi/perl-App-CPAN-SBOM) [![Issues](https://img.shields.io/github/issues/giterlizzi/perl-App-CPAN-SBOM.svg)](https://github.com/giterlizzi/perl-App-CPAN-SBOM/issues) [![Coverage Status](https://coveralls.io/repos/github/giterlizzi/perl-App-CPAN-SBOM/badge.svg)](https://coveralls.io/github/giterlizzi/perl-App-CPAN-SBOM)

# App-CPAN-SBOM - CPAN SBOM (Software Bill of Materials) generator

## Synopsis

```.bash

cpan-sbom --distribution libwww-perl@6.78

cpan-sbom \
    --project-directory . \
    --project-name "My Cool Application" \
    --project-version 1.337 \
    --project-license Artistic-2.0
    --project-author "Larry Wall <larry@wall.org>"
```

## Install

Using Makefile.PL:

To install `App-CPAN-SBOM` distribution, run the following commands.

    perl Makefile.PL
    make
    make test
    make install

Using `App::cpanminus`:

    cpanm App::CPAN::SBOM


## Documentation

- `perldoc App::CPAN::SBOM`
- https://metacpan.org/release/App-CPAN-SBOM

## Copyright

- Copyright 2025 © Giuseppe Di Terlizzi
