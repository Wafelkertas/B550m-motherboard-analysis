# Runtime AOD variable reader

`Read-AodSetup.ps1` exports the `AOD_SETUP` UEFI variable from a running Windows installation. It is read-only with respect to UEFI NVRAM: it calls `GetFirmwareEnvironmentVariableEx`, copies the returned data to a local file, and reports the relevant gate byte.

Run PowerShell **as Administrator** from the cloned repository:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Read-AodSetup.ps1
```

The default output is `AOD_SETUP.bin` on the current user's Desktop. To choose another local file:

```powershell
.\scripts\Read-AodSetup.ps1 -OutputPath C:\Temp\AOD_SETUP.bin
```

The script reads byte offset `0x13D` of the variable data. For the analyzed PRO-DASH 3.7 IFR, `1` means the `Onboard Voltage Controls` menu gate permits visibility; another value means the IFR gate suppresses it. This reports a runtime state only—it does not demonstrate that a requested VDDIO setting is electrically applied.

Common failures:

* Win32 error `1314`: PowerShell was not started with Administrator rights.
* Win32 error `203`: Windows/firmware did not expose the variable. Use the read-only Linux `efivarfs` method described in the main report as a fallback.

Do not use this script to write a UEFI variable; it has no write functionality.
