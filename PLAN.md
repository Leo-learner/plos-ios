# Personal Learning OS (PLOS) — 落地执行方案 v7（iOS 本地版 · 从零开始 · 定稿）

## 0. 运行协议
- **本版为全新起点**：抛弃此前网页版的一切产物（服务器、Flask、Python 内核、旧设计稿），从空仓库开始。
- **产品形态**：原生 iOS App。不依赖云端大模型、不依赖服务器后端，调度智能全部由**本地确定性算法**实现。
- **分工**：Claude 制定方案与提示词（本文件）；Claude Design 从零设计 UI（Phase D）；**Hermes Agent + deepseek-v4-pro** 执行全部编码阶段（Phase K / UI / INT / P）。
- **用法**：本文件放仓库根目录。执行某阶段时，把该阶段提示词整段贴给执行方；编码阶段提示词要求 Hermes 先读本文件 §1（共享规格）。
- **一次只跑一个阶段**。deepseek-v4-pro 做常规编码可靠，但长任务与工具调用稳定性弱于 Claude——所以阶段切得小、验收标准硬、单测做护栏。每阶段必须过验收清单再进下一阶段。

## 依赖图
```
Phase D（全新 iOS UI 设计，Claude Design）   ∥   Phase K（Swift 内核，Hermes）
        └───────────────┬───────────────────────────┘
        Phase UI（SwiftUI 静态屏，Hermes，吃 D 的 Handoff Bundle）
                        ↓
        Phase INT（内核 + SwiftData + 通知接线，Hermes）
                        ↓
        Phase P（打磨与扩展，Hermes）
```
D 与 K 互不依赖、可并行；UI 只依赖 D；INT 同时消费 K 与 UI。

---

# §1. 共享规格（所有阶段的唯一事实源）

## 1.1 产品内核
月目标固定、日计划每天动态生成的**单人**学习系统。设计哲学：**允许失败，不允许脱轨**——以"系统每天在运行"代替"靠意志力坚持"。休息日与 0% 日不惩罚，系统运行即成功。核心 KPI：月目标达标、连续运行天数（streak）、断线次数趋近 0。

每日闭环：早晨（看昨天 → 选能量 → 本地即时生成今日计划）→ 白天（照计划做）→ 晚间（滑块一分钟汇报）→ 明天重新生成。没有补作业机制，只有重新规划。

## 1.2 数据模型（Swift 语义）
```
Goal        { id, subject, type: deadline|habit|milestone, target, unit,
              total: Double, done: Double, start: Date, deadline: Date,
              importance: Double(默认1.0), successThreshold: Double, historyDelay: Int }
RestStrategy{ cycleStudy: Int, cycleRest: Int, flexRestTotal: Int, flexUsed: Int }
Day         { date, dayType: study|rhythmRest|flexRest, energy: high|normal|low?,
              planned: [PlannedItem], reported: [ReportItem], systemRan: Bool, note: String? }
PlannedItem { goalId, minutes: Int, label, plannedUnits: Double, order: Int }
ReportItem  { goalId, completionPct: Int }
Health      { lastExercise: Date?, lateNights7d: Int, highPressureStreak: Int }
Event       { type: exam, subject, date }
Month       { month, restStrategy, goals[], days{} }
```
要点：`done` 是每目标一个浮点（"做了20题"直接换算成进度，无需定义原子任务）；`systemRan` 与完成度分开记（0% 日、休息日打开即为 true）——它是 streak 与"断线次数=0"的落地。

## 1.3 休息策略 → 学习日轴（核心）
建月时设 `{cycleStudy, cycleRest, flexRestTotal}`（如学5休2 + 灵活2天）：
```
backbone_study_days  = 学N休M 铺满整月日历的学习日数        # 学5休2×30天 = 22
study_days_total     = backbone_study_days − flexRestTotal  # 22−2 = 20（保底学习日）
rem_backbone_study   = 明天→月底的 backbone 学习日数
rem_flex             = flexRestTotal − flexUsed
study_days_remaining = max(rem_backbone_study − rem_flex, 1)
study_days_elapsed   = study_days_total − study_days_remaining
```
- 学N休M 是**骨架**，铺满整月日历，标出每天是学习日还是节奏休息日。
- 灵活休息日是**额度池**，可在任意学习日一键花掉，把当天转成休息；骨架节奏不变。
- 单日基准对齐**保底学习日**完成 100% 全量：灵活额度全用掉也能完成；不用满等于提前/缓冲；用灵活休息日只回到既定基准，不抬高其它天的量。

