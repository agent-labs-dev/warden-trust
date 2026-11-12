# Warden trust record

This repository is the public trust record for Warden, self-hosted security software for AWS and
Kubernetes. It lists the SHA-256 of every Warden installer we publish and of every root, the key
list the installer trusts.

The website at wardensec.ai serves the installer and the hash in the line that checks it. A
website that is no longer ours could serve a changed installer together with a matching hash.
Every check the installer makes runs inside the installer, so a changed copy could skip them all.
This record is kept on GitHub, apart from the website, so a change to the website does not change
it. Compare against this record before you run anything. Only the main branch is the record; any
other branch in this repository is not.

## What is in ROOTS.txt

One fact per line, in three shapes:

- `root 1 sha256 <hex>`: root 1, the key list built into the installer. This line never changes.
- `root <n> sha256 <hex>`: a later root.
- `installer sha256 <hex>`: an installer we published.

Lines are only ever added, never changed or removed.

## Check the installer before you run it

Linux:

```sh
curl -fsSLo install.sh https://wardensec.ai/install
h=$(sha256sum < install.sh | cut -d' ' -f1)
curl -fsSL https://raw.githubusercontent.com/agent-labs-dev/warden-trust/main/ROOTS.txt \
  | grep -Fx "installer sha256 $h" || echo "NOT LISTED: do not run install.sh"
```

macOS:

```sh
curl -fsSLo install.sh https://wardensec.ai/install
h=$(shasum -a 256 < install.sh | cut -d' ' -f1)
curl -fsSL https://raw.githubusercontent.com/agent-labs-dev/warden-trust/main/ROOTS.txt \
  | grep -Fx "installer sha256 $h" || echo "NOT LISTED: do not run install.sh"
```

If the line prints, the file you hold is an installer we published. Then run the file you
checked, not a new download:

```sh
sh install.sh --root-sha256=<hex from the root 1 line>
```

The installer stops with `ROOT_PIN` if its root 1 differs.

The pinned install line on wardensec.ai/docs/install carries a 64-character hash in
`echo "<hash> *install.sh"`. That line only checks the file against the website itself, so its
hash must also be one of the `installer` lines here.

The npm package `wardensec`, at the version the install page names, carries the same
`install.sh`, byte for byte. To check it (use `shasum -a 256` in place of `sha256sum` on macOS):

```sh
npm pack wardensec@<version>
tar -xOf wardensec-<version>.tgz package/install.sh | sha256sum
```

Use the exact version the install page names (the release name without its leading `v`). Never
use the bare package name or a tag such as `latest` or `alpha`: a tag can move to another
version. The hash must be one of the `installer` lines.

## Further checks (optional)

Root 1 and the roots kept after an install come from the installer you checked above. These
checks back up that check and never replace it.

Root 1 sits in the installer between the lines `cat <<'WD_ROOT_1'` and `WD_ROOT_1`. To hash it
from the file you downloaded (use `shasum -a 256` in place of `sha256sum` on macOS):

```sh
awk '/^WD_ROOT_1$/{f=0} f{print} /<<.WD_ROOT_1.$/{f=1}' install.sh | sha256sum
```

The result must equal the `root 1` line. Later roots are served at
`https://wardensec.ai/releases/root/<n>.txt`. Hash each the same way and compare it with its
`root <n>` line.

After an install, the installer keeps every root it used. This prints their hashes (use
`shasum -a 256` in place of `sha256sum` on macOS):

```sh
sha256sum "${XDG_DATA_HOME:-$HOME/.local/share}"/warden/trust/root-*.txt
```

## If anything differs

Do not run `install.sh`. If you already installed, do not run `warden setup`. If a line you
relied on is gone or has changed, do not install.

The website keeps a copy of this file at https://wardensec.ai/roots.txt. If the two differ, this
record wins: do not install.

Write to support@wardensec.ai with the hash you computed, the line you compared it with, and where
you downloaded the file. The security policy is at https://wardensec.ai/security#report; the
contact file is https://wardensec.ai/.well-known/security.txt.

## How this record changes

The main branch changes only through pull requests merged by the maintainers. Commits to main
must be signed; GitHub signs each merge. Force-pushes and deletion of main are blocked, so a line
removed later would still show in the public history. The first commit is the one GitHub made when
this repository was created; every change since has landed as a pull request. This repository
replaced an earlier one of the same name on 2026-11-12; the lines of ROOTS.txt were carried over
unchanged.

## What this record does not prove

- It does not vouch for a copy of the installer from anywhere else. Only a file whose hash
  matches an `installer` line is covered.
- It does not say which installer is current. A listed line means the installer was published.
- It covers the `install.sh` inside the npm package, not the package's launcher that `npx` runs.
  To run only checked bytes, check `install.sh` as above and run it with `sh`.
- It is not the release signature check. The installer checks each release itself: each
  signature against the keys in the roots, and each file against its signed hash.
- A matching root hash read from the installer itself proves nothing on its own. A changed
  installer could carry the real root 1. The `installer` line is the check that counts.
