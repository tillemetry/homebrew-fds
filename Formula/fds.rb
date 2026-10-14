class Fds < Formula
  desc "Fire Dynamics Simulator by NIST (unofficial Apple Silicon build)"
  homepage "https://pages.nist.gov/fds-smv/"
  url "https://github.com/firemodels/fds/archive/refs/tags/FDS-6.11.1.tar.gz"
  sha256 "f0a3493ea5f77b18ee5aae065ffb5c3677ae5cc0e1479b5aac22872b472dc417"
  license :public_domain

  depends_on "cmake" => :build
  depends_on arch: :arm64
  depends_on "gcc"
  depends_on :macos
  depends_on "open-mpi"

  resource "hypre" do
    url "https://github.com/hypre-space/hypre/archive/refs/tags/v3.0.0.tar.gz"
    sha256 "d9dbfa34ebd07af1641f04b06338c7808b1f378e2d7d5d547514db9f11dffc26"
  end

  resource "sundials" do
    url "https://github.com/LLNL/sundials/archive/refs/tags/v7.5.0.tar.gz"
    sha256 "8b5fe715009cd0f1a0ff244729c2570e3e631d3bf357495e7813b5063d4d0cf3"
  end

  def install
    ENV.fortran
    ENV["OMPI_FC"] = formula_opt_bin("gcc")/"gfortran"
    mpi = formula_opt_bin("open-mpi")
    hypre = buildpath/"hypre-install"
    sundials = buildpath/"sundials-install"

    # Static HYPRE and SUNDIALS at the versions NIST pins for this release; no build-time downloads.
    resource("hypre").stage do
      (pkgshare/"licenses/hypre/blas").mkpath
      (pkgshare/"licenses/hypre/lapack").mkpath
      cp %w[COPYRIGHT LICENSE-APACHE LICENSE-MIT NOTICE], pkgshare/"licenses/hypre"
      cp "src/blas/COPYING", pkgshare/"licenses/hypre/blas"
      cp "src/lapack/COPYING", pkgshare/"licenses/hypre/lapack"
      cd "src" do
        system "./configure", "--prefix=#{hypre}", "CC=#{mpi}/mpicc", "CXX=#{mpi}/mpicxx",
               "--disable-fortran", "--without-MPI", "--enable-shared=no", "--with-timing",
               "--without-superlu", "--without-dsuperlu"
        system "make"
        system "make", "install"
      end
    end

    resource("sundials").stage do
      (pkgshare/"licenses/sundials/cvode").mkpath
      cp ["LICENSE", "NOTICE"], pkgshare/"licenses/sundials"
      cp ["src/cvode/LICENSE", "src/cvode/NOTICE"], pkgshare/"licenses/sundials/cvode"
      system "cmake", "-S", ".", "-B", "build", *std_cmake_args(install_prefix: sundials),
             "-DCMAKE_C_COMPILER=#{mpi}/mpicc", "-DCMAKE_Fortran_COMPILER=#{mpi}/mpifort",
             "-DBUILD_FORTRAN_MODULE_INTERFACE=ON", "-DBUILD_SHARED_LIBS=OFF", "-DBUILD_STATIC_LIBS=ON",
             "-DBUILD_CVODE=ON", "-DBUILD_ARKODE=OFF", "-DBUILD_IDA=OFF", "-DBUILD_IDAS=OFF",
             "-DBUILD_KINSOL=OFF", "-DBUILD_CVODES=OFF", "-DEXAMPLES_ENABLE_C=OFF",
             "-DEXAMPLES_ENABLE_F2003=OFF", "-DBUILD_TESTING=OFF"
      system "cmake", "--build", "build"
      system "cmake", "--install", "build"
    end

    cd "Build/ompi_gnu_osx" do
      # NIST's own GNU/Open MPI macOS target. The tarball has no .git, so pass the revision.
      system "make", "-f", "../makefile", "ompi_gnu_osx", "VPATH=../../Source",
             "COMP_FC=#{mpi}/mpifort", "HYPRE_HOME=#{hypre}", "SUNDIALS_HOME=#{sundials}",
             "GIT_HASH=FDS-#{version}", "GIT_BRANCH=homebrew", "GIT_DATE=2026-07-09", "GIT_STAT=",
             "LFLAGSMKL_CUSTOM=", "FFLAGSMKL="
      bin.install "fds_ompi_gnu_osx" => "fds"
    end

    # Local-machine MPI settings from Build/ompi_gnu_osx_arm64/FDSG.
    (bin/"FDSG").write <<~SH
      #!/bin/bash
      set -euo pipefail
      ranks=1
      input=
      while [ "$#" -gt 0 ]; do
        case "$1" in
          -h|--help) echo 'Usage: FDSG input.fds [-n processes]'; exit 0 ;;
          -n)
            if [ "$#" -lt 2 ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
              echo 'Error: -n requires a positive integer' >&2; exit 2
            fi
            ranks="$2"; shift 2 ;;
          *.fds)
            if [ -n "$input" ]; then echo 'Error: specify one input file' >&2; exit 2; fi
            input="$1"; shift ;;
          *) echo "Error: unknown argument: $1" >&2; exit 2 ;;
        esac
      done
      if [ -z "$input" ] || [ ! -f "$input" ]; then
        echo 'Error: specify an existing .fds input file' >&2; exit 2
      fi
      cd -- "$(dirname -- "$input")"
      input="./$(basename -- "$input")"
      export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
      if [ "$ranks" = 1 ]; then
        exec /usr/bin/caffeinate -i -s "#{opt_bin}/fds" "$input"
      fi
      exec /usr/bin/caffeinate -i -s "#{mpi}/mpiexec" \\
        --mca btl tcp,self --mca btl_tcp_if_include lo0 \\
        --mca btl_tcp_keepalive_time 60 --mca btl_tcp_keepalive_intvl 10 \\
        -x OMP_NUM_THREADS -n "$ranks" "#{opt_bin}/fds" "$input"
    SH
    (bin/"FDSG").chmod 0755
    pkgshare.install "LICENSE.md"
    (pkgshare/"PACKAGING.txt").write <<~EOS
      Fire Dynamics Simulator is developed by the National Institute of Standards and Technology.
      Packaging changes: Apple Silicon Homebrew build and local MPI launcher (FDSG).
      Source: firemodels/fds release FDS-#{version}.
    EOS
  end

  def caveats
    <<~EOS
      This is an unofficial Apple Silicon package of NIST's FDS #{version} release.
      Run: FDSG input.fds -n 4
      FDSG uses local-machine MPI workarounds and defaults OMP_NUM_THREADS to 1.
      Use fds or mpiexec directly for custom or multi-host execution.
      Smokeview is not included.
    EOS
  end

  test do
    ENV["OMP_NUM_THREADS"] = "1"
    (testpath/"smoke.fds").write <<~EOS
      &HEAD CHID='smoke', TITLE='Homebrew smoke test' /
      &MESH IJK=4,4,4, XB=0,1,0,1,0,1 /
      &MESH IJK=4,4,4, XB=1,2,0,1,0,1 /
      &TIME T_END=0.02 /
      &DUMP DT_HRR=0.01 /
      &TAIL /
    EOS
    [1, 2].each do |ranks|
      mkdir "ranks #{ranks}" do
        cp testpath/"smoke.fds", "smoke.fds"
        system bin/"FDSG", "smoke.fds", "-n", ranks.to_s
        assert_match "STOP: FDS completed successfully", File.read("smoke.out")
        assert_path_exists Pathname.pwd/"smoke_hrr.csv"
      end
    end
    assert_match "positive integer", shell_output("#{bin}/FDSG -n 0 2>&1", 2)
    assert_match "positive integer", shell_output("#{bin}/FDSG -n 2>&1", 2)
  end
end
