# 案例复盘：内容寻址 runtime relocation

## 初始症状

Computer Use runtime 不可用。WindowsApps 的复制首先失败，普通递归复制无法可靠处理受保护源文件。随后发现平铺的 `cua_node` 虽然完整，却没有被应用复用。

## 判断如何演进

应用实际要求内容哈希子目录；仅有平铺目录不能满足 runtime lookup。早期曾把 `ComputerUseNodeRepl` 错误当作直接根因，后续证据推翻了这一判断：它不足以解释为什么完整目录未被选择，目录位置和内容键才是前提。

内容键由 `manifest.json`、`bin` 下的两个启动器的相对路径与 SHA-256 计算得出。每一项以 UTF-8 的 `relativePath + NUL + lowercase(fileSha256) + NUL` 写入，再对拼接结果求 SHA-256 并取前 16 位。

## 实施陷阱

- Windows PowerShell 5.1 没有 `Path.GetRelativePath`，因此脚本实现了兼容的 URI 相对路径算法。
- 曾将 staging 放在源 `cua_node` 内部，复制时会把 staging 自身纳入枚举，产生递归风险。最终改为 runtime 根目录内的短路径。
- 深层依赖容易触及 `MAX_PATH`；文件系统访问使用 `\\?\` 扩展路径。
- 不能依赖通用递归复制；最终使用 .NET `FileStream` 逐字节复制，并在同卷 staging 完整验证后用 `Directory.Move` 提升。

## 最终验证

最终验证记录应同时包含源与目标的文件数、总字节数和内容哈希键，并逐文件比对 SHA-256。端到端验证仅证明 Windows Computer Use 能打开记事本并输入 `111`；它不证明 Chrome 浏览器集成已经恢复。公开示例刻意不包含机器专属的最终计数、字节数或哈希值，避免把安装布局和运行时指纹发布到仓库。
