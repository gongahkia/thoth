#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRAFT_DIR="$ROOT_DIR/docs/github-issues"
REPO_SLUG=""
DRY_RUN=0

usage() {
    cat <<USAGE
Usage: $(basename "$0") [--repo owner/name] [--dry-run]

Creates GitHub issues from the markdown drafts in docs/github-issues.
Requires a valid gh authentication session.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO_SLUG="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$REPO_SLUG" ]]; then
    remote_url="$(git -C "$ROOT_DIR" remote get-url origin)"
    REPO_SLUG="$(printf '%s\n' "$remote_url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

mapfile -t draft_files < <(find "$DRAFT_DIR" -maxdepth 1 -type f -name '[0-9][0-9]-*.md' | sort)

if [[ ${#draft_files[@]} -eq 0 ]]; then
    echo "No issue drafts found in $DRAFT_DIR" >&2
    exit 1
fi

for draft in "${draft_files[@]}"; do
    title="$(sed -n '1s/^# //p' "$draft")"
    if [[ -z "$title" ]]; then
        echo "Missing title in $draft" >&2
        exit 1
    fi

    body_file="$(mktemp)"
    trap 'rm -f "$body_file"' EXIT
    tail -n +3 "$draft" > "$body_file"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf 'Would create issue in %s: %s\n' "$REPO_SLUG" "$title"
    else
        printf 'Creating issue in %s: %s\n' "$REPO_SLUG" "$title"
        gh issue create --repo "$REPO_SLUG" --title "$title" --body-file "$body_file"
    fi

    rm -f "$body_file"
    trap - EXIT
done
