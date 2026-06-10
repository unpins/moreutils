# moreutils

[moreutils](https://joeyh.name/code/moreutils/) — the C programs from Joey Hess's collection of Unix utilities. A single self-contained binary, built natively for Linux and macOS.

[![CI](https://github.com/unpins/moreutils/actions/workflows/moreutils.yml/badge.svg)](https://github.com/unpins/moreutils/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

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

`unpin install moreutils` creates the commands `errno`, `ifdata`, `ifne`, `isutf8`, `lckdo`, `mispipe`, `parallel`, `pee`, and `sponge`. The full list is always in `unpin info moreutils`.

## Programs

| command | what it does |
| --- | --- |
| `sponge` | soak up all of stdin, then write it to a file (lets a pipeline read and write the same file) |
| `parallel` | run a command for each argument, several at a time |
| `pee` | feed stdin to several commands at once (like `tee` into pipes) |
| `ifne` | run a command only if stdin is not empty |
| `mispipe` | pipe two commands, returning the exit status of the first |
| `lckdo` | run a command while holding a lock on a file |
| `isutf8` | check whether files (or stdin) are valid UTF-8 |
| `ifdata` | print information about a network interface |
| `errno` | look up errno names, numbers, and messages |

The Perl programs from moreutils (`vidir`, `vipe`, `ts`, `combine`, `zrun`, `chronic`) are not included — they depend on non-core Perl modules, so they don't fit a self-contained single binary.

## Build locally

```bash
nix build
./result/bin/moreutils errno -l
```

Or run directly:

```bash
nix run github:unpins/moreutils
```

Linux x86_64 ~130 KB stripped. The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/moreutils/releases) page has standalone binaries for manual download.

## Build notes

- The programs are folded into one `moreutils` binary that picks the right tool from how it's invoked; `unpin install` recreates the individual commands. (Several tools each define their own `usage` and globals, so every tool's symbols except its entry point are made file-local before linking.)
- **No Windows build.** Most of these tools rely on the POSIX process model (`fork`/`waitpid`/pipes). mingw doesn't provide it, and while Cosmopolitan polyfills `fork` on Windows, its fork/spawn/`waitpid` emulation is unreliable for `parallel`'s job scheduling — jobs run but their output is lost — so a Windows build would silently misbehave. For parallel command execution on Windows, `xargs -P` (from [unpins/findutils](https://github.com/unpins/findutils)) is a portable alternative.
- No upstream features are disabled on the platforms that are shipped.

