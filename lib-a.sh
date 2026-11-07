#!/usr/bin/env bash
# Remnawave CDN setup. Same flow as nodes: profile inbound -> enable on node -> squad -> host.
set -u
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/remnawave-cdn"
CONFIG_FILE="$CONFIG_DIR/config.env"
NODES_FILE="$CONFIG_DIR/nodes.json"
CDN_PATH="/static/media/live/segment0.ts"
CDN_PORT=2053

need() {
  local bin="$1" pkg="${2:-$1}" required="${3:-1}"
  if command -v "$bin" >/dev/null 2>&1; then
    return 0
  fi
  echo "Нет $bin, ставлю $pkg..."
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    sudo -v || { echo "Нет прав на установку $pkg"; [[ "$required" == 1 ]] && exit 1; return 1; }
  fi
  if command -v apt-get >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then apt-get update -qq && apt-get install -y "$pkg"; else sudo apt-get update -qq && sudo apt-get install -y "$pkg"; fi
  elif command -v dnf >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then dnf install -y "$pkg"; else sudo dnf install -y "$pkg"; fi
  elif command -v yum >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then yum install -y "$pkg"; else sudo yum install -y "$pkg"; fi
  elif command -v apk >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then apk add --no-cache "$pkg"; else sudo apk add --no-cache "$pkg"; fi
  elif command -v pacman >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then pacman -Sy --noconfirm "$pkg"; else sudo pacman -Sy --noconfirm "$pkg"; fi
  elif command -v brew >/dev/null 2>&1; then
    brew install "$pkg"
  else
    echo "Поставь вручную: $pkg"
    [[ "$required" == 1 ]] && exit 1
    return 1
  fi
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Не удалось поставить $bin"
    [[ "$required" == 1 ]] && exit 1
    return 1
  fi
  echo "$bin установлен."
}

need curl curl
need jq jq
need sshpass sshpass 0

mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR" 2>/dev/null || true
hr(){ printf '%s\n' "----------------------------------------"; }
pause(){ read -r -p "Enter... " _; }
save_panel(){ umask 077; printf 'PANEL_URL=%q\nTOKEN=%q\n' "$PANEL_URL" "$TOKEN" > "$CONFIG_FILE"; chmod 600 "$CONFIG_FILE" 2>/dev/null || true; }
load_panel(){ PANEL_URL=""; TOKEN=""; [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"; }
ensure_nodes(){ [[ -f "$NODES_FILE" ]] || echo '{}' > "$NODES_FILE"; }
api(){ local m="$1" p="$2" b="${3:-}" t; t=$(mktemp); local c; if [[ -n "$b" ]]; then c=$(curl -sS --max-time 45 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -X "$m" -d "$b" -o "$t" -w '%{http_code}' "${PANEL_URL%/}$p" || echo 000); else c=$(curl -sS --max-time 45 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -X "$m" -o "$t" -w '%{http_code}' "${PANEL_URL%/}$p" || echo 000); fi; printf '%s\n' "$c"; cat "$t"; rm -f "$t"; }
ok(){ [[ "$1" =~ ^2 ]]; }
setup_panel(){ load_panel; read -r -p "URL панели [${PANEL_URL:-}]: " u; read -r -p "Токен [${TOKEN:+сохранён}]: " t; PANEL_URL="${u:-$PANEL_URL}"; PANEL_URL="${PANEL_URL%/}"; TOKEN="${t:-$TOKEN}"; [[ -z "$PANEL_URL" || -z "$TOKEN" ]] && { echo "нужны оба"; return 1; }; save_panel; echo "сохранено: $PANEL_URL"; }
require_panel(){ load_panel; [[ -z "$PANEL_URL" || -z "$TOKEN" ]] && setup_panel; }
node_save(){ ensure_nodes; local tmp; tmp=$(mktemp); jq --arg u "$1" --arg n "$2" --arg a "$3" --arg h "$4" --arg su "$5" --arg sp "$6" --arg op "$7" --arg cd "$8" '.[$u]={uuid:$u,name:$n,address:$a,ssh_host:$h,ssh_user:$su,ssh_pass:$sp,origin_port:($op|tonumber?//443),cdn_domain:$cd,updated:(now|todate)}' "$NODES_FILE" > "$tmp" && mv "$tmp" "$NODES_FILE"; chmod 600 "$NODES_FILE" 2>/dev/null || true; }
node_get(){ ensure_nodes; jq -c --arg u "$1" '.[$u]//empty' "$NODES_FILE"; }
select_node(){ local u n a p; local uu=() nn=() aa=() pp=(); while IFS=$'\t' read -r u n a p; do uu+=("$u"); nn+=("$n"); aa+=("$a"); pp+=("$p"); done < <(printf '%s' "$1" | jq -r '.[]|[.uuid,.name,.address,(.configProfile.activeConfigProfileUuid//"")]|@tsv'); echo "Нода:"; select n in "${nn[@]}" Отмена; do [[ "$n" == Отмена || -z "$n" ]] && return 1; local i=$((REPLY-1)); SELECTED_UUID="${uu[$i]}"; SELECTED_NAME="${nn[$i]}"; SELECTED_ADDR="${aa[$i]}"; SELECTED_PROFILE="${pp[$i]}"; echo "$SELECTED_NAME"; return 0; done; }
select_squad(){ local out c b; out=$(api GET /api/internal-squads); c=$(printf '%s\n' "$out"|head -n1); b=$(printf '%s\n' "$out"|tail -n +2); ok "$c" || return 1; local uu=() nn=(); while IFS=$'\t' read -r u n; do uu+=("$u"); nn+=("$n"); done < <(printf '%s' "$b"|jq -r '.internalSquads[]|[.uuid,.name]|@tsv'); echo "Сквад:"; select n in "${nn[@]}" Отмена; do [[ "$n" == Отмена || -z "$n" ]] && return 1; local i=$((REPLY-1)); SELECTED_SQUAD_UUID="${uu[$i]}"; SELECTED_SQUAD_NAME="${nn[$i]}"; return 0; done; }
