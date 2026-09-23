# FDS for Homebrew (Apple Silicon)

`fds.rb` builds an unofficial FDS package for ARM64 macOS. It uses the public
NIST source at `d12d366cd8e7a20fd97cc33d2f892934ee9a1e8b` (2026-01-14),
which matches this fork's Fortran source, plus HYPRE 3.0.0 and SUNDIALS 7.5.0.
All three downloads have SHA-256 checksums. The version identifies a development
snapshot, not a new official NIST release.

## Install locally

Homebrew and the Xcode Command Line Tools must already be installed.
From this repository's root:

```sh
mkdir -p "$(brew --repository)/Library/Taps/tillemetry/homebrew-fds/Formula"
cp Formula/fds.rb "$(brew --repository)/Library/Taps/tillemetry/homebrew-fds/Formula/"
brew install --build-from-source tillemetry/fds/fds
brew test tillemetry/fds/fds
```

Homebrew installs GCC, Open MPI, and CMake as dependencies. The first installation
compiles FDS and its solver libraries. No prebuilt bottle is provided.

```sh
FDSG input.fds
FDSG input.fds -n 4
OMP_NUM_THREADS=2 FDSG input.fds -n 4
brew uninstall fds
```

`fds` is the raw executable. `FDSG` runs in the input file's directory, prevents
system sleep during execution, and propagates the simulation's exit status.
It defaults to one OpenMP thread per rank and uses the fork's TCP/loopback MPI
settings for multiple ranks. These settings are for a single Mac; use `mpiexec`
and `fds` directly for multiple hosts. Smokeview is separate.

## Public distribution

This tap downloads only public sources and is separate from the private FDS fork:

```sh
brew install tillemetry/fds/fds
brew test tillemetry/fds/fds
```

Prebuilt bottles and CI can be added separately after choosing supported macOS
versions and a build budget.

## Maintenance and checks

```sh
brew style tillemetry/fds/fds
brew audit --strict tillemetry/fds/fds
brew test tillemetry/fds/fds
brew linkage --test tillemetry/fds/fds
```

The formula test runs a tiny two-mesh case with one and two MPI ranks and checks
completion and output files. This checks packaging, not scientific validation.
When updating sources, update the revision/date/version and archive checksum
together, then repeat the clean build and tests. Retain NIST's license notice.
