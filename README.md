# Codex Desktop Computer Use Runtime Repair (Windows)

[简体中文](README.zh-CN.md) | English

> Experimental community tooling. The first release is intended to be tagged **v0.1.0**.

This project diagnoses and repairs a Windows Codex Desktop failure in which bundled resources or the `cua_node` runtime are not relocated correctly, causing Computer Use to appear unavailable or fail to control Windows.

This is **not an official OpenAI project and is not affiliated with OpenAI**.

Only Windows Computer Use has been fully repaired and verified end to end. Browser and `hatch-pet` are not within the fully validated repair scope.

## Symptoms

In the documented case, normal chat, code generation, and terminal tasks continued to work, while several features that depend on local desktop resources failed at the same time.

Initially:

- Computer Use was shown as unavailable in Settings;
- Browser was also shown as unavailable;
- `hatch-pet` could not be used normally.

After the first repair pass restored bundled plugins and base resources:

- Computer Use, Browser, and `hatch-pet` no longer appeared unavailable;
- Computer Use became visible but still could not control Windows;
- the current session still had no working Windows control channel;
- Browser still failed to connect or initialize.

After repairing the content-addressed `cua_node` runtime layout, Computer Use was fully restored and passed the following tests:

- Windows Notepad opened successfully;
- mouse control worked;
- the text `111` was entered successfully;
- the Windows control channel worked normally.

This demonstrates an important distinction:

> A plugin being visible does not mean its runtime and control channel are actually working.

## Is This the Same Failure?

The issue is a strong match if several of the following are true:

- `Settings → Computer Use` shows the plugin as unavailable;
- `Settings → Browser` also shows the plugin as unavailable;
- `hatch-pet` or several other local plugins fail at the same time;
- Computer Use is visible but cannot control Windows;
- chat and terminal tasks work, but local desktop features fail;
- `cua_node` files exist, but Codex still reports the runtime as unavailable;
- a flat `cua_node` tree exists, but the content-hash subdirectory is missing;
- logs contain `node-repl-missing`, `missingHelperPath`, `missingTransportModulePath`, or `not-ready`;
- copying resources from WindowsApps fails with `UNKNOWN`, `errno -4094`, or `os error 6000`.

Quick reference:

| Symptom | Match level |
|---|---|
| Computer Use is shown as unavailable | High |
| Browser and `hatch-pet` fail at the same time | Medium to high |
| Computer Use is visible but cannot control Windows | High |
| Chat and terminal work, but local plugins fail | Medium to high |
| Flat `cua_node` exists, but the hash directory is missing | Very high |
| Logs contain `node-repl-missing` or `missingHelperPath` | High |
| Only the Chrome extension is disconnected | Not necessarily related |
| Only `Cannot redefine property: process` appears | More likely a separate Browser issue |
| Codex cannot sign in or all online features fail | Usually unrelated |
| The issue occurs on macOS or Linux | Not supported |

Do not run the repair based only on visible symptoms. Run the read-only diagnostic first.

## Root Cause Summary

Some Codex Desktop plugins depend on local resources bundled with the application, including:

- bundled plugin files;
- `codex.exe` and `rg.exe`;
- the `cua_node` runtime;
- `node.exe` and `node_repl.exe`;
- `node_modules`;
- the Computer Use helper;
- the transport module;
- native pipe or native messaging channels.

These resources originate in the Store installation directory:

~~~text
C:\Program Files\WindowsApps\OpenAI.Codex_<VERSION>\app\resources\
~~~

Codex must deploy some of them into the current user's local application data directory.

The documented failure had two layers.

### 1. Bundled resource deployment failed

Copying resources out of WindowsApps failed, causing Computer Use, Browser, and `hatch-pet` to be shown as unavailable.

Observed errors included:

~~~text
UNKNOWN
errno -4094
os error 6000
~~~

### 2. The Computer Use runtime was not recognized

After the first repair pass, a complete `cua_node` tree existed at:

~~~text
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\
~~~

However, the tested Codex version did not reuse that flat directory.

It required the runtime to exist under a content-addressed directory:

~~~text
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\<CONTENT_HASH>\
~~~

Without the correct hash directory:

- `node.exe` and `node_repl.exe` paths may not resolve;
- the Computer Use helper and transport module may not be found;
- the native pipe may never become ready;
- the current session may not receive a Windows control channel.

Related log entries may include:

~~~text
missingHelperPath=true
missingTransportModulePath=true
node-repl-missing
computer_use_native_pipe_thread_config_skipped reason=not-ready
~~~

For the full analysis, see:

- [Root cause analysis](docs/ROOT-CAUSE.md)
- [Complete Chinese case study](docs/CASE-STUDY.zh-CN.md)

## Safety Boundary

This project separates diagnosis from repair.

### Read-only by default

Without `-Apply`, the scripts only inspect:

- the installed Codex version;
- the Store package path;
- the bundled `cua_node` source directory;
- the content hash for the current version;
- the expected runtime target directory;
- required files;
- file sizes and SHA-256 hashes;
- `node_modules`, the helper, and the transport module.

Read-only mode does not:

- copy the runtime;
- create staging directories;
- modify the target;
- delete old caches or backups;
- terminate processes;
- change system configuration.

### Explicit repair only

The script writes files only when invoked with:

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply
~~~

Before writing, it checks that Codex, ChatGPT, and `codex.exe` have fully exited. If any related process is still running, the script stops and does not forcefully terminate it.

### This project does not

