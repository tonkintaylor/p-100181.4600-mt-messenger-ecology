// MtMessengerPipeline.Launcher.cs
//
// Tiny GUI-subsystem launcher compiled to MtMessengerPipeline.exe at build time
// (see tasks\build_launcher.ps1 -> Add-LauncherExe). Its job: start the
// WinForms PowerShell launcher (launcher.ps1) with NO console window, and carry
// the app icon so the Start-menu shortcut and taskbar show the app — not
// powershell.exe.
//
// Built with: csc /target:winexe /win32icon:app.ico /reference:System.Windows.Forms.dll
//   - /target:winexe  -> Windows (GUI) subsystem, so launching it never spawns
//                        a console window.
//   - launches powershell with CreateNoWindow + Hidden so PowerShell (a console
//     app) gets no console either; the only window is the WinForms form.

using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace MtMessenger
{
    internal static class Launcher
    {
        [STAThread]
        private static void Main()
        {
            try
            {
                string dir = AppDomain.CurrentDomain.BaseDirectory;
                string script = Path.Combine(dir, "launcher.ps1");
                if (!File.Exists(script))
                {
                    Fail("Launcher script not found:\n" + script);
                    return;
                }

                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"",
                    WorkingDirectory = dir,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
                // The launcher runs independently; this stub exits immediately.
            }
            catch (Exception ex)
            {
                Fail("Could not start the launcher:\n\n" + ex.Message);
            }
        }

        private static void Fail(string message)
        {
            MessageBox.Show(message, "Mt Messenger Ecology Pipeline",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
