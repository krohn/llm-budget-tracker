#!/bin/bash
set -euo pipefail

# Builds the app, packages it as a DMG and publishes it as a GitLab release.
# Runs in GitLab CI for version tags (vX.Y.Z).

APP_NAME="LLMBudgetTracker"
PACKAGE_NAME="llm-budget-tracker"
TAG="${CI_COMMIT_TAG:?must run in a tag pipeline}"
VERSION="${TAG#v}"
DMG="${APP_NAME}-${VERSION}.dmg"

# Tag must match the version in project.yml
PROJECT_VERSION=$(grep 'MARKETING_VERSION:' project.yml | sed "s/.*MARKETING_VERSION: \"//;s/\".*//")
if [ "$VERSION" != "$PROJECT_VERSION" ]; then
  echo "Error: tag $TAG does not match MARKETING_VERSION $PROJECT_VERSION in project.yml"
  exit 1
fi

# Lint and tests run in the earlier CI stages
DERIVED_DATA_DIR="build/DerivedData"
rm -rf build dist
mkdir -p dist
xcodegen generate
xcodebuild build \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR"

# DMG with the app and a link to /Applications
STAGING=$(mktemp -d)
ditto "$DERIVED_DATA_DIR/Build/Products/Release/${APP_NAME}.app" "$STAGING/${APP_NAME}.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "LLM Budget Tracker ${VERSION}" -srcfolder "$STAGING" -format UDZO -ov "dist/$DMG"
rm -rf "$STAGING"

# Upload to the generic package registry
PACKAGE_FILE_ID=$(curl --fail-with-body --silent --show-error --location \
  --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
  --upload-file "dist/$DMG" \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${DMG}?select=package_file" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')

# Release notes: this version's section from CHANGELOG.md
export RELEASE_NOTES
RELEASE_NOTES=$(awk -v heading="## [${VERSION}]" '
  index($0, heading) == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found && /^\[[^]]+\]: / { exit }
  found { print }
' CHANGELOG.md)

export TAG DMG
export DOWNLOAD_URL="${CI_PROJECT_URL}/-/package_files/${PACKAGE_FILE_ID}/download"
python3 -c '
import json, os
print(json.dumps({
    "tag_name": os.environ["TAG"],
    "name": os.environ["TAG"],
    "description": os.environ["RELEASE_NOTES"],
    "assets": {"links": [{
        "name": os.environ["DMG"],
        "url": os.environ["DOWNLOAD_URL"],
        "direct_asset_path": "/" + os.environ["DMG"],
        "link_type": "package",
    }]},
}))' | curl --fail-with-body --silent --show-error --location \
  --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
  --header "Content-Type: application/json" \
  --data @- \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/releases" > /dev/null

echo "Published $TAG: ${CI_PROJECT_URL}/-/releases/${TAG}"
