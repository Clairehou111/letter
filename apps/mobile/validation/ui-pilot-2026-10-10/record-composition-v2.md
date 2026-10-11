# Record v2：一个日期，一次短记录

2026-10-10。设计提案，可用于接下来的 Flutter 实施；本审阅没有修改产品代码。保留已批准 Today 样板、Build17 Quiet Dusk、已有健康事实与导航合同。

## 设计判断

用户指出的「还是很多排好的卡片」成立。首轮 Record 已减少重复字段，但它仍是一条纵向容器清单：日期卡、症状区、Daily impact 卡、Bleeding 卡、多个 Context 卡、Products 卡、Notes 与 log。用一致圆角把它们排好，只改善样式，没有改变使用节奏。

**推荐一个明确结构：日期作为工具，四个有名字的章节作为导航，每次只显示一个章节的主要内容。** 页面名称仍是 `Record`。用户先决定今天要记哪一类，再完成一件事；真实已保存的内容成为轻量的回看入口。首屏必须能够看懂「哪一天、在哪一章、下一步做什么」，而不是同时展示全部类别的外框。

这轮是内容构图与互动结构的变化，不是再给卡片添加悬浮、阴影或淡入。

## 参考证据：取机制，不取表演

已查看 `/private/tmp/letter-motion-references/` 两段用户提供视频的全部 overview，以及选定单帧。`sources.json` 对应原始本地文件；视频 1 长约 148 秒、视频 2 长约 88 秒。这是具体画面机制的观察，未对示例 App 的真实性能作背书。

| 实际参考画面 | 适用的设计机制 | 转译到 Record |
| --- | --- | --- |
| 视频 2 的分类联动滚动 | 用户始终知道当前类别，内容位置与导航状态有关系 | 固定四章 rail 与唯一 active section；选择时下划线与内容同时回应。此轮用明确章节切换，不再叠加一个竞争的 scroll-spy 状态机 |
| 视频 2 的面板分层 | 背景上下文安静，当前任务占据前景 | 症状浏览与子编辑是聚焦面板；保留日期／来源关系，避免完整页面里继续套字段卡 |
| 视频 2 的按钮状态形变 | 控件根据真实运行状态改变，而非始终只有一个文字按钮 | Notes 保存动作有 pending / saved / retry；形变不先于持久化结果，不增加无关的二分按钮 |
| 视频 2 的卡片切换／聚拢 | 选择与空间关系连续，下一项不是突然出现 | 章节内容短距离变换并保持工具条稳定；不把健康记录做成可甩走的 3D 卡堆 |
| 视频 1 的分层／卷轴／黏连 | 显示「层级、中心、连接」的关系 | 只借清楚的前景焦点与连续反馈；不采用健康数值的透视卷轴、随机环境光或必须拖动的液滴 |

