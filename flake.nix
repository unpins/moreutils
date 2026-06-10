{
  description = "Standalone build of moreutils";

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
  # Linux + macOS only. ./multicall.nix builds the 9 C tools static and
  # post-links them. No Windows build: most tools assume fork/waitpid/pipe,
  # which mingw lacks; Cosmopolitan polyfills fork on Windows but its
  # fork/spawn/waitpid emulation is unreliable for `parallel`'s job model
  # (jobs run but output is lost), so shipping it would silently misbehave.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "moreutils";
      # These tools mostly have no --version; `errno -h` is the portable
      # exit-0 smoke. defaultApplet routes the bare/renamed invocation there.
      smoke = [ "-h" ];
      smokePattern = "Usage: errno";
      build = pkgs:
        import ./multicall.nix {
          lib = pkgs.lib // unpins-lib.lib;
        } pkgs;
    };
}
