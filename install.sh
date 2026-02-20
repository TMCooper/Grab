#!/bin/bash
#
# quick installer for grab
# usage: bash install.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Installing grab..."
echo ""

bash "$SCRIPT_DIR/grab.sh" --install
