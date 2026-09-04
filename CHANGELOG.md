# Changelog

## [Unreleased]

### Fixed

- The README ran the programs positionally (`unpin moreutils sponge file.txt`),
  a form the binary does not accept — it answers with the list of programs and
  exits 1. Every example now uses `--unpin-program=`, including the
  `./result/bin/...` and `nix run` ones, and the bare invocation is described
  as what it does: print the list.

### Changed

- Built by the same compiler as the rest of the catalog. The binary grew from
  140 KB to 196 KB. Checked on Linux x86_64 and arm64, and on the Windows
  build: all nine programs do their work — `errno 13` resolves EACCES,
  `sponge` writes, `ifne` runs a command only with input on stdin, `pee` feeds
  both readers, `mispipe` returns the first command's exit status, `isutf8`
  accepts valid UTF-8 and names the byte on invalid, `parallel` runs its jobs,
  `ifdata` reads an interface address, `lckdo` takes the lock. Windows carries
  eight of the nine — `ifdata` needs Linux network ioctls — and announces
  exactly those eight.
