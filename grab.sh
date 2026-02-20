#!/bin/bash
#
# grab - fast repo search & clone for your GitHub account
# requires: gh (github cli)
#

VERSION="1.2.0"

# -- colors --
r='\033[0;31m' g='\033[0;32m' y='\033[1;33m'
b='\033[0;34m' c='\033[0;36m' w='\033[1m'
d='\033[2m' n='\033[0m'

msg()  { echo -e "${b}${1}${n}"; }
ok()   { echo -e "${g}${1}${n}"; }
warn() { echo -e "${y}${1}${n}"; }
err()  { echo -e "${r}${1}${n}" >&2; }
dim()  { echo -e "${d}${1}${n}"; }

# -- help --
usage() {
    cat <<EOF

  ${w}grab${n} v${VERSION} — fast GitHub repo search & clone

  ${w}USAGE${n}
    grab <keywords...>    search & clone a repo
    grab -l, --list       list all your repos
    grab --install        install grab globally
    grab -h, --help       show this help
    grab -v, --version    show version

  ${w}EXAMPLES${n}
    grab anime downloader     matches repos containing both words
    grab dashboard            matches any repo with 'dashboard'
    grab rias bot             matches 'Rias-Gremory-Bot'

  ${w}NOTES${n}
    - case insensitive, order independent
    - separators (- _ .) are ignored during matching
    - only searches ${y}your${n} repos (authenticated user)

EOF
    exit 0
}

# -- detect package manager & install gh --
_install_gh() {
    warn "gh (GitHub CLI) is not installed."
    msg "attempting auto-install..."

    local pm=""
    if   command -v apt    &>/dev/null; then pm="apt"
    elif command -v pacman &>/dev/null; then pm="pacman"
    elif command -v dnf    &>/dev/null; then pm="dnf"
    elif command -v zypper &>/dev/null; then pm="zypper"
    elif command -v brew   &>/dev/null; then pm="brew"
    fi

    case "$pm" in
        apt)
            dim "  -> detected apt (debian/ubuntu)"
            sudo mkdir -p -m 755 /etc/apt/keyrings
            wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
            sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
                | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
            sudo apt update -qq && sudo apt install -y -qq gh
            ;;
        pacman) dim "  -> detected pacman (arch)";  sudo pacman -Sy --noconfirm github-cli ;;
        dnf)    dim "  -> detected dnf (fedora)";    sudo dnf install -y -q gh ;;
        zypper) dim "  -> detected zypper (suse)";   sudo zypper install -y gh ;;
        brew)   dim "  -> detected brew";            brew install gh ;;
        *)
            err "could not detect a supported package manager."
            err "install gh manually: https://cli.github.com"
            exit 1
            ;;
    esac

    command -v gh &>/dev/null || { err "gh installation failed."; exit 1; }
    ok "gh installed."
}

# -- install grab globally --
_do_install() {
    local dest="$HOME/.local/bin"
    local src
    src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    mkdir -p "$dest"
    cp "$src" "$dest/grab"
    chmod +x "$dest/grab"

    local patched=""
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        grep -qF '.local/bin' "$rc" && continue
        printf '\n# grab - fast repo search & clone\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
        patched="$patched $(basename "$rc")"
    done

    echo ""
    ok "installed -> $dest/grab"
    [ -n "$patched" ] && dim "  PATH added to:$patched"
    echo ""
    dim "  open a new shell or run: source ~/.bashrc"
    echo ""
    exit 0
}

# -- list repos --
_list() {
    _require_gh && _require_auth

    echo ""
    msg "your repos:"
    echo ""

    gh repo list --limit 200 --json name,visibility,description \
        --template '{{range .}}  {{printf "%-32s %-8s %s\n" .name .visibility .description}}{{end}}'

    echo ""
    exit 0
}

# -- checks --
_require_gh() {
    command -v gh &>/dev/null || _install_gh
}

_require_auth() {
    gh auth status &>/dev/null 2>&1 || {
        err "not authenticated. run: gh auth login"
        exit 1
    }
}

# -- normalize a string for fuzzy match --
# strips separators and lowercases
_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _.-'
}

# -- search repos --
# matches all keywords against repo name (case/separator insensitive)
# returns matching nameWithOwner lines
_search() {
    local terms=("$@")

    local repos
    repos=$(gh repo list --limit 200 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null)
    [ -z "$repos" ] && return

    local results=()
    while IFS= read -r repo; do
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

# -- pick from multiple results --
_pick() {
    local choices=("$@")
    local count=${#choices[@]}

    warn "$count repos matched:"
    echo ""

    local i=1
    for repo in "${choices[@]}"; do
        local name="${repo##*/}"
        printf "  ${w}%2d${n}  %s ${d}(%s)${n}\n" "$i" "$name" "$repo"
        ((i++))
    done

    echo ""
    local pick
    while true; do
        printf "${c}  pick [1-%d, q=quit]: ${n}" "$count"
        read -r pick

        [[ "$pick" == "q" || "$pick" == "Q" ]] && { dim "  cancelled."; exit 0; }

        if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= count )); then
            echo ""
            _clone_repo "${choices[$((pick - 1))]}"
            return
        fi

        err "  invalid choice."
    done
}

# -- clone --
_clone_repo() {
    local repo="$1"
    local name="${repo##*/}"
    msg "cloning $name..."
    echo ""
    gh repo clone "$repo"
    echo ""
    ok "done. -> ./$name"
}

# ============================================================
#  main
# ============================================================

[ $# -eq 0 ] && usage

case "$1" in
    -h|--help)    usage ;;
    -v|--version) echo "grab v${VERSION}"; exit 0 ;;
    --install)    _do_install ;;
    -l|--list)    _list ;;
    -*)           err "unknown flag: $1"; usage ;;
esac

_require_gh
_require_auth

query="$*"
msg "searching '$query'..."
echo ""

mapfile -t hits < <(_search "$@")

case ${#hits[@]} in
    0)
        err "no repos matched '$query'."
        dim "  try: grab -l"
        exit 1
        ;;
    1)
        _clone_repo "${hits[0]}"
        ;;
    *)
        _pick "${hits[@]}"
        ;;
esac
