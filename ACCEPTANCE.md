# PLOS iOS 验收报告（ACCEPTANCE）

- 验收日期：2026-07-03（含 iOS 平台装好后的构建/冒烟复测，及 C0 修复复验）
- 事实源：仓库根目录 `PLAN.md` §1（共享规格）
- 验收范围：Phase K / UI / INT / P 全部产物
- 环境：macOS (Darwin 25.5.0)，Xcode 26.6 (17F113)，iOS 26.5 模拟器运行时，iPhone 17 Pro 模拟器（本机无 iPhone 16 Pro，等价替代）

---

## 结论：⚠️ 有条件通过（C0/C1/C2 三项硬阻塞已在本次修复并复验；第 1 步硬项全绿）

初次验收发现**首要阻塞 C0：集成后的真实 App 在仓库现状下无法构建**——能构建的只是 Phase‑UI 静态壳（`PLOSApp`，Mock 假数据），真入口 `PLOSIntApp` 与内核、全部 INT/P 文件都被排除在构建外。经授权本次已修复 C0（接线）、C1（色值集中）、C2（内核 Date()），三次独立提交。

**经你授权，本次已实施 C0 修复并复验通过**：修好工程接线后，**真实 App 成功构建（0 error）并在模拟器冷启动、无崩溃、渲染真实 UI（今天/月计划/进度 TabBar + 能量三选 + 通知授权弹窗）**。内核 `swift test` 38/38 全绿。

**C0、C1、C2 三项已全部修复并复验；第 1 步 7 个硬项全部通过。** 剩余为非阻塞的质量项与人工走查：

| # | 剩余项 | 类型 |
|---|---|---|
| ~~C0~~ | ✅ 已修复：真实 App 接线可构建运行 | 已解决 |
| ~~C1~~ | ✅ 已修复：App target 色值散写归零（85 处 → `PLOS.Palette` 命名 token；Widget 7 处随 P6 处理） | 已解决 |
| ~~C2~~ | ✅ 已修复：内核 `Date()` 归零（`healthReminders` 改 `if let` 解析） | 已解决 |
| L1 | 完整每日闭环（建月→三能量生成→晚间汇报→次日重排→streak→持久化→通知深链）仅冷启动冒烟到位，**深度交互需人工走查**（本机无 UI 自动化工具 idb/XCUITest） | 走查 |
| P3–P10 | 一般/建议项（预算 habit 溢出、habit 进度不推进、通知深链、小组件未接入、时区隐式依赖等）——非阻塞，见下 | 质量 |

> 现状：**自动化硬门槛（第 1~3 步机器可判部分）全绿**。是否放行取决于你对 P4/P5/P6 等功能缺口的接受度与 L1 人工走查结果。

---

## C0 修复与复验（本次实施）

**问题**：committed `PLOS.xcodeproj` 只编译 12/23 文件、`@main` 是静态壳 `PLOSApp`、`PLOSKernel` 0 引用；用 `project.yml` 重生成则 `error: unable to resolve module dependency: 'PLOSKernel'` + 双 `@main` 冲突。

**修法（改动 3 个文件，未动任何业务逻辑）**：
1. `project.yml`：新增本地 SwiftPM 包依赖
   ```yaml
   packages:
     PLOSKernel:
       path: .
   targets:
     PLOS:
       dependencies:
         - package: PLOSKernel
           product: PLOSKernel
   ```
2. `PLOS/PLOSApp.swift`：删除其 `@main`（保留为开发预览壳；真入口 `PLOSIntApp` 成为唯一 `@main`）。
3. `xcodegen generate` 重生成 `PLOS.xcodeproj`。

**复验结果**：
```
compiled swift files: 23/23（含 PLOSIntApp/AppViewModel/Persistence/Notifications/全部 Phase-P）
PLOSKernel refs in pbxproj: 5（内核已链接）
xcodebuild build (iPhone 17 Pro) → ** BUILD SUCCEEDED **  0 error / 4 warning
模拟器：安装→launch(PID)→launchctl 在册→无崩溃日志；首屏为真实 App（今天 TabBar + 能量选择 + 通知授权请求）
```
4 条 warning 均为无害的"未使用局部变量"（`AppViewModel.swift:150`、`HealthCheckInView.swift:77`、`ProgressData.swift:70/91`）。
> 说明：INT/P 源码在正确接线后**零编译错误**通过，说明业务代码本身写得扎实，此前只是工程配置从未把它们编进产物。

