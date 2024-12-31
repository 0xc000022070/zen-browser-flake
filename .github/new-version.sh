#!/bin/sh

echo "Fetching upstream version from GitHub API..." >&2
upstream_data=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest)
echo "Upstream data: $upstream_data" >&2

upstream=$(echo "$upstream_data" | tr -d '\000-\037\177' | jq -r '.tag_name')
echo "Upstream version is: $upstream" >&2

local=$(grep -oP 'beta_version = "\K[^"]+' flake.nix)
echo "Current version (local) is: $local" >&2 # first!

if [ "$upstream" != "$local" ]; then
    echo "new_version=true" >>"$GITHUB_OUTPUT"
    echo "upstream=$upstream" >>"$GITHUB_OUTPUT"
fi

echo "$upstream"
