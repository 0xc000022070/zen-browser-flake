#!/bin/sh

repo_tags=$(curl 'https://api.github.com/repos/zen-browser/desktop/tags' -s)

twilight_tag=$(echo "$repo_tags" | jq -r '.[]|select(.name|test("twilight"))')
beta_tag=$(echo "$repo_tags" | jq -r '(map(select(.name | test("-b.")))) | first')

check_update() {
    name=$1
    arch=$2
    target_tag_meta=$3

    meta=$(jq ".[\"$name\"][\"$arch-linux\"]" <sources.json)

    local_sha1=$(echo "$meta" | jq -r '.sha1')
    remote_sha1=$(echo "$target_tag_meta" | jq -r '.commit.sha')

    echo "Checking $name version @ $arch... local=$local_sha1 remote=$remote_sha1"

    if [ "$local_sha1" = "$remote_sha1" ]; then
        echo "Local $name version is up to date"
    else
        echo "should_update=true" >>"$GITHUB_OUTPUT"
        return
    fi
}

set -e

check_update "beta" "x86_64" "$beta_tag"
check_update "beta" "aarch64" "$beta_tag"
check_update "twilight" "x86_64" "$twilight_tag"
check_update "twilight" "aarch64" "$twilight_tag"
