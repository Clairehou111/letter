# UI pilot 原生视觉复核

2026-10-10；独立 GPT UI 审阅代理。范围仅为已实施的 Today / Record / period range 样板，未修改产品代码，未改写原始全页面审阅。

状态：首轮 12 张原生图片审阅完成；主代理正在实施唯一修正批次，后续原生确认尚未写入本报告。

## 判断

**样板方向成立，已经明显减少后台表单感；建议完成下面一个小批次修正后直接在 Simulator 展示。** 不需要再扩展重构范围。

逐张查看 `screenshots/` 的 12 张原生 iOS PNG，均为 402 × 874、默认文字比例、虚构数据。当前清单记录零渲染异常、durable reopen 与 preview cancellation 验证；这些属于采集／行为证据。主代理报告完整测试 991 passed / 1 skipped、分析器通过、受保护文件无变化。本视觉审阅未独立重跑这些检查。

## 实际画面中已经改善的部分

- **Today**：周期状态、Moment、Body、Sleep、Private note 形成短行动层级。已保存 Moment 变为 `Calm` 与 `Moment saved · tap to edit`，与未记录状态明显不同；所有 12 个 feeling 已集中在一个面板中。
- **Record**：默认页不再同时铺满 Quick picks 与完整分类；日期、pinned、browse 和有名字的类别摘要更清楚。症状 degree 0–5 已成为紧凑的一行。
- **记录反馈**：`Not recorded` 与选中 0 后的 `Not present` 不混淆。保存症状与私人笔记的确认及 Undo 出现在相关区域，笔记不再只有清空输入这一种局部回应。
- **月经区间**：Oct 2–6 的连续底带跨周延续，两个真实边界有端点；进行中改为 `End: Ongoing` 与 `No end date yet`，没有伪造结束日期。今天环与月经底带可区分，面板保留独立每日 flow 的说明。
- **品牌**：深紫色 canvas、克制的强调色和已有导航保留；普通任务使用无衬线层级，明显比旧版重复的大衬线分组更适合手机。

## 唯一建议修正批次

| 顺序 | 真实画面问题 | 小范围修正 | 保持不变 |
| --- | --- | --- | --- |
| 1 | `moment-all12` 的未选中项与 sheet 完全同底，看起来像两列说明文字；period Start / End 也缺少默认可点击外观 | 对这两组控件明确传入稍抬升的现有主题 surface；必要时加极轻边界。继续用已有 selected / pressed 样式，不能只靠点击后的颜色才暴露操作性 | 12 个值、草稿／保存边界、日期状态机与所有 callbacks |
| 2 | `sleep-shortcut-editor` 的 Enter exact / Restful 勾为很暗的颜色，在紫色底上难辨识 | 仅把选中 checkmark 设为当前 `colorScheme.onSurface`，使其与其它明确选中勾一致 | duration 桶与 exact 值、quality 值、字段布局与保存行为 |
| 3 | Today Body 卡两行摘要、Sleep 一行摘要，导致并排底边不齐 | 根据实际内容让同一行两张卡等高，内容仍顶对齐；大字／窄宽保持已有竖向堆叠。避免固定设备高度或为了对齐删掉真实摘要 | 两个深入口、真实摘要、文字扩展与 44 点命中区 |
| 4 | Today 设置占据单独顶部区域，title/date 在下一层，主要内容开始偏低 | 保持 shell 拥有 pinned 设置与预留 header 区域，让 Today title/date/brand 进入共享 header strip；不要把标题覆盖在预留区。若新增 `showHeader: false`，独立 Today 的默认值仍保持原 API 行为 | 系统安全区域、预留 header、设置点击区、既有设置路由与其它页面 header |

建议修改边界：Today baseline 的局部 header、Moment option 与 paired quick cards；shell 的 Today 专属 header strip；period range editor 的 Start / End 控件填色；Record context editor 的选中勾颜色。保留 shell header 所有权，只改相关布局接线，不重构导航。共享 `InteractionSurface` 的全局默认色不必改，避免其它宿主因此意外改变。

这四项可在同一批完成。完成后做相关行为／语义检查，并仅确认受影响的正常尺寸 native 状态；不再启动新的全页面审美循环。

## 证据边界

`moment-pressed` 和 `record-degree-pressed` 可见按压表面变化，保存图可见持久选中与确认文字。彩色十字是测试手势标记，不属于产品。

这些 PNG **不能测量** 80–150 ms 的实际响应、连续动画流畅度、物理触感或真实设备帧率。也不能凭截图证明 range preview 的取消没有写入；该点由清单所述行为验证支持。部分 Record focus 图刻意滚动至 degree，不能据此把标题位于视口外判成导航或焦点 bug。

当前结果适合让用户在 Simulator 实际体验；它是完成一个获批准样板的结果，不等于全应用视觉优化或发布验收结束。
