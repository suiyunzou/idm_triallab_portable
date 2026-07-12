<#
.SYNOPSIS
  Detect and remove IDM-related CLSID ACL locks (IAS Freeze residue).

.DESCRIPTION
  Blue-team fingerprint: Owner=NULL SID + Everyone:ReadKey only on trial CLSIDs.
  This script takes ownership, restores a normal DACL, then deletes the locked keys
  so IDM can recreate them cleanly. Does NOT write trial values / serials.
  -ScanOnly works without admin. Unlock requires elevation.
#>
param(
  [switch]$ScanOnly,
  [string]$LogPath = ""
)

$ErrorActionPreference = "Continue"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ScanOnly -and -not $isAdmin) {
  Write-Host "ERROR: unlock requires Administrator. Re-run elevated, or use -ScanOnly."
  exit 5
}

function Write-Log([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m
  Write-Host $line
  if ($LogPath) { Add-Content -Path $LogPath -Value $line -Encoding UTF8 }
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TokPriv {
  [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
  public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, int BufferLength, IntPtr PreviousState, IntPtr ReturnLength);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool OpenProcessToken(IntPtr ProcessHandle, int DesiredAccess, out IntPtr TokenHandle);
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out long lpLuid);
  [StructLayout(LayoutKind.Sequential, Pack=1)]
  public struct TOKEN_PRIVILEGES { public int PrivilegeCount; public long Luid; public int Attributes; }
  public static void Enable(string name) {
    IntPtr h;
    if (!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle, 0x28, out h))
      throw new Exception("OpenProcessToken " + Marshal.GetLastWin32Error());
    long luid;
    if (!LookupPrivilegeValue(null, name, out luid))
      throw new Exception("Lookup " + name + " " + Marshal.GetLastWin32Error());
    TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
    tp.PrivilegeCount = 1; tp.Luid = luid; tp.Attributes = 2;
    if (!AdjustTokenPrivileges(h, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero))
      throw new Exception("Adjust " + Marshal.GetLastWin32Error());
  }
}
"@

if (-not $ScanOnly) {
  foreach ($p in @("SeTakeOwnershipPrivilege", "SeRestorePrivilege", "SeBackupPrivilege")) {
    try { [TokPriv]::Enable($p); Write-Log "priv OK $p" } catch { Write-Log "priv FAIL $p $_" }
  }
}

# Interactive user SID (elevated process is often Administrators)
$userSid = $null
$userAcc = $null
try {
  $ex = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1
  $o = Invoke-CimMethod -InputObject $ex -MethodName GetOwner
  $nt = New-Object System.Security.Principal.NTAccount($o.Domain, $o.User)
  $userSid = $nt.Translate([System.Security.Principal.SecurityIdentifier]).Value
  $userAcc = $nt
  Write-Log "interactive user=$($o.Domain)\$($o.User) sid=$userSid"
} catch {
  $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $userAcc = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Translate([System.Security.Principal.NTAccount])
  Write-Log "fallback sid=$userSid"
}

# Known IDM / IAS trial CLSIDs + heuristic scan
$known = @(
  "{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}",
  "{11469A89-1D27-4D15-8B12-F487D0A0A694}",
  "{6DDF00DB-1234-46EC-8356-27E81B29B7AD}",
  "{7B8E9164-324D-4A2E-A46D-DA2E7A5B87C1}",
  "{D5B554FB-0EFB-4FB4-A213-C338295120CE}",
  "{07999AC3-0580-4194-B22C-69BBBA92AE86}",
  "{5ED60779-4B7C-4F01-B348-B9443F40D796}"
)

function Test-LockedAcl($acl) {
  if (-not $acl) { return $false }
  $owner = $null
  try { $owner = $acl.Owner } catch {}
  $nullOwner = ($owner -eq "NULL SID" -or $owner -match "S-1-0-0" -or $owner -eq "NT AUTHORITY\NULL SID")
  $denies = @($acl.Access | Where-Object { $_.AccessControlType -eq "Deny" })
  $onlyEveryoneRead = (
    $acl.Access.Count -eq 1 -and
    $acl.Access[0].IdentityReference.Value -eq "Everyone" -and
    ($acl.Access[0].RegistryRights.ToString() -match "ReadKey|Read")
  )
  return ($nullOwner -or $denies.Count -gt 0 -or $onlyEveryoneRead)
}

function Get-CandidateKeys {
  $list = New-Object System.Collections.Generic.List[string]
  $roots = @(
    "Registry::HKEY_CURRENT_USER\Software\Classes\CLSID",
    "Registry::HKEY_USERS\$userSid\Software\Classes\CLSID",
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\CLSID",
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Classes\CLSID"
  )
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($id in $known) {
      $p = Join-Path $root $id
      if (Test-Path $p) { [void]$list.Add($p) }
    }
    # Heuristic: any CLSID with trial value names or locked ACL
    Get-ChildItem $root -EA SilentlyContinue | ForEach-Object {
      $hit = $false
      try {
        $ip = Get-ItemProperty $_.PSPath -EA SilentlyContinue
        foreach ($n in @("Therad", "MData", "Model", "scansk", "tvfrdt")) {
          if ($ip.PSObject.Properties.Name -contains $n) { $hit = $true; break }
        }
      } catch {}
      try {
        $acl = Get-Acl $_.PSPath -EA SilentlyContinue
        if (Test-LockedAcl $acl) { $hit = $true }
      } catch { $hit = $true }
      if ($hit) { [void]$list.Add($_.PSPath) }
    }
  }
  $list | Select-Object -Unique
}

