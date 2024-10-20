#!/bin/sh

echo "Fetching upstream version from GitHub API..." >&2
upstream_data=$(curl -vs https://api.github.com/repos/zen-browser/desktop/releases/latest)
echo "Upstream data: $upstream_data" >&2

upstream=$(echo "$upstream_data" | jq -r '.tag_name')
local=$(grep -oP 'version = "\K[^"]+' flake.nix)

if [ "$upstream" != "$local" ]; then
    echo "new_version=true" >>"$GITHUB_OUTPUT"
    echo "upstream=$upstream" >>"$GITHUB_OUTPUT"
fi

echo "$upstream"
