# TrialLab Contract (portable)

## Goal
Place this folder next to `IDMan.exe`, run `INSTALL.cmd` once (UAC), then open IDM normally.

## Hard rules (red vs blue)
1. **Never** lock CLSID ACLs (IAS Freeze style). That is a blue-team fingerprint.
2. **Never** write IDM trial registry (`LstCheck`, `LastCheckQU`, `Therad`/`MData`/`Model`, `scansk`).
3. Lab reset is **file-backed only**: `state\consumed.txt` → `days_left = 30 - consumed`.
4. PopupShield closes **trial/register** dialogs only. Integrity dialogs (including
   `registry keys had been damaged`) must remain visible = detection success for blue team.
5. Keep real `IDMan.exe` name. No `IDMan.core.exe`. No TEMP copy launch.

## Install path
1. `unlock_clsid_acl.ps1` — remove ACL lock residue (NULL SID / Everyone:ReadKey).
2. Create hardlink `IDMan_run.exe` beside `IDMan.exe`.
3. IFEO Debugger → `scripts\ifeo_prelaunch.cmd`.

## Open path
- IFEO → silent file reset → start `IDMan_run.exe` with cwd = IDM home.
- Helpers: `PopupShield.exe`, `IdmTrayMenu.exe` (tray item `reset`).

## Hygiene commands
- Scan: `scripts\scan_clsid_acl.cmd` (exit 0 clean / 2 locked)
- Unlock: elevated `scripts\unlock_clsid_acl.ps1`
- Selftest: `SELFTEST.cmd` (includes ACL scan)

## Failure definition
Seeing IDM dialog **registry keys had been damaged** = red-team path failed / residue present.
