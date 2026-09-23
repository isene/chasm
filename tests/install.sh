#!/bin/bash
# Focused installer checks; no root, network, or real desktop required.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

bundle(){
    local name=$1 frame_text=$2 dir
    dir=$TMP/$name/chasm
    mkdir -p "$dir/bin" "$dir/share/xcursors/default/cursors" "$dir/share/bare/plugins" "$dir/lib/systemd"
    for b in frame tile tile-strip glass bare show bolt bolt-auth spot chasm-session chasm-keys chasm-wp chasm-bg bits-cpu; do
        printf '#!/bin/sh\necho %s\n' "$b" > "$dir/bin/$b"
        chmod 755 "$dir/bin/$b"
    done
    printf '#!/bin/sh\necho %s\n' "$frame_text" > "$dir/bin/frame"
    printf 'frame test\n' > "$dir/VERSIONS"
    printf 'cursor\n' > "$dir/share/xcursors/default/cursors/hand"
    printf 'theme\n' > "$dir/share/xcursors/default/index.theme"
    printf 'service\n' > "$dir/lib/systemd/bolt-greet.service"
    tar -czf "$TMP/$name.tar.gz" -C "$TMP/$name" chasm
    sha256sum "$TMP/$name.tar.gz" > "$TMP/$name.tar.gz.sha256"
}
install_bundle(){
    "$HERE/chasm-install" --prefix "$TMP/prefix" --home "$TMP/home" --no-greeter --tarball "$TMP/$1.tar.gz" >/dev/null
}
fail_bundle(){
    if install_bundle "$1" >/dev/null 2>&1; then echo "unexpected success: $1" >&2; exit 1; fi
}

bundle first first
bundle second second
mkdir -p "$TMP/prefix/bin" "$TMP/home"
printf '#!/bin/sh\necho legacy\n' > "$TMP/prefix/bin/frame"
chmod 755 "$TMP/prefix/bin/frame"

# A bad checksum must not touch the existing installation.
printf x >> "$TMP/first.tar.gz"
fail_bundle first
[ "$("$TMP/prefix/bin/frame")" = legacy ]
bundle first first

# A broken bundle or link cannot reach activation.
tar -czf "$TMP/missing.tar.gz" -C "$TMP/first" chasm/VERSIONS
sha256sum "$TMP/missing.tar.gz" > "$TMP/missing.tar.gz.sha256"
fail_bundle missing
[ "$("$TMP/prefix/bin/frame")" = legacy ]
mkdir -p "$TMP/evil/chasm"
ln -s /tmp "$TMP/evil/chasm/escape"
tar -czf "$TMP/evil.tar.gz" -C "$TMP/evil" chasm
sha256sum "$TMP/evil.tar.gz" > "$TMP/evil.tar.gz.sha256"
fail_bundle evil
[ "$("$TMP/prefix/bin/frame")" = legacy ]
tar -czf "$TMP/traversal.tar.gz" --transform='s#chasm/VERSIONS#chasm/../escape#' -C "$TMP/first" chasm/VERSIONS
sha256sum "$TMP/traversal.tar.gz" > "$TMP/traversal.tar.gz.sha256"
fail_bundle traversal
[ "$("$TMP/prefix/bin/frame")" = legacy ]

# Simulate a failure partway through the first migration.
mkdir -p "$TMP/fakebin"
printf '#!/bin/sh\ncase " $* " in *"/bin/tile "*) exit 1 ;; esac\nexec /usr/bin/ln "$@"\n' > "$TMP/fakebin/ln"
chmod 755 "$TMP/fakebin/ln"
if PATH="$TMP/fakebin:$PATH" install_bundle first >/dev/null 2>&1; then
    echo 'migration unexpectedly succeeded' >&2; exit 1
fi
[ "$("$TMP/prefix/bin/frame")" = legacy ]
[ ! -e "$TMP/prefix/lib/chasm/current" ]

install_bundle first
[ "$("$TMP/prefix/bin/frame")" = first ]
# A failed preparation step must leave the active bundle alone.
mkdir -p "$TMP/blocked-home"
chmod 555 "$TMP/blocked-home"
if "$HERE/chasm-install" --prefix "$TMP/prefix" --home "$TMP/blocked-home" --no-greeter --tarball "$TMP/second.tar.gz" >/dev/null 2>&1; then
    echo 'upgrade unexpectedly succeeded' >&2; exit 1
fi
[ "$("$TMP/prefix/bin/frame")" = first ]
"$HERE/chasm-install" --prefix "$TMP/prefix" --rollback >/dev/null
[ "$("$TMP/prefix/bin/frame")" = legacy ]
"$HERE/chasm-install" --prefix "$TMP/prefix" --rollback >/dev/null
[ "$("$TMP/prefix/bin/frame")" = first ]
[ -x "$TMP/prefix/bin/bits-cpu" ]
"$HERE/chasm-install" --prefix "$TMP/prefix" --rollback >/dev/null
[ "$("$TMP/prefix/bin/frame")" = legacy ]
install_bundle first
install_bundle second
[ "$("$TMP/prefix/bin/frame")" = second ]
"$HERE/chasm-install" --prefix "$TMP/prefix" --rollback >/dev/null
[ "$("$TMP/prefix/bin/frame")" = first ]
[ -f "$TMP/home/.striprc" ]
grep -Fq "$TMP/prefix/bin/bits-cpu" "$TMP/home/.striprc"
echo 'installer checks passed'