主代理进一步检索的产品参考：[Gentler 2025 界面更新](https://gentlerstories.com/newsroom/20250317amoreintuitivestreak)、[Apple Design Awards](https://developer.apple.com/design/awards/)。它们用于研究个人状态与主要动作的组织。具体设计适用性是本提案的推断，不代表这些产品有同样的健康记录能力，也不把其视觉外观直接复制到 Letter Within。

已实际查看这两处官方素材的本地图片 `gentler-streak-2025.png` 与 `moonlitt-official-2026.jpeg`。Gentler 的时间路径、Today’s Activities、For You 与 Past Activities 各有职责；恢复插画、睡眠微图、周期状态、回顾与运动行使用不同内容尺度。可借鉴的是「一个主要状态，加上有区别的下一步」，不是卡片数量或健康评分。Record 的编辑器、已保存事实与导航也应有不同重量，不能仅用同一种外框区分。

Moonlitt 的三张界面都把月亮与时间路径作为主体，时间／位置标签与少量工具围绕它，底部仅保留当前状态。可借鉴的是稳定的内容焦点和退后的工具：Record 中当前症状与 degree、或用户自己的文字应成为主体，日期与 rail 服务于它。不要移植天体、3D 旋转或月相来暗示健康事实。这些静态官方图片证明可见层级，获奖与图片均不能证明我们的交互性能或适用性。

## 正常手机的具体构图

```text
Record                                      Done
calendar  Fri, Oct 9  chevron        Recording today

Symptoms    Daily life    Products    Notes
────────

当前章节的一个主要任务
  Symptoms：pinned / search → 选一个症状 → degree
  Daily life：清楚的命名行 → 聚焦子编辑
  Products：清楚的命名行 → 聚焦子编辑
  Notes：自己的文字 → 保存

Saved on this day                          chevron
真实摘要；需要时展开完整来源与编辑操作
```

工具条与章节 rail 不随章节内容跳动。日期是一行可以点击的工具，不再是一张大卡片；当前日期与 Today / Later recall 清楚相邻。四章是独立记录任务的目录，不是全局导航的新目的地。

在正常宽度使用一个横向有名字的 rail，44 点以上点击区。窄宽／大字可以横向滚动 rail，并把当前章滚到可见位置；不得缩小字体、缩成无标签图标或把 Products 放进 `More`。active 用短下划线和字重表达，不把每个 tab 都包成胶囊卡片。

## 每章的内容职责

| 章节 | 默认内容 | 开始编辑以后 | 禁止重新出现的结构 |
| --- | --- | --- | --- |
| Symptoms | 2–4 个 pinned；一条安静的搜索／Browse 入口；Daily impact 与 Bleeding 两个有名字的平面摘要行 | 当前症状名成为焦点，六个 degree 构成一个紧凑图形轨道，选中完整文字在其下；impact / bleeding 进入对应短控制区域 | pinned、Quick picks、完整分类同时重复陈列；degree 外再套一张大字段卡；五张纵向流量卡 |
| Daily life | Sleep、Activity/rest、Appetite/cravings、Significant event、Basal body temperature 的命名行；每行只用真实摘要和进入箭头 | 一个现有 context editor，日期与原始字段语义保持 | 每行独立大圆角容器、重复 `View or add a dated record` 说明、泛化成 Other |
| Products | What I tried、Medication、Supplement、Birth control 明确分别可见；需要的已保存内容可回看 | 对应已有 intervention editor；产品、行为与 check-back 保持各自类型 | 把所有实体合成一个表单、把未录入视为未使用、隐藏具体类别名 |
| Notes | 自己的文字作为主内容；安静输入区域、字符上限和稳定保存动作；已有同日 notes 可展开编辑 | 保存确认与 Undo 就在输入附近；新增／编辑均使用既有来源与条件恢复 | 强制选择健康标签；大空卡片；保存后仅清空输入而无附近回应 |

平面命名行使用统一的文字起点、紧凑行距、细分隔线和少量同系统图标。它们属于同一内容面，不是各自拥有阴影与圆角的卡片。标题、当前值和动作有明确字重差异；强调色只给当前操作与选中，不给每一条静态名称。

Symptoms 不选症状时，优先让 pinned 提供下一步；选定之后让症状名与 degree 成为首要视觉。degree 沿用既有 0–5 图形；`Not recorded` 与明确 0 的 `Not present` 不混淆。其它类别不同时在下方全部展开。

Notes 是唯一以用户文字为主体的一章，可比其它章节留更多呼吸空间。Daily life / Products 是快速查找的列表，不能为了统一而强行变成 Notes 那样的大白区。构图统一的是任务关系，不是所有区块的外形。

`Saved on this day` 仅是一条轻量回看行和真实摘要，按需打开完整同日记录。它不能成为永久的第二张大面板，也不能创造跨类型「健康分数」。默认不在每章复制整份 dated log；完整编辑／删除／合法 Undo 与来源仍可达。保存反馈保留在正在操作的章内。

## 动效：章节与结果的连续性

以下为目标配方，尚未在实际设备测量。

- **按压**：沿用已实施的 80 ms 左右表面／轻 scale 与 120 ms release；触碰即开始，取消即恢复。不要等待 haptics。
- **章节切换**：仅改变当前可见章，已挂载的章保留草稿，点击后立即改变 active 状态，不弹丢弃确认。下划线约 150–180 ms 从当前位置到新位置；内容约 180–220 ms 的短淡入与不超过 8–12 点的横向变化。不是整页飞入，也不是所有行逐条排队入场。
- **症状聚焦**：名称与六位 degree 在同一章节内出现，保持搜索／pinned 与该内容的关系。已有选中状态立即呈现；不要等待展开动画才允许点击。
- **子编辑前景**：沿用现有原生 route / sheet 关系，短过渡约 240–300 ms。任务进入时背景上下文降低重量；不做倾斜透视、文字模糊或多个深度层。
- **真实保存**：pending 就在相关动作上；持久化成功后才出现 check / Saved 与可用 Undo。反馈改变区域状态而不是把一串消息插到页面顶端。失败保留草稿与重试；新草稿开始时，旧 saved 状态不继续冒充当前结果。
- **Reduce Motion**：取消空间位移与 scale；保留即时下划线、字重、选中、pending、saved、error 和 live-region 表达。所有过渡可中断、可改向，不排队重放旧操作。

首批不加入章节 swipe；点击 rail 即可完成。以后若加入 swipe，同样只切换可见内容并保留草稿，不能让滑动写入／删除记录。换日、Done 与子编辑仍必须执行草稿保护。滚动仍只滚当前内容，不靠滚动距离推断健康状态。

## 状态与导航边界

以下草稿切换行为按主代理已记录于 active ui-pilot spec 的产品决定修订，取代本提案早先「换章也确认丢弃」的建议；这是待原生验证的实施合同，不是已经从截图观察到的行为。

1. 建议新增本地 presentation enum：Symptoms / Daily life / Products / Notes。active section 是当前 Record route 的临时状态，不持久化为 Today 选择，不进入数据仓库。
2. `_session.session.selectedDate` 是所有章节的同一日期。换章不换日、不写数据；换日仍走现有 future / draft / save guard。
3. 换章是无破坏的视图切换：各 pane 保持挂载，note／picker 草稿、控制器与选择保留，不提示丢弃、不清空、不隐式保存。仅当前章可响应指针／辅助功能与活动动画；隐藏状态仍由现有会话管理。日期、Done 或打开子编辑时，现有 guard 必须检查其它隐藏章的草稿；Keep editing 保留草稿，只有明确确认 Discard 才丢弃对应未保存内容。
4. 正在保存时禁用 rail 和冲突导航，不反复提交；async 返回仍使用既有 mounted / generation / session 状态。旧日期或旧编辑器的结果不得覆盖新操作。
5. Today Body intent → Symptoms；Today Sleep intent → Daily life，并按现有意图打开 Sleep editor；Today note intent → Notes。`initialSymptom`、来自 Patterns 的 symptom / date 和原始 origin 同样映射到 Symptoms。
6. 从 Today、Cycle、Care、Patterns 进入，完成／返回仍回原 route；全局四个目的地与 Record 行动不变。日历依然是单日选择，月经边界依然是独立 range。
7. repo、clock、provenance、0／missing、source ID、product/action/check-back 类型、条件 Undo、提示后合并月经、native file handoff 与付费规则全部保持。

## 首批实施边界与验收

主要修改 `record_hub_screen.dart` 的 composition 与局部 section 状态；按需调整 `observation_picker.dart` 的聚焦呈现，并使用现有 `InteractionSurface`。新增 rail helper 可以留在 Record presentation 内。数据 repository、clinical 算法、提醒、账户与 Today 构图不因这轮 Record 改动而重构。

保留 `RecordHubScreen` 现有公共构造参数与 callbacks、`RecordEntrySection` 入口合同、原 key 的行为职责。可以增加明确的章节 keys 与 tab 语义；不要用 UI label 字符串识别数据类别。

最低有意义验证：

- 正常手机初始 Record 首屏展示日期、四章 rail 与 Symptoms 主任务，没有纵向的大卡片墙。
- 四章所有有名字的类别可达；大字 rail 仍可操作；屏幕阅读器能识别当前 tab。
- 在 Notes 输入未保存文字，切到 Symptoms 再返回，文字保留且没有丢弃提示；degree draft 往返同样保留，换章不写数据。
- 草稿所在章隐藏时，换日、Done、打开子编辑仍触发保护；Keep editing 保留内容，只有明确确认 Discard 才清理对应草稿。保存 pending 时 rail 禁用且不重复写入。
- 明确 0、改值、重复选择移除、Undo、储存失败／重试、历史日期与 midnight 边界保持既有合同。
- Today Body / Sleep / Note、Patterns initialSymptom、返回来源 route 正常；完整 dated log 与具体产品类别没有消失。
- Reduce Motion 下仍能理解选中与保存；一段真正对应该原生 route 的操作演示观察章节切换、聚焦、保存。静态 PNG 只证明构图和状态，不证明帧率与触感。

下一步应直接实施这个有限结构，再以一个正常尺寸原生操作流程检验。不要回到「给每条记录换一款卡片」或一次堆叠全部视频效果。