**铁律 1**：expected_progress 与 urgency 全部基于保底学习日（**学习日轴**）。休息日绝不推进时钟、绝不产生压力——写成日历轴等于系统因为用户休息而催他，是最严重的正确性 bug。

## 1.4 打分（每个 deadline/milestone 目标）
```
progress       = done / total
baseline_today = (total − done) / study_days_remaining          # 单日基准
over  = max(progress − successThreshold, 0) / max(1 − successThreshold, 1e-6)
decay = 1 − (1 − IMPORTANCE_FLOOR) * over                        # 达标前=1，过线后平滑→FLOOR
expected_progress = study_days_elapsed / study_days_total
gap      = expected_progress − progress                          # >0 落后节奏
urgency  = 1 + URGENCY_K / study_days_remaining
pressure = max(gap, 0) * urgency * importance * decay * (1 + 0.1*historyDelay)
```
**铁律 2**：无 `if passed` 分支——达标只通过连续的 decay 因子起作用（过线后重要性平滑衰减、让位给未达标科目），压力公式结构对所有目标一致。

habit 目标（如英语每天阅读）：不参与 pressure 竞争，固定 `HABIT_CHUNK`，每个学习日出现；达标判定看"完成学习日占比"。

## 1.5 分配
```
budget = BUDGET[energy]                     # high:150 / normal:100 / low:45（分钟）
1. 扣除所有 habit 的 HABIT_CHUNK
2. 剩余按 pressure 占比分配；单科向 baseline_today 折算的分钟数看齐
3. min/max chunk：<MIN_CHUNK(15) 省略；单科 ≤ MAX_CHUNK(90)
4. 低谷日只保留 pressure 最高的 1~2 个 deadline 项 + habit（目标是不断线，不是效率）
5. 按 pressure 降序输出
```
常量集中在 `KernelConfig`：`URGENCY_K=7, IMPORTANCE_FLOOR=0.1, BUDGET={150,100,45}, MIN_CHUNK=15, MAX_CHUNK=90, HABIT_CHUNK=15, REVIEW_CHUNK=20`。

## 1.6 规则取舍层（全部确定性）
按序应用于分配结果：
- **连续性**：昨天某目标 0<completionPct<100 → 今日该项 label 追加「（接昨天）」。
- **考前轻量**：明天有该科 exam 事件 → 该科强制降为 `REVIEW_CHUNK` 分钟、label「只复习，不上新内容」、置顶提示。
- **多样性护栏**：某科已连续 3 个学习日拿到 MAX_CHUNK 且存在 pressure 相差 <20% 的其它科 → 本日两科各让一步（防单科长期独占）。
- **Health 提醒**：`(today − lastExercise) ≥ 4天`、`lateNights7d ≥ 3`、`highPressureStreak ≥ 5` 任一触发 → 生成提醒文案进输出（**只提醒，不改预算**；预算下调只来自用户手动选低谷日）。

## 1.7 模板 reasoning（信任机制）
计划为什么这么排，由分句模板按触发条件拼装，**必须带真实数字**：
```
[状态句]   高能日，预算150分钟，安排{n}项。／ 普通日，预算100分钟。／
           低谷日，预算压到45分钟，只保最关键项，其余明天再追。
[主推句]   {科目}落后节奏{gap%}、保底剩余学习日{d}天、压力最高，今日优先。
[让位句]   {科目}已过达标线（{progress%}≥{threshold%}），优先级让给未达标科目。
[基准句]   {科目}按基准推进：今日{units}{unit}（剩余{rem}{unit}÷{d}天）。
[考前句]   明天{科目}考试，今日只安排复习，不上新内容。
[健康句]   已连续{k}天未运动／近一周熬夜{k}次，建议今晚早点休息。
[休息卡]   今天是计划内休息日，好好休息。系统仍在运行——连续第{streak}天。
[灵活卡]   已使用1个灵活休息日（剩余{r}个），不影响整体节奏与基准。
```
拼装规则：状态句必有；每个入选目标出主推句/基准句之一；触发才出让位/考前/健康句。禁止空话——每句至少一个数字或明确事实。

## 1.8 内核公开接口
```
plan(state: MonthState, today: Date) -> DayPlan
DayPlan = .rest(card: RestCard)                       // dayType≠study 时短路
        | .study(items: [PlannedItem], reasoning: String, healthNotes: [String])
```
纯函数：`today` 注入参数，内部**禁止** `Date()`/`Calendar.current` 取"现在"；同输入必同输出。

## 1.9 晚间换算
- 生成计划时把每项的 `baseline_today` 折算单位量存进 `plannedUnits`。
- 汇报：`done = min(total, done + completionPct/100 × plannedUnits)`。
- habit：completionPct>0 即记"该学习日完成"。
- 自由备注仅作个人备忘展示，**不影响调度**。
- 保存汇报（含全 0%）或休息日打开 → `systemRan=true`；streak = 连续 systemRan 天数。

