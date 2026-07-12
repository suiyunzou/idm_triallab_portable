using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class PopupShield
{
    const uint WM_CLOSE = 0x0010;
    const uint BM_CLICK = 0x00F5;
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr p, IntPtr c, string cls, string win);

    // Only trial / register nags — NEVER integrity / reinstall / integration errors
    static readonly string[] AllowNeedles = {
        "30 day trial", "30-day trial", "Trial period is over", "trial period has expired",
        "days left", "Do you want to register", "Please register IDM", "register your copy",
        "has not been registered for", "free trial period", "Already purchased",
        "Enter your Serial Number", "Please enter your Serial Number",
        "counterfeit Serial Number", "Register IDM",
        "\u8bd5\u7528", "\u6ce8\u518c", "\u5e8f\u5217\u53f7", "\u6fc0\u6d3b"
    };

    // Integrity / reinstall / integration — NEVER auto-close (blue-team signal)
    static readonly string[] DenyNeedles = {
        "cannot find a file", "necessary for browser", "Please reinstall",
        "outdated or corrupted", "browser integration", "Download Video",
        "install it over", "official website", "reinstall IDM",
        "registry keys had been damaged", "flaky spyware", "restore all damaged",
        "corrupted system registry", "damaged since the last run",
        "\u627e\u4e0d\u5230", "\u8bf7\u91cd\u65b0\u5b89\u88c5", "\u635f\u574f", "\u96c6\u6210",
        "\u6ce8\u518c\u8868"
    };

    static string LogPath;

    static int Main(string[] args)
    {
        uint pid = 0;
        if (args.Length > 0) uint.TryParse(args[0], out pid);
        string dir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        LogPath = Path.Combine(dir, "state", "silent_reset.log");
        if (!Directory.Exists(Path.GetDirectoryName(LogPath)))
            LogPath = Path.GetFullPath(Path.Combine(dir, "..", "state", "silent_reset.log"));
        Directory.CreateDirectory(Path.GetDirectoryName(LogPath));
        File.AppendAllText(LogPath, DateTime.Now.ToString("HH:mm:ss") + " POPUP_SHIELD start pid=" + pid + "\r\n");

        var until = DateTime.UtcNow.AddMinutes(30);
        while (DateTime.UtcNow < until)
        {
            if (pid != 0)
            {
                try { if (Process.GetProcessById((int)pid).HasExited) break; }
                catch { break; }
            }
            try { Sweep(pid); } catch (Exception ex) { File.AppendAllText(LogPath, "SHIELD_ERR " + ex.Message + "\r\n"); }
            Thread.Sleep(300);
        }
        return 0;
    }

    static void Sweep(uint targetPid)
    {
        EnumWindows((h, l) =>
        {
            if (!IsWindowVisible(h)) return true;
            uint wpid; GetWindowThreadProcessId(h, out wpid);
            if (targetPid != 0 && wpid != targetPid) return true;

            var title = new StringBuilder(512);
            GetWindowText(h, title, title.Capacity);
            var cls = new StringBuilder(64);
            GetClassName(h, cls, cls.Capacity);
            string t = title.ToString();
            string c = cls.ToString();

            var body = new StringBuilder();
            EnumChildWindows(h, (ch, ll) =>
            {
                var tx = new StringBuilder(1024);
                GetWindowText(ch, tx, tx.Capacity);
                if (tx.Length > 0) body.Append(tx).Append(' ');
                return true;
            }, IntPtr.Zero);
            string all = (t + " " + body);

            foreach (var d in DenyNeedles)
            {
                if (all.IndexOf(d, StringComparison.OrdinalIgnoreCase) >= 0)
                    return true;
            }

            bool hit = false;
            foreach (var n in AllowNeedles)
            {
                if (all.IndexOf(n, StringComparison.OrdinalIgnoreCase) >= 0) { hit = true; break; }
            }
            if (!hit) return true;

            bool clicked =
                Click(h, "OK") || Click(h, "\u786e\u5b9a") || Click(h, "Yes") || Click(h, "\u662f") ||
                Click(h, "Cancel") || Click(h, "\u53d6\u6d88") || Click(h, "Close") || Click(h, "\u5173\u95ed") ||
                Click(h, "No") || Click(h, "\u5426");
            if (!clicked) PostMessage(h, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            File.AppendAllText(LogPath, DateTime.Now.ToString("HH:mm:ss") + " POPUP_SHIELD closed title=[" + t + "] class=[" + c + "]\r\n");
            return true;
        }, IntPtr.Zero);
    }

    static bool Click(IntPtr parent, string text)
    {
        IntPtr btn = FindWindowEx(parent, IntPtr.Zero, "Button", text);
        if (btn == IntPtr.Zero) return false;
        PostMessage(btn, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
        return true;
    }
}
