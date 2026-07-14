# Codex Desktop Computer Use Runtime Repair (Windows)

[简体中文](README.zh-CN.md) | English

> Experimental tooling, proposed as **v0.1.0**.

This independent community project diagnoses and, only when explicitly requested, repairs a failed `cua_node` runtime relocation for Codex Desktop on Windows. It is **not an OpenAI official project and has no affiliation with OpenAI**.

The validated scope is Windows Computer Use only. Chrome browser integration is **not** within the verified repair scope and must not be considered restored by this project.

## Safety boundary

- Run the read-only diagnostic first; decide whether to use `-Apply` only after reviewing its result.
- The tools do not change WindowsApps permissions, `app.asar`, the registry, or official binaries.
- They do not redistribute application, runtime, Electron, Node, or WindowsApps binaries.
- A repair refuses to write while Codex, ChatGPT, or its command-line process is running.

## Tested environment

- Windows 11
- Windows PowerShell 5.1
- OpenAI.Codex 26.707.9564.0

Other versions may have a different layout. Review the diagnostic output before applying anything.

## Use

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Test-CodexComputerUseRuntime.ps1
.\scripts\Repair-CodexComputerUseRuntime.ps1
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply -ReportPath .\repair-report.json
```

`Repair-CodexComputerUseRuntime.ps1` is dry-run by default. `-Apply` stages a byte-for-byte copy on the same volume, verifies it, then atomically moves it into place. It never overwrites an incomplete existing target and leaves historical work areas untouched.

## Contents

- `scripts/`: content-key calculation, read-only inspection, and guarded repair.
- `docs/`: root cause, safety model, troubleshooting and the Chinese case study.
- `examples/`: deliberately redacted output and an illustrative layout.
- `tests/`: PowerShell/Pester static-contract checks.

See [browser integration status](docs/BROWSER-INTEGRATION-STATUS.md), [root cause](docs/ROOT-CAUSE.md), and [safety notes](docs/SAFETY.zh-CN.md).