## 1.10 设计 token
以 Phase D 新导出的 Handoff Bundle 为准：其全部 CSS 变量（颜色/字体/间距）落地为 `DesignSystem.swift` 常量（Color/Font/Spacing），全部 UI 只引用它、不散写十六进制。

---

# §2. Phase D 提示词（贴给 Claude Design）——全新 iOS UI 设计

```
请为一款原生 iOS App 从零设计 UI：逐屏产出、对话式迭代，最后导出 Handoff Bundle（各屏 + 全部状态 + 可复用组件 + 设计 token）交给工程用 SwiftUI 实现。

【一句话】Personal Learning OS（PLOS）：月目标固定、日计划由本地算法每天动态生成的单人学习工具。核心理念——以「系统每天在运行」代替「靠意志力坚持」；允许失败，不允许脱轨。

【用户与场景】单人（一名大学生），iPhone，每天早上打开一次看今天学什么，晚上花一分钟汇报。第一原则=低启动成本：打开计划屏，一分钟内知道今天干什么。休息日、完成0%的日子，视觉上都不能有惩罚感。

【平台】原生 iOS（SwiftUI 实现）：竖屏、安全区（灵动岛/底部指示条）、拇指可达、导航用 iOS 惯例（TabBar 或 NavigationStack）、控件贴原生手感（滑块/Toggle/日期picker）。计划由本地算法即时算出——不要设计"AI思考中"的loading态，生成即完成。

【需要设计的屏】

1) 建月设置（低频，信息密度可高）
   - 目标列表（可增删），每个目标：科目名 · 类型（deadline按期完成/habit每天做/milestone里程碑）· 总量+单位 · 截止日 · 重要性 importance（默认1.0可调）· 达标线 successThreshold（如数学80%、英语70%）
   - 休息策略：学N休M（如学5休2）+ 灵活休息日额度（如2天）
   - 保底学习日预览：实时算出并显示（如「本月保底学习日20天，单日基准将对齐它完成100%」）
   样例数据（请用真实内容）：高数·deadline·6章·截止6/30·重要性1.2·达标80% ／ 英语·habit·每天阅读·达标70% ／ 线代·deadline·100题·截止6/28·达标80% ／ 项目·milestone·课程作业·截止6/25 ／ 学5休2+灵活2天→保底20学习日。

2) 早晨屏（每天入口，按当天类型三分支）
   A. 学习日：能量三选（高能/普通/低谷，大按钮一点即选）→「生成今日计划」→ 计划列表（每条：科目·分钟·label 如"线代刷题（接昨天）"）+ reasoning 段落 + 「用一个灵活休息日」按钮（显示剩余额度如 2/2）。
      ↳ 能量选择请出两版对比：纯手动点 vs 系统预填一个用户可改。
      ↳ reasoning 必须显眼、可读——它是用户信任系统的唯一理由，绝不能小灰字塞角落。文案口吻是"系统本地计算"，如："低谷日，预算压到45分钟。线代落后节奏27%、保底剩余学习日6天、压力最高，只保它和英语日常，其余明天再追。"
   B. 节奏休息日：休息卡——"今天是计划内休息日"，无任务，明确显示「系统仍在运行·连续第N天」。
   C. 灵活休息日：用户点按钮后本日转休息卡，额度−1。
   顶部可能出现：健康提醒条（黄色系、可关闭，如"已连续4天未运动，今晚早点休息"，只提醒无按钮改计划）。

3) 计划视图（低启动成本主屏，<1分钟扫完）
   今日条目（科目+分钟+完成/进行中）· reasoning 一行浓缩 · 极简月进度（各科完成度+达标线标记，保持轻）· 今日类型标识 + 连续运行天数。

4) 晚间汇报（快、低摩擦）
   逐项完成度滑块 0–100% + 一个可选「个人备忘」框（仅记录，不影响明天计划）+ 保存。全部0%也不惩罚，保存后仍算"系统运行"。
   样例：线代 [80%] 备忘"只刷了20题"；英语 [100%]。

【横切状态】首次运行空态（引导建月）；达标科目标记（过线后"已达标✓"淡化让位，不消失）；连续运行天数标记（0%日与休息日照样计入）。

【预留位】数据面板风格位（各科完成率、负荷曲线、streak热力），Phase P 用，现在不必做完。

【设计原则】移动优先竖屏拇指可达；计划屏<1分钟看懂；reasoning 显眼；三种日类型一眼可辨；晚间低摩擦；可失败不惩罚（休息/0%日不用红色崩盘感）。

【观感】留给你定。唯一建议：每天清晨用的日常工具，倾向平静、清爽、易读；想要个性可探索克制的配色方向，多出几版对比再锁。

【交付】Handoff Bundle：各屏+全部横切状态+可复用组件+设计token（颜色/字体/间距变量命名规整，便于映射 SwiftUI 常量文件）。
```

