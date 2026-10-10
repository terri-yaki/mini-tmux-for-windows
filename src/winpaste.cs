// MiniTmux Native Windows Clipboard Reader (winpaste.exe)
// Reads Unicode text from Windows clipboard and outputs UTF-8 to stdout with zero PowerShell overhead.

using System;
using System.Runtime.InteropServices;

class WinPaste {
    [DllImport("user32.dll", SetLastError = true)]
    static extern bool OpenClipboard(IntPtr hWndNewOwner);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool CloseClipboard();

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr GetClipboardData(uint uFormat);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalLock(IntPtr hMem);

    [DllImport("kernel32.dll")]
    static extern bool GlobalUnlock(IntPtr hMem);

    const uint CF_UNICODETEXT = 13;

    static void Main() {
        if (!OpenClipboard(IntPtr.Zero)) return;
        try {
            IntPtr hData = GetClipboardData(CF_UNICODETEXT);
            if (hData != IntPtr.Zero) {
                IntPtr pText = GlobalLock(hData);
                if (pText != IntPtr.Zero) {
                    try {
                        string text = Marshal.PtrToStringUni(pText);
                        if (!string.IsNullOrEmpty(text)) {
                            Console.OutputEncoding = System.Text.Encoding.UTF8;
                            Console.Write(text);
                        }
                    } finally {
                        GlobalUnlock(hData);
                    }
                }
            }
        } finally {
            CloseClipboard();
        }
    }
}
