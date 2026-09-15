#!/usr/bin/env bash

get_categories() {
    local response=""
    local urls=(
        "https://www.pornhub.org/webmasters/categories"
        "https://www.pornhub.com/webmasters/categories"
    )

    for url in "${urls[@]}"; do
        if response=$(curl -fsSL -m 10 -H "Accept: application/json" -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" "$url" 2>/dev/null) && [ -n "$response" ]; then
            if printf '%s' "$response" | jq -e '.categories | type == "array"' >/dev/null 2>&1; then
                break
            fi
        fi
        response=""
    done

    if [ -z "$response" ]; then
        echo "Failed to fetch categories from the API." >&2
        return 1
    fi

    printf '%s' "$response" |
        jq -r '.categories[] | "\(.id)|\(.category)"' |
        sed 's/-/ /g; s/\b\(.\)/\u\1/g' |
        sort -t'|' -k2
}
