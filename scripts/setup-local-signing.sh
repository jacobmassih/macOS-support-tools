#!/bin/sh
set -eu

if [ "${1-}" = "" ]; then
  echo "Usage: ./scripts/setup-local-signing.sh YOUR_TEAM_ID" >&2
  exit 1
fi

mkdir -p Config
cat > Config/LocalSigning.xcconfig <<EOF
DEVELOPMENT_TEAM = $1
EOF

echo "Created Config/LocalSigning.xcconfig"
