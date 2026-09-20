#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

pin_get() {
    jq -r --arg p "$1" --arg k "$2" \
        'getpath(["addons"] + ($p | split(".")) + [$k])' <sources.json
}

update_pin() {
    jq --arg p "$1" --arg rev "$2" --arg hash "$3" \
        'setpath(["addons"] + ($p | split(".")) + ["rev"]; $rev)
         | setpath(["addons"] + ($p | split(".")) + ["hash"]; $hash)' \
        <sources.json >sources.json.tmp
    mv sources.json.tmp sources.json
}

main() {
    set -e

    updated=""
    pins=$(jq -r '.addons
        | paths(type == "object" and has("rev")) as $p
        | getpath($p) as $r
        | "\($p | join(".")):\($r.owner)/\($r.repo)"' <sources.json)

    for entry in $pins; do
        pin=${entry%%:*}
        slug=${entry#*:}
        owner=${slug%%/*}
        repo=${slug#*/}

        if [ "$owner" = "null" ] || [ "$repo" = "null" ]; then
            echo "error: addons.$pin has no owner/repo in sources.json" 1>&2
            exit 1
        fi

        current=$(pin_get "$pin" rev)

        branch=$(gh api "repos/$owner/$repo" --jq '.default_branch')
        remote=$(gh api "repos/$owner/$repo/commits/$branch" --jq '.sha')

        if [ "$remote" = "$current" ]; then
            echo "$pin: up to date ($(echo "$current" | cut -c1-7))"
            continue
        fi

        echo "$pin: $(echo "$current" | cut -c1-7) -> $(echo "$remote" | cut -c1-7) ($owner/$repo@$branch)"
        updated="$updated $pin"

        if [ "$only_check" = true ]; then
            continue
        fi

        hash=$(nix store prefetch-file --unpack --hash-type sha256 --json \
            "https://github.com/$owner/$repo/archive/$remote.tar.gz" | jq -r '.hash')

        update_pin "$pin" "$remote" "$hash"
    done

    updated=$(echo "$updated" | sed 's/^ *//')

    if [ "$updated" = "" ]; then
        echo "every addon pin is up to date"

        if [ "$ci" = true ]; then
            echo "should_update=false" >>"$GITHUB_OUTPUT"
        fi

        return 0
    fi

    if [ "$ci" = true ]; then
        echo "should_update=true" >>"$GITHUB_OUTPUT"
        echo "commit_message=chore(addons): bump $(echo "$updated" | sed 's/ /, /g')" >>"$GITHUB_OUTPUT"
    fi
}

main
