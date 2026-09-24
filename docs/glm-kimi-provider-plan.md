# Agent Ring 支持 GLM / Kimi Coding Plan — 调研与改造方案

> 状态:**已实施(AIbot 二轮 review 已修复,CI 通过)** · 版本:v3.1 · 日期:2026-09-24
> 实施记录见「六、实施检查清单」末尾。

---

## 一、调研结论

### 1.1 Agent Ring 项目原理(纠正一个前提)
Agent Ring **不是驱动 coding agent 的工具**,而是 macOS 菜单栏的 AI 套餐用量圆环监控器(Swift/SwiftUI,单 target,Xcode 文件系统同步组——新 .swift 文件放进 `AgentRing/` 自动纳入编译)。当前支持 Codex、Cursor、Antigravity 三个 provider(没有 Claude)。

每个 provider 是一条手接线的竖直链路,无 registry 抽象:

```
ProviderType(enum,穷举 switch)
  → XxxAPIService(URLSession 拉配额 API)
  → XxxUsageData(模型 + mapper)
  → DataRefreshManager(定时刷新扇出、@Published)
  → MenuBarManager(数据镜像、菜单栏圆环渲染)
  → UI(弹窗列 UsageDetailView、账号管理 AuthSettingsView)
  → KeychainManager / EncryptedCredentialStore(多账号)
  → NotificationManager、BluetoothPayload(伴侣屏推送)
```

Swift 穷举 switch 意味着新增 `ProviderType` case 后,编译器会强制指出所有需要修改的位置。新增一个 provider ≈ 3~4 个新文件 + 约 19 处既有文件编辑(参照最简单的 Cursor:`AgentRing/Services/CursorAPIService.swift` 仅 169 行)。

### 1.2 claude-hud 原理(jarrodwatts/claude-hud,28k stars)
Claude Code statusline 插件:从 stdin JSON 读上下文,原生用量来自 `rate_limits` 字段(**仅 Anthropic 官方后端发射**)。API-key 后端(GLM/Kimi)不发射,官方逃生口是 `display.externalUsagePath`——从本地快照 JSON 读 5h/7d 配额。用户现有 `~/.claude/claude-hud-glm-usage-setup.md` + launchd feeder 走的就是这条路(GLM 已通,Kimi 未接)。

### 1.3 cc-switch 原理(farion1231/cc-switch,134k stars)
Tauri 2(Rust+React)桌面应用,SSOT 是 SQLite(`~/.cc-switch/cc-switch.db`),切换供应商 = 原子写各 CLI 配置文件(`~/.claude/settings.json` 的 `env` 等)。用户当前 Claude 后端被切在 **Kimi**(`https://api.kimi.com/coding/`,token `sk-kimi-*`),之前是 GLM。

### 1.4 数据源端点(方案核心依据)

| | GLM Coding Plan | Kimi Coding Plan |
|---|---|---|
| 端点 | `GET https://bigmodel.cn/api/monitor/usage/quota/limit` | `GET https://api.kimi.com/coding/v1/usages` |
| 认证 | `Authorization: Bearer <智谱 API Key>` | `Authorization: Bearer <sk-kimi-*>` |
| 响应 | `{code, data:{limits:[{type:"TOKENS_LIMIT", unit, number, percentage(已用%), nextResetTime(ms epoch)}…], level}}`;5h=unit3/number5,7d=unit6/number1,**按 nextResetTime 排序识别最稳** | `{usage:{limit,used,remaining,resetTime}, limits:[{window:{duration,timeUnit}, detail:{…}}]}`;5h=duration 300、weekly=10080(分钟) |
| 依据 | 用户 feeder 脚本长期运行验证 | 社区配额面板 dsh-quota-panel + Kimi CLI `/usage` 交叉印证 |

两者都是「双窗口(5h/7d)已用百分比 + 重置时间」,与现有 **Codex 的 5h+weekly 双环同构** → UI 模式照抄 Codex 列;认证比 Cursor 更简单(纯粘贴 API Key,无网页登录,无需 WebLogin 组件)。

## 二、已确认决策(2026-09-23,用户)

| # | 决策点 | 结论 |
|---|---|---|
| D1 | API Key 录入 | 手动粘贴 + 「从 Claude Code 当前配置导入」按钮(读 `~/.claude/settings.json` 按 base URL 识别预填) |
| D2 | 端点范围 | 仅国内:`bigmodel.cn` + `api.kimi.com`(硬编码,与现有惯例一致) |
| D3 | 实施范围 | **先做本体**(菜单栏+弹窗+多账号),蓝牙推送/阈值通知二期补(留编译桩) |
| D4 | claude-hud 联动 | 不做,专注 Agent Ring 本身 |

