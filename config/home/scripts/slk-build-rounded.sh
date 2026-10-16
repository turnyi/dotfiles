#!/usr/bin/env bash
# Rebuild slk with rounded corners on every panel.
#
# Upstream draws the FOCUSED pane with lipgloss.ThickBorder(), whose corners are
# square — that squareness is the focus indicator. This swaps it for
# RoundedBorder() so no pane has square corners; focus is still obvious because
# the focused border is also painted in the theme's primary colour.
#
# Homebrew's slk is left completely alone. The build lands beside it and an
# alias in zsh/aliases.zsh points `slk` at it, so deleting either reverts to
# stock. Re-run this after `brew upgrade --cask gammons/tap/slk` to rebuild
# against the new version.
set -euo pipefail

OUTPUT="$HOME/.local/bin/slk-rounded"
REPO="https://github.com/gammons/slk.git"
# The blockquote bar is a ThickBorder too, and should stay thick — it is a
# quote marker, not a panel corner. Only the panel files get rewritten.
PANEL_FILES=(
  "internal/ui/styles/styles.go"
  "internal/ui/view_sidebar.go"
)

command -v go >/dev/null || {
  echo "slk-build-rounded: needs the Go toolchain (brew install go)" >&2
  exit 1
}

# Build whatever version Homebrew currently has, so the patched binary never
# silently lags the real one.
version="$(brew list --cask --versions slk 2>/dev/null | awk '{print $2}')"
if [ -z "$version" ]; then
  echo "slk-build-rounded: slk is not installed via Homebrew; pass a tag" >&2
  exit 1
fi
tag="v${1:-$version}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

echo "Building slk $tag with rounded panel borders..."
git clone --depth 1 --branch "$tag" "$REPO" "$workdir/src" >/dev/null 2>&1

cd "$workdir/src"
for file in "${PANEL_FILES[@]}"; do
  sed -i '' "s/lipgloss\.ThickBorder()/lipgloss.RoundedBorder()/g" "$file"
done

# Stamp the same version vars goreleaser uses, so `slk --version` reports the
# real upstream version with a "+rounded" marker rather than a bare "dev".
commit="$(git rev-parse HEAD)"
GOFLAGS=-mod=mod go build -trimpath -o "$workdir/slk" \
  -ldflags="-s -w -X main.version=${tag#v}+rounded -X main.commit=$commit" \
  ./cmd/slk

mkdir -p "$(dirname "$OUTPUT")"
mv "$workdir/slk" "$OUTPUT"
chmod +x "$OUTPUT"
echo "Installed $OUTPUT (from $tag)"
echo "zsh/aliases.zsh already points \`slk\` here; open a new shell to pick it up."
