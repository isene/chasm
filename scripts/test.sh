#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

mkdir -p build/test

echo_out=$(./bin/arm-echo hello arm64 Darwin)
if [ "$echo_out" != "hello arm64 Darwin" ]; then
  echo "arm-echo failed: $echo_out" >&2
  exit 1
fi

printf 'first\nsecond\nthird\n' > build/test/input.txt
./bin/arm-cat build/test/input.txt > build/test/cat.out
cmp build/test/input.txt build/test/cat.out

upper_out=$(printf 'aBc 123 zZ\n' | ./bin/arm-upper)
if [ "$upper_out" != "ABC 123 ZZ" ]; then
  echo "arm-upper failed: $upper_out" >&2
  exit 1
fi

lines_stdin=$(printf 'one\ntwo\nthree' | ./bin/arm-lines)
if [ "$lines_stdin" != "2" ]; then
  echo "arm-lines stdin failed: $lines_stdin" >&2
  exit 1
fi

printf 'a\nb\n' > build/test/a.txt
printf 'c\n' > build/test/b.txt
./bin/arm-lines build/test/a.txt build/test/b.txt > build/test/lines.out
cat > build/test/lines.expected <<'EOF'
2 build/test/a.txt
1 build/test/b.txt
3 total
EOF
cmp build/test/lines.expected build/test/lines.out

echo "ARM64 Darwin assembly tools passed."
