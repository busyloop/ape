#!/bin/bash

set -e

VERSION=$(git describe --tags | cut -c 2-)

cat <<EOF
# Installation

## macOS

\`\`\`bash
wget https://github.com/busyloop/ape/releases/download/v${VERSION}/ape-${VERSION}.darwin-x86_64
chmod +x ape-${VERSION}.darwin-x86_64
sudo mv ape-${VERSION}.darwin-x86_64 /usr/local/bin/ape
\`\`\`

## Linux

\`\`\`bash
wget https://github.com/busyloop/ape/releases/download/v${VERSION}/ape-${VERSION}.linux-x86_64
chmod +x ape-${VERSION}.linux-x86_64
sudo mv ape-${VERSION}.linux-x86_64 /usr/bin/ape
\`\`\`

EOF
