#!/bin/bash
#
# grab - fast repo search & clone for your GitHub account
# requires: gh (github cli)
#

VERSION="2.8.0"
GRAB_REPO="TMCooper/Grab"

# -- colors & themes --
r=$'\033[0;31m' g=$'\033[0;32m' y=$'\033[1;33m'
b=$'\033[0;34m' c=$'\033[0;36m' w=$'\033[1m'
m=$'\033[0;35m' d=$'\033[2m' n=$'\033[0m'

# -- icons (unicode safe) --
ICON_REPO="REPO"
ICON_OWNER="USER"
ICON_BRANCH="BRCH"
ICON_SEARCH="SRCH"
ICON_SUCCESS="DONE"
ICON_ERROR="ERR!"
ICON_WARN="WARN"

# -- state --
NEW_VERSION=""

# -- helper UI functions --
msg()   { printf "  ${b}%s${n} %s\n" "$ICON_SEARCH" "$1"; }
ok()    { printf "  ${g}%s${n} %s\n" "$ICON_SUCCESS" "$1"; }
warn()  { printf "  ${y}%s${n} %s\n" "$ICON_WARN" "$1"; }
err()   { printf "  ${r}%s${n} %s\n" "$ICON_ERROR" "$1" >&2; }
dim()   { printf "  ${d}%s${n}\n" "$1"; }
header() {
    echo ""
    printf "  ${w}${c}%s${n}\n" "$1"
    printf "  ${d}%s${n}\n" "----------------------------------------------------"
}

# -- privilege helper (handles root vs non-root on Raspberry Pi & Linux) --
_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        "$@"
    fi
}

# -- help --
usage() {
    echo -e "
  ${w}${c}grab${n} ${d}v${VERSION}${n}
  ${d}Fast GitHub repository search & cloning tool${n}

  ${w}USAGE${n}
    ${g}grab${n} <keywords...>             ${d}Search & clone your own repo${n}
    ${g}grab${n} -o <owner> [keywords...]  ${d}Search & clone from another user/org${n}
    ${g}grab${n} -b [branch] [keywords...] ${d}Search & clone specific branch${n}
    ${g}grab${n} -l, --list                ${d}List all your repos${n}
    ${g}grab${n} -d, --desc                ${d}Show full descriptions in list${n}
    ${g}grab${n} --update                  ${d}Update grab to latest version${n}
    ${g}grab${n} --install                 ${d}Install grab globally${n}
    ${g}grab${n} -v, --version             ${d}Show version${n}
    ${g}grab${n} -h, --help                ${d}Show this help${n}

  ${w}EXAMPLES${n}
    ${c}grab anime downloader${n}          ${d}Matches 'Anime-Sama-Downloader'${n}
    ${c}grab -o torvalds linux${n}         ${d}Search 'linux' in Torvalds' repos${n}
    ${c}grab myrepo -b dev${n}             ${d}Clone branch 'dev' of 'myrepo'${n}

  ${w}NOTES${n}
    ${d}• Separators (- _ .) are ignored during fuzzy search${n}
    ${d}• Shows update notice if a new version is available${n}
    "
    exit 0
}

