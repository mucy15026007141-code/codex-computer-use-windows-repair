# Codex Desktop Computer Use Runtime Repair（Windows）

简体中文 | [English](README.md)

> 实验性工具，建议首个版本标记为 **v0.1.0**。

这是一个独立的社区项目，用于诊断并在明确授权后最小化修复 Windows 上 Codex Desktop 的 `cua_node` runtime relocation 失败。它**不是 OpenAI 官方项目，与 OpenAI 无隶属关系**。

当前仅验证 Windows Computer Use。Chrome 浏览器集成**不在已验证修复范围内**，不能据此宣称浏览器功能已经恢复。

## 安全边界

- 请先运行只读诊断；阅读结果后再决定是否显式使用 `-Apply`。
- 工具不会修改 WindowsApps 权限、`app.asar`、注册表或官方二进制。
- 仓库不包含、不重新分发应用、runtime、Electron、Node 或 WindowsApps 二进制。
- Codex、ChatGPT 或其命令行进程运行时，修复脚本会拒绝写入。

## 已测试环境

- Windows 11
- Windows PowerShell 5.1
- OpenAI.Codex 26.707.9564.0

其他版本的目录布局可能不同；应用修复前请人工确认诊断输出。

## 使用方式

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Test-CodexComputerUseRuntime.ps1
.\scripts\Repair-CodexComputerUseRuntime.ps1
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply -ReportPath .\repair-report.json
```

`Repair-CodexComputerUseRuntime.ps1` 默认 dry-run。只有 `-Apply` 会执行同卷 staging、逐字节验证和 `Directory.Move`；它不会覆盖不完整目标，也不会删除旧的工作目录或平铺 runtime。

详见[浏览器集成状态](docs/BROWSER-INTEGRATION-STATUS.md)、[根因](docs/ROOT-CAUSE.md)与[安全说明](docs/SAFETY.zh-CN.md)。
