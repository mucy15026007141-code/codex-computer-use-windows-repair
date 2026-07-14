# Security Policy

Do not file reports containing user profiles, browser data, cookies, tokens, application logs, or copied runtime files. Use a minimal redacted description, product version, and the diagnostic result.

This project intentionally avoids WindowsApps permission changes, registry edits, package tampering, and binary redistribution. Review scripts before using `-Apply`; use it only on a machine you administer. The generated report replaces the current profile path with `C:\Users\<USER>\`.

For a suspected vulnerability in these scripts, open a private security advisory on the hosting service if available. Do not attach executable artifacts.
