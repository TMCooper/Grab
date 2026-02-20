#!/bin/bash
#
# grab - fast repo search & clone for your GitHub account
# requires: gh (github cli)
#

VERSION="2.2.0"
GRAB_REPO="TMCooper/Grab"

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
    grab <keywords...>             search & clone your own repo
    grab -o <owner> [keywords...]  search & clone from another user/org
    grab -l, --list                list all your repos
    grab -l -o <owner>             list repos of another user/org
    grab --install                 install grab globally
    grab -h, --help                show this help
    grab -v, --version             show version

  ${w}EXAMPLES${n}
    grab anime downloader          matches your repos with both words
    grab -o torvalds linux         search torvalds' repos for 'linux'
    grab -o JetBrains kotlin       search JetBrains repos
    grab -l -o microsoft           list microsoft's public repos

  ${w}NOTES${n}
    - case insensitive, order independent
    - separators (- _ .) are ignored during matching
    - without -o, searches ${y}your${n} repos only
    - auto-updates on launch if a new version is available

EOF
    exit 0
}

# -- version comparison --
# returns 0 if $1 > $2 (newer)
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

# -- auto update: compare version with remote, update if newer --
_auto_update() {
    command -v grab &>/dev/null || return

    local remote_version
    remote_version=$(gh api "repos/${GRAB_REPO}/contents/grab.sh?ref=main" --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null | grep -m1 '^VERSION=' | cut -d'"' -f2)
    [ -z "$remote_version" ] && return

    _version_newer "$remote_version" "$VERSION" || return

    msg "updating v${VERSION} -> v${remote_version}..."

    local tmp
    tmp=$(mktemp)
    if gh api "repos/${GRAB_REPO}/contents/grab.sh?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$tmp" 2>/dev/null; then
        local target
        target=$(command -v grab 2>/dev/null || echo "$HOME/.local/bin/grab")
        cp "$tmp" "$target"
        chmod +x "$target"
        rm -f "$tmp"
        ok "updated."
    else
        rm -f "$tmp"
    fi
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
    local owner="$1"

    _require_gh && _require_auth

    echo ""
    if [ -n "$owner" ]; then
        msg "repos of $owner:"
    else
        msg "your repos:"
    fi
    echo ""

    if [ -n "$owner" ]; then
        gh repo list "$owner" --limit 200 --json name,visibility,description \
            --template '{{range .}}  {{printf "%-32s %-8s %s\n" .name .visibility .description}}{{end}}'
    else
        gh repo list --limit 200 --json name,visibility,description \
            --template '{{range .}}  {{printf "%-32s %-8s %s\n" .name .visibility .description}}{{end}}'
    fi

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
_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _.-'
}

# -- search repos (own or from a specific owner) --
_search() {
    local owner="$1"
    shift
    local terms=("$@")

    local repos
    if [ -n "$owner" ]; then
        repos=$(gh repo list "$owner" --limit 200 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null)
    else
        repos=$(gh repo list --limit 200 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null)
    fi
    [ -z "$repos" ] && return

    # no keywords = return all
    if [ ${#terms[@]} -eq 0 ]; then
        echo "$repos"
        return
    fi

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
        local owner="${repo%%/*}"
        printf "  ${w}%2d${n}  %s ${d}(%s)${n}\n" "$i" "$name" "$owner"
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
#  main — argument parsing
# ============================================================

[ $# -eq 0 ] && usage

OWNER=""
DO_LIST=false
KEYWORDS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)    usage ;;
        -v|--version) echo "grab v${VERSION}"; exit 0 ;;
        --install)    _do_install ;;
        -l|--list)    DO_LIST=true; shift ;;
        -o|--owner)
            [ -z "${2:-}" ] && { err "-o requires an owner name."; exit 1; }
            OWNER="$2"
            shift 2
            ;;
        -*)
            err "unknown flag: $1"
            usage
            ;;
        *)
            KEYWORDS+=("$1")
            shift
            ;;
    esac
done

_require_gh
_require_auth

# check for updates and apply if newer
_auto_update

# -- list mode --
if $DO_LIST; then
    _list "$OWNER"
fi

# -- search mode --
if [ ${#KEYWORDS[@]} -eq 0 ] && [ -z "$OWNER" ]; then
    usage
fi

if [ -n "$OWNER" ]; then
    msg "searching ${OWNER}'s repos for '${KEYWORDS[*]}'..."
else
    msg "searching '${KEYWORDS[*]}'..."
fi
echo ""

mapfile -t hits < <(_search "$OWNER" "${KEYWORDS[@]}")

case ${#hits[@]} in
    0)
        err "no repos matched '${KEYWORDS[*]}'."
        if [ -n "$OWNER" ]; then
            dim "  try: grab -l -o $OWNER"
        else
            dim "  try: grab -l"
        fi
        exit 1
        ;;
    1)
        _clone_repo "${hits[0]}"
        ;;
    *)
        _pick "${hits[@]}"
        ;;
esac
