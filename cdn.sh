#!/usr/bin/env bash
# Run: bash <(curl -fsSL https://raw.githubusercontent.com/samur005/remnawave-cdn/main/cdn.sh)
BASE="https://raw.githubusercontent.com/samur005/remnawave-cdn/main"
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
curl -fsSL "$BASE/lib-a.sh" -o "$DIR/a.sh" || { echo "не скачал lib-a.sh"; exit 1; }
curl -fsSL "$BASE/lib-b.sh" -o "$DIR/b.sh" || { echo "не скачал lib-b.sh"; exit 1; }
source "$DIR/a.sh" || { echo "ошибка lib-a.sh"; exit 1; }
source "$DIR/b.sh" || { echo "ошибка lib-b.sh"; exit 1; }
