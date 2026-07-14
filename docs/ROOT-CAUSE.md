# Root cause

The affected desktop build expected a relocated runtime below a content-addressed directory, not merely a complete flat runtime directory. The content key is derived from three anchors: the manifest and the two launcher binaries. A complete flat copy can therefore remain unused.

WindowsApps-protected source files also made ordinary recursive copy approaches unreliable. This project uses .NET byte streams only after explicit `-Apply`, verifies every copied file, and promotes only a complete staged directory.

The earlier `ComputerUseNodeRepl` error was initially treated as a direct executable failure. Later evidence showed it was not sufficient to identify the root cause: runtime location and key selection had to be correct first.
