#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# 有完整 Xcode 用 Xcode；只有 Command Line Tools 的机器回退到默认工具链
DEFAULT_DEV_DIR="/Applications/Xcode.app/Contents/Developer"
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "$DEFAULT_DEV_DIR" ]; then
  export DEVELOPER_DIR="$DEFAULT_DEV_DIR"
fi
# GLM / Kimi Coding Plan mapper 行为测试：窗口分类、字符串数字解码、
# 微秒 ISO8601 解析、回退链（limits → 顶层 usage → booster_wallet）、百分比钳制。
# fixture 来自 2026-09-23 端点实测响应（脱敏）。
swiftc -swift-version 5 \
    AgentRing/Models/GlmUsageData.swift \
    AgentRing/Models/KimiUsageData.swift \
    Tests/CodingPlanMapperChecks.swift -o /tmp/agentring-coding-plan-mapper-checks
/tmp/agentring-coding-plan-mapper-checks
rm /tmp/agentring-coding-plan-mapper-checks
