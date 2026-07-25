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
3. Converts PDF text content to TSPL TEXT commands (via pdftotext)
4. Wraps plain text in TSPL commands for direct printing

## Requirements

- Arch Linux (or derivative)
- Python 3.10+ with bleak (`python-bleak`)
- CUPS printing system
- BlueZ Bluetooth stack
- poppler (for pdftotext PDF text extraction)

## Files

- `setup.sh` - Automated installer
- `backend/ble` - CUPS backend (Python 3 + bleak)
- `ppd/Printer_ITPP130.ppd` - PPD for raw printing mode
- `README.md` - Documentation

## Known Issues

- **PDF images not supported**: Only text content from PDFs is printed (the printer doesn't support BLE bitmap rendering)
- **Extra blank label**: Each print may produce one extra blank label (firmware behavior)
- **BLE reconnection**: After system sleep, power-cycle the printer to re-enable BLE

## How It Works

The CUPS backend (`/usr/lib/cups/backend/ble`) uses Python bleak to:
1. Disconnect any existing bluetoothctl connection to the printer
2. Connect directly via BLE GATT
3. Find a writable characteristic (prefers FFF2 or ISSC UART)
4. Send TSPL data in MTU-sized chunks (no delay between chunks for speed)

Data flow:
```
PDF input  -> pdftotext -> TSPL TEXT commands -> BLE backend -> printer
Text input -> TSPL TEXT commands             -> BLE backend -> printer
```

The backend detects input type (PDF vs text vs TSPL) and converts accordingly.

## License

MIT