- change WindowsApps permissions or ownership;
- modify `app.asar`;
- modify the registry;
- modify environment variables;
- change the Store package;
- replace official binaries;
- redistribute the Codex runtime;
- overwrite an existing target that fails validation;
- automatically remove old staging directories, runtimes, or backups;
- use a hard-coded Codex version or content hash.

## Tested Environment

The repair and end-to-end validation were completed on:

- Windows 11
- Windows PowerShell 5.1
- OpenAI.Codex 26.707.9564.0
- the Microsoft Store `OpenAI.Codex` package

Not yet validated:

- Windows 10
- Windows on ARM
- PowerShell 7
- non-Store installations
- other Codex Desktop versions
- macOS
- Linux

The scripts do not hard-code the username, version, installation path, or content hash. They detect and calculate those values from the current installation.

After a Codex update, do not reuse an old hash directory. Run the read-only diagnostic again.

## Quick Start

### 1. Download the repository

Using Git:

~~~powershell
git clone https://github.com/mucy15026007141-code/codex-computer-use-windows-repair.git
cd codex-computer-use-windows-repair
~~~

You can also download the repository as a ZIP file, extract it fully, and open PowerShell in the repository root.

### 2. Allow scripts in the current PowerShell process

~~~powershell
Set-ExecutionPolicy -Scope Process Bypass
~~~

This change applies only to the current PowerShell window and is discarded when the window closes.

### 3. Run the read-only diagnostic

~~~powershell
.\scripts\Test-CodexComputerUseRuntime.ps1
~~~

Pay particular attention to:

~~~text
TargetComplete
RecommendRepair
~~~

If the result is:

~~~text
TargetComplete=True
RecommendRepair=False
~~~

the runtime target is already complete and should not be repaired again.

### 4. Review the repair decision

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1
~~~

Without `-Apply`, this remains read-only and does not create staging directories or copy files.

### 5. Fully exit Codex and ChatGPT

Before applying the repair, exit Codex and ChatGPT from both their windows and the system tray.

Read-only process check:

~~~powershell
Get-Process ChatGPT,codex -ErrorAction SilentlyContinue
~~~

No output means the related processes have exited.

### 6. Apply the repair

Run this only when the diagnostic explicitly recommends repair:

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply
~~~

Optional redacted JSON report:

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply -ReportPath .\repair-report.json
~~~

The repair script:

- creates a short staging path on the same volume;
- copies files with `.NET FileStream`;
- supports Windows PowerShell 5.1 and long paths;
- validates file counts and total bytes;
- validates SHA-256 hashes for critical files;
- verifies `node_modules`, the helper, and the transport module;
- commits the validated target with `Directory.Move`.

Do not repeatedly rerun `-Apply` after an error. Review the full error output first.

## Verification After Repair

A successful script run only proves that the runtime was copied and validated. Computer Use must still be tested end to end.

After the repair:

1. restart Codex Desktop;
2. create a new conversation;
3. enter:

~~~text
Open Notepad and type 111
~~~

A complete success should mean:

- Codex invokes Computer Use;
- Windows Notepad opens;
- mouse and window control work;
- `111` is entered successfully;
- the session no longer reports a missing Windows control channel.

The documented successful repair produced:

~~~text
SourceFileCount      : 3558
TargetFileCount      : 3558
SourceTotalBytes     : 287463111
TargetTotalBytes     : 287463111
NodeModulesDirectory : True
CodexComputerUseExe  : True
HelperTransportJs    : True
UnhandledErrors      : False
~~~

## Current Status and Limitations

| Feature | Status |
|---|---|
| Computer Use plugin visibility | Restored |
| Computer Use Windows control | Restored and verified end to end |
| Browser plugin visibility | Restored |
| Browser connection and initialization | Not fixed |
| `hatch-pet` plugin visibility | Restored |
| Full `hatch-pet` functionality | Not verified |
| Windows PowerShell 5.1 | Verified |
| Other Codex versions | More testing required |

This project does not claim to repair every plugin problem.

Browser still has separate issues, including:

- the Chrome extension showing as disconnected;
- `Cannot redefine property: process`;
- the Chrome Web Store extension being unavailable;
- native messaging or extension initialization failures.

These should not be treated as part of the verified Computer Use repair.

This project also does not address:

- sign-in failures;
- account or workspace permissions;
- server-side feature availability;
- network or server outages;
- macOS or Linux issues.

## Documentation

- [Root cause analysis](docs/ROOT-CAUSE.md)
- [Complete Chinese case study](docs/CASE-STUDY.zh-CN.md)
- [Troubleshooting (Chinese)](docs/TROUBLESHOOTING.zh-CN.md)
- [Safety notes (Chinese)](docs/SAFETY.zh-CN.md)
- [Browser integration status](docs/BROWSER-INTEGRATION-STATUS.md)
- [Redacted successful output](examples/successful-output.redacted.txt)
- [Runtime directory layout](examples/runtime-layout.txt)

## Reporting Issues

Before opening an Issue:

1. run the read-only diagnostic;
2. do not immediately run `-Apply`;
3. remove usernames, email addresses, tokens, cookies, and personal paths;
4. do not upload the full `logs_2.sqlite`;
5. do not upload Codex, Node, Electron, or WindowsApps binaries;
6. include your Codex, Windows, and PowerShell versions;
7. explain whether the plugin is shown as unavailable or is visible but unusable.

Redacted results from other versions and devices are welcome.

## Disclaimer

This is an unofficial community tool.

Users are responsible for reviewing the diagnostic output and accepting the risks of applying the repair. The maintainers do not guarantee that this method will work on every Codex version, device, or plugin failure.
