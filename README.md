# PLOSKernel

Personal Learning OS (PLOS) — 纯 Swift 本地调度内核。

## 运行测试

```bash
swift test
```

## 结构

```
Sources/PLOSKernel/
  Models.swift          // §1.2 数据类型（Codable）
  KernelConfig.swift    // §1.5 常量集中管理
  RestSchedule.swift    // §1.3 休息骨架→学习日轴
  Scoring.swift         // §1.4 进度/压力/衰减打分
  Allocator.swift       // §1.5 预算分配
  Rules.swift           // §1.6 连续性/考前/多样性/健康提醒
  Reasoning.swift       // §1.7 模板 reasoning 拼装
  Scheduler.swift       // §1.8 编排 + 公开接口 plan(state:today:)

Tests/PLOSKernelTests/   // XCTest（30 tests）
Fixtures/               // 7 个 JSON 夹具
```

## 公开接口

```swift
let plan: DayPlan = Scheduler.plan(state: monthState, today: someDate)
```

`today` 由调用方注入；内核内禁止 `Date()` 或任何副作用。同输入必同输出。

## 验收清单

- [x] swift test 全绿（30 tests）
- [x] 无 UI / 网络 / 持久化代码
- [x] 常量只在 KernelConfig
- [x] 纯函数纪律：无 Date() 参数注入
- [x] 7 个夹具全覆盖 7 种边界
