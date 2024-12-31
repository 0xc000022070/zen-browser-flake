#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

repo_tags=$(curl 'https://api.github.com/repos/zen-browser/desktop/tags' -s)

twilight_tag=$(echo "$repo_tags" | jq -r '.[]|select(.name|test("twilight"))')
beta_tag=$(echo "$repo_tags" | jq -r '(map(select(.name | test("-b.")))) | first')

commit_beta_targets=""
commit_beta_version=""
commit_twilight_targets=""
commit_twilight_version=""

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

        if $only_check; then
            echo "should_update=true" >>"$GITHUB_OUTPUT"
            exit 0
        fi

        version=$(echo "$target_tag_meta" | jq -r '.name')
        download_url="https://github.com/zen-browser/desktop/releases/download/$version/zen.linux-$arch.tar.bz2"

        prefetch_output=$(nix store prefetch-file --hash-type sha256 --json "$download_url")
        sha256=$(echo "$prefetch_output" | jq -r '.hash')

        jq ".[\"$name\"][\"$arch-linux\"] = {\"name\":\"$name\",\"version\":\"$version\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
        mv sources.json.tmp sources.json

        echo "$name was updated to $version" # missing nix build!

        if ! $ci; then
            return
        fi

        if [ "$name" = "beta" ]; then
            if [ "$commit_beta_targets" = "" ]; then
                commit_beta_targets="$arch"
                commit_beta_version="$version"
            else
                commit_beta_targets="$commit_beta_targets && $arch"
            fi
        fi

        if [ "$name" = "twilight" ]; then
            if [ "$commit_twilight_targets" = "" ]; then
                commit_twilight_targets="$arch"
                commit_twilight_version="latest"
            else
                commit_twilight_targets="$commit_twilight_targets && $arch"
            fi

        fi

    fi
}

set -e

try_to_update "beta" "x86_64" "$beta_tag"
try_to_update "beta" "aarch64" "$beta_tag"
try_to_update "twilight" "x86_64" "$twilight_tag"
try_to_update "twilight" "aarch64" "$twilight_tag"

if $only_check && $ci; then
    echo "should_update=false" >>"$GITHUB_OUTPUT"
fi

# Check if there are changes
if ! git diff --exit-code >/dev/null; then
    init_message="Update Zen Browser"
    message="$init_message"

    if [ "$commit_beta_targets" != "" ]; then
        message="$message beta @ $commit_beta_targets to $commit_beta_version"
    fi

    if [ "$commit_twilight_targets" != "" ]; then
        if [ "$message" != "$init_message" ]; then
            message="$message and"
        fi

        message="$message twilight @ $commit_twilight_targets to $commit_twilight_version"
    fi

    echo "commit_message=$message" >>"$GITHUB_OUTPUT"
fi