# -- version comparison --
_version_newer() {
    local v1="${1#v}" v2="${2#v}"
    [ "$v1" = "$v2" ] && return 1

    local IFS='.'
    local i a=($v1) b=($v2)
    for ((i = 0; i < ${#a[@]} || i < ${#b[@]}; i++)); do
        local na=${a[i]:-0} nb=${b[i]:-0}
        (( na > nb )) && return 0
        (( na < nb )) && return 1
    done
    return 1
}

# -- check for update (sets NEW_VERSION if available) --
_check_update() {
    command -v grab &>/dev/null || return

    local remote_version
    remote_version=$(gh api "repos/${GRAB_REPO}/contents/grab.sh?ref=main" --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null | tr -d '\r' | grep -m1 '^VERSION=' | cut -d'"' -f2)
    [ -z "$remote_version" ] && return

    if _version_newer "$remote_version" "$VERSION"; then
        NEW_VERSION="$remote_version"
    fi
}

# -- perform update --
_do_update() {
    _require_git && _require_gh && _require_auth
    
    header "SYSTEM UPDATE"
    msg "Checking for updates..."
    
    local remote_version
    remote_version=$(gh api "repos/${GRAB_REPO}/contents/grab.sh?ref=main" --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null | tr -d '\r' | grep -m1 '^VERSION=' | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        err "Could not fetch remote version."
        exit 1
    fi

    if ! _version_newer "$remote_version" "$VERSION"; then
        ok "Grab is already up to date (v${VERSION})."
        exit 0
    fi

    msg "Updating v${VERSION} → v${remote_version}..."
    
    local tmp
    tmp=$(mktemp)
    if gh api "repos/${GRAB_REPO}/contents/grab.sh?ref=main" --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null | tr -d '\r' > "$tmp" 2>/dev/null; then
        local target
        target=$(command -v grab 2>/dev/null || echo "$HOME/.local/bin/grab")
        cp "$tmp" "$target"
        chmod +x "$target"
        rm -f "$tmp"
        ok "Update successful. v${remote_version} is now installed."
        echo ""
        exit 0
    else
        rm -f "$tmp"
        err "Update failed. Please check your internet connection."
        exit 1
    fi
}

# -- print update notice --
_print_update_notice() {
    if [ -n "$NEW_VERSION" ]; then
        echo ""
        warn "Update available: v${VERSION} → v${NEW_VERSION}"
        dim "  Run: grab --update"
        echo ""
    fi
}

# -- ensure git is installed --
_require_git() {
    if ! command -v git &>/dev/null; then
        warn "git is not installed."
        msg "Attempting auto-install of git..."
        if command -v apt-get &>/dev/null; then
            _sudo apt-get update -qq && _sudo apt-get install -y -qq git
        elif command -v apt &>/dev/null; then
            _sudo apt update -qq && _sudo apt install -y -qq git
        elif command -v pacman &>/dev/null; then
            _sudo pacman -Sy --noconfirm git
        elif command -v dnf &>/dev/null; then
            _sudo dnf install -y -q git
        elif command -v zypper &>/dev/null; then
            _sudo zypper install -y git
        elif command -v brew &>/dev/null; then
            brew install git
        else
            err "Could not auto-install git. Please install git manually."
            exit 1
        fi
        command -v git &>/dev/null || { err "git installation failed."; exit 1; }
        ok "git successfully installed."
    fi
}

# -- detect package manager & install gh --
_install_gh() {
    warn "gh (GitHub CLI) is not installed."
    msg "Attempting auto-install..."

    local pm=""
    if   command -v apt-get &>/dev/null || command -v apt &>/dev/null; then pm="apt"
    elif command -v pacman  &>/dev/null; then pm="pacman"
    elif command -v dnf     &>/dev/null; then pm="dnf"
    elif command -v zypper  &>/dev/null; then pm="zypper"
    elif command -v brew    &>/dev/null; then pm="brew"
    fi

    case "$pm" in
        apt)
            _sudo apt-get update -qq
            if _sudo apt-get install -y -qq gh 2>/dev/null; then
                ok "gh installed via apt package manager."
            else
                # Fallback to official GitHub CLI repository (supports arm64, armhf, etc.)
                if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
                    _sudo apt-get install -y -qq curl ca-certificates
                fi

                _sudo mkdir -p -m 755 /etc/apt/keyrings
                if command -v curl &>/dev/null; then
                    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                        | _sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
                else
                    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                        | _sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
                fi

                _sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
                local arch
                arch=$(dpkg --print-architecture 2>/dev/null || echo "arm64")
                echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                    | _sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
                _sudo apt-get update -qq && _sudo apt-get install -y -qq gh
            fi
            ;;
        pacman) _sudo pacman -Sy --noconfirm github-cli ;;
        dnf)    _sudo dnf install -y -q gh ;;
        zypper) _sudo zypper install -y gh ;;
        brew)   brew install gh ;;
        *)
            err "Could not detect a supported package manager."
            dim "Install gh manually: https://cli.github.com"
            exit 1
            ;;
    esac

    command -v gh &>/dev/null || { err "gh installation failed."; exit 1; }
    ok "gh successfully installed."
}

