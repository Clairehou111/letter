# Today / Record v2 原生视觉复核

2026-10-10。结论：**PASS，可以作为本轮样板交给用户在 simulator 查看。** 四章构图已经改变记录节奏，不再同时陈列所有字段卡。本结论限于本轮正常尺寸原生样板；不是全 App 的最终高级质感验收，也不改变信息架构或健康数据合同。没有修改产品代码。

## 证据与范围

逐张查看 `screenshots/manifest.json` 中全部 16 张 PNG：Today default、Moment pressed / all12 / saved；Record default / symptom-focused / degree-pressed / zero-saved / pane-selected / daily-life / products / notes / note-saved；Sleep shortcut editor；period range closed / ongoing preview。

Manifest 记录 review7A、402 × 874 logical、1206 × 2622 pixels、DPR 3、textScale 1.0、synthetic fixture、schema 18、16 / 16 captures、render exceptions 0、durable reopen 与 preview cancellation 通过。它们是运行产物记录，不由视觉判断替代。主代理另外报告 analyzer clean、995 PASS / 1 optional SKIP；本审阅没有重复执行全套测试。

实际视频 `screenshots/ios-record-pane-interactions.mov` 为 26.128 秒。查看了 8.6 秒附近的切换帧及 9.0–10.75 秒每 0.25 秒连续采样的八帧：Daily life 的按压底色释放、选中下划线继续存在、日期与底部回看位置保持稳定。这段原生操作比单张截图提供更多状态连续性证据；未测量 FPS、输入延迟、触感，也没有完整逐帧认证全部 26 秒。

## 实际图像观察

| 区域 | 观察与判断 |
| --- | --- |
| Today | 品牌、Today、日期与设置现在同处一个保留的标题区，原先独立 gear 行造成的空档已减少。Moment 是一个直接动作，Body / Sleep 高度相等，Private note 提供真实内容入口。原背景与有限强调色保持一致。默认截图中这些入口和全局导航都完整可见。 |
| Moment | 12 个选项现在有清楚的表面，正文与按钮边界可辨。按压图与释放图不同；保存后 Calm、填色心形、边框和 `Moment saved · tap to edit` 共同构成持续状态，不是只靠瞬时 toast。截图里的十字指示是 fixture 触点证据，不是新增产品装饰。 |
| Record 工具与 rail | 日期已经是一行工具，四章名称无需猜测，当前章通过字重与下划线表达。切换不使标题／日期／底部回看入口改变位置；同屏没有全类别卡片墙。 |
| Symptoms | 默认只有 pinned、搜索、Browse、Daily impact 与 Bleeding 的平面摘要；选症状后六个 degree 成为一个完整操作组。按压与持久选中外观有区别。零值保存图明确显示 `0 ✓`、`Not present`，未记录图为 `Not recorded`；Daily impact 没被自动补值。 |
| Daily life | 五个有名字的行完整可见，Sleep 有已记录摘要，其余明确 `Not recorded`。BBT 没藏入 Other。空白区属于短目录，没有为填满屏幕添加无意义容器。 |
| Products | What I tried、Medication、Supplement、Birth control 分别明确可见；四行构成一个目录，而非四张表单。视觉上保留了具体类别的可发现性。 |
| Notes | 用户文字区域是主任务；空输入的 Save note 为禁用状态。保存图在原位置附近显示 `Private note saved locally for Fri, Oct 9.` 与完整 Undo；底部摘要从 1 note 更新到 2 notes。截图证明显示的状态，不单独证明数据库提交时序。 |
| Sleep 子编辑 | `Enter exact` 和 `5 Restful` 的选中 check 已清楚可读，450 值与日期可见。它仍是原有聚焦编辑器，按钮边框较多，但本轮没有继续把这个子任务扩成新的跨页面改造。 |
| Period range | Start / End 表面清楚。闭合区间 Oct 2–6 的 band 跨两周连续，两个实心边界与今日 9 的空心环有区别。ongoing 图显示 End = Ongoing、No end date yet，band 到今天而不是伪造结束边界；文字明确每日 flow 独立。Save / Cancel / Delete 分别可见。 |

没有发现本轮正常尺寸图中的溢出警示、关键 rail 标签断行、类别丢失或必须先理解大表单才能开始记录的视觉阻断。

## 源码推断与观察边界

定点读取 `record_hub_screen.dart` 的 workspace composition：`IndexedStack` / `Offstage` 保留各 pane，当前内容有独立 `SingleChildScrollView`，固定回看入口在 `Expanded` 内容区之后，隐藏 pane 由 `TickerMode` 停止活动。这支持「切视图而不是重新创建编辑器」的实现意图；隐藏草稿保护仍由行为测试证明，不能从 PNG 认证。

symptom-focused 图的搜索上缘、zero-saved 图的下方 Undo 恰在当前滚动 viewport 边界处截断。源码结构显示它们在可滚动内容区，底部回看行占自己的布局空间，不能据此声称永久遮挡或不可达。Notes saved 的 Undo 在静态图里完整可见。此次没有把自然滚动裁切列成产品阻断。

period band 只从图片确认区间表达；不从高亮推断每一天具有相同流量。持久化、撤销、日界、来源、pending 禁用与隐藏草稿保留，继续依据主代理测试与原生 fixture 记录。

## 下一轮可归并的一批小修，当前不阻断

建议后续只做一个内容与控件清晰度批次，不增加 3D、持续漂浮或新的大卡片：

- 症状编辑器内部的 `Done` 与页顶 `Done` 同屏同名，但分别是结束症状编辑和结束 Record。将局部动作改成明确的 `Close symptom` 或对应产品文案，保留原行为与 key；减少用户对两个完成动作的猜测。
- Today / Daily life 的 Sleep 摘要目前为 `450 min · Restful`。在保持已保存精确分钟值的前提下，显示 `7 h 30 min · Restful` 更符合普通用户的阅读；不改 stored value、不把区间输入转换成精确值。
- Notes 空输入的底线目前近黑，弱于其它目录分隔。下一批统一为现有 outlineVariant 的安静可见状态，同时保留 focus 区别；不要重新引入输入大卡片。

这些是后续提案，不是本轮代码已完成的事实。本轮达到「日期稳定、类别清楚、一次聚焦任务、动作有回应、保存结果可见」的样板目标，可以先让用户实际操作。Patterns／Pattern Record、Cycle archive、My Preparation Plan 与 Care／Kit 的功能重叠由主代理另行审计；此次不据视觉重排或合并它们。