---

## 第 1 步：自动化硬项

| # | 硬项 | 结果 | 证据 |
|---|---|---|---|
| 1 | `swift test` 全绿 | ✅ 通过 | **38 项，0 失败**（原 30 + 本次 8 抽查） |
| 2 | 内核无 `Date()` / `Calendar.current` | ✅ **通过（C2 修复后）** | 内核实际 `Date()`/`Calendar.current` 计数=0（仅存文档注释） |
| 3 | App 色值只在 DesignSystem.swift | ✅ **通过（C1 修复后）** | App target `Color(hex:`/`0x…` 计数=0；全部改引 `PLOS.Palette` |
| 4 | 纯本地（无网络/三方库） | ✅ 通过 | 全仓库 grep 均空 |
| 5 | 常量集中在 KernelConfig | ✅ 通过 | 7 常量仅 `KernelConfig.swift` 定义 |
| 6 | `xcodebuild build` 零 error | ✅ **通过（C0 修复后）** | 真实 App `** BUILD SUCCEEDED **`，0 error / 4 无害 warning。（修复前 committed 工程只能构建静态壳、真实 App 用 project.yml 构建失败——见 C0） |
| 7 | UI 测试 target | ➖ 不适用 | 无 unit/UI test target；内核测试走 SwiftPM。按规格不扣分 |

---

## 第 2 步：内核行为抽查（新增 8 项 ACCEPTANCE 测试，全部通过）

文件：`Tests/PLOSKernelTests/ACCEPTANCE_KernelSpotChecks.swift`。期望值均按 §1 公式手算并在测试内注明推导。

| 项 | 断言 | 手算推导 | 结果 |
|---|---|---|---|
| a | 学5休2 铺 **2026年7月(31天)** + 灵活2 | cycle=7，`(day-1)%7<5`；31=4×7+3 → **backbone=23**、保底=**21**（对照 30天=22 正是 §1.3 示例）。7/1：rem=**20**/elapsed=**1**；7/15：rem=**10**/elapsed=**11** | ✅ |
| b | 学习日轴铁律：中途插休息日 → expected_progress 不变 | 派生轴仅由「骨架+today」决定；插入 7/6、7/8 休息日后 `plan()` 逐字节一致；7/10 ep=8/21 **≠** 日历轴 9/31 | ✅ |
| c | 达标衰减单调 + 端点 1/FLOOR；无 if-passed | `decay=1−0.9·over`：阈值=1.0、(t+1)/2=0.55、0.99=0.145、100%=0.1；单调；已达标<1、未达标=1 | ✅ |
| d | 三能量 sum(minutes)≤BUDGET；低谷日 deadline≤2 | high≤150/normal≤100/low≤45；低谷日 deadline/milestone ≤2 | ✅ |
| e | 同 state+today 多次调用逐字节一致 | 富状态连调 6 次 `JSONEncoder(.sortedKeys)` 全等 | ✅ |
| f | §1.9 晚间换算 | `done=min(total, done+0.8·plannedUnits)`：2.4；封顶6.0；0%不变。镜像 `AppViewModel.swift:262-263` | ✅ |

另 2 项"缺陷佐证"：`..._DOCUMENTS_BUG`（低谷日 4 habit → 60>45，P3）；`..._DOCUMENTS_GAP`（habit `plannedUnits==0` → 增量恒 0，P4）。
铁律 2：`Scoring.swift`/`Allocator.swift` 无任何以「达标/passed/threshold」为条件的 `if` 分支。✅

---

## 第 3 步：模拟器冒烟（C0 修复后，对真实 App）

