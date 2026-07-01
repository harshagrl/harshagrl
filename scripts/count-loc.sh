#!/bin/bash
set -e

echo "Starting LOC counting process..."

WORKSPACE_DIR="$(pwd)"
OUTPUT_FILE="$WORKSPACE_DIR/loc-data.json"
TEMP_DIR=$(mktemp -d)

# We use GITHUB_ACTOR to automatically target your username (akki120781)
USERNAME=${GITHUB_ACTOR:-"akki120781"}

echo "Fetching public repository list for $USERNAME..."
ALL_REPOS=()
PAGE=1

while true; do
    # Fetching your public repos using the automatic token for rate limiting
    RESPONSE=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/users/$USERNAME/repos?per_page=100&page=${PAGE}")

    IS_ARRAY=$(echo "$RESPONSE" | jq -r 'if type == "array" then "yes" else "no" end' 2>/dev/null || echo "no")
    if [ "$IS_ARRAY" != "yes" ]; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Invalid response")
        echo "Error: GitHub API returned an error: $ERROR_MSG"
        exit 1
    fi

    REPOS_ON_PAGE=$(echo "$RESPONSE" | jq -r '.[].full_name // empty')

    if [ -z "$REPOS_ON_PAGE" ]; then
        break
    fi

    while IFS= read -r repo; do
        ALL_REPOS+=("$repo")
    done <<< "$REPOS_ON_PAGE"

    COUNT=$(echo "$RESPONSE" | jq '. | length')
    if [ "$COUNT" -lt 100 ]; then
        break
    fi

    PAGE=$((PAGE + 1))
done

echo "Found ${#ALL_REPOS[@]} public repositories."

cd "$TEMP_DIR"

echo "Cloning repositories..."
for repo in "${ALL_REPOS[@]}"; do
    echo "  Cloning $repo..."
    # Cloning without needing a PAT since they are public
    git clone --depth 1 "https://github.com/${repo}.git" "$(basename "$repo")" 2>/dev/null \
        || echo "  Warning: Failed to clone $repo, skipping."
done

echo "Running tokei to count lines of code..."
tokei . --output json --exclude '*.md,*.txt,README*,LICENSE*' > "$OUTPUT_FILE"

echo "Cleaning up temporary directory..."
cd "$WORKSPACE_DIR"
rm -rf "$TEMP_DIR"

echo "LOC counting complete! Results saved to $OUTPUT_FILE"