function Unlock-And-Delete([string]$psPath) {
  Write-Log "---- $psPath ----"
  # Convert PS path to hive + subkey
  $raw = $psPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', '' -replace '^Registry::', ''
  $parts = $raw -split '\\', 2
  $hiveName = $parts[0]
  $sub = $parts[1]
  $hive = switch -Regex ($hiveName) {
    '^HKEY_USERS$' { [Microsoft.Win32.RegistryHive]::Users }
    '^HKEY_LOCAL_MACHINE$' { [Microsoft.Win32.RegistryHive]::LocalMachine }
    '^HKEY_CURRENT_USER$' { [Microsoft.Win32.RegistryHive]::CurrentUser }
    default { throw "bad hive $hiveName" }
  }
  $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Default)
  $key = $null
  try {
    $key = $base.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
  } catch { Write-Log "Open TakeOwnership fail: $($_.Exception.Message)" }
  if (-not $key) {
    try { $key = $base.OpenSubKey($sub, $true) } catch {
      Write-Log "Open writable fail: $($_.Exception.Message)"; return $false
    }
  }
  try {
    $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::All)
    Write-Log "before owner=$($acl.GetOwner([type]'System.Security.Principal.NTAccount'))"
    $admin = New-Object System.Security.Principal.NTAccount("BUILTIN", "Administrators")
    $acl.SetOwner($admin)
    $key.SetAccessControl($acl)
    Write-Log "owner -> Administrators"
  } catch { Write-Log "SetOwner fail: $($_.Exception.Message)" }

  $key.Close()
  try {
    $key = $base.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
      [System.Security.AccessControl.RegistryRights]::ChangePermissions -bor
      [System.Security.AccessControl.RegistryRights]::TakeOwnership -bor
      [System.Security.AccessControl.RegistryRights]::ReadKey)
  } catch {
    try { $key = $base.OpenSubKey($sub, $true) } catch {
      Write-Log "Reopen fail: $($_.Exception.Message)"; return $false
    }
  }

  try {
    $acl = $key.GetAccessControl()
    $admin = New-Object System.Security.Principal.NTAccount("BUILTIN", "Administrators")
    $sys = New-Object System.Security.Principal.NTAccount("NT AUTHORITY", "SYSTEM")
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($r in @($acl.Access)) {
      try { [void]$acl.RemoveAccessRule($r) } catch { try { $acl.RemoveAccessRuleAll($r) } catch {} }
    }
    $full = [System.Security.AccessControl.RegistryRights]::FullControl
    $inh = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
    $prop = [System.Security.AccessControl.PropagationFlags]::None
    $allow = [System.Security.AccessControl.AccessControlType]::Allow
    foreach ($acc in @($admin, $sys, $userAcc)) {
      $rule = New-Object System.Security.AccessControl.RegistryAccessRule($acc, $full, $inh, $prop, $allow)
      $acl.AddAccessRule($rule)
    }
    $key.SetAccessControl($acl)
    Write-Log "DACL restored FullControl"
  } catch { Write-Log "DACL fail: $($_.Exception.Message)" }
  $key.Close()

  $parentPath = Split-Path $sub -Parent
  $name = Split-Path $sub -Leaf
  try {
    $parent = $base.OpenSubKey($parentPath, $true)
    if ($parent) {
      $parent.DeleteSubKeyTree($name)
      $parent.Close()
      Write-Log "DELETED OK"
      return $true
    }
    Write-Log "parent open fail"
    return $false
  } catch {
    Write-Log "Delete fail: $($_.Exception.Message)"
    return $false
  }
}

$cands = @(Get-CandidateKeys)
Write-Log "candidates=$($cands.Count)"
$locked = @()
foreach ($c in $cands) {
  try {
    $acl = Get-Acl $c -EA Stop
    $props = @()
    try {
      $ip = Get-ItemProperty $c -EA SilentlyContinue
      foreach ($n in @("Therad", "MData", "Model", "scansk", "tvfrdt")) {
        if ($ip.PSObject.Properties.Name -contains $n) { $props += $n }
      }
    } catch {}
    $isLock = Test-LockedAcl $acl
    if ($isLock -or $props.Count -gt 0) {
      $locked += [PSCustomObject]@{ Path = $c; Owner = $acl.Owner; Props = ($props -join ","); Locked = $isLock }
      Write-Log ("FOUND owner={0} props=[{1}] locked={2} path={3}" -f $acl.Owner, ($props -join ","), $isLock, $c)
    }
  } catch {
    $locked += [PSCustomObject]@{ Path = $c; Owner = "ACL_FAIL"; Props = ""; Locked = $true }
    Write-Log "FOUND ACL_FAIL path=$c err=$($_.Exception.Message)"
  }
}

if ($locked.Count -eq 0) {
  Write-Log "CLEAN: no CLSID ACL locks"
  exit 0
}

if ($ScanOnly) {
  Write-Log "SCAN_ONLY hits=$($locked.Count)"
  exit 2
}

$fail = 0
foreach ($item in $locked) {
  if (-not (Unlock-And-Delete $item.Path)) { $fail++ }
}

# Re-scan
$left = 0
foreach ($c in @(Get-CandidateKeys)) {
  try {
    $acl = Get-Acl $c -EA Stop
    if (Test-LockedAcl $acl) {
      Write-Log "STILL_LOCKED $c owner=$($acl.Owner)"
      $left++
    }
  } catch {
    Write-Log "STILL_UNREADABLE $c"
    $left++
  }
}

if ($left -gt 0 -or $fail -gt 0) {
  Write-Log "UNLOCK_INCOMPLETE left=$left fail=$fail"
  exit 1
}
Write-Log "UNLOCK_OK"
exit 0
