#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env.local"
VERSION="$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")"

RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

show_logo() {
  echo ""
  echo -e "${CYAN}  ____  ___ ____  ____   _  _____ ____ _   _ ${RESET}"
  echo -e "${CYAN} |  _ \\|_ _/ ___||  _ \\ / \\|_   _/ ___| | | |${RESET}"
  echo -e "${CYAN} | | | || |\\___ \\| |_) / _ \\ | || |   | |_| |${RESET}"
  echo -e "${CYAN} | |_| || | ___) |  __/ ___ \\| || |___|  _  |${RESET}"
  echo -e "${CYAN} |____/|___|____/|_| /_/   \\_\\_| \\____|_| |_|${RESET}"
  echo ""
  echo -e "  ${DIM}v${VERSION} - Docker production launcher${RESET}"
  echo ""
}

show_help() {
  show_logo
  echo -e "  ${BOLD}USAGE${RESET}"
  echo "    ./dispatch.sh <command>"
  echo ""
  echo -e "  ${BOLD}COMMANDS${RESET}"
  echo "    setup      Create or update .env.local for Docker"
  echo "    start      Start Dispatch with Docker Compose"
  echo "    stop       Stop running Dispatch containers"
  echo "    restart    Restart Dispatch containers"
  echo "    logs       Follow Dispatch logs"
  echo "    status     Show container status"
  echo "    pull       Pull latest image and restart"
  echo "    down       Stop and remove containers/network"
  echo "    version    Show version number"
  echo "    help       Show this help message"
  echo ""
  echo -e "  ${DIM}Developer workflow (npm build/test/dev) moved to ./dispatch-dev.sh${RESET}"
  echo ""
}

assert_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Docker is not installed or not on PATH.${RESET}"
    exit 1
  fi
}

make_auth_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr '+/' '-_' | tr -d '=' | tr -d '\n'
    return
  fi

  if [ -r /dev/urandom ] && command -v base64 >/dev/null 2>&1; then
    head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n'
    return
  fi

  printf "dispatch-local-secret-change-me"
}

get_env_value() {
  local target_key="$1"

  if [ ! -f "$ENV_FILE" ]; then
    return 1
  fi

  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    local line="${raw_line%$'\r'}"

    case "$line" in
      ""|\#*)
        continue
        ;;
      "$target_key="*)
        echo "${line#*=}"
        return 0
        ;;
    esac
  done < "$ENV_FILE"

  return 1
}

ensure_env_file() {
  local existing="false"
  local dispatch_port="3000"
  local nextauth_url=""
  local auth_secret=""
  local auth_trust_host=""
  local auth_github_id=""
  local auth_github_secret=""
  local extras=()

  if [ -f "$ENV_FILE" ]; then
    existing="true"
  fi

  if dispatch_port="$(get_env_value "DISPATCH_PORT")"; then :; else dispatch_port="3000"; fi
  if nextauth_url="$(get_env_value "NEXTAUTH_URL")"; then :; else nextauth_url="http://localhost:${dispatch_port}"; fi
  if auth_secret="$(get_env_value "AUTH_SECRET")"; then :; else auth_secret="$(make_auth_secret)"; fi
  if auth_trust_host="$(get_env_value "AUTH_TRUST_HOST")"; then :; else auth_trust_host="true"; fi
  if auth_github_id="$(get_env_value "AUTH_GITHUB_ID")"; then :; else auth_github_id=""; fi
  if auth_github_secret="$(get_env_value "AUTH_GITHUB_SECRET")"; then :; else auth_github_secret=""; fi

  if [ -f "$ENV_FILE" ]; then
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
      local line="${raw_line%$'\r'}"
      local key=""

      case "$line" in
        ""|\#*)
          continue
          ;;
      esac

      key="${line%%=*}"
      case "$key" in
        AUTH_SECRET|NEXTAUTH_URL|AUTH_TRUST_HOST|AUTH_GITHUB_ID|AUTH_GITHUB_SECRET|DISPATCH_PORT)
          ;;
        *)
          extras+=("$line")
          ;;
      esac
    done < "$ENV_FILE"
  fi

  {
    echo "# NextAuth"
    echo "AUTH_SECRET=${auth_secret}"
    echo "NEXTAUTH_URL=${nextauth_url}"
    echo "AUTH_TRUST_HOST=${auth_trust_host}"
    echo "AUTH_GITHUB_ID=${auth_github_id}"
    echo "AUTH_GITHUB_SECRET=${auth_github_secret}"
    echo ""
    echo "# Docker"
    echo "DISPATCH_PORT=${dispatch_port}"

    if [ ${#extras[@]} -gt 0 ]; then
      echo ""
      echo "# Additional"
      local extra_line
      for extra_line in "${extras[@]}"; do
        echo "$extra_line"
      done
    fi

    echo ""
  } > "$ENV_FILE"

  if [ "$existing" = "true" ]; then
    echo -e "${GREEN}Updated .env.local for Docker deployment.${RESET}"
  else
    echo -e "${GREEN}Created .env.local for Docker deployment.${RESET}"
  fi
  echo -e "${DIM}Using DISPATCH_PORT=${dispatch_port}${RESET}"
}

run_compose() {
  docker compose --env-file "$ENV_FILE" "$@"
}

cmd_setup() {
  show_logo
  assert_docker
  ensure_env_file
}

cmd_start() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose up -d
  echo -e "${GREEN}Dispatch is running.${RESET}"
}

cmd_stop() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose stop
}

cmd_restart() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose restart
}

cmd_logs() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose logs -f dispatch
}

cmd_status() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose ps
}

cmd_down() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose down
}

cmd_pull() {
  show_logo
  assert_docker
  ensure_env_file
  run_compose pull
  run_compose up -d
}

COMMAND="${1:-help}"

case "$COMMAND" in
  setup)   cmd_setup ;;
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  logs)    cmd_logs ;;
  status)  cmd_status ;;
  down)    cmd_down ;;
  pull)    cmd_pull ;;
  version) echo "Dispatch v${VERSION}" ;;
  help)    show_help ;;
  *)
    echo -e "${RED}Unknown command: ${COMMAND}${RESET}"
    echo ""
    show_help
    exit 1
    ;;
esac
