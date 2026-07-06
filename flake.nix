{
  description = "moreutils (the C tools) as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # moreutils ships ~15 small programs; the unpins one-pkg-one-bin rule folds
  # them into a single `moreutils` multicall binary. We ship only the C tools
  # (isutf8 ifdata ifne pee sponge mispipe lckdo parallel errno) — the rest
  # (vidir vipe ts combine zrun chronic) are Perl scripts with non-core module
  # deps (IPC::Run, Date::Parse), out of scope for a self-contained binary.
  #
  # Linux + macOS native fold via the unpin-llvm engine (9 tools, static,
  # bitcode self-fold); Windows via Cosmopolitan (./cosmo.nix, 8 tools — ifdata
  # is Unix network-interface only). mingw has no fork/waitpid/pipes, but cosmo's NT
  # process layer runs the whole moreutils job model — validated on a real
  # Windows VM, including a 200-job `parallel -j 8` stress with no output
  # lost. (wine is not a proxy here: it can't run APE at all.)
  outputs = { self, unpins-lib }:
    let
      ulib = unpins-lib.lib;

      # Engine path (Linux + macOS): moreutils has no static-libc story in
      # nixpkgs — `pkgsStatic.moreutils` drags in a static perl (for the
      # vidir/ts/… perl scripts) whose test suite fails to cross/static-build,
      # so we can't use the stock derivation. Instead build ONLY the nine C tools as separate
      # executables straight from the upstream Makefile's `%: %.c` rules — as
      # distinct binaries, not a hand-folded multicall. The engine captures each
      # link sidecar and the standalone self-folds them into one `moreutils`
      # binary.
      cTools = [ "isutf8" "ifdata" "ifne" "pee" "sponge" "mispipe" "lckdo" "parallel" "errno" ];
      engineBuild = pkgs:
        let
          static = pkgs.pkgsStatic;
          # Use the SAME stdenv the nix-lib wired onto pkgsStatic.moreutils (the
          # unpin-llvm engine + capture hook). The stock `static.stdenv` is the
          # plain gcc one and would skip the link-capture sidecars the bitcode
          # multicall hook needs ("no link sidecar for <tool>").
          engStdenv = static.moreutils.stdenv;
        in engStdenv.mkDerivation {
          pname = "moreutils";
          inherit (pkgs.moreutils) version;
          src = pkgs.moreutils.src;
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            # errno.c includes a generated table of E* codes from the target
            # <errno.h> (mirrors upstream's Makefile errnos.h rule).
            echo '#include <errno.h>' > dump.c
            $CC -E -dD dump.c | awk '/^#define E/ { printf "{\"%s\",%s},\n", $2, $2 }' > errnos.h
            rm -f dump.c
            # Compile to .o then link, so the engine's link-capture sidecar
            # (which needs >=1 object input on the LINK step) fires per tool.
            # isutf8 is the two-file is_utf8/ subdir.
            $CC $CFLAGS -I. -Iis_utf8 -c is_utf8/main.c -o isutf8-main.o
            $CC $CFLAGS -I. -Iis_utf8 -c is_utf8/is_utf8.c -o isutf8-is_utf8.o
            $CC $LDFLAGS -o isutf8 isutf8-main.o isutf8-is_utf8.o
            for t in ifdata ifne pee sponge mispipe lckdo parallel errno; do
              $CC $CFLAGS -I. -c "$t.c" -o "$t.o"
              $CC $LDFLAGS -o "$t" "$t.o"
            done
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            for t in ${pkgs.lib.concatStringsSep " " cTools}; do
              install -m755 "$t" "$out/bin/$t"
            done
            # Embed each shipped tool's man page (arch-independent roff from the
            # native nixpkgs moreutils — same-version; withMan folds it in).
            mkdir -p $out/share/man/man1
            for t in ${pkgs.lib.concatStringsSep " " cTools}; do
              gzip -dc ${pkgs.buildPackages.moreutils}/share/man/man1/$t.1.gz > $out/share/man/man1/$t.1
            done
            runHook postInstall
          '';
          meta.license = pkgs.lib.licenses.gpl2Plus;
        };
    in
    ulib.mkStandaloneFlake {
      inherit self;
      name = "moreutils";
      # These tools mostly have no --version; `errno -h` is the portable
      # exit-0 smoke. defaultProgram routes the bare/renamed invocation there.
      smoke = [ "-h" ];
      smokePattern = "Usage: errno";
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };

      # Build via the unpin-llvm engine + emit a bitcode multicall module. On
      # Linux AND macOS the engine compiles the nine C tools (engineBuild) to
      # bitcode and the standalone self-folds them into one `moreutils` binary;
      # windows folds via Cosmopolitan (./cosmo.nix). The perl scripts
      # (vidir/ts/…) are out of scope (non-core module deps). Pure C, no
      # frameworks/libraries beyond libc — no requires.cxx/frameworks.
      engine = "unpin-llvm";
      multicall = {
        programs = map (n: { name = n; }) cTools;
        defaultProgram = "errno";
      };

      build = engineBuild;
    };
}
