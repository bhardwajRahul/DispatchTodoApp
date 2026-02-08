#!/usr/bin/env bash
#
# Dispatch developer launcher for the Dispatch task management app.
#
# Usage:
#   ./dispatch-dev.sh <command>
#
# Commands:
#   setup    Interactive setup (.env + Docker Compose startup)
#   dev      Start the development server
#   start    Start the production server
#   build    Create a production build
#   update   Pull latest, install deps, run migrations
#   seed     Load sample data
#   studio   Open Drizzle Studio (database GUI)
#   test     Run the test suite
#   lint     Run ESLint
#   version  Show version number
#   help     Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Version ───────────────────────────────────────────────────
VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")

# ── Colors ────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
UNDERLINE="\033[4m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

# 256-color palette for gradient
C1="\033[38;5;51m"
C2="\033[38;5;50m"
C3="\033[38;5;44m"
C4="\033[38;5;38m"
C5="\033[38;5;32m"
C6="\033[38;5;44m"

# ── Logo ──────────────────────────────────────────────────────
show_logo() {
    echo ""
    echo -e "${C1}  ██████╗ ██╗███████╗██████╗  █████╗ ████████╗ ██████╗██╗  ██╗${RESET}"
    echo -e "${C2}  ██╔══██╗██║██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██║  ██║${RESET}"
    echo -e "${C3}  ██║  ██║██║███████╗██████╔╝███████║   ██║   ██║     ███████║${RESET}"
    echo -e "${C4}  ██║  ██║██║╚════██║██╔═══╝ ██╔══██║   ██║   ██║     ██╔══██║${RESET}"
    echo -e "${C5}  ██████╔╝██║███████║██║     ██║  ██║   ██║   ╚██████╗██║  ██║${RESET}"
    echo -e "${C6}  ╚═════╝ ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝${RESET}"
    echo ""
    echo -e "  ${DIM}v${VERSION} - Developer launcher (requires npm)${RESET}"
    echo ""
}

# ── Help ──────────────────────────────────────────────────────
show_help() {
    show_logo

    echo -e "  ${BOLD}USAGE${RESET}"
    echo -e "    ./dispatch-dev.sh ${CYAN}<command>${RESET}"
    echo ""
    echo -e "  ${BOLD}COMMANDS${RESET}"

    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "setup"   "Interactive setup (.env + Docker Compose startup)"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "dev"     "Start the development server (http://localhost:3000)"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "start"   "Start the production server"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "build"   "Create a production build"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "update"  "Pull latest changes, install deps, run migrations"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "seed"    "Load sample data into the database"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "studio"  "Open Drizzle Studio (database GUI)"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "test"    "Run the test suite"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "lint"    "Run ESLint"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "version" "Show version number"
    printf "    ${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "help"    "Show this help message"
    echo ""
}

# ── Prerequisite checks ──────────────────────────────────────
assert_node_modules() {
    if [ ! -d "node_modules" ]; then
        echo -e "  ${YELLOW}Dependencies not installed. Running npm install...${RESET}"
        echo ""
        npm install
        if [ $? -ne 0 ]; then
            echo -e "  ${RED}npm install failed. Please fix errors and retry.${RESET}"
            exit 1
        fi
        echo ""
    fi
}

# ── Commands ──────────────────────────────────────────────────
cmd_setup() {
    show_logo
    assert_node_modules
    npx tsx scripts/setup.ts
}

cmd_dev() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Starting development server...${RESET}"
    echo -e "  ${DIM}http://localhost:3000${RESET}"
    echo ""
    npm run dev
}

cmd_start() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Starting production server...${RESET}"
    echo ""
    npm run start
}

cmd_build() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Creating production build...${RESET}"
    echo ""
    npm run build
}

cmd_update() {
    show_logo
    echo -e "  ${GREEN}Updating Dispatch...${RESET}"
    echo ""

    # Pull latest changes
    echo -e "  [1/3] ${CYAN}Pulling latest changes...${RESET}"
    git pull || echo -e "  ${YELLOW}Git pull failed — you may have local changes. Continuing...${RESET}"
    echo ""

    # Install dependencies
    echo -e "  [2/3] ${CYAN}Installing dependencies...${RESET}"
    npm install
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}npm install failed.${RESET}"
        exit 1
    fi
    echo ""

    # Run migrations
    echo -e "  [3/3] ${CYAN}Running database migrations...${RESET}"
    npm run db:migrate || echo -e "  ${YELLOW}No pending migrations or migration failed.${RESET}"
    echo ""

    echo -e "  ${GREEN}Update complete!${RESET}"
    echo ""
}

cmd_seed() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Seeding database with sample data...${RESET}"
    echo ""
    npm run db:seed
}

cmd_studio() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Opening Drizzle Studio...${RESET}"
    echo -e "  ${DIM}Browse your database at https://local.drizzle.studio${RESET}"
    echo ""
    npm run db:studio
}

cmd_test() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Running tests...${RESET}"
    echo ""
    npm test
}

cmd_lint() {
    show_logo
    assert_node_modules
    echo -e "  ${GREEN}Running ESLint...${RESET}"
    echo ""
    npm run lint
}

# ── Route ─────────────────────────────────────────────────────
COMMAND="${1:-help}"

case "$COMMAND" in
    setup)   cmd_setup ;;
    dev)     cmd_dev ;;
    start)   cmd_start ;;
    build)   cmd_build ;;
    update)  cmd_update ;;
    seed)    cmd_seed ;;
    studio)  cmd_studio ;;
    test)    cmd_test ;;
    lint)    cmd_lint ;;
    version) echo "Dispatch v${VERSION}" ;;
    help)    show_help ;;
    *)
        echo -e "  ${RED}Unknown command: ${COMMAND}${RESET}"
        echo ""
        show_help
        exit 1
        ;;
esac
