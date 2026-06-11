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
  # Linux + macOS native via ./multicall.nix (9 tools, static, post-linked);
  # Windows via Cosmopolitan (./cosmo.nix, 8 tools — ifdata is Unix
  # network-interface only). mingw has no fork/waitpid/pipes, but cosmo's NT
  # process layer runs the whole moreutils job model — validated on a real
  # Windows VM, including a 200-job `parallel -j 8` stress with no output
  # lost. (wine is not a proxy here: it can't run APE at all.)
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "moreutils";
      # These tools mostly have no --version; `errno -h` is the portable
      # exit-0 smoke. defaultApplet routes the bare/renamed invocation there.
      smoke = [ "-h" ];
      smokePattern = "Usage: errno";
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };
      build = pkgs:
        import ./multicall.nix {
          lib = pkgs.lib // unpins-lib.lib;
        } pkgs;
    };
}
