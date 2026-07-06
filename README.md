# moreutils

[moreutils](https://joeyh.name/code/moreutils/) — the C programs from Joey Hess's collection of Unix utilities. A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/moreutils/actions/workflows/moreutils.yml/badge.svg)](https://github.com/unpins/moreutils/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install moreutils`.

## Usage

Run a program with [unpin](https://github.com/unpins/unpin):

```bash
echo hi | unpin moreutils sponge file.txt          # soak up stdin, then write the file
unpin moreutils parallel gzip -- *.log             # run a command per argument, in parallel
git ls-files | unpin moreutils ifne xargs wc -l    # run only if stdin is non-empty
unpin moreutils errno 13                            # look up an errno code
```

To install the programs onto your PATH:

```bash
unpin install moreutils
```

This creates `sponge`, `parallel`, `pee`, `ifne`, and the rest — `unpin info moreutils` lists them all (on Windows, every one except `ifdata`).

## Build locally

```bash
nix build
./result/bin/moreutils errno -l
```

Or run directly:

```bash
nix run github:unpins/moreutils
```

Linux x86_64 ~190 KB stripped. The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/moreutils/releases) page has standalone binaries for manual download.

## Build notes

- The programs are folded into one `moreutils` binary that picks the right tool from how it's invoked; `unpin install` recreates the individual commands. (Several tools each define their own `usage` and globals, so every tool's symbols except its entry point are made file-local before linking.)
- The Windows build comes from [Cosmopolitan](https://github.com/jart/cosmopolitan) (mingw has no `fork`/`waitpid`/pipes, which most of these tools are built on). Cosmopolitan's NT process layer runs the whole moreutils job model — validated on real Windows, including a 200-job `parallel -j 8` stress with no output lost. It ships 8 of the 9 programs; `ifdata` (network-interface info via Unix-only APIs) has no Windows translation.
- The Perl programs (`vidir`, `vipe`, `ts`, `combine`, `zrun`, `chronic`) are excluded — they need non-core Perl modules that don't fit a self-contained single binary. Every C program ships, with no upstream features disabled.

