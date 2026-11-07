#!/usr/bin/env bash
# Loads the real CDN setup script. Run: bash <(curl -fsSL https://raw.githubusercontent.com/samur005/remnawave-cdn/main/remnawave-cdn.sh)
BASE="https://raw.githubusercontent.com/samur005/remnawave-cdn/main"
source <(curl -fsSL "$BASE/lib-a.sh") || { echo "не скачал lib-a.sh"; exit 1; }
source <(curl -fsSL "$BASE/lib-b.sh") || { echo "не скачал lib-b.sh"; exit 1; }