## 三、改造方案

### Step 0:实测端点(实施第一步,事实核验)
- 用本地 token curl 两个端点,确认字段确切类型(Kimi `resetTime` 格式、`used` 可靠性;GLM schema 复核)。
- 实测响应存为测试 fixture(脱敏)。
- **状态:见「四、事实核验记录」**

### Step 1:GLM provider 全链路
**新文件 3 个:**
1. `AgentRing/Models/GlmUsageData.swift` — 响应 Codable + `GlmUsageData{primary/secondary: LimitData?, planLevel}`(字段命名对齐 Codex);mapper 按 nextResetTime 升序取 TOKENS_LIMIT 首尾两条,percentage 钳 0–100,ms→Date
2. `AgentRing/Services/GlmAPIService.swift` — 照 CursorAPIService 骨架;`fetchUsage` + `validateApiKey`(调用量端点);`code!=200`/401 → `.unauthorized`;含 `debugModeEnabled` mock 分支(A5)
3. `AgentRing/Views/Components/GlmColumnView.swift` — 照 CursorColumnView(~70 行):ActivityRingView 外环=5h、内环=7d + UnifiedLimitRow

**编辑约 17 个文件(GLM 部分):**
- `ProviderType.swift`:case `glm` + displayName `"GLM"`(A9)
- `UserSettings.swift`:LimitType 加 `glmPrimary/glmSecondary`(对齐 `codexPrimary/codexSecondary` 惯例,行标签复用 `L.DetailRow.fiveHour/sevenDay`,无新增行级 i18n 键);`glmAccounts/currentGlmAccountId/glmApiKey/hasValidGlmCredentials`;add/remove/switch/update 账号(发 `.accountChanged`);`getActiveGlmDisplayTypes`;`orderedActiveProviders`/`hasAnyValidCredentials` 覆盖
- `KeychainManager.swift`:save/load/deleteGlmAccounts + migratableAccountKeys 加 `"accounts_glm"`
- `DataRefreshManager.swift`:service、@Published 数据、needsRelogin(Key 失效态)、shouldFetch/fetch/processSuccess/clear/mark、smart-monitoring 利用率上报、handleAccountChanged/handleManualRefresh
- `MenuBarManager.swift`:published 镜像 + Combine 绑定、popover 宽度档位扩展(现 4+:1020,需为 5/6 个 provider 加档)、`maxRowsPerProvider` 数组扩容、MenuAction 加 `glmKeyInvalid`(点击打开设置 Auth 页,而非 web 登录)
- `MenuBarUI.swift` / `MenuBarIconRenderer.swift`:图标缓存 key、`buildGlmCluster`、品牌图标 case
- `UsageDetailView.swift`:bindings、列 switch、errorState
- `UsageRowComponents.swift`:UnifiedLimitRow 加 glmData 参数 + 穷举 switch
- `ColorScheme.swift`:GLM 智谱蓝主环(≈#3E5FFB)/深蓝内环(A8)
- `AuthSettingsView.swift`:picker 加 "GLM" + 账号卡(`providerAccountsCard` 通用组件,tokenLabel="API Key")+ 删除路由;账号卡显示账号标识(GLM=level、Kimi=userId 尾号,刷新时更新);添加流程按 A2:粘贴即验证、失败标红但可保存
- `ImageHelper.swift`:`createGlmIcon` 品牌方块
- `LocalizationHelper.swift` + `en.lproj`/`zh-Hans.lproj` Localizable.strings:约 12 键/provider
- **一期留桩点**:`BluetoothPayload.swift` buildPayload switch 加 case 返回 nil(TODO 二期,不改 JSON schema,老固件无感)、`NotificationManager.swift`/`DiagnosticsView.swift` 的 ProviderType switch 加桩 case
- 新 helper `AgentRing/Helpers/ClaudeConfigImporter.swift`:一键导入——读 `~/.claude/settings.json`,按 `env.ANTHROPIC_BASE_URL` 前缀识别(`open.bigmodel.cn`/`bigmodel.cn`→GLM、`api.kimi.com`→Kimi),预填 token;不匹配则提示

### Step 2:Kimi provider 全链路(照抄 Step 1 模式)
- `KimiUsageData.swift`:mapper 主路径 `limits[]`(duration=300→5h)回退顶层 `usage`(weekly);percentage = used/limit;**数字为字符串需 FlexibleNumber,resetTime 为带微秒 ISO8601**;`booster_wallet.usages` 作交叉校验备选;accountIdentifier 用响应内 `userId`
- `KimiAPIService.swift`(同含 mock 分支)、`KimiColumnView.swift`、全部同款编辑(case `kimi` + displayName `"Kimi"`、LimitType `kimiPrimary/kimiSecondary`、keychain key `"accounts_kimi"`、Kimi 月紫 ≈#7D5FFF 配色、图标);**booster_wallet 不展示**(A10)

### Step 3:测试与收尾
- 新增 `Tests/CodingPlanMapperChecks.swift` + `Scripts/test-coding-plan-mapper.sh`(照 test-credential-store.sh 模式:swiftc 独立编译 mapper + fixture 断言)
- `xcodebuild build -scheme AgentRing` 验证;跑全部 `Scripts/test-*.sh`
- README/README_EN provider 列表补 GLM、Kimi

### 关键设计点
- **多账号与去重**:Kimi 用响应内 `userId` 作 accountIdentifier;GLM 响应无账号标识,用 key 指纹(前 8 位);账号名靠 alias 手填
- **账号添加体验(A2)**:粘贴即验证(调用量端点);成功自动回填账号标识(GLM level / Kimi userId 尾号)作默认 alias;失败标红提示但**允许保存**,坏 key 由刷新时的失效态暴露
- **档位展示(A4)**:GLM `level` 仅在设置页账号卡显示(随 processGlmSuccess 更新),弹窗列不显示
- **Key 失效处理**:复用 needsRelogin UI 样式,文案改「API Key 失效」,动作=打开设置页重新粘贴/导入
- **GLM 的 TIME_LIMIT(MCP 月配额)忽略**,只取 TOKENS_LIMIT
- **不做大重构**(不引入 registry/字典化参数):保持与现有 provider 接线惯例一致,编译器穷举 switch 兜底防漏改

### 实施方式(A3/A7)
- **单 commit 一次到位**(用户选定;实施中仍按 Step 0→3 顺序逐步自验——每步 xcodebuild 编译、跑测试脚本——全部通过后合并为一次提交)
- 本文档在实施完成后精简更新为 docs/「新增 provider 集成指南」存档,供后续 provider 参照

### 二期(本次不做,桩已留)
蓝牙伴侣屏推送(pushPayload 签名扩参 + payload builder + `docs/BLUETOOTH_PROTOCOL.md`)、阈值通知、国际版端点(z.ai / moonshot.ai)。

### 风险
- Kimi 端点字段类型此前未经实测 → 见「四、事实核验记录」
- cc-switch 切换会更换 `settings.json` 里的 token:已粘贴的 key 可能失效 — 一键导入按钮即为此设计的快速刷新入口

## 四、事实核验记录

| 事实 | 状态 | 结论 |
|---|---|---|
| Kimi `GET /coding/v1/usages` 实测 | ✅ 2026-09-23,HTTP 200 | 见 4.1 |
| GLM `GET /api/monitor/usage/quota/limit` 实测 | ✅ 2026-09-23,HTTP 200 | 见 4.2 |
| Codex 双环模型同构确认 | ✅ 已核 | 见 4.3 |

### 4.1 Kimi 端点实测(脱敏样例)

```json
{
  "usage": { "limit": "100", "used": "59", "remaining": "41",
             "resetTime": "2026-09-25T06:04:48.581180Z" },
  "limits": [
    { "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
      "detail": { "limit": "100", "used": "7", "remaining": "93",
                  "resetTime": "2026-09-23T04:04:48.581180Z" } }
  ],
  "booster_wallet": { "userId": "cuu5***",
    "usages": {
      "limit_5h": { "used_ratio": 0.069053, "reset_time": "2026-09-23T04:04:47Z" },
      "limit_7d": { "used_ratio": 0.592841, "reset_time": "2026-09-25T06:04:47Z" } } }
}
```

对实现的影响:
- **数字全部是字符串** → Codable 必须走 FlexibleNumber(String/Double/Int)解码
- **resetTime 为带微秒的 ISO8601** → 需要 `fractionalSeconds` 的 ISO8601DateFormatter
- `limits[]` 实测只有 **5h 一条**(duration=300);weekly 无独立条目,回退顶层 `usage`(其 resetTime 与 7d 对齐)— 与 dsh 面板"weekly 回退顶层 usage"的说法吻合
- **备选路径**:`booster_wallet.usages` 直接给出 `limit_5h`/`limit_7d` 的 `used_ratio`(0–1 小数)+ `reset_time`,字段最规整;实现取主路径 `limits[]+usage 回退`,`booster_wallet.usages` 作交叉校验/备选
- 响应含 `userId` → **Kimi 的 accountIdentifier 可用 userId 尾号**(优于 key 指纹)

### 4.2 GLM 端点实测(脱敏样例)

```json
{ "code": 200, "msg": "操作成功", "success": true,
  "data": { "limits": [
    { "type": "TIME_LIMIT",  "unit": 5, "number": 1, "usage": 4000, "currentValue": 114,
      "remaining": 3886, "percentage": 2, "nextResetTime": 1791338592997 },
    { "type": "TOKENS_LIMIT", "unit": 3, "number": 5, "percentage": 5,  "nextResetTime": 1790143338507 },
    { "type": "TOKENS_LIMIT", "unit": 6, "number": 1, "percentage": 50, "nextResetTime": 1790301792961 } ],
    "level": "max" } }
```

与 feeder 文档一致:两条 TOKENS_LIMIT(unit3/number5=5h,unit6/number1=7d),按 `nextResetTime` 升序识别首尾;`percentage`=已用%;`nextResetTime`=毫秒;`level`=档位;TIME_LIMIT 为 MCP 月配额(忽略);响应无账号标识 → GLM 的 accountIdentifier 用 key 指纹。

### 4.3 Codex 模型同构确认

`AgentRing/Models/CodexUsageData.swift:11-25`:`CodexUsageData{primary/secondary: LimitData{percentage, resetsAt}, extraUsage}` — GLM/Kimi 的双窗口与 `LimitData{percentage, resetsAt}` 完全同构,可直接沿用字段命名。`UserSettings.swift:100-162` 的 LimitType 惯例为 `codexPrimary/codexSecondary`(rawValue `codex_primary/...`),且行标签**复用** `L.DetailRow.fiveHour/sevenDay` → GLM/Kimi 采用 `glmPrimary/glmSecondary`、`kimiPrimary/kimiSecondary`,无需新增行级 i18n 键。GLM/Kimi 返回的是绝对重置时间(GLM ms 时间戳 / Kimi ISO),比 Codex 的 `reset_after_seconds` 还简单。

## 五、审计记录(grilling)

### Round 1(2026-09-23)

| # | 问题 | 决定 |
|---|---|---|
| A1 | GLM/Kimi 实现抽象程度 | **独立文件对,照项目惯例**(每 provider 各自 Service+Model,与 Codex/Cursor 平行;编译器穷举 switch 兜底) |
| A2 | 账号添加体验 | **粘贴即验证;成功自动回填账号标识;失败标红提示但允许保存**(用户合并方案:验证+警告+可保存) |
| A3 | 提交/PR 切分 | **单 commit 一次到位**(用户选定,替代推荐的按里程碑分 commit) |
| A4 | GLM 档位 level 展示 | **仅设置页账号卡显示**,弹窗列不显示 |
| A5 | debug mock 数据 | **两 provider 都加**(照 Cursor `debugModeEnabled` 分支) |
| A6 | 窗口扩展策略 | **固定 5h/7d**,未来新增窗口再改代码 |
| A7 | 计划文档归宿 | **保留为 docs/ 设计文档**,实施完成后精简为「新增 provider 集成指南」 |

### Round 2(2026-09-23)

| # | 问题 | 决定 |
|---|---|---|
| A8 | 弹窗圆环品牌配色 | **GLM 智谱蓝(≈#3E5FFB)+ Kimi 月紫(≈#7D5FFF)**,内环同色加深(照 Codex/Cursor 现有模式);菜单栏图标仍单色模板 |
| A9 | Provider 显示名 | **GLM / Kimi** 英文短名(照 Codex/Cursor 惯例) |
| A10 | Kimi booster_wallet(加油包)数据 | **不显示**,专注 5h/7d 双环与 Codex 对称;该字段仅作 mapper 备选路径(4.1) |

**前沿已空**:两轮共 17 项决策(D1–D4 + A1–A10 + 3 项事实核验),设计树全部分支已遍历,无遗留暗设。

## 六、实施检查清单

> 按序执行;每步结束 `xcodebuild build -scheme AgentRing` 自验;全部通过后按 A3 单 commit 提交。

### Step 0 端点验证
- [x] Kimi `GET /coding/v1/usages` 实测(HTTP 200,见 4.1)
- [x] GLM `GET /api/monitor/usage/quota/limit` 实测(HTTP 200,见 4.2)
- [x] Codex 双环同构确认(见 4.3)
- [x] 响应样例落为 `Tests/CodingPlanMapperChecks.swift` fixture(脱敏)

### Step 1 GLM 全链路
- [x] `ProviderType.swift`:case `glm`,displayName `"GLM"`
- [x] `AgentRing/Models/GlmUsageData.swift`(response Codable + mapper,TOKENS_LIMIT 首尾分类)
- [x] `AgentRing/Services/GlmAPIService.swift`(fetchUsage/validateApiKey/mock 分支)
- [x] `AgentRing/Views/Components/GlmColumnView.swift`(外环 primary/内环 secondary)
- [x] `UserSettings.swift`:LimitType `glmPrimary/glmSecondary`、glm 账号体系、getActiveGlmDisplayTypes、orderedActiveProviders 等
- [x] `KeychainManager.swift`:accounts_glm + migratableAccountKeys
- [x] `DataRefreshManager.swift`:service/@Published/shouldFetch/fetch/processSuccess/失效态/smart-monitoring
- [x] `MenuBarManager.swift` / `MenuBarUI.swift` / `MenuBarIconRenderer.swift`:镜像绑定、图标、popover 档位(5:1200/6+:1380)、MenuAction glmRelogin→打开设置
- [x] `UsageDetailView.swift` / `UsageRowComponents.swift`:列、UnifiedLimitRow
- [x] `ColorScheme.swift`:智谱蓝
- [x] `AuthSettingsView.swift`:picker/账号卡/粘贴即验证(失败标红可保存)
- [x] `ImageHelper.swift`:createGlmIcon
- [x] i18n(zh/en 两份 Localizable.strings + LocalizationHelper)
- [x] `BluetoothPayload.swift`/`NotificationManager.swift`/`DiagnosticsView.swift`:桩 case(TODO 二期)
- [x] `ClaudeConfigImporter.swift`:导入按钮(base URL 识别)

### Step 2 Kimi 全链路(同构复制 Step 1)
- [x] case `kimi`,displayName `"Kimi"`;LimitType `kimiPrimary/kimiSecondary`
- [x] `KimiUsageData.swift`(FlexibleNumber 字符串数字、微秒 ISO8601、limits[]+usage 回退、booster 备选、userId 标识)
- [x] `KimiAPIService.swift` / `KimiColumnView.swift` / 其余同款编辑(keychain `accounts_kimi`、月紫配色)
- [x] booster_wallet 不展示(A10)

### Step 3 测试与收尾
- [x] `Tests/CodingPlanMapperChecks.swift` + `Scripts/test-coding-plan-mapper.sh` — **18/18 PASS**(GLM 窗口分类/钳制/ms→Date/单条边界/乱序;Kimi FlexibleNumber/ISO 微秒/回退链/used 推导/booster 兜底)
- [x] 本地全量 typecheck(swiftc,77/78 文件通过;本机无完整 Xcode,排除的 1 个为 Sparkle 依赖文件)——完整 xcodebuild 构建由 CI(macos-15)执行
- [x] `Scripts/test-credential-store.sh`、`Scripts/test-ring-display.sh` 通过(credential-store 脚本顺手修了无 Xcode 机器的 DEVELOPER_DIR 回退)
- [x] README / README_EN provider 列表更新
- [x] 单 commit 提交(A3)
- [ ] 本文档精简为「新增 provider 集成指南」(A7,后续维护时完成)

### 实施记录(2026-09-23)

落地与方案的两处细节偏差(均为实现层面,不改变决策):
1. 添加账号弹窗独立为 `AgentRing/Views/Settings/Tabs/CodingPlanAccountSheet.swift`(A2「粘贴即验证+失败可保存」的载体),GLM/Kimi 共用;
2. `UsageError` 新增 `apiKeyInvalid` case(`error.api_key_invalid` 文案),作为「Key 失效态」的具体错误载体,替代复用 sessionExpired。
