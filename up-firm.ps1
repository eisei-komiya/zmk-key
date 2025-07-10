param(
    [Parameter(Mandatory=$true)]
    [string]$side,
    
    [Parameter(Mandatory=$false)]
    [switch]$init
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

# Copy settings reset firmware first (only if --init flag is specified)
if ($init) {
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
} else {
    Write-Host "Skipping settings reset (use --init to reset settings)" -ForegroundColor Blue
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
            Write-Host "Attempting to remove microball Bluetooth devices..." -ForegroundColor Yellow
            
            try {
                # Debug: Show microball-related devices only
                Write-Host "Searching for microball devices..." -ForegroundColor Blue
                $allBtDevices = Get-PnpDevice -Class "Bluetooth" -Status "OK" | Where-Object { $_.FriendlyName -like "*microball*" }
                foreach ($dev in $allBtDevices) {
                    Write-Host "  Found: '$($dev.FriendlyName)' (exact match check: $($dev.FriendlyName -eq 'microball'))" -ForegroundColor Gray
                }
                
                # Method 1: Using Get-PnpDevice (target main microball device)
                $btDevices = Get-PnpDevice -Class "Bluetooth" -Status "OK" | Where-Object { 
                    $_.FriendlyName -eq "microball" -or $_.FriendlyName -eq "Microball"
                }
                
                Write-Host "Found $($btDevices.Count) microball-related devices" -ForegroundColor Blue
                
                if ($btDevices.Count -gt 0) {
                    foreach ($device in $btDevices) {
                        Write-Host "Removing device: $($device.FriendlyName)" -ForegroundColor Yellow
                        try {
                            # Try using PnpUtil if available
                            if (Get-Command "pnputil.exe" -ErrorAction SilentlyContinue) {
                                $deviceId = $device.InstanceId
                                Write-Host "Using pnputil to remove device: $deviceId" -ForegroundColor Blue
                                & pnputil.exe /remove-device "$deviceId" /force 2>$null
                            } else {
                                # Fallback to WMI method
                                $wmiDevice = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -eq $device.InstanceId }
                                if ($wmiDevice) {
                                    $wmiDevice.Delete()
                                }
                            }
                        } catch {
                            Write-Host "Failed to remove $($device.FriendlyName): $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                    Write-Host "Bluetooth device removal completed!" -ForegroundColor Green
                } else {
                    Write-Host "No microball Bluetooth devices found via PnP" -ForegroundColor Blue
                    
                    # Fallback: Try manual removal via Bluetooth settings
                    Write-Host "Automatic removal not available. Opening Bluetooth settings..." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Automatic removal failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Opening Bluetooth settings for manual removal..." -ForegroundColor Yellow
                
                try {
                    Start-Process "ms-settings:bluetooth"
                    Write-Host "Bluetooth settings opened successfully!" -ForegroundColor Green
                    Write-Host "Please manually remove microball devices from the list" -ForegroundColor Yellow
                } catch {
                    Write-Host "Could not open Bluetooth settings automatically" -ForegroundColor Red
                    Write-Host "Please open Settings > Bluetooth & devices manually" -ForegroundColor Yellow
                }
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