# IDM TrialLab Portable

把本文件夹放到 `IDMan.exe` **同级目录**，执行一次 `INSTALL.cmd`，之后即可长期使用。

本包用于本地试用机制实验：**不改写** IDM 试用注册表，**不锁定** CLSID ACL。约束说明见 [docs/CONTRACT.md](docs/CONTRACT.md)。

## 功能一览

- 一键安装：清理 ACL 残留 → 创建硬链接 → 注册 IFEO
- 日常只需正常打开 `IDMan.exe`（无需每次管理员权限）
- 两种重置方式：启动时自动重置，或托盘手动 `reset`
- 自动关闭试用/注册类弹窗；完整性告警窗会保留，便于排查

## 环境要求

- Windows（支持 UAC）
- 已安装 Internet Download Manager（存在 `IDMan.exe`）
- 安装 / 卸载时需要管理员权限（仅一次 UAC）

## 安装

### 1. 放置位置

```text
...\Internet Download Manager\
  IDMan.exe
  IDM_TrialLab_Portable\     ← 本包（与 IDMan.exe 同级）
    INSTALL.cmd
    UNINSTALL.cmd
    SELFTEST.cmd
    bin\
    scripts\
    state\
    docs\
```

### 2. 执行安装

1. 双击 `INSTALL.cmd`
2. UAC 点「确定」
3. 完成后正常启动 `IDMan.exe`

安装过程会自动：

1. 清除 CLSID ACL 锁残留（`NULL SID` + `Everyone:ReadKey`）
2. 创建 `IDMan_run.exe` 硬链接
3. 注册 IFEO（长期有效）

### 3. 可选自检

```bat
SELFTEST.cmd
```

成功时输出 `ALL SELFTESTS PASSED`。

## 日常操作

| 操作 | 方法 |
|------|------|
| 启动 | 打开 `IDMan.exe` |
| ACL 扫描 | `scripts\scan_clsid_acl.cmd`（干净=`0`，仍有锁=`2`） |
| 自检 | `SELFTEST.cmd` |
| 卸载 | `UNINSTALL.cmd` |

## 重置方式

有两种，可任选其一：

1. **手动重置**  
   托盘图标右键 → 选择 `reset`。

2. **自动重置（默认）**  
   每次启动 `IDMan.exe` 时，IFEO 会先跑一段预启动脚本并把试用计数归零。启动瞬间可能会闪一下**黑色 cmd 窗口**，属正常现象，窗口会很快消失。

## 卸载

双击 `UNINSTALL.cmd` 并确认 UAC。将会：

- 移除 IFEO 注册
- 删除 `IDMan_run.exe` 硬链接
- 保留本包目录（方便再次安装）

## 行为约定

| 会做 | 不会做 |
|------|--------|
| 只修改本包 `state\consumed.txt` | 不改 `LstCheck` / CLSID / ACL |
| 托盘注入 `reset` 菜单项 | 不锁注册表（如 IAS Freeze） |
| 只关试用/注册弹窗 | 不关「registry keys had been damaged」 |

若出现「注册表已被损坏」类弹窗，说明环境仍有残留或安装失败，**不是**成功信号。

## 目录结构

```text
IDM_TrialLab_Portable/
├── INSTALL.cmd       # 一键安装
├── UNINSTALL.cmd     # 一键卸载
├── SELFTEST.cmd      # 安装后自检
├── bin/              # 预编译助手程序
├── scripts/          # 安装、IFEO、扫描与重置脚本
├── state/            # 本机运行状态（本地日志，不入库）
└── docs/CONTRACT.md  # 详细行为契约
```

## 常见问题

**找不到 `IDMan.exe`？**  
本包必须与 `IDMan.exe` 同级，不要只复制子目录。

**托盘没有 `reset`？**  
确认 `IdmTrayMenu.exe` 在运行，或执行 `SELFTEST.cmd`；也可查看 `state\silent_reset.log`。即使没有托盘菜单，每次启动也会自动重置。

**启动时闪黑窗？**  
正常。那是 IFEO 预启动脚本在做自动重置，一般会很快关掉。

**每次都要管理员运行吗？**  
不用。仅安装 / 卸载需要 UAC。

**可以移动本包吗？**  
不建议。IFEO 记录的是安装时的绝对路径；移动后请重新运行 `INSTALL.cmd`。

## 自行编译（可选）

```bat
scripts\build.cmd
```

产物写入 `bin\`。

## 声明

请仅在合法授权的软件副本上，用于学习、实验或环境验证。请遵守当地法律与软件许可协议。
