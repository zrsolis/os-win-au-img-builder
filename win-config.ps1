# Create our working/download directory
 try {
    $path = (New-Item -Path c:\ -Name tests -ItemType Directory -ErrorAction Stop).FullName
} catch [System.Management.Automation.ItemNotFoundException],[System.IO.IOException]{
    Write-Output "An unexpected error occurred: $($_.Exception.Message)"
} 


# Determine which type of Windows we are running
$wintype = (Get-CimInstance Win32_OperatingSystem).ProductType
if ($wintype -eq 2) {
    Write-Output "This is a Domain Controller. Why are you trying to sysprep a Domain Controller? Please re-think your life choices."
    break
}
if ($wintype -eq 1) {
    Write-Output "This is a desktop OS, setting user to Admin"
    $user = "Admin"
} else {
    Write-Output "This is a server OS, setting user to Administrator"
    $user = "Administrator"
}

# Enable RDP access
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\" -Name fDenyTSConnections -Value 0 #Enable RDP

# Allow RDP connections through the firewall
Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-Tcp -Enabled True
Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-Udp -Enabled True

# Enable File and Printer Sharing 
Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled True -Profile Any

# Disable Hibernate
powercfg -h off

# Enable High Performance power settings
powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Enable PSRemoting
Enable-PSRemoting -Force

# Enable RealTimeIsUniversal and set Time Zone to UTC
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name RealTimeIsUniversal -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name TimeZoneKeyName -Value "UTC"

# Set script execution policy to unrestricated
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "PowerShell"
New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Name EnableScripts -Value 1
New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Name ExecutionPolicy -Value "Unrestricted"

#Enable Remote Management with WinRM
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "WinRM"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM" -Name Service
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -Name AllowAutoConfig -Value 1
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -Name IPv4Filter -Value "*"
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -Name IPv6Filter -Value "*"

# Set Visual Effects to Best Performance
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Value 2

# Disable Automatic Updates
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "WindowsUpdate"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AU"
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name NoAutoUpdate -Value 1

# Download VirtIO guest agent, mount and get drive letter of mounted ISO
Invoke-WebRequest -Uri https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -OutFile "$path\virtio-win.iso"
$mount = Mount-DiskImage -ImagePath "$path\virtio-win.iso"
$DL = (Get-DiskImage -DevicePath $mount.DevicePath | Get-Volume).DriveLetter

# Install VirtIO drivers
Start-Process "msiexec.exe" -Wait -ArgumentList ("/I $DL:\virtio-win-gt-x64.msi /qn ADDLOCAL=ALL /norestart")

# install Qemu Guest Agent
Start-Process "msiexec.exe" -Wait -ArgumentList ("/I $DL:\guest-agent\qemu-ga-x86_64.msi /qn /norestart")
Dismount-DiskImage -DevicePath $mount.DevicePath | Out-Null

# Install CloudBase-Init
Invoke-WebRequest -Uri https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi -OutFile "$path\CloudBaseInitSetup_Stable_x64.msi"
Start-Process "msiexec.exe" -Wait -ArgumentList("/I $path\CloudBaseInitSetup_Stable_x64.msi /qn USERNAME=$user LOGGINGSERIALPORTNAME=""COM1"" /norestart")

# Cleanup History
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*.*"

# Sysprep and Shutdown
c:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