- 目标机：iPhone 17 Pro（iOS 26.5）。真实 App `com.plos.app` 安装 → `simctl launch` 返回 PID → `launchctl` 在册 → **无崩溃日志**。✅
- 首屏：真实 `PLOSIntApp` UI——底部 **今天/月计划/进度 TabBar**、今天页**能量三选**（自动建了本月、7/3 是学习日）、并弹出**通知授权请求**（`NotificationManager.requestPermission()` 生效）。冷启动不崩。✅（截图留存）
- 未自动验证：能量选择→生成计划→reasoning、晚间汇报、次日重排、streak、持久化、通知深链等**深度交互**（本机无 idb/XCUITest，留人工走查 L1）。

---

## 发现的问题（C0 已修复；其余均未动手修）

### 阻塞
**C0 · 真实 App 未接线 / 不可构建 —— ✅ 本次已修复并复验**（详见上「C0 修复与复验」）。改动 `project.yml` / `PLOSApp.swift` / 重生成 `PLOS.xcodeproj`，未动业务逻辑。

**C1 · 色值散写违反硬项 —— ✅ 本次已修复** — 原 App 85 处 `Color(hex: 0x…)`
- 修法：`DesignSystem.swift` 补 34 个语义 token（值与原 hex 完全一致，视觉零变化），全部 App 视图改引 `PLOS.Palette.<token>`；App target 散写归零、`xcodebuild` 通过。
- 遗留：`PLOSWidget` 7 处未处理（小组件尚未接入构建，随 P6 一并做）。

**C2 · 内核残留 `Date()` —— ✅ 本次已修复** — `Sources/PLOSKernel/Rules.swift`
- 修法：`healthReminders` 将 `parseDate(today) ?? Date()` 改为并入 `if let` 条件；解析失败仅跳过"未运动"提醒，其余健康提醒不受影响，对合法 today 行为一致。内核 `Date()` 归零，`swift test` 38/38。

### 一般
**P3 · 预算可被突破（habit 溢出）** — `Allocator.swift:29-43` + `Scheduler.swift:110-120`：`habit数×15>budget`（低谷日≥4）→ sum 超 BUDGET，Step 7 单项钳制救不回（佐证 `test_ACCEPTANCE_d2`）。建议 habit 纳入总预算或 Step 7 迭代钳制。

**P4 · habit 进度永不推进 / 不进度盘** — `Allocator.swift:37`/`AppViewModel.swift:262-266`/`Scoring.swift:139`/`ProgressData.swift:45`：habit `plannedUnits=0`→§1.9 增量恒 0；`scoreAll` 排除 habit；无"完成学习日占比"。`AppViewModel.swift:265-266` 注释与实现不符。建议：晚间对 habit 记「完成学习日」计数并算达标率。

**P5 · 通知深链未实现** — `Notifications.swift:104-109`：`didReceive` 仅 `completionHandler()`；categoryIdentifier 不被消费，`selectedTab` 不因通知切换。§5.7 未落地（定时触发+授权 ✅）。建议按 category 路由。

**P6 · 小组件未接入构建** — `PLOSWidget/`、`project.yml`、无 `.entitlements`：不在工程、无 App Group、App 端不写 `group.com.plos.app` 也不 `reloadAllTimelines()`。建议加 widget extension target + App Group + App 侧写共享数据。（C0 修复只接了主 App，未含 Widget。）

**P7 · 内核日期计算隐式依赖 `TimeZone.current`** — `RestSchedule/Rules/Reasoning`（7 处 `Calendar(identifier:.gregorian)`）：同一 `today: Date` 跨时区抽取 y/m/d 可不同。建议显式 `timeZone=UTC` 或由 App 注入。

**P10 · 4 条编译 warning（无害）** — `AppViewModel.swift:150`、`HealthCheckInView.swift:77`、`ProgressData.swift:70/91`：未使用局部变量。建议顺手清掉。

### 建议
**P8 · 考前 reasoning 句无数字** — `Reasoning.swift:167`：§1.7 允许「明确事实」故合规，但与 `testReasoningEverySentenceHasNumber` 纯数字判据不一致且未覆盖考前分支。建议补数字或豁免+补覆盖。

