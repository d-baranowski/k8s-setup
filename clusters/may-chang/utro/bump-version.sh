#!/usr/bin/env zsh
set -euo pipefail

dir="${0:A:h}"

# Discover the current version by grabbing the first utro-* image tag we find.
current="$(grep -hEo 'ghcr\.io/inspiration-particle/utro-[a-z]+:[0-9]+\.[0-9]+\.[0-9]+' "$dir"/*.yaml \
  | head -1 | awk -F: '{print $NF}')"

if [[ -z "$current" ]]; then
  echo "could not detect current utro version" >&2
  exit 1
fi

# Bump patch by default.
IFS=. read -r maj min pat <<<"$current"
default="${maj}.${min}.$((pat + 1))"

if [[ $# -ge 1 ]]; then
  version="$1"
else
  echo "current utro version: ${current}"
  version="$default"
  vared -p "new version: " version
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "not a semver: $version" >&2
  exit 1
fi

if [[ "$version" == "$current" ]]; then
  echo "already at ${version}, nothing to do"
  exit 0
fi

# Match ghcr.io/inspiration-particle/utro-<name>:<tag>, replace tag.
# Works on macOS (BSD sed) and Linux (GNU sed) by writing to a temp file.
for f in "$dir"/*.yaml; do
  tmp="$(mktemp)"
  sed -E "s|(ghcr\.io/inspiration-particle/utro-[a-z]+):[^[:space:]]+|\1:${version}|g" "$f" > "$tmp"
  if ! cmp -s "$f" "$tmp"; then
    mv "$tmp" "$f"
    echo "updated $(basename "$f")"
  else
    rm "$tmp"
  fi
done

echo "bumped utro components to ${version}"
