# Builds PRoot for Android with a 16 KB-page-safe toolchain.
#
# PROOT_TERMINAL.MD §2.2. The published prebuilts at green-green-avk/build-proot-android are linked
# with NDK r23 and their LOAD segments are 4 KB-aligned, so they will not load on a device with 16 KB
# pages — every device shipping with Android 15+ on a 16 KB kernel. This image exists to produce the
# same binaries with the alignment fixed.
#
# GPL-2.0: PRoot's source, this file and build.sh beside it are the "corresponding source" that has to
# be published alongside any release carrying libproot.so. See ../../CSharpShellMaui.TerminalPRoot/LICENSES.md.

# bullseye, and the reason is talloc rather than anything about Debian.
#
# talloc 2.1.14 — the version green-green-avk's recipe pins — bundles a waf that is **Python 2
# only**. Not "old Python 3", actually Python 2: `except Utils.WafError, e:` is a SyntaxError on
# every Python 3 there has ever been. So no amount of picking a younger python3 helps, and the
# needed interpreter is one Debian dropped after bullseye.
#
# bullseye is the last release carrying python2 (2.7.18). It only ever runs the build system —
# nothing about the interpreter reaches the produced binaries, which are cross-compiled by the
# NDK clang below. Bumping TALLOC_V to a waf-2.0 release would remove the need, but the
# cross-answers.txt in make-talloc-static.sh is written against 2.1.14's configure checks, and
# rewriting those to avoid installing an old interpreter is a poor trade.
FROM debian:bullseye-slim

# python-is-python2 matters as much as python2 itself: talloc's Makefile invokes waf as `python`,
# and an image without that name fails with `env: 'python': No such file or directory` — from a
# `make distclean || true` line, so the first failure is swallowed and the error resurfaces later
# at ./configure, pointing at the wrong step.
#
# python3 is here too, for build.sh's own alignment check. The two do not interfere: only `python`
# is what waf reaches for.
#
# The rest is the recipe's own dependency list: wget for get-proot.sh/get-talloc.sh, make/gcc for
# the host side of the cross build, file for its sanity checks.
# Retries because bullseye is oldstable and deb.debian.org drops connections often enough to fail
# a clean build on nothing but luck. One transient fetch failure aborts the whole layer.
RUN apt-get -o Acquire::Retries=8 update \
    && apt-get -o Acquire::Retries=8 install -y --no-install-recommends \
        bash curl wget unzip make gcc g++ python2 python-is-python2 python3 gawk binutils \
        tar gzip bzip2 xz-utils ca-certificates git file patch \
    && rm -rf /var/lib/apt/lists/*

# gawk specifically, and it has to be the *default* awk. PRoot's GNUmakefile generates
# loader/loader-info.c by piping `readelf -s` through loader-info.awk, which calls strtonum() — a
# GNU awk builtin. Debian defaults to mawk, which does not have it, and the build dies with
# "function strtonum never defined" after having compiled and linked the loader successfully, so
# the failure looks like a linker problem rather than a missing package. Installing gawk is not
# enough on its own: Debian keeps mawk as the alternative when both are present.
RUN update-alternatives --set awk /usr/bin/gawk

# r29 rather than the r28 floor, to match the NDK that produced the 16 KB-aligned libtermux.so in
# CSharpShellMaui.TerminalPRoot/libs — one toolchain generation across the whole native payload is one
# less variable when something does not load.
ARG NDK_VERSION=android-ndk-r29
RUN curl -fsSL -o /tmp/ndk.zip "https://dl.google.com/android/repository/${NDK_VERSION}-linux.zip" \
    && unzip -q /tmp/ndk.zip -d /opt \
    && rm /tmp/ndk.zip
ENV NDK_HOME=/opt/${NDK_VERSION}

# Pinned rather than tracking master: this is the source that has to be republished to satisfy GPLv2,
# so it has to be a commit that can be named.
ARG RECIPE_REF=master
RUN git clone https://github.com/green-green-avk/build-proot-android /src \
    && cd /src && git checkout "${RECIPE_REF}" && git rev-parse HEAD > /recipe-commit.txt

COPY build.sh /build.sh
RUN chmod +x /build.sh

WORKDIR /src
CMD ["/build.sh"]
