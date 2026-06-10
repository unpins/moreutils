# moreutils ships its tools as independent single-.c programs (plus isutf8's
# two-file is_utf8/ subdir) built by a trivial Makefile — no shared library, no
# autotools. To honour one-pkg-one-bin we compile only the C tools, fold each
# into one relocatable object, and link a single multicall binary.
#
# Why localize-all-but-main per tool: several tools define an *external* `usage`
# (ifdata/sponge/parallel) with conflicting signatures, plus their own globals.
# Renaming just `main` would still collide at the final link. So per tool we
# `ld -r` its objects together, rename `main` → `<tool>_main`, and keep ONLY
# that symbol global (every other defined symbol becomes file-local) — the
# whole-program-as-a-library trick, one entry point each. Internal references
# (e.g. isutf8 main.c → is_utf8.c helpers, now local) stay resolved inside the
# combined object.
{ lib }:
pkgs:
let
  static = pkgs.pkgsStatic;

  # Mach-O leads C symbols with `_`; ELF does not. objcopy symbol args need it.
  pfx = lib.optionalString static.stdenv.hostPlatform.isDarwin "_";
  staticFlag = lib.optionalString (!static.stdenv.hostPlatform.isDarwin) "-static";

  # i686-musl PIC quirk: -fPIC code references __x86.get_pc_thunk.* and each
  # object exports its own (linkonce) copy. Our `objcopy --keep-global-symbol`
  # localizes *every* global but <tool>_main — including those thunks — so
  # libc.a's references to them go unresolved at the final link. A static,
  # non-PIE binary needs no PIC: build non-PIC so no thunks exist to localize.
  # Harmless on the other arches (they have no such thunks anyway).
  picFlag = lib.optionalString static.stdenv.hostPlatform.isLinux "-fno-pic";
  noPieFlag = lib.optionalString static.stdenv.hostPlatform.isLinux "-no-pie";

  # The partial link must use the UNWRAPPED ld: the wrapper appends
  # NIX_LDFLAGS to every invocation, and nix-lib's dns-fallback puts
  # `--wrap=getaddrinfo … -l:libunpindns.a -lc` there — so a wrapped `ld -r`
  # folds PIC libc.a members into each tool object, whose COMDAT pc-thunks
  # the objcopy step then localizes (fatal on i686, silent libc text
  # duplication everywhere else). An `-r` combine of the tool's own objects
  # needs no search paths, so the raw ld loses nothing.
  rawLd = "${static.stdenv.cc.bintools.bintools}/bin/${static.stdenv.cc.targetPrefix}ld";

  # All nine C tools. ifdata is Linux/Unix network-interface only; it builds and
  # runs here, but is dropped from the cosmo/Windows multicall (see cosmo.nix).
  applets = [ "isutf8" "ifdata" "ifne" "pee" "sponge" "mispipe" "lckdo" "parallel" "errno" ];

  multicall = static.stdenv.mkDerivation {
    pname = "moreutils";
    inherit (pkgs.moreutils) version;
    src = pkgs.moreutils.src;

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      pfx="${pfx}"

      # errno.c includes a generated table of E* codes built from the *target*
      # <errno.h> (mirrors upstream's Makefile errnos.h rule).
      echo '#include <errno.h>' > dump.c
      $CC -E -dD dump.c | awk '/^#define E/ { printf "{\"%s\",%s},\n", $2, $2 }' > errnos.h
      rm -f dump.c

      mkdir -p multicall objs

      objsForTool() {
        case "$1" in
          isutf8) echo "is_utf8/main.c is_utf8/is_utf8.c" ;;
          *)      echo "$1.c" ;;
        esac
      }

      OBJS=""
      for t in ${lib.concatStringsSep " " applets}; do
        toolobjs=""
        for s in $(objsForTool "$t"); do
          o="objs/$t.$(basename "$s" .c).o"
          $CC -O2 ${picFlag} -I. -Iis_utf8 -c "$s" -o "$o"
          toolobjs="$toolobjs $o"
        done
        ${rawLd} -r $toolobjs -o "objs/$t.o"
        $OBJCOPY --redefine-sym "''${pfx}main=$pfx''${t}_main" "objs/$t.o"
        $OBJCOPY --keep-global-symbol="$pfx''${t}_main" "objs/$t.o"
        OBJS="$OBJS objs/$t.o"
      done

      printf '%s\n' ${lib.concatStringsSep " " applets} > multicall/apps.list
${lib.multicallDispatcherC { name = "moreutils"; defaultApplet = "errno"; }}
      $CC -O2 ${picFlag} -c -o multicall/dispatcher.o multicall/dispatcher.c

      $CC ${staticFlag} ${noPieFlag} -o moreutils multicall/dispatcher.o $OBJS

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 moreutils $out/bin/moreutils
      for n in ${lib.concatStringsSep " " applets}; do
        ln -s moreutils $out/bin/$n
      done
      runHook postInstall
    '';

    meta = {
      description = "Standalone build of moreutils (C tools)";
      license = lib.licenses.gpl2Plus;
    };
  };
in
lib.withAliases pkgs
  {
    primary = "moreutils";
    aliasesFromSymlinksIn = "bin";
  }
  multicall
