# Codex Desktop Computer Use Runtime Repair（Windows）

简体中文 | [English](README.md)

> 实验性社区工具，建议首个版本标记为 **v0.1.0**。

用于诊断和修复 Windows 版 Codex Desktop 因 bundled resources 或 `cua_node` runtime relocation 失败，导致 Computer Use 插件不可用或无法控制 Windows 的问题。

本项目**不是 OpenAI 官方项目，与 OpenAI 无隶属关系**。

目前仅对 Windows Computer Use 完成了端到端修复验证。Browser 和 `hatch-pet` 不在已验证的完整修复范围内。

## 问题表现

在本次实际案例中，Codex 的普通聊天、代码生成和终端功能正常，但多个依赖本地资源的插件同时异常。

最初在设置页面中：

- Computer Use 直接显示插件不可用；
- Browser 直接显示插件不可用；
- `hatch-pet` 无法正常使用。

第一轮修复 bundled plugin 和基础资源后：

- Computer Use、Browser 和 `hatch-pet` 不再显示插件不可用；
- Computer Use 已经可见，但仍无法控制 Windows；
- 当前会话仍没有可用的 Windows 控制通道；
- Browser 仍无法完成连接和初始化。

继续修复 `cua_node` 的内容哈希缓存布局后，Computer Use 最终恢复，并通过了以下测试：

- 成功打开 Windows 记事本；
- 成功控制鼠标；
- 成功输入 `111`；
- Windows 控制通道正常工作。

这说明：

> 插件显示可用，不代表底层 runtime 和控制通道已经正常。

## 是否可能属于同一种故障

匹配度较高的情况包括：

- `设置 → Computer Use` 直接显示插件不可用；
- `设置 → Browser` 同样显示插件不可用；
- `hatch-pet` 等多个本地插件同时异常；
- Computer Use 已经显示，但无法控制 Windows；
- 普通聊天和终端正常，只有本地交互插件异常；
- `cua_node` 文件存在，但 Codex 仍报告 runtime 不可用；
- 平铺 `cua_node` 完整，但缺少内容哈希子目录；
- 日志出现 `node-repl-missing`、`missingHelperPath`、`missingTransportModulePath` 或 `not-ready`；
- 从 WindowsApps 复制资源时出现 `UNKNOWN`、`errno -4094` 或 `os error 6000`。

快速判断：

| 现象 | 匹配程度 |
|---|---|
| Computer Use 页面直接显示插件不可用 | 高 |
| Browser 和 `hatch-pet` 同时异常 | 较高 |
| Computer Use 可见但无法控制 Windows | 高 |
| 普通对话正常，仅本地插件异常 | 较高 |
| 平铺 `cua_node` 完整，但哈希目录缺失 | 很高 |
| 日志出现 `node-repl-missing` 或 `missingHelperPath` | 高 |
| 只有 Chrome 扩展显示未连接 | 不一定匹配 |
| 只有 `Cannot redefine property: process` | 更像 Browser 独立问题 |
| Codex 无法登录或所有联网功能异常 | 通常不匹配 |
| macOS 或 Linux 上的问题 | 不适用 |

不要只根据界面现象直接运行修复。请先执行只读诊断。

## 根因概要

Codex Desktop 的部分插件依赖随应用安装的本地资源，包括：

- bundled plugin 文件；
- `codex.exe`、`rg.exe`；
- `cua_node` runtime；
- `node.exe`、`node_repl.exe`；
- `node_modules`；
- Computer Use helper；
- transport 模块；
- native pipe 或 native messaging 通道。

这些资源最初位于 Store 安装目录中：

~~~text
C:\Program Files\WindowsApps\OpenAI.Codex_<VERSION>\app\resources\
~~~

Codex 启动后，需要把部分资源部署到当前用户目录。

本次故障包含两个层级。

### 1. bundled resources 部署失败

从 WindowsApps 复制资源时出现失败，导致 Computer Use、Browser 和 `hatch-pet` 在设置页面中直接显示插件不可用。

相关错误曾包括：

