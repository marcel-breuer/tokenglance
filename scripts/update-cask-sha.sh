#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"
SHA="${2:?sha256 required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASK="$ROOT/Casks/tokenglance.rb"

/usr/bin/sed -i '' "s/^  version .*/  version \"${VERSION}\"/" "$CASK"
/usr/bin/sed -i '' "s/^  sha256 .*/  sha256 \"${SHA}\"/" "$CASK"

