# FDS for Homebrew (Apple Silicon)

An unofficial Homebrew formula for NIST's
[Fire Dynamics Simulator](https://pages.nist.gov/fds-smv/) (FDS) on Apple
Silicon Macs. Not affiliated with NIST.

It builds NIST's FDS 6.11.1 release from source, with the HYPRE 3.0.0 and
SUNDIALS 7.5.0 versions NIST pins for that release. All three downloads have
SHA-256 checksums.

> **Disclaimer.** This is an unofficial, community-maintained build. It is not
> affiliated with or endorsed by NIST. It is provided "as is", without warranty
> of any kind (see [LICENSE](LICENSE)). This build has been checked to compile
> and run; it has not been validated for accuracy. Results used for design,
> code compliance, or any life-safety decision must be checked by a qualified
> fire protection engineer against NIST's official releases, its Verification
> and Validation Guides, and the FDS User's Guide. You use this software at
> your own risk.

## Install

Install [Homebrew](https://brew.sh) first. Its installer also installs the
Xcode Command Line Tools if they are missing. Apple distributes those only
through its own channels, not GitHub.

```sh
brew install tillemetry/fds/fds
```

Or add the tap first, after which the short name works for install, upgrade
and uninstall:

```sh
brew tap tillemetry/fds
brew install fds
```

No `sudo` needed: Homebrew installs into folders you own and refuses to run as
root. Only installing Homebrew itself asks for an administrator password.

Homebrew installs GCC, Open MPI and CMake as dependencies, then compiles FDS
and its solver libraries (a few minutes). No prebuilt bottle is provided yet.

## Run

```sh
FDSG input.fds                          # one process
FDSG input.fds -n 4                     # 4 MPI processes, usually one per mesh
OMP_NUM_THREADS=2 FDSG input.fds -n 4   # override the one-thread-per-process default
```

`FDSG` is the only command added to your `PATH`. It runs in the input file's
directory, keeps the Mac awake during the run, and passes on the simulation's
exit status. For runs with more than one process, it works around two hangs
seen on long runs on Apple Silicon:

- MPI traffic goes over TCP on the loopback interface (`lo0`), because Open
  MPI's shared-memory transport can hang mid-run.
- Each process runs one OpenMP thread by default, because many processes each
  starting the default thread count can deadlock in the radiation solver.

These settings are for a single Mac. For multiple hosts, call `mpiexec` with
the raw executable, `$(brew --prefix fds)/libexec/fds`, directly. Smokeview is
separate.

## Maintenance and checks

```sh
brew style tillemetry/fds/fds
brew audit --strict tillemetry/fds/fds
brew test tillemetry/fds/fds
brew linkage --test tillemetry/fds/fds
```

The formula test runs a tiny two-mesh case with one and two MPI processes and
checks completion and output files, then runs the same mesh with
`SOLVER='UGLMAT HYPRE'` at two processes to confirm HYPRE was built with MPI.
This checks packaging, not scientific validation.

FDS links Homebrew's GCC and Open MPI dynamically. After `brew upgrade` moves
either to a new major version, run `brew reinstall fds`.

To move to a new FDS release: update the FDS `url`, its `sha256`, and the
`GIT_DATE` passed to `make` (the release commit's date). Bump the HYPRE and
SUNDIALS tags and checksums if NIST's `Build/makefile` pins new versions. Then
repeat a clean build and the checks above. Retain NIST's license notice.
