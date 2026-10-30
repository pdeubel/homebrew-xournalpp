# homebrew-xournalpp

Personal Homebrew tap for [Xournal++](https://github.com/xournalpp/xournalpp).

The official `xournal++` cask was disabled on 2026-09-01 because the upstream
macOS builds are not notarized. This tap keeps it installable and clears the
quarantine attribute after install.

```bash
brew install --cask pdeubel/xournalpp/xournalpp
```

A daily GitHub Action checks for new upstream releases and opens a PR that
bumps the version and checksums. Merge it, then `brew upgrade --cask xournalpp`.
Run `./scripts/update.sh` locally to do the same by hand.
