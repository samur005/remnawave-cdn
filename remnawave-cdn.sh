#!/usr/bin/env bash
# Remnawave CDN setup. Same flow as nodes: profile inbound -> enable on node -> squad -> host.
set -u
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/remnawave-cdn"
CONFIG_FILE="$CONFIG_DIR/config.env"
NODES_FILE="$CONFIG_DIR/nodes.json"
CDN_PATH="/static/media/live/segment0.ts"
CDN_PORT=2053
mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR" 2>/dev/null || true
command -v curl >/dev/null || { echo "need curl"; exit 1; }
command -v jq >/dev/null || { echo "need jq"; exit 1; }
echo "see README"