---

# §3. Phase K 提示词（贴给 Hermes Agent）——Swift 调度内核

```
【任务】在空仓库中创建 Swift Package「PLOSKernel」，实现 PLAN.md §1.2~§1.8 的全部调度内核，并用 XCTest 验证到"同输入必同输出、七个夹具全过"。先完整阅读仓库根目录 PLAN.md 的 §1，规格以它为准。

【范围】纯逻辑库：数据模型、休息骨架推导、打分、分配、规则取舍、模板 reasoning、公开接口 plan(state:today:)。
【明确不做】不建 Xcode App 工程、不写任何 SwiftUI/UIKit、不用 SwiftData/CoreData、不发网络请求、不引第三方依赖。

【结构】
Sources/PLOSKernel/
  Models.swift          // §1.2 数据类型（Codable，供夹具 JSON 解码）
  KernelConfig.swift    // §1.5 常量，集中可调
  RestSchedule.swift    // §1.3：骨架铺月、保底学习日、rem/elapsed 派生
  Scoring.swift         // §1.4：baseline/decay/gap/pressure
  Allocator.swift       // §1.5：预算分配
  Rules.swift           // §1.6：连续性/考前/多样性/健康提醒
  Reasoning.swift       // §1.7：模板拼装
  Scheduler.swift       // §1.8：编排 + dayType 短路
Tests/PLOSKernelTests/  // XCTest
Fixtures/               // 7 个 JSON 夹具（打进 test bundle）

【纯函数纪律】today 一律参数注入；Kernel 内禁止 Date()/"当前时间"；所有函数无副作用。这是验收硬项。

【7 个夹具】(各压一个边界，JSON 按 Models 可解码)
1 high_energy 高能日多科推进
2 low_energy 低谷日45min，只应保住最高压 deadline + habit
3 way_behind 某科 gap 很大 → 显著提优先并在 reasoning 出现主推句
4 near_deadline study_days_remaining≤2 → urgency 拉满
5 zero_yesterday 昨天全0% → 今日正常重排（无"补作业"概念），连续性规则不触发
6 rhythm_rest dayType=rhythmRest → 返回 .rest 短路，不进打分
7 passed_goal 某科 progress≥threshold → decay 生效让位、reasoning 出让位句，且代码中无 if-passed 分支

【XCTest 必测】
- 学5休2×30天 → backbone=22、保底=20；rem/elapsed 派生正确
- 学习日轴：在中途插入休息日，expected_progress 不变（与日历轴对照断言不同）
- gap≤0 → pressure=0；decay 在达标线=1、100%=FLOOR、区间单调递减
- 分配：sum(minutes)≤budget；habit 必得 HABIT_CHUNK；min/max chunk 生效；pressure 降序
- 低谷日仅 1~2 deadline 项；考前规则强制 REVIEW_CHUNK；连续性 label 追加正确
- reasoning：每句含数字；休息卡含 streak 占位；同一 state+today 两次调用输出逐字节一致
- 7 个夹具全部跑 plan() 且结构合法

【验收】swift test 全绿；无 UI/网络/持久化代码；常量只在 KernelConfig；README 写明如何跑测试。
【提交】小步提交，每个模块一个 commit，信息用中文。
```

---

# §4. Phase UI 提示词（贴给 Hermes Agent）——SwiftUI 静态屏