# -- install grab globally --
_do_install() {
    local dest="$HOME/.local/bin"
    local src
    src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    header "INSTALLATION"
    mkdir -p "$dest"
    cp "$src" "$dest/grab"
    chmod +x "$dest/grab"

    local patched=""
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        [ -f "$rc" ] || continue
        grep -qF '.local/bin' "$rc" && continue
        printf '\n# grab - fast repo search & clone\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
        patched="$patched $(basename "$rc")"
    done

    ok "Binary installed to $dest/grab"
    [ -n "$patched" ] && dim "Added to PATH via: $patched"
    echo ""
    msg "Restart your shell or run: ${c}source ~/.bashrc${n} (or ${c}source ~/.profile${n})"
    echo ""
    exit 0
}

# -- list repos --
_list() {
    local owner="$1"
    local full_desc="${FULL_DESC:-false}"
    _require_gh && _require_auth

    if [ -n "$owner" ]; then
        header "REPOSITORIES: $owner"
    else
        header "YOUR REPOSITORIES"
    fi

    local output
    local template
    if $full_desc; then
        template='{{range .}}  {{printf "\033[1m%-32s\033[0m " .name}}{{if eq .visibility "PUBLIC"}}{{printf "\033[0;32m%-8s\033[0m " .visibility}}{{else}}{{printf "\033[0;31m%-8s\033[0m " .visibility}}{{end}}{{printf " \033[0;34m%s\033[0m\n" .description}}{{end}}'
    else
        template='{{range .}}  {{printf "\033[1m%-32s\033[0m " .name}}{{if eq .visibility "PUBLIC"}}{{printf "\033[0;32m%-8s\033[0m " .visibility}}{{else}}{{printf "\033[0;31m%-8s\033[0m " .visibility}}{{end}}{{printf " \033[0;34m%.50s\033[0m\n" .description}}{{end}}'
    fi

    if [ -n "$owner" ]; then
        output=$(gh repo list "$owner" --limit 200 --json name,visibility,description --template "$template")
    else
        output=$(gh repo list --limit 200 --json name,visibility,description --template "$template")
    fi

    if [ -z "$output" ] || [ "$output" == "" ]; then
        if [ -n "$owner" ]; then
            err "No public repositories found for '$owner'."
        else
            err "No repositories found."
        fi
    else
        echo -e "$output"
    fi
    _print_update_notice
    exit 0
}

_require_gh() {
    command -v gh &>/dev/null || _install_gh
}

_require_auth() {
    gh auth status &>/dev/null 2>&1 || {
        err "Not authenticated with GitHub CLI."
        dim "Please run: ${c}gh auth login${n}"
        exit 1
    }
}

_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _.-'
}

