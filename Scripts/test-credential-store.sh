#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# 有完整 Xcode 用 Xcode；只有 Command Line Tools 的机器回退到默认工具链
DEFAULT_DEV_DIR="/Applications/Xcode.app/Contents/Developer"
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "$DEFAULT_DEV_DIR" ]; then
  export DEVELOPER_DIR="$DEFAULT_DEV_DIR"
fi
# 行为测试加密凭据存储（Release 模式的凭据载体）：加密往返、密钥 0600、
# 排除备份标记、模拟版本更新后可读、篡改拒绝、密钥丢失回退。
swiftc -swift-version 5 \
    AgentRing/Services/EncryptedCredentialStore.swift \
    Tests/CredentialStoreChecks.swift -o /tmp/agentring-credential-store-checks
/tmp/agentring-credential-store-checks
rm /tmp/agentring-credential-store-checks
