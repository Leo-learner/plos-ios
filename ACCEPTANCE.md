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
