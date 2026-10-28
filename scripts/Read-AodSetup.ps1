#Requires -RunAsAdministrator
<##
.SYNOPSIS
    Read-only export of the AMD Overclocking (AOD_SETUP) UEFI variable.

.DESCRIPTION
    This script calls the Windows firmware-environment read API. It does not
    write UEFI NVRAM, update BIOS, or modify the value it reads. The saved
    binary contains variable data only; UEFI attributes are printed separately.

    In the analyzed MSI B550M PRO-DASH BIOS, byte offset 0x13D is the menu
    capability gate for AMD Overclocking > Onboard Voltage Controls:
      1 = the IFR gate permits the menu to be visible
      any other value = the IFR gate suppresses the menu

.PARAMETER OutputPath
    Destination for the exported variable data. Defaults to AOD_SETUP.bin on
    the current user's Desktop.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $env:USERPROFILE 'Desktop\AOD_SETUP.bin')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class UefiVariableReader {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern uint GetFirmwareEnvironmentVariableEx(
        string name,
        string guid,
        byte[] buffer,
        uint size,
        out uint attributes);
}
'@

$name = 'AOD_SETUP'
$guid = '{5ED15DC0-EDEF-4161-9151-6014C4CC630C}'
$buffer = New-Object byte[] 4096
[uint32]$attributes = 0

$size = [UefiVariableReader]::GetFirmwareEnvironmentVariableEx(
    $name,
    $guid,
    $buffer,
    [uint32]$buffer.Length,
    [ref]$attributes
)

if ($size -eq 0) {
    $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Unable to read $name. Win32 error: $errorCode"
}

if ($size -le 0x13D) {
    throw "Variable is only $size bytes; it does not contain offset 0x13D."
}

[byte[]]$data = $buffer[0..($size - 1)]
[IO.File]::WriteAllBytes($OutputPath, $data)
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutputPath).Hash

[pscustomobject]@{
    Variable       = "$name $guid"
    DataBytes      = $size
    UefiAttributes = ('0x{0:X8}' -f $attributes)
    GateOffset     = '0x13D'
    GateValue      = $data[0x13D]
    GateMeaning    = if ($data[0x13D] -eq 1) { 'IFR permits menu visibility' } else { 'IFR suppresses the menu' }
    OutputPath     = $OutputPath
    SHA256         = $hash
} | Format-List