_search() {
    local owner="$1"
    shift
    local terms=("$@")

    local repos
    if [ -n "$owner" ]; then
        repos=$(gh repo list "$owner" --limit 200 --json nameWithOwner --jq '.[].nameWithOwner')
    else
        repos=$(gh repo list --limit 200 --json nameWithOwner --jq '.[].nameWithOwner')
    fi
    [ -z "$repos" ] && return

    if [ ${#terms[@]} -eq 0 ]; then
        echo "$repos"
        return
    fi

    local results=()
    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        local name_part="${repo##*/}"
        local norm
        norm=$(_normalize "$name_part")

        local match=true
        for t in "${terms[@]}"; do
            local nt
            nt=$(_normalize "$t")
            if [[ "$norm" != *"$nt"* ]]; then
                match=false
                break
            fi
        done

        $match && results+=("$repo")
    done <<< "$repos"

    printf '%s\n' "${results[@]}" 2>/dev/null | sed '/^$/d'
}

_pick() {
    local choices=("$@")
    local count=${#choices[@]}
    local branch="${BRANCH:-}"
    local pick_branch="${PICK_BRANCH:-false}"

    header "RESULTS"
    warn "$count repositories found"
    echo ""

    local i=1
    for repo in "${choices[@]}"; do
        local name="${repo##*/}"
        local owner="${repo%%/*}"
        printf "  ${c}%2d${n}  ${w}%-30s${n} ${d}%s${n}\n" "$i" "$name" "$owner"
        ((i++))
    done

    echo ""
    local pick
    while true; do
        printf "  ${w}Pick [1-%d, q=quit] > ${n}" "$count"
        read -r pick

        [[ "$pick" == "q" || "$pick" == "Q" ]] && { dim "Operation cancelled."; _print_update_notice; exit 0; }

        if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= count )); then
            local selected="${choices[$((pick - 1))]}"
            if [ -n "$branch" ]; then
                _clone_repo "$selected" "$branch"
            elif $pick_branch; then
                _pick_branch "$selected"
            else
                _clone_repo "$selected"
            fi
            return
        fi
        err "Invalid choice."
    done
}

_pick_branch() {
    local repo="$1"
    local branches
    branches=$(gh api "repos/$repo/branches" --jq '.[].name' 2>/dev/null)

    if [ -z "$branches" ]; then
        warn "No branch list found. Cloning default branch..."
        _clone_repo "$repo"
        return
    fi

    mapfile -t b_hits < <(echo "$branches")
    local b_count=${#b_hits[@]}

    header "CHOOSE BRANCH: ${repo##*/}"
    echo ""
    local i=1
    for b_name in "${b_hits[@]}"; do
        printf "  ${m}%2d${n}  ${c}%s${n}\n" "$i" "$b_name"
        ((i++))
    done

    echo ""
    local b_pick
    while true; do
        printf "  ${w}Branch [1-%d, q=quit] > ${n}" "$b_count"
        read -r b_pick

        [[ "$b_pick" == "q" || "$b_pick" == "Q" ]] && { dim "Operation cancelled."; _print_update_notice; exit 0; }

        if [[ "$b_pick" =~ ^[0-9]+$ ]] && (( b_pick >= 1 && b_pick <= b_count )); then
            _clone_repo "$repo" "${b_hits[$((b_pick - 1))]}"
            return
        fi
        err "Invalid choice."
    done
}

_clone_repo() {
    local repo="$1"
    local branch="${2:-}"
    local name="${repo##*/}"
    
    header "CLONING"
    if [ -n "$branch" ]; then
        msg "Target: ${w}${name}${n} (${m}${branch}${n})"
        echo ""
        if ! gh repo clone "$repo" -- --branch "$branch" 2>&1; then
            err "Branch '${branch}' not found. Let's pick one."
            _pick_branch "$repo"
        fi
    else
        msg "Target: ${w}${name}${n}"
        echo ""
        gh repo clone "$repo"
    fi
    echo ""
    ok "Repository successfully cloned to ./${name}"
    _print_update_notice
}

# ============================================================
#  main
# ============================================================

[ $# -eq 0 ] && usage

OWNER=""
BRANCH=""
PICK_BRANCH=false
DO_LIST=false
KEYWORDS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)    usage ;;
        -v|--version) echo "grab v${VERSION}"; exit 0 ;;
        --install)    _do_install ;;
        --update)     _do_update ;;
        -l|--list)    DO_LIST=true; shift ;;
        -d|--desc)    FULL_DESC=true; shift ;;
        -o|--owner)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                err "-o requires an owner name."
                exit 1
            fi
            OWNER="$2"
            shift 2
            ;;
        -b|--branch)
            if [ -n "${2:-}" ] && [[ "${2:-}" != -* ]]; then
                BRANCH="$2"
                shift 2
            else
                PICK_BRANCH=true
                shift
            fi
            ;;
        -*) err "Unknown flag: $1"; usage ;;
        *)  KEYWORDS+=("$1"); shift ;;
    esac
done

_require_git
_require_gh
_require_auth
_check_update

if $DO_LIST; then
    _list "$OWNER"
fi

if [ ${#KEYWORDS[@]} -eq 0 ] && [ -z "$OWNER" ]; then
    usage
fi

if [ -n "$OWNER" ]; then
    if [ ${#KEYWORDS[@]} -gt 0 ]; then
        msg "Searching ${y}${OWNER}${n} for '${w}${KEYWORDS[*]}${n}'..."
    else
        msg "Fetching all repositories for ${y}${OWNER}${n}..."
    fi
else
    msg "Searching for '${w}${KEYWORDS[*]}${n}'..."
fi
echo ""

mapfile -t hits < <(_search "$OWNER" "${KEYWORDS[@]}")

case ${#hits[@]} in
    0)
        err "No repositories matched your search."
        [ -n "$OWNER" ] && dim "Try: grab -l -o $OWNER" || dim "Try: grab -l"
        _print_update_notice
        exit 1
        ;;
    1)
        if [ -n "$BRANCH" ]; then _clone_repo "${hits[0]}" "$BRANCH"
        elif $PICK_BRANCH; then _pick_branch "${hits[0]}"
        else _clone_repo "${hits[0]}"
        fi
        ;;
    *)
        _pick "${hits[@]}"
        ;;
esac
