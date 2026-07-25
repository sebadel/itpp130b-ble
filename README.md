# ITPP130B BLE Printer Driver

CUPS driver for MUNBYN ITPP130B shipping label printer over Bluetooth Low Energy (BLE) on Arch Linux.

## Quick Start

```bash
sudo ./setup.sh
```

## What It Does

The MUNBYN ITPP130B only supports BLE (not classic Bluetooth SPP) on Linux. The manufacturer's Windows-only BLE driver doesn't work on Linux. This driver:

1. Installs a custom CUPS backend that communicates via BLE GATT
2. Installs a CUPS filter that converts PDF/PostScript/text to TSPL
3. Pairs the printer via Bluetooth
4. Enables printing from any application (file viewers, command line, etc.)

## Requirements

- Arch Linux (or derivative)
- Python 3.10+ with bleak (`python-bleak`)
- CUPS printing system
- BlueZ Bluetooth stack
- poppler (for pdftotext PDF text extraction)
- ghostscript (for PostScript text extraction from file viewers)

## Files

- `setup.sh` - Automated installer
- `backend/ble` - CUPS backend (Python 3 + bleak)
- `filter/ble_tspl` - CUPS filter (converts PDF/PS/text to TSPL)
- `ppd/Printer_ITPP130.ppd` - PPD with cupsFilter entries
- `README.md` - Documentation

## Known Issues

- **PDF images not supported**: Only text content from PDFs is printed (the printer doesn't support BLE bitmap rendering)
- **Extra blank label**: Each print may produce one extra blank label (firmware behavior)
- **BLE reconnection**: After system sleep, power-cycle the printer to re-enable BLE

## How It Works

### CUPS Filter (`/usr/lib/cups/filter/ble_tspl`)

The filter handles format conversion:
- Detects input type (PDF, PostScript, or plain text)
- Extracts text using pdftotext (PDF) or ghostscript (PostScript)
- Converts text to TSPL TEXT commands
- Outputs TSPL for the backend

### CUPS Backend (`/usr/lib/cups/backend/ble`)

The backend handles BLE communication:
1. Disconnects any existing bluetoothctl connection
2. Connects directly via BLE GATT
3. Finds a writable characteristic (prefers FFF2 or ISSC UART)
4. Sends TSPL data in MTU-sized chunks

### Data Flow

```
Application (Evince, lp, etc.)
    |
    v
CUPS Filter (ble_tspl)
    |-- PDF: pdftotext -> TSPL TEXT commands
    |-- PostScript: ghostscript -> TSPL TEXT commands
    |-- Text: wrap in TSPL TEXT commands
    |
    v
CUPS Backend (ble)
    |
    v
Printer (BLE GATT)
```

This architecture allows file viewers to print correctly since they send `application/pdf` which CUPS routes through the filter.

## License

MIT
