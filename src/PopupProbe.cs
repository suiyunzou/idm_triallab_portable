using System;
using System.Runtime.InteropServices;
using System.Threading;
internal static class PopupProbe {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int MessageBoxW(IntPtr h, string t, string c, uint type);
  static int Main() {
    var th=new Thread(()=>{
      MessageBoxW(IntPtr.Zero,
        "Internet Download Manager free trial period has expired. Please register IDM.",
        "30 day trial - Register IDM",
        0x00000030);
    });
    th.SetApartmentState(ApartmentState.STA);
    th.Start();
    th.Join(20000);
    return 0;
  }
}
