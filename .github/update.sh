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

get_beta_tag_short_meta() {
    echo "$remote_tags" | jq -r '(map(select(.name | test("[0-9]+\\.[0-9]+b$")))) | first'
}

get_twilight_tag_full_meta() {
    # Remove control characters
    gh api repos/zen-browser/desktop/releases/tags/twilight
}

twilight_tag=$(get_twilight_tag_full_meta)
beta_tag=$(get_beta_tag_short_meta)

get_twilight_release_artifact_meta_from_zen_repo() {
    arch=$1

    echo "$twilight_tag" | tr -d '\000-\031' | jq -r --arg arch "$arch" \
        '.assets[] | select(.name | contains("zen.linux") and contains($arch)) | "\(.id) \(.name)"'
}

download_artifact_from_zen_repo() {
    artifact_id="$1"
    # relative or absolute path
    file_path="$2"

    curl -L \
        -H "Accept: application/octet-stream" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/zen-browser/desktop/releases/assets/$artifact_id" >"$file_path"
}

get_updated_at_of_twilight_artifact_from_zen_repo() {
    gh api repos/zen-browser/desktop/releases/tags/twilight | jq -r '.assets | (map(select(.name | test("zen.linux-(x86_64|aarch64).tar.xz")))) | first | .updated_at'
}

get_twilight_version_name() {
    echo "$twilight_tag" | tr -d '\000-\031' | jq -r '.name' | grep -oE '([0-9\.])+(t|-t.[0-9]+)'
}

resolve_full_sha1_from_zen_repo() {
    short_sha1="$1"

    curl -sL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/zen-browser/desktop/commits/$short_sha1" |
        jq -r '.sha'
}

resolve_version_remote_sha1() {
    # twilight or beta
    version="$1"

    if [ "$version" = "twilight" ]; then
        short_sha1=$(echo "$twilight_tag" | tr -d '\000-\031' | jq -r '.body' | grep -oE '^[-•] [0-9a-f]{7,}' | head -n 1 | awk '{print $2}')
        resolve_full_sha1_from_zen_repo "$short_sha1"
        return
    fi

    if [ "$version" = "beta" ]; then
        echo "$beta_tag" | jq -r '.commit.sha'
        return
    fi

    echo "bad version! (clue: $version)"
    exit 1
}

twilight_version_name=$(get_twilight_version_name)
if [ "$twilight_version_name" = "" ]; then
    echo "No twilight version name could be extracted... (clue: $twilight_tag))"
    exit 1
fi

resolve_semver() {
    # twilight or beta
    version="$1"

    if [ "$version" = "twilight" ]; then
        echo "$twilight_version_name"
        return
    fi

    if [ "$version" = "beta" ]; then
        echo "$beta_tag" | jq -r '.name'
        return
    fi

    echo "bad version! (clue: $version)"
    exit 1
}

commit_beta_targets=""
commit_beta_version=""
commit_twilight_targets=""
commit_twilight_version=""

