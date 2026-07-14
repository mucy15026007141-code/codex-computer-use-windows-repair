# 安全说明

默认模式只读。`-Apply` 是唯一写入开关，且在检测到 Codex、ChatGPT 或命令行进程运行时终止。修复只在用户可写的 runtime 根目录创建新的短 staging 路径；不会修改 WindowsApps、权限、注册表、`app.asar` 或官方文件。

脚本不清理历史 staging、备份或平铺 runtime。存在且完整的目标保持不变；存在但不完整的目标也不覆盖。可选报告只输出脱敏 JSON，不包含浏览器数据、Cookie、令牌或应用日志。
