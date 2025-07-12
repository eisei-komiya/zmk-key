param(
    [Parameter(Mandatory=$false)]
    [string]$side,
    
    [Parameter(Mandatory=$false)]
    [switch]$init,
    
    [Parameter(Mandatory=$false)]
    [switch]$btclean
)

# Parameter check
if ($btclean) {
    # btclean mode - no side parameter needed
    Write-Host "Bluetooth cleanup mode activated" -ForegroundColor Cyan
} else {
    # Normal firmware update mode
    if (-not $side -or ($side -ne "L" -and $side -ne "R")) {
        Write-Host "Error: Please specify -side L or -side R" -ForegroundColor Red
        Write-Host "Usage: .\up-firm.ps1 -side L [-init]" -ForegroundColor Yellow
        Write-Host "   or: .\up-firm.ps1 -btclean" -ForegroundColor Yellow
        exit 1
    }
}

# Skip firmware processing if btclean mode
if ($btclean) {
    # Jump to Bluetooth cleanup
    Write-Host "Skipping firmware processing..." -ForegroundColor Blue
    & {
        # Bluetooth cleanup function
        Write-Host "Starting Bluetooth device cleanup..." -ForegroundColor Yellow
        
        # Check if btdiscovery is available
        if (Get-Command "btdiscovery.exe" -ErrorAction SilentlyContinue) {
            try {
                Write-Host "Discovering all paired devices..." -ForegroundColor Blue
                
                # First check what switches are available
                $helpResult = & btdiscovery.exe -? 2>&1 | Out-String
                Write-Host "--- btdiscovery.exe help ---" -ForegroundColor Gray
                Write-Host $helpResult -ForegroundColor Gray
                Write-Host "--- End of help ---" -ForegroundColor Gray
                
                # Also check btinfo for getting paired devices
                Write-Host "Checking btinfo for paired devices..." -ForegroundColor Blue
                $btinfoResult = ""
                if (Get-Command "btinfo.exe" -ErrorAction SilentlyContinue) {
                    $btinfoResult = & btinfo.exe 2>&1 | Out-String
                    Write-Host "--- btinfo.exe output ---" -ForegroundColor Gray
                    Write-Host $btinfoResult -ForegroundColor Gray
                    Write-Host "--- End of btinfo output ---" -ForegroundColor Gray
                }
                
                # Check btcom help for unpairing
                Write-Host "Checking btcom help..." -ForegroundColor Blue
                if (Get-Command "btcom.exe" -ErrorAction SilentlyContinue) {
                    $btcomHelp = & btcom.exe -? 2>&1 | Out-String
                    Write-Host "--- btcom.exe help ---" -ForegroundColor Gray
                    Write-Host $btcomHelp -ForegroundColor Gray
                    Write-Host "--- End of btcom help ---" -ForegroundColor Gray
                }
                
                # Try different discovery methods
                Write-Host "Trying device discovery..." -ForegroundColor Blue
                $discResult = & btdiscovery.exe 2>&1 | Out-String
                
                Write-Host "--- btdiscovery.exe output ---" -ForegroundColor Gray
                Write-Host $discResult -ForegroundColor Gray
                Write-Host "--- End of btdiscovery output ---" -ForegroundColor Gray
                
                # Combine all results for searching
                $allResults = $discResult + "`n" + $btinfoResult
                
                # Look for microball devices with more flexible matching
                $microballLines = @()
                $allResults -split "`n" | ForEach-Object {
                    $line = $_.Trim()
                    if ($line -match "microball" -or $line -match "Microball" -or $line -match "MICROBALL") {
                        $microballLines += $line
                        Write-Host "  Found microball line: $line" -ForegroundColor Green
                    }
                }
                
                if ($microballLines.Count -gt 0) {
                    Write-Host "microball devices found in paired devices ($($microballLines.Count) lines)" -ForegroundColor Green
                    
                    # Extract device addresses from discovery output
                    $deviceAddresses = @()
                    foreach ($line in $microballLines) {
                        if ($line -match "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}") {
                            $address = [regex]::Match($line, "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}").Value
                            if ($address -and $deviceAddresses -notcontains $address) {
                                $deviceAddresses += $address
                                Write-Host "  Found device address: $address" -ForegroundColor Cyan
                            }
                        }
                    }
                    
                    if ($deviceAddresses.Count -eq 0) {
                        Write-Host "No MAC addresses found in microball device lines" -ForegroundColor Yellow
                        Write-Host "Trying to extract addresses from all lines..." -ForegroundColor Yellow
                        
                        # Try to find all MAC addresses and let user choose
                        $allAddresses = @()
                        $discResult -split "`n" | ForEach-Object {
                            if ($_ -match "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}") {
                                $address = [regex]::Match($_, "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}").Value
                                if ($address -and $allAddresses -notcontains $address) {
                                    $allAddresses += $address
                                    Write-Host "  Available address: $address" -ForegroundColor Gray
                                }
                            }
                        }
                        
                        if ($allAddresses.Count -gt 0) {
                            Write-Host "Please check addresses manually and specify which to remove" -ForegroundColor Yellow
                        }
                    } else {
                        # Remove each device using btcom
                        foreach ($addr in $deviceAddresses) {
                            Write-Host "Removing device: $addr" -ForegroundColor Yellow
                            try {
                                $removeResult = & btcom.exe -u $addr 2>&1 | Out-String
                                Write-Host "  Remove result: $removeResult" -ForegroundColor Gray
                                Write-Host "  Removed: $addr" -ForegroundColor Green
                            } catch {
                                Write-Host "  Failed to remove $addr : $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                        
                        Write-Host "Bluetooth device removal completed!" -ForegroundColor Green
                    }
                } else {
                    Write-Host "No microball devices found in paired devices" -ForegroundColor Blue
                    Write-Host "Checking for any devices with similar names..." -ForegroundColor Blue
                    
                    # Show all device names for manual inspection
                    $allDeviceNames = @()
                    $discResult -split "`n" | ForEach-Object {
                        $line = $_.Trim()
                        if ($line -and $line -notmatch "^Bluetooth" -and $line -notmatch "^Discovering") {
                            $allDeviceNames += $line
                        }
                    }
                    
                    if ($allDeviceNames.Count -gt 0) {
                        Write-Host "All paired devices:" -ForegroundColor Blue
                        foreach ($name in $allDeviceNames) {
                            Write-Host "  $name" -ForegroundColor Gray
                        }
                    }
                }
            } catch {
                Write-Host "Error using Bluetooth Command Line Tools: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Falling back to manual removal..." -ForegroundColor Yellow
                
                try {
                    Start-Process "ms-settings:bluetooth"
                    Write-Host "Bluetooth settings opened for manual removal" -ForegroundColor Green
                } catch {
                    Write-Host "Could not open Bluetooth settings" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Bluetooth Command Line Tools not found" -ForegroundColor Red
            Write-Host "Please install from: https://bluetoothinstaller.com/bluetooth-command-line-tools" -ForegroundColor Yellow
            Write-Host "Opening Bluetooth settings for manual removal..." -ForegroundColor Yellow
            
            try {
                Start-Process "ms-settings:bluetooth"
                Write-Host "Bluetooth settings opened" -ForegroundColor Green
            } catch {
                Write-Host "Could not open Bluetooth settings" -ForegroundColor Red
            }
        }
        
        Write-Host "Bluetooth cleanup complete!" -ForegroundColor Green
    }
    
    exit 0
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
    Write-Host "=== Initialization Mode ===" -ForegroundColor Cyan
    Write-Host "Performing complete initialization with Bluetooth cleanup..." -ForegroundColor Cyan
    
    # Step 1: Bluetooth device cleanup first
    Write-Host ""
    Write-Host "Step 1: Bluetooth device cleanup..." -ForegroundColor Yellow
    
    # Check if btdiscovery is available
    if (Get-Command "btdiscovery.exe" -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Discovering existing microball devices..." -ForegroundColor Blue
            
            # Discover paired devices
            $discResult = & btdiscovery.exe 2>&1 | Out-String
            
            Write-Host "--- btdiscovery.exe output ---" -ForegroundColor Gray
            Write-Host $discResult -ForegroundColor Gray
            Write-Host "--- End of btdiscovery output ---" -ForegroundColor Gray
            
            # Look for microball devices
            $microballLines = @()
            $discResult -split "`n" | ForEach-Object {
                $line = $_.Trim()
                if ($line -match "microball" -or $line -match "Microball" -or $line -match "MICROBALL") {
                    $microballLines += $line
                    Write-Host "  Found microball line: $line" -ForegroundColor Green
                }
            }
            
            if ($microballLines.Count -gt 0) {
                Write-Host "Found $($microballLines.Count) microball device(s) - removing..." -ForegroundColor Green
                
                # Extract device addresses
                $deviceAddresses = @()
                foreach ($line in $microballLines) {
                    if ($line -match "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}") {
                        $address = [regex]::Match($line, "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}").Value
                        if ($address -and $deviceAddresses -notcontains $address) {
                            $deviceAddresses += $address
                            Write-Host "  Found device address: $address" -ForegroundColor Cyan
                        }
                    }
                }
                
                # Remove each device
                foreach ($addr in $deviceAddresses) {
                    Write-Host "Removing device: $addr" -ForegroundColor Yellow
                    try {
                        $removeResult = & btcom.exe -u $addr 2>&1 | Out-String
                        Write-Host "  Remove result: $removeResult" -ForegroundColor Gray
                        Write-Host "  Removed: $addr" -ForegroundColor Green
                    } catch {
                        Write-Host "  Failed to remove $addr : $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                Write-Host "Bluetooth device cleanup completed!" -ForegroundColor Green
            } else {
                Write-Host "No microball devices found" -ForegroundColor Blue
            }
        } catch {
            Write-Host "Bluetooth cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Continuing with manual cleanup..." -ForegroundColor Yellow
            
            $manualCleanup = Read-Host "Open Bluetooth settings for manual cleanup? (y/n)"
            if ($manualCleanup -eq "y") {
                try {
                    Start-Process "ms-settings:bluetooth"
                    Write-Host "Bluetooth settings opened" -ForegroundColor Green
                    Read-Host "Press Enter after manually removing microball devices"
                } catch {
                    Write-Host "Could not open Bluetooth settings" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "Bluetooth Command Line Tools not found - manual cleanup recommended" -ForegroundColor Yellow
        $manualCleanup = Read-Host "Open Bluetooth settings for manual cleanup? (y/n)"
        if ($manualCleanup -eq "y") {
            try {
                Start-Process "ms-settings:bluetooth"
                Write-Host "Bluetooth settings opened" -ForegroundColor Green
                Read-Host "Press Enter after manually removing microball devices"
            } catch {
                Write-Host "Could not open Bluetooth settings" -ForegroundColor Red
            }
        }
    }
    
    # Step 2: Settings reset firmware
    Write-Host ""
    Write-Host "Step 2: Settings reset firmware..." -ForegroundColor Yellow
    
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
    Write-Host "Skipping initialization (use --init for complete initialization with Bluetooth cleanup)" -ForegroundColor Blue
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
            Write-Host "Attempting to remove microball Bluetooth devices using Bluetooth Command Line Tools..." -ForegroundColor Yellow
            
            # Check if btdiscovery is available
            if (Get-Command "btdiscovery.exe" -ErrorAction SilentlyContinue) {
                try {
                    Write-Host "Discovering microball devices..." -ForegroundColor Blue
                    
                    # Discover paired devices and find microball devices
                    $discResult = & btdiscovery.exe 2>&1 | Out-String
                    
                    Write-Host "--- btdiscovery.exe output ---" -ForegroundColor Gray
                    Write-Host $discResult -ForegroundColor Gray
                    Write-Host "--- End of btdiscovery output ---" -ForegroundColor Gray
                    
                    # Look for microball devices with more flexible matching
                    $microballLines = @()
                    $discResult -split "`n" | ForEach-Object {
                        $line = $_.Trim()
                        if ($line -match "microball" -or $line -match "Microball" -or $line -match "MICROBALL") {
                            $microballLines += $line
                            Write-Host "  Found microball line: $line" -ForegroundColor Green
                        }
                    }
                    
                    if ($microballLines.Count -gt 0) {
                        Write-Host "microball devices found in paired devices ($($microballLines.Count) lines)" -ForegroundColor Green
                        
                        # Extract device addresses from discovery output
                        $deviceAddresses = @()
                        foreach ($line in $microballLines) {
                            if ($line -match "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}") {
                                $address = [regex]::Match($line, "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}").Value
                                if ($address -and $deviceAddresses -notcontains $address) {
                                    $deviceAddresses += $address
                                    Write-Host "  Found device address: $address" -ForegroundColor Cyan
                                }
                            }
                        }
                        
                        if ($deviceAddresses.Count -eq 0) {
                            Write-Host "No MAC addresses found in microball device lines" -ForegroundColor Yellow
                            Write-Host "Trying to extract addresses from all sources..." -ForegroundColor Yellow
                            
                            # Try to find all MAC addresses and let user choose
                            $allAddresses = @()
                            $allResults -split "`n" | ForEach-Object {
                                if ($_ -match "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}") {
                                    $address = [regex]::Match($_, "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}").Value
                                    if ($address -and $allAddresses -notcontains $address) {
                                        $allAddresses += $address
                                        Write-Host "  Available address: $address" -ForegroundColor Gray
                                    }
                                }
                            }
                            
                            # Also check registry for MAC addresses
                            try {
                                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices"
                                if (Test-Path $regPath) {
                                    $regDevices = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                                    foreach ($regDev in $regDevices) {
                                        $deviceName = $regDev.Name
                                        if ($deviceName -match "([0-9A-F]{2}){12}") {
                                            # Convert registry format to MAC address
                                            $macFromReg = [regex]::Match($deviceName, "([0-9A-F]{2}){12}").Value
                                            if ($macFromReg) {
                                                $formattedMac = ""
                                                for ($i = 0; $i -lt $macFromReg.Length; $i += 2) {
                                                    if ($i -gt 0) { $formattedMac += ":" }
                                                    $formattedMac += $macFromReg.Substring($i, 2)
                                                }
                                                if ($allAddresses -notcontains $formattedMac) {
                                                    $allAddresses += $formattedMac
                                                    Write-Host "  Registry address: $formattedMac" -ForegroundColor Gray
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch {
                                Write-Host "Registry check failed: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                            
                            if ($allAddresses.Count -gt 0) {
                                Write-Host "Please check addresses manually and specify which to remove" -ForegroundColor Yellow
                            }
                        } else {
                            # Remove each device using btcom
                            foreach ($addr in $deviceAddresses) {
                                Write-Host "Removing device: $addr" -ForegroundColor Yellow
                                try {
                                    $removeResult = & btcom.exe -u $addr 2>&1 | Out-String
                                    Write-Host "  Remove result: $removeResult" -ForegroundColor Gray
                                    Write-Host "  Removed: $addr" -ForegroundColor Green
                                } catch {
                                    Write-Host "  Failed to remove $addr : $($_.Exception.Message)" -ForegroundColor Red
                                }
                            }
                        }
                        
                        Write-Host "Bluetooth device removal completed!" -ForegroundColor Green
                        
                        # Ask for re-pairing
                        Write-Host ""
                        $repair = Read-Host "Re-pair microball devices? (y/n)"
                        
                        if ($repair -eq "y") {
                            Write-Host "Starting discovery for re-pairing..." -ForegroundColor Cyan
                            Write-Host "Please put your microball devices in pairing mode" -ForegroundColor Yellow
                            Read-Host "Press Enter when devices are ready for pairing"
                            
                            # Discover available devices
                            Write-Host "Discovering available devices..." -ForegroundColor Blue
                            $newDiscResult = & btdiscovery.exe 2>&1 | Out-String
                            
                            # Find microball devices
                            $newAddresses = @()
                            $newDiscResult -split "`n" | ForEach-Object {
                                if ($_ -match "microball" -and $_ -match "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}") {
                                    $address = [regex]::Match($_, "([0-9A-F]{2}[:-]){5}[0-9A-F]{2}").Value
                                    if ($address) {
                                        $newAddresses += $address
                                        Write-Host "  Found device for pairing: $address" -ForegroundColor Gray
                                    }
                                }
                            }
                            
                            # Pair each device
                            foreach ($addr in $newAddresses) {
                                Write-Host "Pairing with device: $addr" -ForegroundColor Cyan
                                try {
                                    & btpair.exe -b $addr 2>$null
                                    Write-Host "  Paired: $addr" -ForegroundColor Green
                                } catch {
                                    Write-Host "  Failed to pair with $addr" -ForegroundColor Yellow
                                }
                            }
                            
                            if ($newAddresses.Count -eq 0) {
                                Write-Host "No microball devices found for pairing" -ForegroundColor Yellow
                                Write-Host "Please check device pairing mode and try manual pairing" -ForegroundColor Yellow
                            }
                        }
                    } else {
                        Write-Host "No microball devices found in paired devices" -ForegroundColor Blue
                        Write-Host "Checking for any devices with similar names..." -ForegroundColor Blue
                        
                        # Show all device names for manual inspection
                        $allDeviceNames = @()
                        $allResults -split "`n" | ForEach-Object {
                            $line = $_.Trim()
                            if ($line -and $line -notmatch "^Bluetooth" -and $line -notmatch "^Discovering" -and $line -notmatch "^Invalid" -and $line -notmatch "^---" -and $line -notmatch "^$") {
                                $allDeviceNames += $line
                            }
                        }
                        
                        # Also try PowerShell methods for paired devices
                        Write-Host "Trying PowerShell methods..." -ForegroundColor Blue
                        try {
                            $psDevices = Get-PnpDevice -Class "Bluetooth" -Status "OK" | Where-Object { $_.FriendlyName -ne $null }
                            if ($psDevices) {
                                Write-Host "PowerShell Bluetooth devices:" -ForegroundColor Blue
                                foreach ($dev in $psDevices) {
                                    Write-Host "  $($dev.FriendlyName)" -ForegroundColor Gray
                                    if ($dev.FriendlyName -match "microball" -or $dev.FriendlyName -match "Microball" -or $dev.FriendlyName -match "MICROBALL") {
                                        Write-Host "    ^ Found microball device!" -ForegroundColor Green
                                    }
                                }
                            }
                            
                            # Also check Windows Registry for paired devices
                            Write-Host "Checking Windows Registry..." -ForegroundColor Blue
                            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices"
                            if (Test-Path $regPath) {
                                $regDevices = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                                if ($regDevices) {
                                    Write-Host "Registry Bluetooth devices:" -ForegroundColor Blue
                                    foreach ($regDev in $regDevices) {
                                        $name = (Get-ItemProperty -Path $regDev.PSPath -Name "Name" -ErrorAction SilentlyContinue).Name
                                        if ($name) {
                                            Write-Host "  $name" -ForegroundColor Gray
                                            if ($name -match "microball" -or $name -match "Microball" -or $name -match "MICROBALL") {
                                                Write-Host "    ^ Found microball device in registry!" -ForegroundColor Green
                                            }
                                        }
                                    }
                                }
                            }
                            
                            # Try Windows netsh command for Bluetooth devices
                            Write-Host "Trying Windows netsh command..." -ForegroundColor Blue
                            try {
                                $netshResult = & netsh.exe advfirewall firewall show rule name=all | Out-String
                                if ($netshResult -match "microball") {
                                    Write-Host "Found microball in firewall rules" -ForegroundColor Green
                                }
                            } catch {
                                Write-Host "netsh command failed: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                            
                            # Alternative: Manual device removal approach
                            Write-Host ""
                            Write-Host "=== Manual Bluetooth Cleanup Instructions ===" -ForegroundColor Cyan
                            Write-Host "1. Windows設定 > デバイス > Bluetooth とその他のデバイス を開く" -ForegroundColor Yellow
                            Write-Host "2. 'microball' または類似の名前のデバイスを探す" -ForegroundColor Yellow
                            Write-Host "3. 見つけたら '削除' または 'デバイスの削除' をクリック" -ForegroundColor Yellow
                            Write-Host "4. その後、以下のコマンドを実行してください:" -ForegroundColor Yellow
                            Write-Host "   netsh advfirewall firewall delete rule name=all" -ForegroundColor Cyan
                            Write-Host ""
                            
                            $openSettings = Read-Host "Bluetooth設定を開きますか？ (y/n)"
                            if ($openSettings -eq "y") {
                                try {
                                    Start-Process "ms-settings:bluetooth"
                                    Write-Host "Bluetooth設定を開きました" -ForegroundColor Green
                                } catch {
                                    Write-Host "設定を開けませんでした" -ForegroundColor Red
                                }
                            }
                        } catch {
                            Write-Host "PowerShell method failed: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                        
                        if ($allDeviceNames.Count -gt 0) {
                            Write-Host "All paired devices:" -ForegroundColor Blue
                            foreach ($name in $allDeviceNames) {
                                Write-Host "  $name" -ForegroundColor Gray
                            }
                        }
                    }
                } catch {
                    Write-Host "Error using Bluetooth Command Line Tools: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "Falling back to manual removal..." -ForegroundColor Yellow
                    
                    try {
                        Start-Process "ms-settings:bluetooth"
                        Write-Host "Bluetooth settings opened for manual removal" -ForegroundColor Green
                    } catch {
                        Write-Host "Could not open Bluetooth settings" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "Bluetooth Command Line Tools not found" -ForegroundColor Red
                Write-Host "Please install from: https://bluetoothinstaller.com/bluetooth-command-line-tools" -ForegroundColor Yellow
                Write-Host "Opening Bluetooth settings for manual removal..." -ForegroundColor Yellow
                
                try {
                    Start-Process "ms-settings:bluetooth"
                    Write-Host "Bluetooth settings opened" -ForegroundColor Green
                } catch {
                    Write-Host "Could not open Bluetooth settings" -ForegroundColor Red
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

# Show usage examples
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Blue
Write-Host "  .\up-firm.ps1 -side L           # Update left side firmware" -ForegroundColor Gray
Write-Host "  .\up-firm.ps1 -side R -init     # Update right side with settings reset" -ForegroundColor Gray
Write-Host "  .\up-firm.ps1 -btclean          # Bluetooth device cleanup only" -ForegroundColor Gray