#!/bin/sh
# Decides whether a push needs a new image, and prints build=true or
# build=false for $GITHUB_OUTPUT.
#
#   scripts/is_image_push.sh <before-sha> <after-sha>
#
# It builds UNLESS it can show that every changed path is documentation.
# A push to main rebuilds :latest and watchtower rolls every box watching it,
# so a README edit is not worth a restart. Every case this script cannot read
# is a build: no before sha (a manual run), the all-zeros sha (a new branch or
# tag), a before sha that is not in the history (a force push), and an empty
# diff.
set -eu

BEFORE="${1:-}"
AFTER="${2:?usage: is_image_push.sh <before-sha> <after-sha>}"

build() {
    echo "build=$1"
    exit 0
}

case "$BEFORE" in
    "" | 0000000000000000000000000000000000000000) build true ;;
esac

CHANGED=$(git diff --name-only "$BEFORE" "$AFTER" 2>/dev/null) || build true
[ -n "$CHANGED" ] || build true

# Documentation: any Markdown file, anything under docs/, and the licence.
if printf '%s\n' "$CHANGED" | grep -qvE '(\.md$|^docs/|^LICENSE$)'; then
    build true
fi
build false
