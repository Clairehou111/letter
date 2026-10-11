# Record V3 原生构图与动效复核

2026-10-10。**V3 的有限目标有实际原生证据支持，可以交给用户继续操作；没有发现阻止展示这轮 Record 样板的视觉问题。** 这不是用户已接受高级质感的声明，也不批准用户随后要求优化的 Medication / Supplement / Birth control 管理页。V2 的历史 PASS 与用户否定保持原样：V2 只完成内容分组；V3 才出现前景层次与可见的空间接续。

没有修改产品代码，没有扩展页面、尺寸或临床范围。

## 最终产物，而非失败尝试

本次依据 `v3/screenshots/manifest.json` 的冻结 production fingerprint：

`79a3afd21d53ce81ef2cc17d157964b9b17f1e687923ff4eabe3889c418a4892`

28 / 28 个原生状态，正常 402 × 874 logical、DPR 3、textScale 1.0；synthetic fixture，schema 18，render exceptions 0。child preview cancellation、period preview cancellation、durable reopen 均为 true。这些是 fixture 记录，不是从截图猜测的数据库行为。

首轮 20 项曾因精确体温被同步回调改写而失败，保留于 `v3/attempt-1/screenshots`；它不是本次通过的运行。已逐张审阅首轮 20 项，再逐张查看最终版本 13 张新增／变化状态；其它 15 张 PNG 与已审阅图逐文件 SHA-256 完全相同。最终精确输入图明确保留 `36.555`。按这个证据覆盖全部 28 状态，没有把旧 clip 代替新 clip。

新 `v3/screenshots/ios-record-pane-interactions.mov` 经 ffprobe 为 **39.258333 秒**。查看完整范围的每两秒 overview，并分别查看 1.3–2.3 秒症状展开、9.0–10.0 秒工作面切换的每 50 ms 采样连续帧。采样只用于辨识实际状态关系，不能据其数量宣称产品 FPS、输入延迟、physical haptics 或完整性能验收。

## 对照 V3 目标：实际看到的变化

| 目标 | 原生观察 | 判断边界 |
| --- | --- | --- |
| 一个有两层背衬的前景面 | Record default 静止图可见两层露出的顶缘和独立温暖前景面。四章内容都在同一工作区，日期、rail、底部回看的位置稳定。 | 已从实际图确认。背衬不是健康分数或历史数据卡。 |
| 类别的空间接续 | stage-90 图中前景面处于偏移、缩放与透明度中间态，边缘与背衬的相对位置改变。新 clip 连续帧出现 Symptoms → Daily life 的交接与收敛；overview 也覆盖 Products、Notes 与反向返回。 | 不是只有 underline 改变。录像未精确测量每次过渡耗时，也不声称完全复刻示例的 3D 堆叠。 |
| 由发起项进入专注编辑 | 新 clip 的 Cramp 触点之后，过渡标题从该项附近开始，pinned / search 降低重量，Change symptom 与 degree 进入。origin-reveal 图保留了中途的名字位置；完成图变为 Cramp 的专注任务。 | 实际实现是名字的定位接续加编辑区展开，不是完整卡片几何 morph。不能把它描述成逐角追踪的卡片变形。 |
| 分开局部与全局完成 | 专注图的 `Close symptom` 与页顶 `Done` 清楚区分；Change symptom 有方向箭头。 | 解决两处同名 Done 的歧义。收回的具体来源路径仍以行为／视频完整检查为依据。 |
| 保存动作本身改变 | Notes 的按钮从 Save note 变为 check + Saved；原输入附近有真实日期的 local saved 与 Undo，底部 notes 数量更新。新 clip 中也能看到输入 → Saved。 | Saved 状态实际可见；没有从 overview 单独认证极短 pending 的完整过程。成功时序依据 durable callback 测试。 |

因此 V3 已具备用户参考视频中「前后层次、内容接续、按钮结果」的可用转译。工作面留白、固定工具与专注内容现在共同形成一个任务，而不只是 V2 的四个平面目录。不能仅凭这点代替用户对美感与手感的最终判断。

## 全部状态的可读性与控件家族