**P9 · 低谷日测试判据偏松** — `PLOSKernelTests.swift:472` 断言 `≤3`，规格「1~2」；`test_ACCEPTANCE_d` 已用 `≤2` 收紧。建议原测试改 `≤2`。

---

## 亮点
- **内核（PLOSKernel）**：§1.4~§1.9 忠实实现，两条铁律成立，确定性成立，`swift test` 38/38。
- **INT/P 业务代码质量**：正确接线后零编译错误（仅 4 无害 warning）通过——此前失败纯属工程配置。
- 纯本地、常量集中、README 清晰；§1.9 换算正确且 `done` 封顶 `total`；iCloud 已按 §6.3 妥善延后（`DataSafetyView.swift:36`）。
- 真实 App 冷启动不崩、真实 UI + 通知授权链路生效。

---

## 需要人工确认（真实 App 现已可构建运行；逐项走查其功能）

> 前置：iPhone 17 Pro / iOS 26.5 上真实 `PLOSIntApp` 已 `** BUILD SUCCEEDED **`、冷启动 OK。以下深度交互本机无法自动化，需手动。

1. **建月保底学习日**：样例（高数/英语/线代/项目，学5休2+灵活2）→ 显示**保底学习日 21 天**（31 天月）。
2. **三种能量各生成一次**：高能/普通/低谷 → 量与项数递减；reasoning 每句带数字（考前句见 P8）；低谷日含"预算压到45分钟"。
3. **灵活休息日不暴涨**：用 1 个 → 次日回到既定基准；额度 2→1。
4. **全 0% 汇报无惩罚**：streak 照常 +1、`systemRan=true`、无红色崩盘感。
5. **达标科目淡化+让位句**：过达标线 → "已达标✓"淡化 + 让位句；不消失。
6. **杀 App 重启数据完好**：SwiftData 持久化（done/streak/历史）。
7. **通知定时+深链**：早 8:00/晚 21:30 到达、可改时间/开关；**点按深链——预计不生效（P5）**。
8. **habit 表现**：每学习日出现且 15 分钟；**进度/达标率——预计不推进（P4）**。
9. **小组件**：**预计无法添加/无数据（P6）**。
10. **真机安装**：免费证书真机冷启动不崩、主闭环跑通、无补作业。

---

## 附：本次验收产物与改动
- 新增 `Tests/PLOSKernelTests/ACCEPTANCE_KernelSpotChecks.swift`（8 抽查 + 2 缺陷佐证），随 `swift test` 全绿；保留以便复核。
- **本次三次提交（经授权）**：
  - `a6f99ec` C0：`project.yml`（加内核依赖）+ `PLOSApp.swift`（去重复 `@main`）+ `PLOS.xcodeproj`（xcodegen 重生成）。
  - `b5ca094` C1：`DesignSystem.swift`（+34 token）+ 12 个 App 视图（hex→`PLOS.Palette`）。
  - `e4a60cd` C2：`Sources/PLOSKernel/Rules.swift`（去 `Date()` 兜底）。
- 均在 `master` 分支；未 push。P3–P10 与 L1 走查未做，等你决定。
- 除上述外**未改动其它业务逻辑**；调色为等值替换，视觉零变化。

---

# 2026-08-27 完工阶段（P3–P10 全部修复 + 接线补全）

> 本节记录第二轮完工工作。内核 `swift test` **40/40 全绿**；App 与 Widget 全部源码经
> iOS 模拟器 SDK 交叉类型检查 **0 error / 0 warning**（方法见文末"影子构建"）。
> xcodebuild 全量构建与模拟器 L1 走查在会话时因权限分类器依赖的代理端点故障未能执行，
> 命令队列见文末"待执行"。

## 修复清单（本轮全部落地）

