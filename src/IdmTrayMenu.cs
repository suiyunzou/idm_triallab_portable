using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

internal static class Native
{
    public const uint EVENT_SYSTEM_MENUPOPUPSTART = 0x0006;
    public const uint EVENT_SYSTEM_MENUPOPUPEND = 0x0007;
    public const uint WINEVENT_OUTOFCONTEXT = 0x0000;
    public const uint MF_STRING = 0x00000000;
    public const uint MF_SEPARATOR = 0x00000800;
    public const uint MF_BYCOMMAND = 0x00000000;
    public const uint MF_BYPOSITION = 0x00000400;
    public const int MN_GETHMENU = 0x01E1;
    public const uint WM_CANCELMODE = 0x001F;
    public const uint WM_LBUTTONUP = 0x0202;
    public const int WH_MOUSE_LL = 14;
    public const int WM_NULL = 0x0000;
    public const int HC_ACTION = 0;
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);

    public const uint ID_RESET = 0xF30D; // unlikely to collide with IDM cmds

    public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);
    public delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")] public static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr hmodWinEventProc, WinEventDelegate lpfnWinEventProc, uint idProcess, uint idThread, uint dwFlags);
    [DllImport("user32.dll")] public static extern bool UnhookWinEvent(IntPtr hWinEventHook);
    [DllImport("user32.dll")] public static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] public static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] public static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool AppendMenu(IntPtr hMenu, uint uFlags, uint uIDNewItem, string lpNewItem);
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr hMenu);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetMenuString(IntPtr hMenu, uint uIDItem, StringBuilder lpString, int nMaxCount, uint uFlag);
    [DllImport("user32.dll")] public static extern bool GetMenuItemRect(IntPtr hWnd, IntPtr hMenu, uint uItem, out RECT lprcItem);
    [DllImport("user32.dll")] public static extern bool PtInRect(ref RECT lprc, POINT pt);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT Point);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MSLLHOOKSTRUCT
    {
        public POINT pt;
        public uint mouseData, flags, time;
        public IntPtr dwExtraInfo;
    }
}

public class TrayMenuHost : Form
{
    readonly uint _targetPid;
    readonly string _consumed;
    readonly string _log;
    Native.WinEventDelegate _winEventProc;
    Native.HookProc _mouseProc;
    IntPtr _winEventHook = IntPtr.Zero;
    IntPtr _mouseHook = IntPtr.Zero;
    IntPtr _menuHwnd = IntPtr.Zero;
    IntPtr _hMenu = IntPtr.Zero;
    int _resetPos = -1;
    bool _injected;

    public TrayMenuHost(uint targetPid)
    {
        _targetPid = targetPid;
        string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        string state = Path.Combine(baseDir, "state");
        if (!Directory.Exists(state))
            state = Path.GetFullPath(Path.Combine(baseDir, "..", "state"));
        if (!Directory.Exists(state))
            state = Path.Combine(baseDir, "TrialLab", "state");
        Directory.CreateDirectory(state);
        _consumed = Path.Combine(state, "consumed.txt");
        _log = Path.Combine(state, "silent_reset.log");

        ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        Opacity = 0;
        Size = new Size(0, 0);
        WindowState = FormWindowState.Minimized;

        Load += (s, e) =>
        {
            Hide();
            _winEventProc = OnWinEvent;
            _mouseProc = OnMouse;
            uint pid = _targetPid;
            _winEventHook = Native.SetWinEventHook(
                Native.EVENT_SYSTEM_MENUPOPUPSTART, Native.EVENT_SYSTEM_MENUPOPUPEND,
                IntPtr.Zero, _winEventProc, pid, 0, Native.WINEVENT_OUTOFCONTEXT);
            _mouseHook = Native.SetWindowsHookEx(Native.WH_MOUSE_LL, _mouseProc,
                Native.GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName), 0);
            if (_winEventHook == IntPtr.Zero || _mouseHook == IntPtr.Zero)
            {
                File.AppendAllText(_log, DateTime.Now.ToString("HH:mm:ss") +
                    " TRAY_MENU_HOOK warn winevent=" + _winEventHook + " mouse=" + _mouseHook + "\r\n");
            }
            File.AppendAllText(_log, DateTime.Now.ToString("HH:mm:ss") +
                " TRAY_MENU_HOOK start pid=" + _targetPid + "\r\n");
        };

        FormClosing += (s, e) =>
        {
            if (_winEventHook != IntPtr.Zero) Native.UnhookWinEvent(_winEventHook);
            if (_mouseHook != IntPtr.Zero) Native.UnhookWindowsHookEx(_mouseHook);
        };

