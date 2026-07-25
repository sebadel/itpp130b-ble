#!/usr/bin/env bash
#
# setup.sh — Install MUNBYN ITPP130B BLE label printer driver on Arch Linux
#
# Usage:
#   ./setup.sh              # Interactive (prompts for user)
#   ./setup.sh --user seb   # Non-interactive
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRINTER_NAME="Printer_ITPP130"
PRINTER_MODEL="MUNBYN ITPP130B"
BLE_MAC_PATTERN="DC:0D:30:4C"
BACKEND_SRC="$SCRIPT_DIR/backend/ble"
PPD_SRC="$SCRIPT_DIR/ppd/Printer_ITPP130.ppd"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m警告:\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m错误:\033[0m %s\n" "$*" >&2; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || error "This script must be run as root (sudo ./setup.sh)"
}

detect_user() {
    if [[ -n "${TARGET_USER:-}" ]]; then
        return
    fi
    if [[ -n "${SUDO_USER:-}" ]]; then
        TARGET_USER="$SUDO_USER"
    else
        read -rp "Enter the regular username to configure: " TARGET_USER
    fi
    id "$TARGET_USER" &>/dev/null || error "User '$TARGET_USER' does not exist"
    info "Target user: $TARGET_USER"
}

# ---------------------------------------------------------------------------
# 1. Install system packages
# ---------------------------------------------------------------------------
install_packages() {
    info "Installing required packages..."
    pacman -S --needed --noconfirm python-bleak bluez bluez-utils bluez-cups cups poppler
}

# ---------------------------------------------------------------------------
# 2. Ensure Bluetooth is running
# ---------------------------------------------------------------------------
ensure_bluetooth() {
    info "Ensuring Bluetooth service is running..."
    systemctl enable --now bluetooth.service 2>/dev/null || true
    bluetoothctl power on 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 3. Pair the printer via bluetoothctl
# ---------------------------------------------------------------------------
pair_printer() {
    info "Scanning for ITPP130B printer (BLE)..."

    # Find the BLE address
    BLE_MAC=""
    for attempt in 1 2 3; do
        bluetoothctl scan on &>/dev/null &
        SCAN_PID=$!
        sleep 8
        kill "$SCAN_PID" 2>/dev/null || true
        wait "$SCAN_PID" 2>/dev/null || true

        BLE_MAC=$(bluetoothctl devices | grep -i "ITPP130B" | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" | head -1)
        if [[ -n "$BLE_MAC" ]]; then
            break
        fi
        warn "Printer not found, retrying (attempt $attempt/3)..."
        # Power cycle the adapter to re-trigger discovery
        bluetoothctl power off 2>/dev/null || true
        sleep 2
        bluetoothctl power on 2>/dev/null || true
        sleep 2
    done

    if [[ -z "$BLE_MAC" ]]; then
        error "Could not find ITPP130B via Bluetooth scan. Make sure the printer is powered on."
    fi

    info "Found printer at $BLE_MAC"

    # Pair via bluetoothctl (classic BT for discovery; BLE is used for data)
    info "Pairing printer..."
    bluetoothctl -- pair "$BLE_MAC" 2>/dev/null || true
    sleep 1
    bluetoothctl -- trust "$BLE_MAC" 2>/dev/null || true
    sleep 1

    # Also store the no-colon form for CUPS URI
    CUPS_MAC=$(echo "$BLE_MAC" | tr -d ':')
    info "CUPS device URI: ble://$CUPS_MAC"
}

# ---------------------------------------------------------------------------
# 4. Install CUPS backend
# ---------------------------------------------------------------------------
install_backend() {
    info "Installing CUPS BLE backend..."
    [[ -f "$BACKEND_SRC" ]] || error "Backend not found at $BACKEND_SRC"
    cp "$BACKEND_SRC" /usr/lib/cups/backend/ble
    chmod 700 /usr/lib/cups/backend/ble
    chown root:root /usr/lib/cups/backend/ble
    info "Backend installed at /usr/lib/cups/backend/ble"
}

# ---------------------------------------------------------------------------
# 5. Install PPD
# ---------------------------------------------------------------------------
install_ppd() {
    info "Installing PPD file..."
    [[ -f "$PPD_SRC" ]] || error "PPD not found at $PPD_SRC"
    cp "$PPD_SRC" /etc/cups/ppd/Printer_ITPP130.ppd
    chmod 644 /etc/cups/ppd/Printer_ITPP130.ppd
    chown root:root /etc/cups/ppd/Printer_ITPP130.ppd
    info "PPD installed at /etc/cups/ppd/Printer_ITPP130.ppd"
}

# ---------------------------------------------------------------------------
# 6. Configure CUPS printer
# ---------------------------------------------------------------------------
configure_cups() {
    info "Configuring CUPS printer..."
    local uri="ble://$CUPS_MAC"

    # Remove existing printer if present
    lpadmin -x "$PRINTER_NAME" 2>/dev/null || true

    lpadmin -p "$PRINTER_NAME" \
        -P /etc/cups/ppd/Printer_ITPP130.ppd \
        -v "$uri" \
        -o printer-is-shared=false \
        -o raw \
        -E

    cupsenable "$PRINTER_NAME" 2>/dev/null || true
    cupsaccept "$PRINTER_NAME" 2>/dev/null || true

    info "Printer '$PRINTER_NAME' configured with URI $uri"
}

# ---------------------------------------------------------------------------
# 7. Add sudoers rule for the user
# ---------------------------------------------------------------------------
setup_sudoers() {
    info "Adding sudoers rule for $TARGET_USER..."
    local rule_file="/etc/sudoers.d/cups-${TARGET_USER}"
    cat > "$rule_file" <<EOF
# Allow $TARGET_USER to manage CUPS printers without password
${TARGET_USER} ALL=(root) NOPASSWD: /usr/bin/cupsenable, /usr/bin/cupsdisable, /usr/bin/cupsaccept, /usr/bin/cupsreject, /usr/bin/lpadmin
EOF
    chmod 440 "$rule_file"
    visudo -cf "$rule_file" || error "sudoers syntax check failed"
    info "Sudoers rule installed at $rule_file"
}

# ---------------------------------------------------------------------------
# 8. Test print
# ---------------------------------------------------------------------------
test_print() {
    info "Sending test label..."
    echo "ITPP130B BLE Test
$(date)
Driver installed successfully" | lp -d "$PRINTER_NAME" 2>/dev/null || warn "Test print failed — try manually: echo 'Test' | lp -d $PRINTER_NAME"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    require_root
    detect_user

    info "=== MUNBYN ITPP130B BLE Printer Setup ==="
    info ""

    install_packages
    ensure_bluetooth
    pair_printer
    install_backend
    install_ppd
    configure_cups
    setup_sudoers

    info ""
    info "=== Setup complete! ==="
    info ""
    info "Print a test label:  echo 'Hello' | lp -d $PRINTER_NAME"
    info "Print a PDF:        lp -d $PRINTER_NAME document.pdf"
    info "Check status:       lpstat -p $PRINTER_NAME"
    info ""
    info "Known issue: each print may produce one extra blank label (firmware behavior)."
}

main "$@"