### 内核（PLOSKernel — 全部有测试护栏）
| 项 | 修复 | 测试 |
|---|---|---|
| P3 预算溢出 | Allocator 按预算确定性截断 habit（goal 顺序）；Scheduler Step 7 改为"压最大项至 MIN_CHUNK → 仍超则从队尾丢弃"的硬不变量 | `test_ACCEPTANCE_d2_budgetHolds_withManyHabits` |
| P7 时区隐式依赖 | 内核日历钉死 UTC（`RestSchedule.calendar`）；新增 `canonicalDate(from:in:)` 作为 App 边界归一化入口 | `test_ACCEPTANCE_g_timezoneIndependence`（在东八区主机上修复前必挂） |
| P8 考前句无数字 | 考前句携带 REVIEW_CHUNK 数字：「只安排20分钟复习」 | `test_ACCEPTANCE_h_preExamSentenceHasNumber` |
| 新发现：考前科目无项 | 该科当日无分配（on-track → pressure 0 → 全被基准上限压掉）时，§1.6 的"强制"落空。现在缺项则**插入**复习项（plannedUnits=0） | 同上 |
| P9 判据偏松 | 低谷日断言 ≤3 → ≤2 | `testFixture2LowEnergy` |
| **新发现（重大）：基准上限单位错配** | 旧公式 `proportion×budget`（proportion=baselineToday/total）把"占总工作量比例"当"占预算比例"，**月初 rem 大时全部科目 cap<15 被丢弃 → 100 分钟的日子只剩 15 分钟 habit**。38 个旧测试没抓到（夹具全是临近截止/严重落后场景）。新公式：按归一化剩余需求（baselineToday/total，无量纲）分摊扣除 habit 后的预算，单位公平、达标科目自然让位 | `PLOSAppTests` 全套（真实"月初新目标"场景）+ 内核 40 项回归 |

### 新增：App 层无头集成测试（`Tests/PLOSAppTests` — L1 数据链路自动化）
Package.swift 常驻 `PLOSAppCheck`（App 源码作 SwiftPM library target）+ `PLOSAppTests`。
内存 SwiftData 容器 + 注入 `today`，纯 `swift test` 即可跑 L1 的数据闭环（9 项）：
建月骨架 31 天 / 三能量预算上限 / 计划与 reasoning 持久化重启恢复 / §1.9 折叠与重存幂等 /
habit 完成学习日计数 / 全 0% 无惩罚 / 次日「接昨天」连续性 + streak 累计 / 灵活休息用与撤销 /
节奏休息日短路 systemRan / 月中改节奏保历史重铺 / 跨月继承节奏。
（`PLOSIntApp` 的 `@main` 在 `SWIFT_PACKAGE` 下条件移除，避免与 XCTest runner 冲突。）
**当前状态：`swift test` 49/49 全绿（内核 40 + App 集成 9）。**

### App 层（比 7-03 清单多出的真问题都在走查预判中修掉）
- **P4 habit 进度**：`goal.done` 对 habit 不再无效累加；达标率 = 完成学习日 ÷ 已发生学习日（§1.4），进度面板新增「习惯」区块（`computeHabitSummaries`）。
- **汇报重复保存重复累加（数据损坏）**：`saveEveningReport` 改为对全月汇报记录的**幂等折叠**：`done = min(total, Σ pct×当日plannedUnits)`；重开汇报页回显已存滑块值（`restoreExistingReport`）。
- **P5 通知深链**：`didReceive` 按 categoryIdentifier 路由（EVENING → 汇报页；冷启动经 `pendingCategory` 兜底）；`updateSchedule` 补上丢失的 categoryIdentifier；新增 `NotificationSettingsView`（§5.7 设置页，`updateSchedule` 首个调用方）。
- **孤儿视图接线**：Tab2 由 ProgressStubView 换成真 `ProgressDashboardView`；`EveningReportIntView` 获得入口（计划页底部 CTA + 深链）；Events/Health/DataSafety/提醒设置 挂到进度页设置区。
- **健康数据断路**：`currentHealth()` 此前从未被消费——`generatePlan` 现在注入 `state.health`；打卡存储改内核规范日（P7 边界）；不再因未勾选运动而清空历史。
- **跨午夜**：`advanceToTodayIfNeeded()` + scenePhase.active 触发；支持跨月（沿用上月节奏参数建新月）。
- **月中改节奏不生效**：`applyRestStrategy` 落库 + `buildSkeleton` 对无历史的日子重铺骨架；保底预览改为随步进器**实时计算**（§2.1）；步进器回显已存月配置。
- **重新选能量**：计划生成后可一键清空重选（L1 走查第 2 项的前置条件）。
- **reasoning 持久化**：`DayEntity.reasoning`（可选字段，轻量迁移），杀 App 重启后信任锚不丢；随导出/导入。
- **streak 日历星期偏移**：1 号对齐真实星期列。
- **P10**：4 处 unused-variable warning 清零（交叉类型检查 0 warning 佐证）。
- **P6 小组件**：`PLOSWidget.swift` 拆出 App 侧 `WidgetPublisher.swift`（写 App Group + `reloadAllTimelines`，计划/汇报/休息/跨日均触发）；widget 色值全部改引共享 `DesignSystem.swift` token（hex 归零）；`project.yml` 新增 widget target（App Group entitlements、NSExtension、App 内嵌）。

