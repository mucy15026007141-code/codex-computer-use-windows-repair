# 排障说明

先运行 `Test-CodexComputerUseRuntime.ps1`。如果提示目标缺失，再审阅源路径、内容哈希键和关键文件校验。只有确认应用已完全退出后，才考虑 `Repair-CodexComputerUseRuntime.ps1 -Apply`。

若目标已经存在但校验失败，脚本会拒绝覆盖；请保留现场并人工分析。若路径过长，请使用支持长路径的 Windows 配置；脚本会对文件系统调用使用 `\\?\` 扩展路径。

Chrome 显示未连接属于独立问题，不要用本项目的 Computer Use 修复结果推断 Chrome 已恢复。