        // Exit when IDM exits
        var t = new System.Windows.Forms.Timer { Interval = 1500 };
        t.Tick += (s, e) =>
        {
            if (_targetPid == 0) return;
            try { if (Process.GetProcessById((int)_targetPid).HasExited) Close(); }
            catch { Close(); }
        };
        t.Start();
    }

    void OnWinEvent(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime)
    {
        try
        {
            if (eventType == Native.EVENT_SYSTEM_MENUPOPUPEND)
            {
                _menuHwnd = IntPtr.Zero;
                _hMenu = IntPtr.Zero;
                _resetPos = -1;
                _injected = false;
                return;
            }
            if (eventType != Native.EVENT_SYSTEM_MENUPOPUPSTART) return;
            if (hwnd == IntPtr.Zero) return;

            uint pid;
            Native.GetWindowThreadProcessId(hwnd, out pid);
            if (_targetPid != 0 && pid != _targetPid) return;

            var cls = new StringBuilder(64);
            Native.GetClassName(hwnd, cls, cls.Capacity);
            if (cls.ToString() != "#32768") return; // menu window class

            IntPtr hMenu = Native.SendMessage(hwnd, Native.MN_GETHMENU, IntPtr.Zero, IntPtr.Zero);
            if (hMenu == IntPtr.Zero) return;
            if (!LooksLikeIdmTrayMenu(hMenu)) return;
            if (MenuAlreadyHasReset(hMenu)) return;

            Native.AppendMenu(hMenu, Native.MF_SEPARATOR, 0, null);
            Native.AppendMenu(hMenu, Native.MF_STRING, Native.ID_RESET, "reset");
            _menuHwnd = hwnd;
            _hMenu = hMenu;
            _resetPos = Native.GetMenuItemCount(hMenu) - 1;
            _injected = true;
            File.AppendAllText(_log, DateTime.Now.ToString("HH:mm:ss") +
                " TRAY_MENU injected reset pos=" + _resetPos + "\r\n");
        }
        catch (Exception ex)
        {
            try { File.AppendAllText(_log, "TRAY_MENU_ERR " + ex.Message + "\r\n"); } catch { }
        }
    }

    bool LooksLikeIdmTrayMenu(IntPtr hMenu)
    {
        int count = Native.GetMenuItemCount(hMenu);
        if (count <= 0 || count > 40) return false;

        // Match the real Chinese IDM tray menu (and English variants).
        // Screenshot items: ���� / ���� IDM / ע�� / ��ϵ���� / ���߶��� / �ٶ����� / ��ʾ������ / ��ԭ
        // NOTE: "��ԭ" is IDM's built-in Restore (show main window), NOT our reset item.
        int score = 0;
        var dump = new StringBuilder();
        var sb = new StringBuilder(256);
        for (uint i = 0; i < (uint)count; i++)
        {
            sb.Clear();
            Native.GetMenuString(hMenu, i, sb, sb.Capacity, Native.MF_BYPOSITION);
            string s = sb.ToString();
            if (string.IsNullOrEmpty(s)) continue;
            dump.Append('[').Append(s).Append(']');

            if (ContainsAny(s, "\u8FD8\u539F", "Restore", "Show main")) score += 2;           // ��ԭ
            if (ContainsAny(s, "\u6CE8\u518C", "Register")) score += 2;                       // ע��
            if (ContainsAny(s, "\u5173\u4E8E", "About")) score += 1;                          // ����
            if (ContainsAny(s, "\u5E2E\u52A9", "Help")) score += 1;                           // ����
            if (ContainsAny(s, "\u901F\u5EA6\u9650\u5236", "Speed")) score += 1;             // �ٶ�����
            if (ContainsAny(s, "\u663E\u793A\u60AC\u6D6E\u7A97", "floating", "Drop target")) score += 1; // ��ʾ������
            if (ContainsAny(s, "\u8054\u7CFB\u6211\u4EEC", "Contact")) score += 1;           // ��ϵ����
            if (ContainsAny(s, "\u5728\u7EBF\u8BA2\u8D2D", "Order", "Buy")) score += 1;      // ���߶���
            if (ContainsAny(s, "Exit", "\u9000\u51FA")) score += 2;                           // �˳�
        }

        bool ok = score >= 3;
        try
        {
            File.AppendAllText(_log, DateTime.Now.ToString("HH:mm:ss") +
                " TRAY_MENU probe score=" + score + " ok=" + ok + " items=" + dump + "\r\n");
        }
        catch { }
        return ok;
    }

    static bool ContainsAny(string s, params string[] keys)
    {
        for (int i = 0; i < keys.Length; i++)
        {
            if (s.IndexOf(keys[i], StringComparison.OrdinalIgnoreCase) >= 0) return true;
        }
        return false;
    }

    bool MenuAlreadyHasReset(IntPtr hMenu)
    {
        int count = Native.GetMenuItemCount(hMenu);
        var sb = new StringBuilder(64);
        for (uint i = 0; i < (uint)count; i++)
        {
            sb.Clear();
            Native.GetMenuString(hMenu, i, sb, sb.Capacity, Native.MF_BYPOSITION);
            string s = sb.ToString();
            if (string.Equals(s, "reset", StringComparison.OrdinalIgnoreCase)) return true;
            // also detect Chinese label if used later
            if (s == "\u8BD5\u7528\u91CD\u7F6E") return true; // ��������
        }
        return false;
    }

    IntPtr OnMouse(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && _injected && _hMenu != IntPtr.Zero && _resetPos >= 0)
        {
            if (wParam == (IntPtr)Native.WM_LBUTTONUP)
            {
                try
                {
                    var info = (Native.MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(Native.MSLLHOOKSTRUCT));
                    Native.RECT rc;
                    if (Native.GetMenuItemRect(_menuHwnd, _hMenu, (uint)_resetPos, out rc))
                    {
                        var pt = info.pt;
                        if (Native.PtInRect(ref rc, pt))
                        {
                            DoReset();
                            if (_menuHwnd != IntPtr.Zero)
                                Native.SendMessage(_menuHwnd, unchecked((int)Native.WM_CANCELMODE), IntPtr.Zero, IntPtr.Zero);
                        }
                    }
                }
                catch { }
            }
        }
        return Native.CallNextHookEx(_mouseHook, nCode, wParam, lParam);
    }

    void DoReset()
    {
        try
        {
            File.WriteAllText(_consumed, "0\r\n");
            File.AppendAllText(_log, DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss") +
                " RESET_OK consumed=0 days_left=30 via=idm-tray-context-menu\r\n");
        }
        catch (Exception ex)
        {
            try { File.AppendAllText(_log, "TRAY_RESET_FAIL " + ex.Message + "\r\n"); } catch { }
        }
    }

    [STAThread]
    static void Main(string[] args)
    {
        uint pid = 0;
        if (args.Length > 0) uint.TryParse(args[0], out pid);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new TrayMenuHost(pid));
    }
}