~~~text
UNKNOWN
errno -4094
os error 6000
~~~

### 2. Computer Use runtime 未被正确识别

第一轮修复后，完整的 `cua_node` 虽然已经存在于：

~~~text
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\
~~~

但当前已验证版本不会直接复用这个平铺目录。

应用要求 runtime 位于按内容哈希命名的目录中：

~~~text
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\<CONTENT_HASH>\
~~~

缺少正确的哈希目录时，可能导致：

- `node.exe` 和 `node_repl.exe` 路径无法解析；
- Computer Use helper 和 transport 模块无法定位；
- native pipe 无法进入 ready 状态；
- 当前会话无法获得 Windows 控制通道。

相关日志可能包括：

~~~text
missingHelperPath=true
missingTransportModulePath=true
node-repl-missing
computer_use_native_pipe_thread_config_skipped reason=not-ready
~~~

详细分析见：

- [根因分析](docs/ROOT-CAUSE.md)
- [完整中文修复复盘](docs/CASE-STUDY.zh-CN.md)

## 安全边界

本项目将诊断和修复明确分开。

### 默认只读

不传入 `-Apply` 时，脚本只会检查：

- 当前 Codex 版本；
- Store 包路径；
- bundled `cua_node` 源目录；
- 当前版本对应的内容哈希；
- 正式 runtime 目标目录；
- 关键文件是否存在；
- 文件大小和 SHA-256 是否匹配；
- `node_modules`、helper 和 transport 模块是否存在。

默认模式不会：

- 复制 runtime；
- 创建 staging；
- 修改正式目标；
- 删除旧缓存或备份；
- 结束任何进程；
- 修改系统配置。

### 显式修复

只有传入：

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply
~~~

脚本才会写入。

执行前会检查 Codex、ChatGPT 和 `codex.exe` 是否已经完全退出。若仍有相关进程运行，脚本会停止，不会强制结束进程。

### 本项目不会执行

- 修改 WindowsApps 权限或所有权；
- 修改 `app.asar`；
- 修改注册表；
- 修改环境变量；
- 修改 Store 安装包；
- 替换官方二进制；
- 从仓库分发 Codex runtime；
- 覆盖已存在但验证不完整的正式目标；
- 自动删除旧 staging、旧 runtime 或备份；
- 使用固定版本号或固定哈希执行修复。

## 已测试环境

已完成真实修复和端到端验证的环境：

- Windows 11
- Windows PowerShell 5.1
- OpenAI.Codex 26.707.9564.0
- Microsoft Store 安装的 `OpenAI.Codex`

尚未完成验证：

- Windows 10
- Windows on ARM
- PowerShell 7
- 非 Microsoft Store 安装版本
- 其他 Codex Desktop 版本
- macOS
- Linux

脚本不会硬编码用户名、版本号、安装目录或内容哈希，而是根据当前安装版本动态检测和计算。

Codex 更新后，不要直接复用旧版本哈希目录。应重新运行只读诊断。

## 快速开始

### 1. 下载仓库

使用 Git：

~~~powershell
git clone https://github.com/mucy15026007141-code/codex-computer-use-windows-repair.git
cd codex-computer-use-windows-repair
~~~

也可以下载 ZIP，完整解压后在仓库根目录打开 PowerShell。

### 2. 设置当前 PowerShell 窗口的执行策略

~~~powershell
Set-ExecutionPolicy -Scope Process Bypass
~~~

该设置只对当前 PowerShell 窗口生效，关闭窗口后自动失效。

### 3. 运行只读诊断

~~~powershell
.\scripts\Test-CodexComputerUseRuntime.ps1
~~~

重点关注：

~~~text
TargetComplete
RecommendRepair
~~~

如果结果为：

~~~text
TargetComplete=True
RecommendRepair=False
~~~

说明正式 runtime 已经完整，不需要修复。

### 4. 查看修复判断

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1
~~~

不传入 `-Apply` 时仍然只读，不会创建 staging 或复制文件。

### 5. 完全退出 Codex 和 ChatGPT

