# IDM TrialLab Portable

把本文件夹放到 `IDMan.exe` **同目录**，执行一次 `INSTALL.cmd`，终身可用。

## 目录关系

```
...\Internet Download Manager\
  IDMan.exe
  IDM_TrialLab_Portable\     ← 本包（与 IDMan.exe 同级）
    INSTALL.cmd
    UNINSTALL.cmd
    SELFTEST.cmd
    bin\
    scripts\
    state\
```

## 一次安装（零参数）

1. 复制本包到 IDM 安装目录（与 `IDMan.exe` 同级）
2. 双击 `INSTALL.cmd`，UAC 点「确定」
3. 之后正常启动 `IDMan.exe`

安装时会自动：
- **清除 CLSID ACL 锁残留**（蓝队指纹：`NULL SID` + `Everyone:ReadKey`）
- 创建 `IDMan_run.exe` 硬链接
- 注册 IFEO（终身）

## 思路（重要）

| 做 | 不做 |
|----|------|
| 只改本包 `state\consumed.txt` | 不改 `LstCheck` / CLSID / ACL |
| 托盘菜单注入 `reset` | 不锁注册表（IAS Freeze） |
| PopupShield 只关试用/注册窗 | 不关「registry keys had been damaged」 |

出现「注册表被损坏」弹窗 = **红队失败 / 仍有残留**，不是成功绕过。

## 日常

| 操作 | 命令 |
|------|------|
| 启动 | `IDMan.exe` |
| 重置 | 托盘右键 → `reset` |
| ACL 扫描 | `scripts\scan_clsid_acl.cmd` |
| 自检 | `SELFTEST.cmd` |
| 卸载 | `UNINSTALL.cmd` |
