using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class ClickReset
{
    const uint BM_CLICK = 0x00F5;
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);

    static IntPtr target = IntPtr.Zero;

    static int Main()
    {
        EnumWindows((h, l) =>
        {
            if (!IsWindowVisible(h)) return true;
            uint wpid; GetWindowThreadProcessId(h, out wpid);
            try
            {
                var p = Process.GetProcessById((int)wpid);
                if (!string.Equals(p.ProcessName, "ResetButton", StringComparison.OrdinalIgnoreCase)) return true;
            }
            catch { return true; }

            EnumChildWindows(h, (ch, ll) =>
            {
                var sb = new StringBuilder(64);
                GetWindowText(ch, sb, sb.Capacity);
                if (sb.ToString() == "reset" || sb.ToString() == "OK")
                {
                    target = ch;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return target == IntPtr.Zero;
        }, IntPtr.Zero);

        if (target == IntPtr.Zero)
        {
            Console.WriteLine("NO_BUTTON");
            return 2;
        }
        PostMessage(target, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
        Thread.Sleep(500);
        Console.WriteLine("CLICKED");
        return 0;
    }
}
