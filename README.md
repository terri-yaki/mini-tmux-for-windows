# tmux-for-windows

tmux 3.6a running natively on Windows. No WSL, no installer, no admin rights.

This is a repackaging of unmodified binaries from the MSYS2 package
repositories (https://repo.msys2.org/msys/x86_64/) plus the minimal set of
runtime libraries they link against. Nothing was compiled or patched for
this repo; the only hand-written file is `etc/tmux.conf`.

tmux itself is written by **Nicholas Marriott** — upstream lives at
https://github.com/tmux/tmux. This repo only packages his work for Windows;
all credit for tmux goes to him and the tmux contributors.

## How it works

`msys-2.0.dll` is the MSYS2 runtime (a Cygwin fork). It gives Windows
processes the POSIX layer tmux needs: `fork()`, pseudo-terminals, and unix
domain sockets. The runtime locates its install root from its own DLL path,
which is why the directory layout is fixed and the folder is relocatable:

```
<root>
├── usr\bin\        tmux.exe, bash.exe, sh.exe, winpty, runtime DLLs
├── usr\share\      terminfo
├── etc\tmux.conf   default-shell = /usr/bin/bash
└── tmp\            tmux server socket: /tmp/tmux-<uid>/default
```

Move the folder wherever you want, but keep the structure. `tmp\` must
exist — tmux creates the `tmux-<uid>` subdirectory itself but not the
parent, and without it `new-session` dies with "no suitable socket path".

## Install

Clone, then add `<root>\usr\bin` to the user PATH. Open a new terminal
afterwards — PATH changes don't propagate to already-running processes.

## Usage

```
tmux new -s main
tmux split-window -h
tmux attach -t main
```

Use `winpty` for Windows-native console programs. MSYS2 ptys are pipes, and
Windows apps (Node.js CLIs, python, cmd, powershell) probe the console API
and disable their interactive UI when stdout isn't a real console. winpty
runs the program on a hidden Windows console and bridges it to the pty:

```
winpty powershell
winpty python
```

Non-console programs (bash, most Unix tools) don't need it.

## MSYS=noglob

When tmux is spawned by a non-MSYS parent (Node, Python, .NET — anything
not linked against `msys-2.0.dll`), the runtime performs POSIX argument
globbing on the incoming Windows command line. That includes brace
expansion, so `-F '#{pane_id}'` arrives at tmux as `#pane_id` and the
format string is dead. Arguments containing spaces get quoted by the parent
and survive untouched; bare ones don't.

Set `MSYS=noglob` in the parent process environment to disable this. If a
`-F` format ever comes back echoed literally, this is why. (Hit firsthand
via tmux-bridge-mcp, which feeds brace-heavy `-F` strings through Node's
`child_process`.)

## Don't mix runtimes

Git for Windows ships its own fork of the msys runtime, ABI-incompatible
with upstream MSYS2's. A pane (which already has MSYS2's runtime mapped)
cannot exec Git Bash's `bash.exe` — the child keeps the loaded runtime and
the mismatched binary dies on startup. Use the bundled bash inside panes.
Calling this tmux *from* Git Bash is fine; that's a separate process.

## Package manifest

All binaries unmodified from https://repo.msys2.org/msys/x86_64/:

- tmux-3.6.a-1
- bash-5.3.015-1
- msys2-runtime-3.6.9-2
- libevent-2.1.12-4
- ncurses-6.6-2 (libs + terminfo)
- libreadline-8.3.003-1
- libintl-0.22.5-1
- libiconv-1.19-1
- winpty-0.4.3-3

winpty is by **Ryan Prichard**: https://github.com/rprichard/winpty
Runtime and packaging infrastructure: the MSYS2 project,
https://github.com/msys2

## Uninstall

Delete the folder, remove it from PATH. No registry entries, no services.

## Licenses

tmux is ISC, bash is GPLv3, winpty is MIT, the MSYS2 runtime is LGPLv3
(Cygwin). All binaries redistributed unmodified; see the respective
projects for license texts.
