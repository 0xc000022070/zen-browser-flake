#!/bin/sh

repo_tags=$(curl 'https://api.github.com/repos/zen-browser/desktop/tags' -s)

twilight_tag=$(echo "$repo_tags" | jq -r '.[]|select(.name|test("twilight"))')
beta_tag=$(echo "$repo_tags" | jq -r '(map(select(.name | test("-b.")))) | first')

try_to_update() {
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
        echo "Local $name version is outdated"

        version=$(echo "$target_tag_meta" | jq -r '.name')
        download_url="https://github.com/zen-browser/desktop/releases/download/$version/zen.linux-$arch.tar.bz2"

        prefetch_output=$(nix store prefetch-file --hash-type sha256 --json "$download_url")
        sha256=$(echo "$prefetch_output" | jq -r '.hash')

        jq ".[\"$name\"][\"$arch-linux\"] = {\"name\":\"$name\",\"version\":\"$version\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
        mv sources.json.tmp sources.json

        echo "$name was updated to $version" # missing nix build!
    fi
}

set -e

try_to_update "beta" "x86_64" "$beta_tag"
try_to_update "beta" "aarch64" "$beta_tag"
try_to_update "twilight" "x86_64" "$twilight_tag"
try_to_update "twilight" "aarch64" "$twilight_tag"
