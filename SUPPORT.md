# CHasm support and releases

The supported bundle is frame, tile, glass, bare, show, chasm-bits, bolt,
and spot. `sources.lock` also pins glyph, which glass includes at build time;
the glyph binary is not bundled. CHasm targets x86_64
Linux. Debian, Ubuntu, and Mint use the automatic package-install path; other
distributions need the fonts and tools listed by `chasm-install --help`.
`glyph` and `hyperlist-display` are separate optional projects.

## Install and recover

Run `./chasm-install` for the latest release, or
`./chasm-install --version rYYYYMMDD-HHMMSS` for a specific one. The release
archive and its `.sha256` file must both be present. A local archive needs
`./chasm-install --tarball /path/to/chasm-amd64.tar.gz` and the adjacent
`/path/to/chasm-amd64.tar.gz.sha256`. `--build` checks out the commits in
`sources.lock` into temporary directories and builds that same suite.

The active bundle is selected by `/usr/local/lib/chasm/current`; previous
bundles remain in `/usr/local/lib/chasm/releases`. Run
`./chasm-install --rollback` to switch to the previous bundle. For a custom
install, pass the same `--prefix DIR` to rollback. User rc files and wallpapers
are kept when upgrading. The first upgrade from an older in-place install
stores its replaced files in a `legacy-*` release so rollback can select them.

If a session fails, inspect `~/.cache/chasm/logs/` and the installed
`/usr/local/share/chasm/VERSIONS`. Report the release tag, those version
lines, Linux distribution, GPU, and the relevant log excerpt in an issue.
The `bolt-greet` option changes the display manager; choose it separately
and keep your old display-manager name for recovery.

## Publish a release

1. Update each SHA in `sources.lock` to the intended component commit.
   Confirm every component checkout is clean, then run
   `./chasm-release --stage /tmp/chasm-stage --root /path/to/component-parent`.
2. Run `bash tests/install.sh`, push a branch, and wait for both GitHub
   checks to pass. Merge the reviewed changes to `master`.
3. Run `./chasm-release --root /path/to/component-parent`. It builds from
   the pinned commits, creates a new UTC timestamp tag, and publishes the
   archive and SHA-256 sidecar. It will not replace an existing release.
4. Test `./chasm-install --version TAG` on a spare Linux amd64 machine,
   including login and rollback. The installer keeps the prior bundle.

SHA-256 catches corruption and mismatched files. It does not authenticate
the publisher against a compromised GitHub release account; signing is a
separate future decision.
