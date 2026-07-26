#!/usr/bin/env bash

set -Eeuo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required"
  exit 1
fi

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY_OWNER:?GITHUB_REPOSITORY_OWNER is required}"
: "${PACKAGE_NAME:?PACKAGE_NAME is required}"

API="https://api.github.com"
OWNER="$GITHUB_REPOSITORY_OWNER"
PACKAGE="$PACKAGE_NAME"

echo "Fetching versions for package '$PACKAGE'..."

versions=$(
  curl -fsSL \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$API/orgs/$OWNER/packages/container/$PACKAGE/versions?per_page=100"
)

echo "Found $(jq length <<<"$versions") versions"

#
# Delete every untagged version
#
echo
echo "Deleting untagged versions..."

jq -r '
  .[]
  | select(.metadata.container.tags | length == 0)
  | .id
' <<<"$versions" |
while read -r id; do
  echo "Deleting untagged version $id"

  curl -fsSL \
    -X DELETE \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$API/orgs/$OWNER/packages/container/$PACKAGE/versions/$id"

done

#
# Keep latest 3 tagged versions
#
echo
echo "Deleting old tagged versions..."

jq -r '
  map(select(.metadata.container.tags | length > 0))
  | sort_by(.created_at)
  | reverse
  | .[3:]
  | .[].id
' <<<"$versions" |
while read -r id; do
  echo "Deleting tagged version $id"

  curl -fsSL \
    -X DELETE \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$API/orgs/$OWNER/packages/container/$PACKAGE/versions/$id"

done

echo
echo "Cleanup completed."