## 收尾执行结果（2026-08-28，全部完成）

| 步骤 | 结果 |
|---|---|
| `xcodegen generate` | ✅ widget + UI test target 已写入工程 |
| `swift test` | ✅ **50/50**（内核 41 + App 集成 9） |
| `xcodebuild build` | ✅ **BUILD SUCCEEDED，0 error / 0 warning** |
| 模拟器冷启动 | ✅ iPhone 17 Pro / iOS 26.5，无崩溃 |
| **L1 走查** | ✅ **XCUITest 5/5 全通过**，截图留档 |

### L1 走查自动化（`PLOSUITests` — 原"需人工确认"清单已转为回归测试）
`-plosToday` 钉住日期、`-plosResetStore` 清库、`-plosSkipNotificationPrompt` 跳过授权弹窗，
使走查在任何真实日期都可重复执行：

| 用例 | 覆盖 |
|---|---|
| test01 空态与建月 | 空态 CTA 存在**且未被浮动 TabBar 遮挡**（isHittable）；保底学习日预览实测 21/骨架 23 |
| test02 学习日闭环 | 三能量选项 → 生成计划（100 分钟精确用满）→ reasoning 卡含预算数字 → 汇报入口可点 → 滑块汇报 → streak 计为 1 天 |
| test03 进度面板 | 各科完成率 + **习惯·完成学习日占比（P4）** + 提醒设置页可达且开关存在 |
| test04 节奏休息日 | 休息卡短路、无能量选择器、"系统仍在运行"文案 |
| test05 灵活休息 | 花额度 → 剩余1个 → 撤销回到学习日 |

### 走查中发现并修复的三个缺陷（测试之外只有"看"才能抓到）
1. **App 被信箱式压缩渲染**（缺 `UILaunchScreen` → iOS 兼容模式）：窗口缩小、内容与浮动 TabBar 碰撞。修：`INFOPLIST_KEY_UILaunchScreen_Generation`。
2. **主 CTA 被 TabBar 遮挡**：滚动内容缺底部留白，首屏够不到"去建月目标"。修：底部 40pt 留白；测试以 `isHittable` 永久防回归。
3. **reasoning 事实错误**：两个落后科目**都自称"压力最高"**（§1.7 要求每句为真）。修：仅压力最高者用该句式，其余为「同样落后X%，今日一并推进」；`test_ACCEPTANCE_i` 断言该短语最多出现一次。
> 附带修复：`advanceToTodayIfNeeded()` 会在前台刷新时把注入日期覆盖回真实日期，使任何钉住日期的测试静默失效。改为 `pinnedToday` 优先。

### 复现命令
```
cd /Users/leo/Desktop/01-项目/plos-ios
swift test                                   # 内核 + App 集成（50）
xcodebuild -project PLOS.xcodeproj -scheme PLOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # L1 走查（5）
```

## 影子构建（无 xcodebuild 时的全量类型检查——可复用的招）
临时向 Package.swift 加 `.target(name: "PLOSAppCheck", dependencies: ["PLOSKernel"], path: "PLOS")`，然后：
```
swift build --triple arm64-apple-ios17.0-simulator \
  --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
```
即可在纯 SwiftPM 下对全部 App 源码做 iOS 目标的编译级检查（验完还原 Package.swift）。
