# moreutils via cosmoStaticCross for Windows-x86_64.
#
# mingw is a non-starter (no fork/waitpid/pipes), but Cosmopolitan's NT
# process layer handles the whole moreutils job model. Proven on the Windows
# VM (not wine — wine can't run APE, see docs/platforms/cosmocc.md): parallel
# runs a 200-job stress with -j 8 and loses no output, pee fans stdin out
# through popen pipes, mispipe/ifne/lckdo/sponge/isutf8/errno all behave.
#
# Ships 8 of the 9 C applets: ifdata reads network-interface info via Unix
# APIs (/proc, ioctls) and has no NT translation, so it stays Linux/macOS.
#
# Two portability shims vs. the native build:
#   - parallel.c calls waitid(), which cosmo libc lacks → cosmo-compat.h
#     emulates it on waitpid(), mirroring upstream's own __CYGWIN__ branch.
#   - pee.c uses signal() without including <signal.h> (transitive on glibc,
#     an implicit-declaration error on cosmocc) → force-include it.
#
# The symbol-isolation recipe differs from ./multicall.nix: cosmocc emits fat
# x86_64+aarch64 objects, so the native `ld -r` + objcopy route doesn't
# apply. Instead each tool is compiled twice — pass 1 to discover its defined
# globals with $NM, pass 2 with a force-included rename header
# (`#define main <tool>_main` + `#define <sym> <tool>__<sym>`) — the same
# X+Z preprocessor-rename recipe e2fsprogs' multicall uses for cosmo.
{ unpins-lib }:
pkgs:
let
  cosmoPkgs = unpins-lib.lib.cosmoStaticCross pkgs;
  lib = cosmoPkgs.lib // unpins-lib.lib;

  applets = [ "isutf8" "ifne" "pee" "sponge" "mispipe" "lckdo" "parallel" "errno" ];

  multicall = cosmoPkgs.stdenv.mkDerivation {
    pname = "moreutils";
    inherit (cosmoPkgs.moreutils) version;
    src = cosmoPkgs.moreutils.src;

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      # errno.c includes a generated table of E* codes built from the target
      # <errno.h> (mirrors upstream's Makefile errnos.h rule). cosmo's E*
      # constants are extern consts resolved per-OS at runtime, so the same
      # table is correct on NT and on the other APE hosts.
      echo '#include <errno.h>' > dump.c
      $CC -E -dD dump.c | awk '/^#define E/ { printf "{\"%s\",%s},\n", $2, $2 }' > errnos.h
      rm -f dump.c

      cp ${./cosmo-compat.h} cosmo-compat.h

      mkdir -p multicall objs

      objsForTool() {
        case "$1" in
          isutf8) echo "is_utf8/main.c is_utf8/is_utf8.c" ;;
          *)      echo "$1.c" ;;
        esac
      }
      extraFlagsFor() {
        case "$1" in
          parallel) echo "-include cosmo-compat.h" ;;
          pee)      echo "-include signal.h" ;;
        esac
      }

      OBJS=""
      for t in ${lib.concatStringsSep " " applets}; do
        # Pass 1: plain compile, then NM-discover the tool's defined globals.
        pass1=""
        for s in $(objsForTool "$t"); do
          o="objs/$t.$(basename "$s" .c).p1.o"
          $CC -O2 -I. -Iis_utf8 $(extraFlagsFor "$t") -c "$s" -o "$o"
          pass1="$pass1 $o"
        done
        {
          echo "/* multicall rename header: $t */"
          echo "#define main ''${t}_main"
          $NM --defined-only -g $pass1 | awk -v t="$t" '
            $2 ~ /^[TBDRWVC]$/ {
              sym = $3
              if (sym ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && sym != "main" && !seen[sym]++)
                print "#define " sym " " t "__" sym
            }'
        } > "multicall/$t.rename.h"
        # Pass 2: rebuild with every global renamed into the tool's namespace.
        toolobjs=""
        for s in $(objsForTool "$t"); do
          o="objs/$t.$(basename "$s" .c).o"
          $CC -O2 -I. -Iis_utf8 -include "multicall/$t.rename.h" $(extraFlagsFor "$t") -c "$s" -o "$o"
          toolobjs="$toolobjs $o"
        done
        OBJS="$OBJS $toolobjs"
      done

      printf '%s\n' ${lib.concatStringsSep " " applets} > multicall/apps.list
${lib.multicallDispatcherC { name = "moreutils"; defaultApplet = "errno"; }}
      $CC -O2 -c -o multicall/dispatcher.o multicall/dispatcher.c

      $CC -o moreutils multicall/dispatcher.o $OBJS

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 moreutils $out/bin/moreutils

      # Embed each shipped tool's man page (see ./multicall.nix). Reuse the
      # build-host nixpkgs roff — arch-independent text, valid for the cosmo
      # build too; the windows build harvests its own share/man. buildPackages
      # keeps it on the native host (perl package — never cross-build it).
      mkdir -p $out/share/man/man1
      for n in ${lib.concatStringsSep " " applets}; do
        gzip -dc ${pkgs.buildPackages.moreutils}/share/man/man1/$n.1.gz > $out/share/man/man1/$n.1
      done

      runHook postInstall
    '';

    meta = {
      description = "Standalone build of moreutils (C tools)";
      license = lib.licenses.gpl2Plus;
    };
  };
in
# No applet symlinks on Windows; the apelink hook renames the binary to
# .exe, and withAliases embeds the applet names as UNPIN_META so unpin's
# installer recreates the argv[0] shims.
lib.withAliases cosmoPkgs
  {
    primary = "moreutils.exe";
    aliases = applets;
  }
  multicall
