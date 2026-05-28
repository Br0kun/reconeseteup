#!/usr/bin/env bash
# ============================================================
#  Recon Tools Installer — CachyOS / Arch Linux
#  Tools: amass, subfinder, assetfinder, dnsx, httpx,
#         gau, waybackurls, katana, gospider, hakrawler,
#         nuclei, whatweb, wafw00f, nmap, ffuf,
#         feroxbuster, kiterunner, arjun, LinkFinder,
#         SecretFinder, SecLists
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOOLS_DIR="$HOME/tools"
GO_TOOLS_DIR="$HOME/go/bin"
mkdir -p "$TOOLS_DIR"

log()     { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✘]${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${NC}"; echo -e "${BOLD}${CYAN}  $1${NC}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════${NC}"; }

check_command() {
    command -v "$1" &>/dev/null
}

# ── 0. Preflight ─────────────────────────────────────────────
header "Preflight checks"

if ! check_command pacman; then
    error "pacman not found — is this really an Arch-based system?"
    exit 1
fi
success "pacman found"

if ! check_command go; then
    log "Go not installed — installing via pacman..."
    sudo pacman -S --needed --noconfirm go
fi
GO_VERSION=$(go version | awk '{print $3}')
success "Go: $GO_VERSION"

if ! check_command python3; then
    log "Python3 not found — installing..."
    sudo pacman -S --needed --noconfirm python python-pip
fi
success "Python: $(python3 --version)"

if ! check_command pip3 && ! check_command pip; then
    sudo pacman -S --needed --noconfirm python-pip
fi

if ! check_command git; then
    sudo pacman -S --needed --noconfirm git
fi
success "git: $(git --version)"

# Ensure Go bin is in PATH
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    warn "Adding \$HOME/go/bin to PATH for this session"
    export PATH="$PATH:$HOME/go/bin"
fi

# ── 1. System packages ────────────────────────────────────────
header "Phase 1 — System packages (pacman)"

PACMAN_PKGS=(
    nmap        # port scanning & fingerprinting
    whatweb     # tech stack fingerprinting
    wafw00f     # WAF detection
    ruby        # needed for whatweb
)

log "Installing system packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}" && success "System packages installed"

# ── 2. Go tools ───────────────────────────────────────────────
header "Phase 2 — Go tools"

declare -A GO_TOOLS=(
    ["amass"]="github.com/owasp-amass/amass/v4/...@master"
    ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    ["assetfinder"]="github.com/tomnomnom/assetfinder@latest"
    ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    ["gau"]="github.com/lc/gau/v2/cmd/gau@latest"
    ["waybackurls"]="github.com/tomnomnom/waybackurls@latest"
    ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
    ["gospider"]="github.com/jaeles-project/gospider@latest"
    ["hakrawler"]="github.com/hakluke/hakrawler@latest"
    ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    ["ffuf"]="github.com/ffuf/ffuf/v2@latest"
    ["feroxbuster"]=""   # handled separately (Rust binary)
    ["kiterunner"]=""    # handled separately (pre-built binary)
)

install_go_tool() {
    local name="$1"
    local pkg="$2"
    if check_command "$name"; then
        warn "$name already installed — skipping"
        return
    fi
    log "Installing $name..."
    if go install "$pkg" 2>/dev/null; then
        success "$name installed"
    else
        error "Failed to install $name — check your Go setup"
    fi
}

for tool in amass subfinder assetfinder dnsx httpx gau waybackurls katana gospider hakrawler nuclei ffuf; do
    install_go_tool "$tool" "${GO_TOOLS[$tool]}"
done

# ── 3. feroxbuster (Rust / pre-built) ────────────────────────
header "Phase 3 — feroxbuster"

if check_command feroxbuster; then
    warn "feroxbuster already installed — skipping"
else
    # Try AUR helper first (yay or paru)
    if check_command yay; then
        log "Installing feroxbuster via yay..."
        yay -S --needed --noconfirm feroxbuster-bin && success "feroxbuster installed via yay"
    elif check_command paru; then
        log "Installing feroxbuster via paru..."
        paru -S --needed --noconfirm feroxbuster-bin && success "feroxbuster installed via paru"
    else
        # Fallback: pre-built binary from GitHub releases
        log "No AUR helper found — downloading feroxbuster binary..."
        FB_VER=$(curl -s https://api.github.com/repos/epi052/feroxbuster/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
        curl -sL "https://github.com/epi052/feroxbuster/releases/download/${FB_VER}/x86_64-linux-feroxbuster.zip" \
            -o /tmp/feroxbuster.zip
        unzip -qo /tmp/feroxbuster.zip -d /tmp/feroxbuster
        sudo mv /tmp/feroxbuster/feroxbuster /usr/local/bin/
        sudo chmod +x /usr/local/bin/feroxbuster
        success "feroxbuster $FB_VER installed"
    fi
fi

# ── 4. kiterunner (pre-built binary) ─────────────────────────
header "Phase 4 — kiterunner"

if check_command kr; then
    warn "kiterunner already installed — skipping"
else
    log "Downloading kiterunner binary..."
    KR_VER=$(curl -s https://api.github.com/repos/assetnote/kiterunner/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -sL "https://github.com/assetnote/kiterunner/releases/download/${KR_VER}/kiterunner_${KR_VER#v}_linux_amd64.tar.gz" \
        -o /tmp/kiterunner.tar.gz
    tar -xzf /tmp/kiterunner.tar.gz -C /tmp/
    sudo mv /tmp/kr /usr/local/bin/kr
    sudo chmod +x /usr/local/bin/kr
    success "kiterunner $KR_VER installed as 'kr'"
fi

# Download kiterunner wordlists
KITE_DIR="$TOOLS_DIR/kiterunner-wordlists"
if [[ ! -d "$KITE_DIR" ]]; then
    log "Downloading kiterunner API wordlists..."
    mkdir -p "$KITE_DIR"
    curl -sL "https://wordlists-cdn.assetnote.io/data/kiterunner/routes-large.kite.tar.gz" \
        -o "$KITE_DIR/routes-large.kite.tar.gz" && \
        tar -xzf "$KITE_DIR/routes-large.kite.tar.gz" -C "$KITE_DIR/" && \
        success "kiterunner wordlists saved → $KITE_DIR"
else
    warn "kiterunner wordlists already exist — skipping"
fi

# ── 5. Python tools ───────────────────────────────────────────
header "Phase 5 — Python tools"

# arjun
if check_command arjun; then
    warn "arjun already installed — skipping"
else
    log "Installing arjun..."
    pip3 install arjun --break-system-packages --quiet && success "arjun installed"
fi

# LinkFinder
LINKFINDER_DIR="$TOOLS_DIR/LinkFinder"
if [[ -d "$LINKFINDER_DIR" ]]; then
    warn "LinkFinder already cloned — skipping"
else
    log "Cloning LinkFinder..."
    git clone --quiet https://github.com/GerbenJavado/LinkFinder.git "$LINKFINDER_DIR"
    pip3 install -r "$LINKFINDER_DIR/requirements.txt" --break-system-packages --quiet
    # Create a global wrapper
    sudo tee /usr/local/bin/linkfinder > /dev/null <<EOF
#!/usr/bin/env bash
python3 $LINKFINDER_DIR/linkfinder.py "\$@"
EOF
    sudo chmod +x /usr/local/bin/linkfinder
    success "LinkFinder installed → linkfinder"
fi

# SecretFinder
SECRETFINDER_DIR="$TOOLS_DIR/SecretFinder"
if [[ -d "$SECRETFINDER_DIR" ]]; then
    warn "SecretFinder already cloned — skipping"
else
    log "Cloning SecretFinder..."
    git clone --quiet https://github.com/m4ll0k/SecretFinder.git "$SECRETFINDER_DIR"
    pip3 install -r "$SECRETFINDER_DIR/requirements.txt" --break-system-packages --quiet
    sudo tee /usr/local/bin/secretfinder > /dev/null <<EOF
#!/usr/bin/env bash
python3 $SECRETFINDER_DIR/SecretFinder.py "\$@"
EOF
    sudo chmod +x /usr/local/bin/secretfinder
    success "SecretFinder installed → secretfinder"
fi

# wafw00f (pip fallback if pacman version is old)
if ! check_command wafw00f; then
    log "Installing wafw00f via pip..."
    pip3 install wafw00f --break-system-packages --quiet && success "wafw00f installed"
fi

# ── 6. SecLists wordlists ─────────────────────────────────────
header "Phase 6 — SecLists wordlists"

SECLISTS_DIR="$TOOLS_DIR/SecLists"
if [[ -d "$SECLISTS_DIR" ]]; then
    warn "SecLists already exists — pulling latest..."
    git -C "$SECLISTS_DIR" pull --quiet && success "SecLists updated"
else
    log "Cloning SecLists (~1.5 GB — this will take a while)..."
    git clone --quiet --depth 1 https://github.com/danielmiessler/SecLists.git "$SECLISTS_DIR"
    success "SecLists saved → $SECLISTS_DIR"
fi

# ── 7. nuclei templates ───────────────────────────────────────
header "Phase 7 — nuclei templates"

if check_command nuclei; then
    log "Updating nuclei templates..."
    nuclei -update-templates -silent && success "nuclei templates updated"
fi

# ── 8. PATH reminder ──────────────────────────────────────────
header "Final setup"

SHELL_RC="$HOME/.bashrc"
[[ "$SHELL" == *"zsh"* ]] && SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == *"fish"* ]] && SHELL_RC="$HOME/.config/fish/config.fish"

if ! grep -q 'go/bin' "$SHELL_RC" 2>/dev/null; then
    log "Adding Go bin to $SHELL_RC..."
    echo '' >> "$SHELL_RC"
    echo '# Go tools (added by recon installer)' >> "$SHELL_RC"
    echo 'export PATH="$PATH:$HOME/go/bin"' >> "$SHELL_RC"
    success "PATH updated in $SHELL_RC"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║        Installation complete!           ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Tool locations:${NC}"
echo -e "  Go binaries   → $GO_TOOLS_DIR"
echo -e "  Python tools  → $TOOLS_DIR"
echo -e "  SecLists      → $SECLISTS_DIR"
echo -e "  kiterunner WL → $TOOLS_DIR/kiterunner-wordlists"
echo ""
echo -e "${BOLD}Reload your shell:${NC}"
echo -e "  source $SHELL_RC"
echo ""
echo -e "${BOLD}Quick test:${NC}"
echo -e "  subfinder -h"
echo -e "  httpx -h"
echo -e "  kr scan -h"
echo -e "  ffuf -h"
echo -e "  nuclei -h"
echo ""
echo -e "${YELLOW}Remember: Only test targets you have written permission for.${NC}"
