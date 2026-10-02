#!/bin/bash
# install-check: prove that a clean machine ends up with a working CHasm.
#
# Run it as a normal user who can sudo, from a checkout of this repo, on a
# machine that has never seen CHasm. It installs the way the README says,
# then starts what was installed. The GitHub job in
# .github/workflows/install-test.yml runs it in clean containers.
#
# Nothing here needs a screen: frame runs with its picture in plain memory
# (--fbtest) and without touching any keyboard or mouse (--noinput).
set -uo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
BIN=/usr/local/bin
fail=0
ok(){ printf '  ok    %s\n' "$1"; }
bad(){ printf '  FAIL  %s\n' "$1"; fail=1; }
check(){ # check NAME COMMAND...: the command must exit 0
    local name=$1 out; shift
    if out=$("$@" 2>&1); then ok "$name"; else bad "$name: ${out:-no output}"; fi
}
prints(){ # prints NAME WANTED COMMAND...: the output must contain WANTED
    local name=$1 want=$2 out; shift 2
    out=$("$@" 2>&1) || true
    case $out in *"$want"*) ok "$name" ;; *) bad "$name: wanted '$want', got '${out:-nothing}'" ;; esac
}

echo "== install"
"$HERE/chasm-install" --no-greeter || { echo "chasm-install failed"; exit 1; }

echo "== files"
for p in frame tile tile-strip glass bare show spot bolt bolt-greet bolt-auth \
         chasm-session chasm-keys chasm-bg chasm-wp bare-open; do
    check "$p is installed" test -x "$BIN/$p"
done
for rc in tilerc striprc glassrc barerc framerc; do
    check "~/.$rc is there" test -s "$HOME/.$rc"
done
check "five wallpapers" test "$(ls "$HOME/.local/share/chasm/wallpapers"/*.png 2>/dev/null | wc -l)" -eq 5
check "session entry for the login screen" test -s /usr/share/xsessions/chasm.desktop
check "bolt-auth is suid root" test -u "$BIN/bolt-auth"
if ldd "$BIN/bolt-auth" 2>&1 | grep -q 'not found'; then
    bad "bolt-auth misses a library: $(ldd "$BIN/bolt-auth" | grep 'not found' | tr -s ' \t\n' ' ')"
else
    ok "bolt-auth finds its libraries"
fi

echo "== programs that need no screen"
prints "frame --version" "frame " frame --version
prints "tile --version"  "tile "  tile --version
prints "show --version"  "show "  show --version
prints "bare runs a command" "hello from bare" bare -c 'echo hello from bare'
check  "bolt-greet draws one frame" bolt-greet --fbtest
for b in date clock uptime mem moonphase; do
    check "bits-$b prints a line" test -n "$("bits-$b" 2>/dev/null)"
done
check "chasm-keys reads the key table" test "$(chasm-keys 2>/dev/null | wc -l)" -gt 5

echo "== the desktop, with no screen"
D=17
LOG=$(mktemp -d)
pids=()
trap 'for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done' EXIT
# No /tmp/.X11-unix on a clean machine: frame (0.1.36 on) makes it itself.

frame $D --fbtest --noinput >"$LOG/frame" 2>&1 &
pids+=($!); FRAME=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S /tmp/.X11-unix/X$D ] && break; sleep 0.2; done
check "frame made the socket folder, sticky and open" test "$(stat -c %a /tmp/.X11-unix)" = 1777
prints "frame answers as an X server" "frame" sh -c "DISPLAY=:$D xdpyinfo | grep 'vendor string'"

DISPLAY=:$D tile --no-autostart >"$LOG/tile" 2>&1 &
pids+=($!); TILE=$!
DISPLAY=:$D glass -e sh -c 'echo hi; sleep 30' >"$LOG/glass" 2>&1 &
pids+=($!); GLASS=$!
DISPLAY=:$D tile-strip >"$LOG/strip" 2>&1 &
pids+=($!); STRIP=$!
sleep 3
for pair in "frame:$FRAME" "tile:$TILE" "glass:$GLASS" "tile-strip:$STRIP"; do
    n=${pair%%:*}; p=${pair##*:}
    if kill -0 "$p" 2>/dev/null; then ok "$n is still running after 3 s"
    else bad "$n died: $(tail -n 3 "$LOG/${n#tile-}" 2>/dev/null | tr '\n' ' ')"; fi
done
prints "tile manages the glass window" "glass" sh -c "DISPLAY=:$D xwininfo -root -tree"

echo
if [ $fail = 0 ]; then echo "install-check: all good"; else echo "install-check: FAILED"; fi
exit $fail
