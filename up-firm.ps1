param(
    [Parameter(Mandatory=$true)]
    [string]$side
)

# Parameter check
if ($side -ne "L" -and $side -ne "R") {
    Write-Host "Error: Please specify L or R" -ForegroundColor Red
    exit 1
}

# Path settings
$dlBasePath = "X:\Downloads"
$zipFile = Join-Path $dlBasePath "firmware.zip"
$firmwarePath = Join-Path $dlBasePath "firmware"
$targetDrive = "E:\"

# Determine filename
if ($side -eq "L") {
    $fileName = "microball_L-seeeduino_xiao_ble-zmk.uf2"
} else {
    $fileName = "microball_R-seeeduino_xiao_ble-zmk.uf2"
}

$resetFileName = "settings_reset-seeeduino_xiao_ble-zmk.uf2"

# Check if ZIP file exists or firmware folder already exists
if (Test-Path $zipFile) {
    # Remove existing firmware folder
    if (Test-Path $firmwarePath) {
        Write-Host "Removing existing firmware folder..." -ForegroundColor Yellow
        Remove-Item $firmwarePath -Recurse -Force
    }

    # Extract ZIP file to firmware folder
    Write-Host "Extracting firmware.zip..." -ForegroundColor Green
    try {
        Expand-Archive -Path $zipFile -DestinationPath $firmwarePath -Force
        Write-Host "Extraction complete!" -ForegroundColor Green
        
        # Delete ZIP file after extraction
        Remove-Item $zipFile -Force
        Write-Host "ZIP file deleted" -ForegroundColor Yellow
    } catch {
        Write-Host "Error: Failed to extract ZIP file - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} elseif (Test-Path $firmwarePath) {
    Write-Host "Using existing firmware folder..." -ForegroundColor Green
} else {
    Write-Host "Error: Neither firmware.zip nor firmware folder found" -ForegroundColor Red
    exit 1
}

$srcFile = Join-Path $firmwarePath $fileName
$resetSrcFile = Join-Path $firmwarePath $resetFileName
$dstFile = Join-Path $targetDrive $fileName
$resetDstFile = Join-Path $targetDrive $resetFileName

# Check file exists
if (-not (Test-Path $srcFile)) {
    Write-Host "Error: File not found - $srcFile" -ForegroundColor Red
    exit 1
}

# Check drive exists
if (-not (Test-Path $targetDrive)) {
    Write-Host "Error: Drive not found - $targetDrive" -ForegroundColor Red
    exit 1
}

# Copy settings reset firmware first
if (Test-Path $resetSrcFile) {
    Write-Host "Copying settings reset firmware: $resetFileName -> $targetDrive" -ForegroundColor Cyan
    try {
        Copy-Item $resetSrcFile $resetDstFile -Force
        Write-Host "Settings reset firmware copied! Please wait for device to restart, then double-click reset button again." -ForegroundColor Cyan
        Read-Host "Press Enter after device has restarted and you've double-clicked reset button again"
    } catch {
        Write-Host "Warning: Failed to copy settings reset firmware - $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Continuing with main firmware..." -ForegroundColor Yellow
    }
} else {
    Write-Host "Settings reset firmware not found, skipping reset step" -ForegroundColor Yellow
}

# Copy main firmware
Write-Host "Copying firmware: $fileName -> $targetDrive" -ForegroundColor Green

try {
    Copy-Item $srcFile $dstFile -Force
    Write-Host "Copy complete!" -ForegroundColor Green
    
    # Ask to delete firmware folder
    Write-Host ""
    $del = Read-Host "Delete firmware folder? (y/n)"
    
    if ($del -eq "y") {
        Remove-Item $firmwarePath -Recurse -Force
        Write-Host "Firmware folder deleted" -ForegroundColor Yellow
        
        # Ask to remove Bluetooth devices
        Write-Host ""
        $removeBt = Read-Host "Remove microball Bluetooth devices? (y/n)"
        
        if ($removeBt -eq "y") {
            Write-Host "Opening Bluetooth settings..." -ForegroundColor Green
            Write-Host "Please manually remove microball devices from the list" -ForegroundColor Yellow
            Write-Host "1. Look for devices named 'microball' or 'Microball'" -ForegroundColor Yellow
            Write-Host "2. Click the three dots (...) next to each device" -ForegroundColor Yellow
            Write-Host "3. Select 'Remove device'" -ForegroundColor Yellow
            
            try {
                # Open Bluetooth settings directly
                Start-Process "ms-settings:bluetooth"
                Write-Host "Bluetooth settings opened successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Could not open Bluetooth settings automatically" -ForegroundColor Red
                Write-Host "Please open Settings > Bluetooth & devices manually" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Firmware folder kept" -ForegroundColor Blue
    }
    
} catch {
    Write-Host "Error: Failed to copy file - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Complete!" -ForegroundColor Green 