```
【任务】创建 iOS App 工程（SwiftUI，iOS 17+，命名 PLOS），按解压在 design/ 下的 Claude Design Handoff Bundle 实现全部屏幕的静态版本。先读 PLAN.md §1.10 与 design/ 内 README。

【事实源】design/project/ 的主设计 .dc.html（读 HTML/CSS 拿颜色、字号、间距、布局；不要在浏览器渲染截图）。目标是像素级还原到 SwiftUI；只复刻视觉，不照抄原型 DOM 结构。
【本阶段用假数据】所有屏用内置 mock 状态渲染；不接内核、不做持久化、不做通知。

【必做】
1) DesignSystem.swift：把 bundle 的全部设计 token 翻成常量（Color(hex:)、Font、间距枚举）。全工程禁止散写十六进制色值——这是验收硬项。
2) 屏：建月设置（目标增删表单+休息策略+保底学习日预览）；早晨三分支（学习日=能量三选→计划列表+reasoning 卡+灵活休息按钮；节奏休息卡；灵活休息卡）；计划视图（主屏，含极简月进度+streak）；晚间汇报（每项滑块+个人备忘框）；首次运行空态。
3) 横切组件：健康提醒条（可关闭）、达标科目淡化标记、「连续第N天」标记。
4) mock 数据要真实（高数/英语/线代/项目，学5休2+灵活2，与 PLAN §1 示例一致），三种日类型和低谷日各能预览到。
5) 导航贴 iOS 惯例（TabBar 或 NavigationStack），适配安全区，支持浅色模式即可。

【明确不做】不引入 PLOSKernel、不写业务逻辑、无网络、无第三方库。
【验收】模拟器可运行走查全部屏与状态；视觉与 bundle 一致；色值全部来自 DesignSystem.swift；每屏一个 commit。
```

---

# §5. Phase INT 提示词（贴给 Hermes Agent）——接线成真 App

```
【任务】把 PLOSKernel 接入 Phase UI 工程，加 SwiftData 持久化与本地通知，跑通完整每日闭环。先读 PLAN.md §1.8~§1.9。

【接线】
1) SwiftData：按 PLAN §1.2 建 @Model（Month/Goal/Day/PlannedItem/ReportItem/Health/Event），替换全部 mock。
2) 建月流程：保存 goals+restStrategy → 用 RestSchedule 铺整月 dayType 骨架并落库，显示保底学习日。
3) 早晨：读今日 Day → dayType≠study 直接休息卡（systemRan=true 落库）；study 则能量三选 → 组 MonthState → PLOSKernel.plan(state, today) → 计划+reasoning 即时渲染并落库（planned 含 plannedUnits）。
4) 灵活休息日按钮：今日转 flexRest、flexUsed+1、清今日 planned、出灵活卡；骨架其余不动。
5) 晚间：滑块汇报 → 按 §1.9 换算更新每个 Goal.done、habit 记完成日、systemRan=true；备注仅存展示。
6) streak：连续 systemRan 天数，休息日计入；主屏与休息卡显示。
7) 本地通知：UNUserNotificationCenter，默认早 8:00「生成今日计划」、晚 21:30「一分钟汇报今天」，设置页可改时间/关闭；点通知深链到对应屏。
8) 健康提醒：Health 数据本阶段仅留手动字段与展示链路（无录入 UI 也可，硬编码空态），提醒条按 §1.6 阈值渲染。

【日期纪律】"今天"在 App 层取一次注入内核；跨天判定用用户时区日历日。Kernel 内仍禁取当前时间。
【验收】模拟器+真机（免费开发者证书，7天重签可接受）完整跑通：建月→早晨生成（三种日类型、三种能量）→晚间汇报→次日重排（无补作业）→streak 正确累计；杀 App 重启数据完好；0% 日照常运行；通知可达且深链正确。
【明确不做】图表/导出备份/考试录入 UI/小组件（Phase P）。
```

---

# §6. Phase P 提示词（贴给 Hermes Agent）——打磨与扩展

```
【任务】在闭环稳定运行的基础上做增强，按序小步交付，每项独立 commit + 可回退：
1) 进度面板：Swift Charts 实现各科完成率环/条 + 达标线标记 + 「按当前保底节奏预计完成度」直线外推（确定性计算，禁止玄学预测）；负荷曲线（每日计划分钟 vs 实际汇报比例）；streak 日历热力。
2) 考试感知落地：Event 录入 UI（科目+日期），内核考前规则（§1.6）在真数据上生效验证。
3) 数据安全：JSON 全量导出/导入（Files app 分享）；可选 iCloud 同步开关（SwiftData+CloudKit，若配置复杂可延后并说明）。
4) 健康数据最小录入：一键「今天运动了」、熬夜次数简单登记，喂 §1.6 阈值。
5) 锁屏/主屏小组件（WidgetKit）：今日前2项+streak（可选，最后做）。
【验收】每项完成后主闭环回归一遍不被破坏；图表数字与库中数据一致可复核。
```

---

# §7. 你（凯中）手上的非编码事项
- 新建空仓库，放入本 PLAN.md。
- Mac + Xcode 环境（M4 MBA 可）；免费 Apple ID 真机装为 7 天重签，长期使用/TestFlight 需 $99/年 开发者账号——Phase INT 真机验收前决定即可。
- Phase D 在 Claude Design 完成并导出 Handoff Bundle，解压放仓库 `design/`。
- 每阶段结束按验收清单自查，过了再开下一阶段。
