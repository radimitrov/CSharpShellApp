## PRoot — GPL-2.0

`native/<abi>/libproot.so`, `libproot-loader.so`, `libproot-loader32.so`.

Built from [`green-green-avk/proot`](https://github.com/green-green-avk/proot) v0.15_release — the
fork that carries the Android patches, an unbundled loader and freely relocatable binaries, which
upstream PRoot does not — statically linked against libtalloc 2.1.14. The build recipe is
[`green-green-avk/build-proot-android`](https://github.com/green-green-avk/build-proot-android),
driven by `tools/build-proot.ps1 -FromSource` through `tools/proot-build/`.

(PROOT_TERMINAL.MD §2.2 says "termux/proot". That was the plan's expectation; the recipe this tree
actually uses pulls green-green-avk's fork, and the two are not the same tree.)

`CSharpShellMaui.TerminalPRoot/native/SOURCE.txt` is written by the build and records the exact recipe
commit. **That file is the thing that makes the source offer specific** — a repository URL on its own
is not enough.

**The app is not a derived work.** PRoot is shipped as a separate executable that the app starts as a
subprocess and communicates with over a pipe — aggregation, which is the posture every Android PRoot
launcher takes, and the reason this does not put the IDE under the GPL.

**Distributing the binary still carries GPLv2 §3's obligation to make the corresponding source
available.** Concretely, every GitHub release whose APK contains these binaries must also carry, as
assets on the same release:

- the fork URL and the **exact commit** the binaries were built from;
- the build script used, so the build is reproducible;
- the GPL-2.0 licence text.

A link to a repository that could move is not enough on its own; the commit is what makes the offer
specific.

libtalloc is LGPL-3.0 and is statically linked into `libproot.so`. Static linking under the LGPL
normally obliges the distributor to allow relinking — here that is satisfied by the same source and
build-script publication, since the whole of PRoot's source is already being offered.

## Termux terminal-emulator and terminal-view — Apache-2.0

`libs/terminal-emulator-master-3b66f87996-1.aar`, `libs/terminal-view-master-3b66f87996-1.aar`, and
the `libtermux.so` inside the first of them.

From [`termux/termux-app`](https://github.com/termux/termux-app), Apache-2.0, inherited from Jack
Palevich's Terminal Emulator for Android. These need only the licence text and the copyright notice
reproduced in the app's third-party licence list — no source offer, and nothing that touches the rest
of the app.

## Debian

The userland is **not** distributed. It is pulled from Docker Hub on the user's device at install
time, so nothing about Debian's packaging ships in the APK and there is no distribution obligation
here at all. That is a genuine advantage of the registry route over hosting a tarball, and worth
remembering if the fallback URL of PROOT_TERMINAL.MD §4.1 is ever made the primary path — doing so
would make this app a Debian redistributor.
