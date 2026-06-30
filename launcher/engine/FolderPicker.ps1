# FolderPicker.ps1 — modern (Explorer-style) folder browser.
#
# Windows PowerShell 5.1's System.Windows.Forms.FolderBrowserDialog always shows
# the dated tree-view picker. The modern folder browser is the shell
# IFileOpenDialog with the FOS_PICKFOLDERS option — same dialog Explorer uses
# (address bar, Quick Access, search, resizable). We reach it via a tiny COM
# interop type compiled on first use, and fall back to the legacy dialog if the
# interop is unavailable for any reason.

$script:FolderPickerCs = @'
using System;
using System.IO;
using System.Runtime.InteropServices;

namespace MtMessenger
{
    public static class FolderPicker
    {
        // Returns the selected folder path, or null if the user cancelled.
        public static string Show(IntPtr owner, string title, string initialPath)
        {
            IFileDialog dlg = (IFileDialog)(new FileOpenDialogRCW());
            try
            {
                uint opts;
                dlg.GetOptions(out opts);
                dlg.SetOptions(opts | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
                if (!string.IsNullOrEmpty(title)) dlg.SetTitle(title);
                if (!string.IsNullOrEmpty(initialPath) && Directory.Exists(initialPath))
                {
                    IShellItem si;
                    Guid g = typeof(IShellItem).GUID;
                    if (SHCreateItemFromParsingName(initialPath, IntPtr.Zero, ref g, out si) == 0 && si != null)
                        dlg.SetFolder(si);
                }
                int hr = dlg.Show(owner);
                if (hr != 0) return null; // non-S_OK => cancelled
                IShellItem result;
                dlg.GetResult(out result);
                string path;
                result.GetDisplayName(SIGDN_FILESYSPATH, out path);
                Marshal.ReleaseComObject(result);
                return path;
            }
            finally
            {
                Marshal.ReleaseComObject(dlg);
            }
        }

        const uint FOS_PICKFOLDERS = 0x20, FOS_FORCEFILESYSTEM = 0x40, FOS_PATHMUSTEXIST = 0x800;
        const uint SIGDN_FILESYSPATH = 0x80058000;

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        static extern int SHCreateItemFromParsingName(string pszPath, IntPtr pbc, ref Guid riid, out IShellItem ppv);

        [ComImport, Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7")]
        class FileOpenDialogRCW { }

        [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IShellItem
        {
            void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
            void GetParent(out IShellItem ppsi);
            void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
            void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
            void Compare(IShellItem psi, uint hint, out int piOrder);
        }

        // IFileDialog (IID), with the inherited IModalWindow.Show first so the
        // vtable order is correct. Only the methods we call have real
        // signatures; the rest hold their slots.
        [ComImport, Guid("42f85136-db7e-439c-85f1-e4075d135fc8"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IFileDialog
        {
            [PreserveSig] int Show(IntPtr parent);                 // IModalWindow
            void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
            void SetFileTypeIndex(uint iFileType);
            void GetFileTypeIndex(out uint piFileType);
            void Advise(IntPtr pfde, out uint pdwCookie);
            void Unadvise(uint dwCookie);
            void SetOptions(uint fos);
            void GetOptions(out uint pfos);
            void SetDefaultFolder(IShellItem psi);
            void SetFolder(IShellItem psi);
            void GetFolder(out IShellItem ppsi);
            void GetCurrentSelection(out IShellItem ppsi);
            void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
            void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
            void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
            void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
            void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
            void GetResult(out IShellItem ppsi);
            void AddPlace(IShellItem psi, int fdap);
            void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
            void Close(int hr);
            void SetClientGuid(ref Guid guid);
            void ClearClientData();
            void SetFilter(IntPtr pFilter);
        }
    }
}
'@

# Compile the interop on first use. Returns $true if the modern picker is usable.
function Initialize-FolderPicker {
    if (([System.Management.Automation.PSTypeName]'MtMessenger.FolderPicker').Type) { return $true }
    try {
        Add-Type -TypeDefinition $script:FolderPickerCs -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Show the modern Explorer-style folder picker; fall back to the legacy dialog.
# Returns the selected path, or $null if cancelled.
function Show-FolderPicker {
    param(
        [string]$Title = 'Select folder',
        [string]$InitialPath = '',
        [System.IntPtr]$Owner = [System.IntPtr]::Zero
    )
    if (Initialize-FolderPicker) {
        try {
            return [MtMessenger.FolderPicker]::Show($Owner, $Title, $InitialPath)
        } catch {
            # Fall through to the legacy dialog on any runtime failure.
        }
    }
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($InitialPath -and (Test-Path -LiteralPath $InitialPath)) { $d.SelectedPath = $InitialPath }
    if ($d.ShowDialog() -eq 'OK') { return $d.SelectedPath }
    return $null
}