- **Today / Moment，4 项**：共享标题区、等高 Body / Sleep、Private note 和全局导航完整可见；12 feeling 选项有可辨表面；按压与保存后的持续选择有区别。fixture 十字是捕获的触点说明，不是产品动效。Build17 的背景与强调色保持。
- **Record workspace，11 项**：四类名称可读；Symptoms 默认 pinned / search / Browse 与两条平面摘要，专注态减少竞争内容。degree 的六个图形有清楚端点标签，明确 0 后显示 `Not present`，之前是 `Not recorded`；没有自动补 Daily impact。保存 Undo 在当前操作附近可见。面内的 Bleeding 在某个滚动位置被 viewport 边缘截断，未据此声称永久不可达。
- **Sleep / Activity / Appetite / Event，4 项**：degree 的图形表面、端点说明、选中边界和当前完整标签形成一致家族。明确 zero 与可选未填仍不同；三个等级的 Moderate 有自己的当前值文字。Duration 是有可读区间文字的独立尺度，并保留 Enter exact；不是把 interval 伪装成精确分钟。
- **Temperature，2 项**：wheel 的中央值突出，手动输入清楚，方法／时间／干扰因素独立有名字；修复后精确字段保留 `36.555`。修复的是 authoritative input 被写坏的问题，不能把 UI 的两位轮值描述成三位精度。
- **Medication / Supplement / Birth control，3 项**：实际 native form 分别有家族名称、实际开始／结束日期与具体类型，没有隐藏为 Other。当前图仍是长表单，不能以此批准新的产品管理与多 use-period 布局；后者按用户新要求另做 V4 验收。
- **What I tried / Check back，2 项**：动作、完成／不能尝试、duration、检查结果与 degree 仍分开；明确 zero 有完整文字，Skip 保留动作的选择可见。没有把检查结果变成疗效结论。
- **Period，2 项**：closed Oct 2–6 区间跨周连续；today 空心环与实心边界区别清楚。ongoing 显示没有结束日期，band 到今天，文字明确 daily flow 保持独立。Save / Cancel / Delete 可读。

## 源码推断，不冒充原生证明

定点读取 `record_workspace_stage.dart`：320 ms controller、位移／缩放／fade、背衬 lift、稳定 key 的 faces，只有 active face 接收输入／语义，非当前 ticker／可见性受控；Reduce Motion 移除空间交接。这解释观察到的空间关系以及保留挂载状态的意图，不证明所有快速反向操作和无障碍场景已经实机测量。隐藏草稿、日期 guard、selected-day、source、Undo 和精确输入都继续依据相应行为验证。

当前没有额外要求一轮全页面重拍，也没有重新加入大型装饰效果。唯一直接关联这次精度修复的显示建议是：exact field 为 `36.555` 时，wheel 同屏显示 `36.56`。权威输入现在正确，数据损失阻断已消除；仍建议在有额外小数的 exact 模式弱化／隐藏两位 wheel，或明确其为两位近似预览，让用户不必猜哪一个会保存。此建议不授权再舍入 exact value。

## 用户新要求的产品管理：待 V4 原生验收

另已实际查看用户的 `Screenshot 2026-10-10 at 20.16.05.png`。当前管理图把 Add、三种 daily use、追加使用、改详情、改结束、Archive、过去 entries 都摆成同等橙色动作。这会让短记录再次成为后台管理清单。建议有限变化：

1. 日期是一行工具，之后先读 product name、实际 use period、selected-day 已存状态。多个产品默认是紧凑命名行，只展开一个当前任务。
2. 展开后主要呈现这一天的单次记录；真实已存状态持续选中。历史与 past use periods 一处折叠；不把已结束／已 archived 的事实混进当前使用选项。
3. 其它动作进入明确命名 More actions sheet；`Add an additional entry` 必须显示 product、记录日与该日已有 entries，再明确提交一个额外 entry。它不能看起来像再次选择 daily shortcut。
4. End use / Change end date 明确改实际边界；Archive use period 的确认说明从 active list 收起、实际日期与旧 records 保留。按现有 API 不暗示可恢复，不把 Archive 等同结束或删除。
5. 新增使用家族专用 Add 文案。表单先明确名称／方法身份与实际 use period，optional classification 可进入短 picker；避免大分类 chip cloud 先于用户最想填的产品身份。剂量与单位靠近，保持原字段、可选性与类型。

以上是基于旧管理图的提案。V3 的原生结果不包含这些 V4 管理状态，不能用本报告声称新产品管理已验收。