update_version() {
    # twilight or beta
    version_name=$1
    # "x86_64" or "aarch64"
    arch=$2

    meta=$(jq ".[\"$version_name\"][\"$arch-linux\"]" <sources.json)

    local_sha1=$(echo "$meta" | jq -r '.sha1')
    remote_sha1=$(resolve_version_remote_sha1 "$version_name")

    local=""
    remote=""
    if [ "$version_name" = "twilight" ]; then
        local=$(jq -r '.twilight_metadata.updated_at' sources.json)
        remote=$(get_updated_at_of_twilight_artifact_from_zen_repo)
    else
        local="$local_sha1"
        remote="$remote_sha1"
    fi

    echo "Checking $version_name version @ $arch... local=$local remote=$remote"

    if [ "$local" = "$remote" ]; then
        echo "Local $version_name version is up to date"
        return
    fi

    echo "Local $version_name version mismatch with remote so we* assume it's outdated"

    if $only_check; then
        echo "should_update=true" >>"$GITHUB_OUTPUT"
        exit 0
    fi

    semver=$(resolve_semver "$version_name")
    updated_at="$remote"

    target_release_name="$semver"
    if [ "$version_name" = "twilight" ]; then
        target_release_name="twilight"
    fi

    download_url="https://github.com/zen-browser/desktop/releases/download/$target_release_name/zen.linux-$arch.tar.xz"

    prefetch_output=$(nix store prefetch-file --unpack --hash-type sha256 --json "$download_url")
    sha256=$(echo "$prefetch_output" | jq -r '.hash')

    entry_name="$version_name"

    if [ "$version_name" = "twilight" ]; then
        entry_name="twilight-official"
        semver="$twilight_version_name"

        updated_at_epoch="$(date -d "$updated_at" +%s)"

        release_name="$semver-$updated_at_epoch"
        release_title="$semver#$updated_at_epoch"

        flake_repo_location="0xc000022070/zen-browser-flake"

        if ! gh release list | grep "$release_title" >/dev/null; then
            echo "Creating $release_name release..."

            # Users with push access to the repository can create a release.
            gh release --repo="$flake_repo_location" \
                create "$release_name" --title="$release_title" \
                --notes "To be ready when they replace the artifacts from https://github.com/zen-browser/desktop/releases/tag/twilight! :)"
        else
            echo "Release $release_name already exists, skipping creation..."
        fi

        get_twilight_release_artifact_meta_from_zen_repo "$arch" |
            while read -r line; do
                artifact_id=$(echo "$line" | cut -d' ' -f1)
                artifact_name=$(echo "$line" | cut -d' ' -f2)

                self_download_url="https://github.com/0xc000022070/zen-browser-flake/releases/download/$release_name/zen.linux-$arch.tar.xz"

                if ! gh release --repo="$flake_repo_location" view "$release_name" | grep "$artifact_name" >/dev/null; then
                    echo "[downloading] An artifact $artifact_name doesn't exists in $release_name"

                    download_artifact_from_zen_repo "$artifact_id" "/tmp/$artifact_name"

                    gh release --repo="$flake_repo_location" \
                        upload "$release_name" "/tmp/$artifact_name"

                    echo "[uploaded] The artifact is available @ following link: $self_download_url"
                else
                    echo "[skipping] An artifact $artifact_name already exists in $release_name @ following link: $self_download_url"
                fi

                jq ".[\"twilight\"][\"$arch-linux\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$self_download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
                mv sources.json.tmp sources.json
            done
    fi

    jq ".[\"$entry_name\"][\"$arch-linux\"] = {\"version\":\"$semver\",\"sha1\":\"$remote_sha1\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
    mv sources.json.tmp sources.json

    echo "$version_name was updated to $semver"

    if ! $ci; then
        return
    fi

    if [ "$version_name" = "beta" ]; then
        if [ "$commit_beta_targets" = "" ]; then
            commit_beta_targets="$arch"
            commit_beta_version="$semver"
        else
            commit_beta_targets="$commit_beta_targets && $arch"
        fi
    fi

    if [ "$version_name" = "twilight" ]; then
        if [ "$commit_twilight_targets" = "" ]; then
            updated_at="$remote"
            updated_at_epoch="$(date -d "$updated_at" +%s)"

            commit_twilight_targets="$arch"
            commit_twilight_version="$twilight_version_name#$updated_at_epoch"
        else
            commit_twilight_targets="$commit_twilight_targets && $arch"
        fi

    fi
}

main() {
    set -e

    update_version "beta" "x86_64"
    update_version "beta" "aarch64"
    update_version "twilight" "x86_64"
    update_version "twilight" "aarch64"

    if $only_check && $ci; then
        echo "should_update=false" >>"$GITHUB_OUTPUT"
    fi

    # Check if there are changes
    if ! git diff --exit-code >/dev/null; then
        # Update twilight metadata
        if [ "$commit_twilight_targets" != "" ]; then
            updated_at=$(get_updated_at_of_twilight_artifact_from_zen_repo)
            jq ".[\"twilight_metadata\"][\"updated_at\"] = \"$updated_at"\" sources.json >sources.json.tmp
            mv sources.json.tmp sources.json
        fi

        # Prepare commit message
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
    fi
}

main
