<#
.SYNOPSIS
    Creates the OPNsense firewall VM of the security homelab with VBoxManage.

.DESCRIPTION
    2 vCPU, 2 GB of RAM, 20 GB dynamically allocated disk, legacy BIOS,
    audio and USB disabled, and four Intel PRO/1000 MT Desktop adapters:
      1. NAT                         -> em0 (WAN)
      2. internal network lan_attack  -> em1 (LAN)
      3. internal network lan_targets -> em2 (OPT1)
      4. internal network lan_monitor -> em3 (OPT2)
    The VM boots on the ISO first, then on the disk.

.EXAMPLE
    .\create-vm.ps1 -IsoPath "D:\Lab\ISO\OPNsense-26.7-dvd-amd64.iso" -BaseFolder "D:\Lab\VMs"
#>
param(
    [Parameter(Mandatory = $true)] [string] $IsoPath,
    [Parameter(Mandatory = $true)] [string] $BaseFolder,
    [string] $VmName = "OPNsense",
    [string] $VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
)

# Stop at the first error instead of continuing with a half-built VM.
$ErrorActionPreference = "Stop"

function Invoke-VBox {
    & $VBoxManage @args
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args -join ' ') failed" }
}

if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }

# 1. Create and register the VM (FreeBSD 64-bit: OPNsense is based on FreeBSD).
Invoke-VBox createvm --name $VmName --ostype FreeBSD_64 --basefolder $BaseFolder --register

# 2. Hardware: CPU, RAM, firmware, display, and no audio or USB (smaller attack surface).
Invoke-VBox modifyvm $VmName --cpus 2 --memory 2048 --firmware bios `
    --graphicscontroller vmsvga --vram 16 `
    --audio-enabled off --usb-ohci off --usb-ehci off --usb-xhci off `
    --boot1 dvd --boot2 disk --boot3 none --boot4 none

# 3. Network adapters, all Intel PRO/1000 MT Desktop (82540EM), named "em" by FreeBSD.
Invoke-VBox modifyvm $VmName --nic1 nat --nic-type1 82540EM
Invoke-VBox modifyvm $VmName --nic2 intnet --intnet2 lan_attack  --nic-type2 82540EM
Invoke-VBox modifyvm $VmName --nic3 intnet --intnet3 lan_targets --nic-type3 82540EM
Invoke-VBox modifyvm $VmName --nic4 intnet --intnet4 lan_monitor --nic-type4 82540EM

# 4. Storage: a 20 GB dynamically allocated disk and the installation ISO.
$disk = Join-Path (Join-Path $BaseFolder $VmName) "$VmName.vdi"
Invoke-VBox createmedium disk --filename $disk --size 20480 --format VDI
Invoke-VBox storagectl $VmName --name IDE --add ide --controller PIIX4
Invoke-VBox storageattach $VmName --storagectl IDE --port 0 --device 0 --type hdd --medium $disk
Invoke-VBox storageattach $VmName --storagectl IDE --port 1 --device 0 --type dvddrive --medium $IsoPath

Write-Host "VM '$VmName' created. Start it with: & '$VBoxManage' startvm $VmName"
