#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

remote_tags=$(curl 'https://api.github.com/repos/zen-browser/desktop/tags' -s)

with_retry() {
    retries=5
    count=0
    output=""
    status=0

    while [ $count -lt $retries ]; do
        output=$("$@" 2>&1)
        status=$?

        if echo "$output" | grep -q 'Not Found'; then
            count=$((count + 1))
            echo "attempt $count/$retries: 404 Not Found encountered, retrying..." >&2
            sleep 1
        else
            echo "[TRACE] [cmd=$*] output: $output" 1>&2
            echo "$output" | tr -d '\000-\031'
            return $status
        fi
    done

    echo "max retries reached. last output: $output (cmd=$*)" >&2
    exit 1
}

get_beta_tag_short_meta() {
    echo "$remote_tags" | jq -r '(map(select(.name | test("[0-9]+\\.[0-9]+b$")))) | first'
}

get_twilight_tag_short_meta() {
    # tags like twilight-1, twilight-2, etc... or you'll make me angry
    echo "$remote_tags" | jq -r '(map(select(.name | test("^twilight-[0-9]+$")))) | sort_by(.name | split("-")[1] | tonumber) | reverse | first'
}

beta_tag=$(get_beta_tag_short_meta)
twilight_tag=$(get_twilight_tag_short_meta)

resolve_version_remote_sha1() {
    # twilight or beta
    version="$1"

    if [ "$version" = "twilight" ]; then
        echo "$twilight_tag" | jq -r '.commit.sha'
        return
    fi

    if [ "$version" = "beta" ]; then
        echo "$beta_tag" | jq -r '.commit.sha'
        return
    fi

    echo "bad version! (clue: $version)" 1>&2
    exit 1
}

resolve_semver() {
    version="$1"

    if [ "$version" = "twilight" ]; then
        echo "$twilight_tag" | jq -r '.name'
        return
    fi

    if [ "$version" = "beta" ]; then
        echo "$beta_tag" | jq -r '.name'
        return
    fi

    echo "bad version! (clue: $version)" 1>&2
    exit 1
}

commit_beta_targets=""
commit_beta_version=""
commit_twilight_targets=""
commit_twilight_version=""
beta_updated=false

update_version() {
    # twilight or beta
    version_name=$1
    # "x86_64" or "aarch64"
    arch=$2
    # "linux" or "darwin"
    os=$3

    meta=$(jq ".variants[\"$version_name\"][\"$arch-$os\"]" <sources.json)

    local_sha1=$(echo "$meta" | jq -r '.sha1')
    remote_sha1=$(resolve_version_remote_sha1 "$version_name")

    local="$local_sha1"
    remote="$remote_sha1"

    echo "Checking $version_name version @ $arch... local=$local remote=$remote"

    if [ "$local" = "$remote" ]; then
        echo "Local $version_name version is up to date"
        return
    fi

    echo "Local $version_name version mismatch with remote so we assume it's outdated"

    if $only_check; then
        echo "should_update=true" >>"$GITHUB_OUTPUT"
        exit 0
    fi

    semver=$(resolve_semver "$version_name")
    target_release_name="$semver"

    if [ "$os" = "darwin" ]; then
        download_url="https://github.com/zen-browser/desktop/releases/download/$target_release_name/zen.macos-universal.dmg"
    else
        download_url="https://github.com/zen-browser/desktop/releases/download/$target_release_name/zen.linux-$arch.tar.xz"
    fi

    if [ "$os" = "darwin" ]; then
        prefetch_output=$(nix store prefetch-file --hash-type sha256 --json "$download_url")
    else
        prefetch_output=$(nix store prefetch-file --unpack --hash-type sha256 --json "$download_url")
    fi
    sha256=$(echo "$prefetch_output" | jq -r '.hash')

    entry_name="$version_name"

    if [ "$version_name" = "twilight" ]; then
        jq ".variants[\"twilight\"][\"$arch-$os\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"} | .variants[\"twilight-official\"][\"$arch-$os\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
        mv sources.json.tmp sources.json
    else
        jq ".variants[\"$entry_name\"][\"$arch-$os\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
        mv sources.json.tmp sources.json
    fi

    echo "$version_name was updated to $semver"

    if ! $ci; then
        return
    fi

    if [ "$version_name" = "beta" ]; then
        beta_updated=true
        if [ "$commit_beta_targets" = "" ]; then
            commit_beta_targets="$arch"
            commit_beta_version="$semver"
        elif ! echo "$commit_beta_targets" | grep -q "$arch"; then
            commit_beta_targets="$commit_beta_targets && $arch"
        fi
    fi

    if [ "$version_name" = "twilight" ]; then
        if [ "$commit_twilight_targets" = "" ]; then
            commit_twilight_targets="$arch"
            commit_twilight_version="$semver"
        elif ! echo "$commit_twilight_targets" | grep -q "$arch"; then
            commit_twilight_targets="$commit_twilight_targets && $arch"
        fi
    fi
}

main() {
    set -e

    update_version "beta" "x86_64" "linux"
    update_version "beta" "aarch64" "linux"
    update_version "beta" "aarch64" "darwin"

    if [ "$twilight_tag" != "null" ] && [ -n "$twilight_tag" ]; then
        update_version "twilight" "x86_64" "linux"
        update_version "twilight" "aarch64" "linux"
        update_version "twilight" "aarch64" "darwin"
    fi

    if $only_check && $ci; then
        echo "should_update=false" >>"$GITHUB_OUTPUT"
    fi

    # touch output.txt && GITHUB_OUTPUT=output.txt .github/update.sh --ci
    if ! git diff --exit-code >/dev/null; then
        init_message="chore(update):"
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
        echo "should_rebase_beta=$beta_updated" >>"$GITHUB_OUTPUT"
    fi
}

main
