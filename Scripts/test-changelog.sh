#!/bin/bash
# 校验 changelog 生成脚本逻辑
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/Scripts/generate-changelog.swift"

# 显式传 repo slug（第 4 个参数）：否则脚本会优先读 GITHUB_REPOSITORY，
# 在 fork 仓库的 CI 里是 <fork-owner>/agentRing，下面的 compare 链接断言就会误报。
UPSTREAM_REPO="haorui-lab/agentRing"

OUTPUT=$(swift "$SCRIPT" v0.1.7 v0.1.8 "" "$UPSTREAM_REPO")

# 1. 必须包含 fix(auth)
if ! grep -q "fix(auth)" <<< "$OUTPUT"; then
    echo "FAIL: changelog missing fix(auth)"
    exit 1
fi
echo "PASS: contains fix(auth)"

# 2. 必须过滤掉 chore(release) 版本号噪音
if grep -q "chore(release): v0.1.8" <<< "$OUTPUT"; then
    echo "FAIL: changelog should filter chore(release)"
    exit 1
fi
echo "PASS: filtered chore(release) bump"

# 3. 必须包含 Full Changelog 对比链接
if ! grep -Fq "https://github.com/haorui-lab/agentRing/compare/v0.1.7...v0.1.8" <<< "$OUTPUT"; then
    echo "FAIL: changelog missing compare link"
    exit 1
fi
echo "PASS: contains compare link"

# 4. 必须拼接安装说明
if ! grep -q "安装与升级说明" <<< "$OUTPUT"; then
    echo "FAIL: changelog missing installation notes"
    exit 1
fi
echo "PASS: contains installation notes"

# 5. 测试 chore(skill) 保留（v0.1.6 到 v0.1.7 之间含 chore(skill)）
OUTPUT_SKILL=$(swift "$SCRIPT" v0.1.6 v0.1.7 "" "$UPSTREAM_REPO")
if ! grep -q "chore(skill)" <<< "$OUTPUT_SKILL"; then
    echo "FAIL: changelog should keep meaningful chore(skill)"
    exit 1
fi
echo "PASS: kept meaningful chore(skill)"

# 6. 不存在的 tag 必须非零退出（防止静默生成空 changelog 发布）
if swift "$SCRIPT" v9.9.9 HEAD > /dev/null 2>&1; then
    echo "FAIL: nonexistent tag should fail loudly"
    exit 1
fi
echo "PASS: nonexistent tag fails loudly"

echo "All changelog generator checks passed."