执行修复前，请从窗口和系统托盘中完全退出 Codex 与 ChatGPT。

只读确认：

~~~powershell
Get-Process ChatGPT,codex -ErrorAction SilentlyContinue
~~~

没有输出表示相关进程已经退出。

### 6. 执行修复

只有诊断明确建议修复时，再运行：

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply
~~~

可选生成脱敏 JSON 报告：

~~~powershell
.\scripts\Repair-CodexComputerUseRuntime.ps1 -Apply -ReportPath .\repair-report.json
~~~

脚本会：

- 创建同卷短路径 staging；
- 使用 `.NET FileStream` 逐文件复制；
- 支持 Windows PowerShell 5.1 和长路径；
- 校验文件数量和总字节数；
- 校验关键文件 SHA-256；
- 检查 `node_modules`、helper 和 transport 模块；
- 验证通过后使用 `Directory.Move` 提交正式目标。

遇到错误时不要连续重复运行 `-Apply`。

## 修复后验证

脚本成功只代表 runtime 复制和校验完成，还需要验证 Computer Use 是否真正恢复。

修复完成后：

1. 重新启动 Codex Desktop；
2. 新建一个对话；
3. 输入：

~~~text
打开记事本并输入 111
~~~

完整成功应表现为：

- Codex 成功调用 Computer Use；
- Windows 记事本被打开；
- 鼠标和窗口控制正常；
- `111` 被成功输入；
- 当前会话不再提示缺少 Windows 控制通道。

本项目的实际修复结果包括：

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

## 当前状态与限制

| 功能 | 状态 |
|---|---|
| Computer Use 插件可见性 | 已恢复 |
| Computer Use Windows 控制 | 已恢复并完成端到端验证 |
| Browser 插件可见性 | 已恢复 |
| Browser 连接与初始化 | 尚未修复 |
| `hatch-pet` 插件可见性 | 已恢复 |
| `hatch-pet` 完整功能 | 尚未验证 |
| Windows PowerShell 5.1 | 已验证 |
| 其他 Codex 版本 | 尚待测试 |

本项目不能保证修复所有插件问题。

Browser 仍存在独立问题，例如：

- Chrome 扩展显示未连接；
- `Cannot redefine property: process`；
- Chrome 商店扩展无法下载；
- native messaging 或扩展初始化异常。

这些问题不应与 Computer Use 的修复结果混为一谈。

本项目也不处理：

- 登录失败；
- 账户或工作区权限问题；
- 服务端未开放功能；
- 网络或服务器故障；
- macOS 或 Linux 问题。

## 详细文档

- [根因分析](docs/ROOT-CAUSE.md)
- [完整中文修复复盘](docs/CASE-STUDY.zh-CN.md)
- [故障排查](docs/TROUBLESHOOTING.zh-CN.md)
- [安全说明](docs/SAFETY.zh-CN.md)
- [浏览器集成状态](docs/BROWSER-INTEGRATION-STATUS.md)
- [成功输出示例](examples/successful-output.redacted.txt)
- [runtime 目录结构](examples/runtime-layout.txt)
- [更新日志](CHANGELOG.md)

## 提交反馈

提交 Issue 前，请：

1. 先运行只读诊断；
2. 不要直接运行 `-Apply`；
3. 删除用户名、邮箱、Token、Cookie 和个人路径；
4. 不要上传完整 `logs_2.sqlite`；
5. 不要上传 Codex、Node、Electron 或 WindowsApps 二进制；
6. 说明 Codex、Windows 和 PowerShell 版本；
7. 说明插件是“显示不可用”还是“可见但不能使用”。

欢迎提交其他版本和设备的脱敏测试结果。

请使用 [Bug Report 模板](https://github.com/mucy15026007141-code/codex-computer-use-windows-repair/issues/new/choose) 提交脱敏后的反馈。

## 免责声明

本项目是非官方社区工具。

使用者应自行判断诊断结果，并承担执行修复的风险。项目维护者不保证该方法适用于所有 Codex 版本、所有设备或所有插件问题。
