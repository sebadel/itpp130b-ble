# ITPP130B BLE Printer Driver

CUPS driver for MUNBYN ITPP130B shipping label printer over Bluetooth Low Energy (BLE) on Arch Linux.

## Quick Start

```bash
sudo ./setup.sh
```

## What It Does

The MUNBYN ITPP130B only supports BLE (not classic Bluetooth SPP) on Linux. The manufacturer's Windows-only BLE driver doesn't work on Linux. This driver:

1. Installs a custom CUPS backend that communicates via BLE GATT
2. Pairs the printer via Bluetooth
3. Configures CUPS to use the rastertolabeltspl filter chain for PDF/image printing
4. Wraps plain text in TSPL commands for direct printing

## Requirements

- Arch Linux (or derivative)
- Python 3.10+ with bleak (`python-bleak`)
- CUPS printing system
- BlueZ Bluetooth stack

## Files

- `setup.sh` - Automated installer
- `backend/ble` - CUPS backend (Python 3 + bleak)
- `ppd/Printer_ITPP130.ppd` - PPD for rastertolabeltspl filter chain
- `README.md` - Documentation

## Known Issues

- **Extra blank label**: Each print produces one extra blank label (firmware behavior)
- **BLE reconnection**: After system sleep, power-cycle the printer to re-enable BLE
- **PDF printing**: Slow due to BLE bandwidth limitations (~124KB TSPL data per page)

## How It Works

The CUPS backend (`/usr/lib/cups/backend/ble`) uses Python bleak to:
1. Scan for the printer by BLE MAC address
2. Connect via BLE GATT
3. Find a writable characteristic (prefers FFF2 or ISSC UART)
4. Send data in MTU-sized chunks

For PDF/image printing, the filter chain is:
```
PDF/image -> pdftoraster -> rastertolabeltspl -> TSPL -> BLE backend -> printer
```

For plain text, the backend wraps it in TSPL commands automatically.

## License

MIT
