# Letter Within：Build17 原生界面与交互审阅

日期：2026-10-10。审阅者是独立的 GPT UI/Flutter 交互审阅代理。本轮产出是设计建议，没有修改产品 UI 代码。

## 结论

用户对「后台表单感」的判断有实际画面依据。深紫色背景、暖白文字和 Care 的场景图形已经形成了品牌基础；问题集中在信息排序、控件语言和反馈覆盖，而不是缺少更多背景效果。

推荐统一方向：**保留 Quiet Dusk，把页面改成能够立即回应触摸的移动端状态与行动界面。** Today 用来了解今天并开始一个短动作；Record 用来完成一个有日期的记录；Cycle 用连续区间表达月经开始与结束。较长的说明、方法学与完整字段仍可访问，但不应成为每个页面的第一件事。

第一批同时做 **Today、Record 的症状交互、月经区间日历**。先建立一套可在 Simulator 里直接体验的样板，再推广到其它页面。不要把所有选项都包成大卡片，也不要通过增加呼吸、发光、弹跳等循环效果解决表单感。

## 证据与适用范围

- 工作分支：`feat/record-hub-build17-2026-10-10`；基础为已发布 Build17 的提交 `cf12e70791c14acb2735415b8c51b1ce6047fac2`，当前还包含 Record Hub 的开发修改。这不是一次新的 Build17 发布。
- 图片来自本目录 `screenshots/` 的原生 iOS 测试采集，使用虚构本地数据。逻辑尺寸 402 × 874，像素尺寸 1206 × 2622，默认文字比例 1.0。
- 已逐张查看共 37 个原生状态画面，并复查最终版本的付费 Patterns：覆盖 Today 与 More、Record、单日日历、症状选择、Daily impact、Bleeding、笔记按压／保存、Sleep、Cycle、月经日期编辑与开启过程、Care 首页与场景、check-back、Patterns、Pattern Record、Preparation、Settings、Reports 与 Clinical matrix。
- 本文以 **实际画面观察**、**代码推断**、**设计提案**区分证据。静态截图能证明层级、选中状态和一次按压的可见反馈；不能证明实际触感、每帧流畅度或保存耗时。
- 按压图片中蓝色／绿色／粉色十字为测试手势标记，不是产品设计。最终文件名 `period-start/end-material-date-picker` 正确表示原生 App 内的 Flutter Material 日期对话框，不是 iOS 系统日期控件。
- 最终 `screenshots/manifest.json` 为 fixture revision 3：37 张图片，`interactionIssues: []`、`renderExceptionCount: 0`。较早 fixture 的滚动问题保留在 `iteration-1/2` 历史中；最终采集完成不等于全部原生发布验收完成。
- 最终 Patterns/Clinical 使用合成的本地 activePaid entitlement 进入实际 App UI；不是一次真实购买。初次相同免费入口保留在 iteration 历史，最终 20/21 已显示数据视图。未展示的其它 Care 场景与全部编辑器，相关判断仍仅限代码推断。
- 视频已做本地抽帧检查，但当前 `native-interaction-review.mp4` 多个样本为 Simulator home，仅部分样本显示 Today。它目前不能证明本次完整交互流程或帧率表现；交互判断采用实际按压／松开 PNG、路由中间帧与代码。该限制不影响静态层级审阅。

## 目前最影响质感的五件事

| 优先级 | 证据 | 问题 | 具体改法 |
| --- | --- | --- | --- |
| P1 | 实际画面 02、06、07 | Record 中同一症状出现在 pinned、Quick picks、分类列表、已保存列表；长页面像字段目录 | 默认显示 pinned 和当日已记录摘要；保留搜索；完整症状分类进入有名字的浏览面板，不在首页重复铺满 |
| P1 | 实际画面 01、12、20、23 | 页面主体前插入若干居中橙色链接，加上较大顶部留白，打断标题与主要内容的关系 | 标题、状态、主动作按统一结构组织；归档、历史、计划等次级入口放进对应有名字的列表组或工具行 |
| P1 | 实际画面 13–15 | 月经开始和结束通过两个互不相连的日期弹窗编辑，用户看不到自己选择的完整区间 | 用一个连续区间日历，同一面板内显示开始、结束或进行中状态；保留最终明确保存与必要的影响确认 |
| P1 | 实际画面 07、09、11、25、26 | 选中状态不统一：有橙色边框、白色勾、深色勾，且部分深色勾在紫色底上很难识别 | 统一选中底色、边框、对比清楚的勾与语义状态；按下、草稿选中、正在保存、已保存分别可辨识 |
| P2 | 实际画面 02、10、22–26 | 大量重衬线标题、描边胶囊、解释段落争夺注意力；卡片层层相似 | 衬线用于页面主标题／少数情绪表达；功能分组用较小的无衬线标题；减少非必要外框，将完整解释移到明确的展开项 |

尤其要修正实际画面 06 中的 `stable identifiers, never words`：这是数据实现约束，不是用户需要阅读的健康记录说明。用户需要看到的是记录发生在哪一天、是否后来回忆、目前保存了什么。该文案的删除或替换属于提案，应保留其底层数据合同。

补充画面让问题更具体：09c 的 Bleeding 五个选项被做成五张纵向大卡片，几乎占满一屏；01c 的相同流量概念却是一个紧凑的五选项行。两者必须统一为适合手机的离散选择，不能把「卡片」当作默认答案。10b–10d 中笔记保存后输入清空、记录出现在 log；页面上方的确认不在当前视口内，反馈应靠近用户刚操作的保存区域。27 中 Clinical matrix 的 `Irritability`、`Cognition` 和 `symptoms` 在普通手机宽度下出现词内拆行；这是需要修正的可读性问题，不能靠更多图表入场动画掩盖。

## 第一批样板的明确设计方向

### Today：今天的状态与几个短动作

**实际画面观察：** 当前首页先展示较大的品牌标题、Cycle day 卡片、开始月经的卡片和 Pattern Record 链接，然后才进入 Moment。Moment 的七个胶囊里有一个 `+ More`。01d 明确显示，More 面板里是另外六个 Moment 值：Energized、Tender、Hopeful、Overwhelmed、Exhausted、Physical，不是所有 Record 类别。首页随后继续展开 bleeding、pinned symptoms 等问答，因此用户的「现在想做一件小事」没有得到足够明确的组织。

**设计提案：**

1. 顶部：`Today`、日期、设置入口。使用系统安全区域内的统一导航间距；缩小仅用于装饰的顶部空白。保留 Letter Within 名称的品牌识别，不必每次打开都把它变成最大的操作页标题。
2. 紧凑的周期状态卡：当前 day、已记录／预计标记、下一次预计区间。开始或结束月经的操作与这张卡的实际状态关联，避免成为额外一张同样重量的问答卡。
3. 一张 **Moment 状态卡**：尚未记录时是 `How is this moment?`；已记录时显示保存的 feeling 与编辑入口。整张卡有清楚的按压反馈，点击进入一个聚焦的 feeling 选择面板，显示全部 12 个现有值。选择后卡片立即显示选中／保存过程，成功后呈现真实已保存状态。这里记录今天当下的 Moment，不提供回填过去 Moment 的新入口。
4. 少量有名字的快捷卡：例如 `Body`、`Sleep`、`Private note`，显示今天是否已有记录以及简短真实摘要。它们进入对应的 Record 子编辑器，不在 Today 展开所有字段。没有数据时用 `Add` 或简短提示，不假装「一切正常」。
5. 有资格且有证据时出现 Comfort Window／Comfort Kit 的行动入口；没有足够证据时保持诚实的缺省。Pattern Record 的状态可归在一个轻量入口，避免挤走每天最常用的动作。

这是对 `+ More` 的**明确替代提案**，不是已实施的改变：把全部 feeling 放入同一个聚焦面板，使首页保留一张完整状态卡。用户提出「每项做成卡片」揭示了可发现性问题，但把 12 个 feeling 和全部记录类别都变成首页大卡片，会重新得到一堵后台式选项墙。卡片应承载一个状态与一个主要动作，而不是仅给每个字段加一个外框。

保留四个内容目的地和全局 Record 行动。快捷卡打开时保留来源页面，完成后回到 Today 并更新真实摘要；完整、历史日期与全部类别仍由 Record 提供。

### Record：先选一个东西，再完成一个短记录

**实际画面观察：** 首屏同时出现 pinned、搜索、Quick picks 和 Physical 分类，Cramps 多次重复。进入症状后，又出现外层症状列表、一个较大的症状面板、六个多行胶囊和 Daily impact 面板。说明正确但过量，用户一直在读「怎样填表」。

**设计提案：**

- 顶部使用紧凑日期工具条，含日期、`Today`／`Later recall` 状态和可见日历入口。日期改变后，标题与已保存摘要保持空间连续；草稿保护继续存在。
- 日期工具条下面先显示 pinned 的 2–4 个症状和此日的真实记录摘要。搜索只负责找一个症状；`Browse symptoms` 打开清楚分类的浏览面板，避免同一页重复陈列症状。
- 一次只打开一个症状编辑区域。正常尺寸上采用六个紧凑的离散 degree 位点：0–5 的既有图形、当前选中的完整文字；小宽度或大字时自适应换行，不能压缩到小于 44 点的点击区。
- 保留 0 的明确 `Not present`，与没有记录分开。重复选择当前已保存 degree 的删除语义继续保留，并有移除／Undo 反馈，不能看起来像又保存了一次。
- Daily impact、Bleeding 和每一种其它类别用可辨识的命名行组织：标题、真实摘要、展开／进入箭头。`Medication`、`Supplement`、`What I tried`、`Birth control`、`Basal body temperature` 等必须各自明确可见、可访问；不能埋入 `Other`。
- 私人笔记采用一个有名字的安静输入面板，保存与字符限制仍保留。Dated log 的真实摘要上移到对应类别内；完整历史仍可访问。
- 一次保存只在相关区域显示反馈，避免在页面上方插入一串文本使所有内容跳动。Undo 只在存在合法 Undo 时出现，并继续使用条件回滚，不能覆盖之后发生的新写入。

### Cycle：月经的开始与结束就是区间

**设计提案：** 单日 Record calendar 与月经 range calendar 共用日期单元、字号、命中区、月份工具条；二者保持不同的交互状态机。

| 模式 | 可见内容 | 点击行为 | 提交 |
| --- | --- | --- | --- |
| Record 单日 | 一个当前选中日期；今天细环；已有记录小点 | 点一个合法日期即选择；日期没有变成区间 | 保留现有单日选择与草稿判断 |
| 月经区间 | 上方有标签的 Start / End；区间连续底带与两个端点 | 第一次确定 Start，第二次确定 End；直接点 Start/End 可编辑对应边界 | `Use these dates` 只确认草稿；现有最终 Save 与影响预览仍为写入边界 |
| 进行中月经 | Start + `Still bleeding`；到今天的开放延续形态 | 不要求补一个结束日期 | 保存 `endDate = null`，不能伪造今天为结束 |

视觉规则：区间内的带状背景在一周内相连，仅真实起止端点有圆头；跨周在边缘延续。采用克制的月经语义色，不让每个日期都成为强橙色按钮。今天环、记录点、选中边界、已有月经区间与预计区间有不同形态和文字说明，不能只靠颜色。

交互规则：选择 End 时点到早于 Start 的日期，可按清楚的指示重新开始选择 Start，或在编辑端点模式中呈现现有校验；不能无提示地交换并保存。跨月选择保留起点，月份切换有方向与短过渡。拖动选择可作为以后可选的增强，首批无需依赖拖动；点击和屏幕阅读器操作应能完成相同任务。

**必须保留的数据行为：**

- 区间带只表达月经开始／结束边界。它不能给区间内每天补写同一个 flow 值；每日流量、None 与 missing 仍是独立事实。
- 同一天开始和结束是有效区间。未来日期不可写入；重叠、已有进行中月经、过期确认均走现有校验。
- 相邻区间的合并仍需要现有明确确认，不得根据动画或颜色自动合并。
- 修改边界后，症状、Moment、notes 与原始日期保持不变；影响 bleeding/reflection 关联时继续提供现有预览与确认。

## 全页面的组件与交互映射

以下为一套统一提案，不是并列风格菜单。

| 页面 | 推荐组件结构 | 适合的动效 | 保留的行为／证据限制 |
| --- | --- | --- | --- |
| Today | 紧凑周期状态、一个 Moment 状态卡、少量命名快捷卡 | 按压回馈；保存后状态变化；条件 Care 入口短展开 | Today 仍表示真实今天；Moment 不回填；不制造正常状态 |
| Record | 日期工具条、pinned、一个症状编辑区、命名类别摘要行 | degree 选中；展开；真实保存确认；Undo | 0 与 missing、来源、草稿保护、条件回滚 |
| Record 日历 | 单日网格与统一月份工具条 | 月份短方向切换；日期按压 | 不改成范围选择 |
| Cycle | 环图作为一个主视觉，紧邻真实状态／主动作；归档移到次级组 | 被选日的轻反馈；range 连续填充 | 实际／预计区分；独立每日 flow |
| Period 编辑 | 一个有 Start / End / Ongoing 的区间面板 | 起止端点选中；范围带更新；保存后返回 | 保存影响预览与必要确认，开放 end 保留 |
| Sleep 等子编辑 | 统一的聚焦编辑器、字段组与稳定保存区域 | 离散选择、exact 输入展开、保存状态 | 可选字段、桶与精确值不混淆；选中勾对比清楚 |
| Medication / Supplement / What I tried / BBT | 明确有名字的入口和相应输入，不用笼统 Other | 行按压、编辑进入、保存返回 | 本轮未逐个截图；结构建议来自代码；保留具体数据合同 |
| Care 首页 | 同一故事下的场景入口；统一大小、对齐和语气；Kit 成为有名字的状态入口 | 入口按压；场景进入连续变化 | 保留现有 Care 作者化图形与安全出口；避免变成问卷 |
| Care 活动场景 | 维持沉浸场景、短文案、可退出控件 | 呼吸／释放只服务此场景；控件打开立即响应 | 不把此类慢节奏动效复制到记录表单；17 可能处于文案过渡，不据单帧判定模糊 bug |
| Care check-back | 简洁三选一、可选更多、稳定保存与 Skip | 被选曲线／表面改变；保存确认 | check-back 是可选；Care action 与结果各自真实保存 |
| Patterns 免费入口 | 统一页面标题与轻量真实状态；付费入口有明确内容说明 | 普通按钮按压与进入 | 初次 iteration 的 20/21 是同一免费入口，最终付费画面另行观察 |
| Patterns 数据视图 | 保留当前三段阅读导航；压缩标题前工具链接与介绍，图表、证据量、来源详情分层 | 选点立即高亮与详情；短筛选变化 | 最终 20/21 已观察；1.5 秒 chart reveal 属代码推断，建议缩短为单次 350–500 ms，不反复阻挡数据读取 |
| Pattern Record | 选择字段、当前状态、覆盖摘要；方法学与历史为命名展开项 | 暂停／恢复状态变化；展开 | missing 真实且中性；不做惩罚性进度、streak 或「你没完成」 |
| Preparation | 自己的文字为主体；已保存支持作为可选择引用；稳定保存动作 | 选中支持的视觉变化；保存确认 | 保留 words snapshot、证据来源与陈旧提醒；不把自报有效性升级为因果 |
| Settings / You | 一致的 grouped list：账户、保护、提醒、历史、备份、报告、Plus、帮助 | 原生风格开关与行按压；短展开 | 历史入口进入命名组；保持提醒单一持久化权威与账户状态 |
| Reports | 先选报告类型，再范围／字段，再预览／导出；付费规则贴近相关动作 | 被选类型／范围立即可见；生成状态；真实文件就绪 | factual 与 clinical、Free 与 Plus 的合同不变；临床数学不因动画改变 |

Reports 实际画面 25/26 中，长段付费规则与五行范围选择占据了大量首屏。把完整规则放进 `What is included` 说明，并在当前导出动作旁清楚显示 `Free` / `Plus` 能减轻负担；免费 CSV、近三个月 factual PDF、受限长范围／clinical PDF、已有文件仍可读取等真实规则不能被弱化或隐藏。

Clinical matrix 27 的后续改法应优先处理标签：为真实类别名提供稳定、足够宽的标签区，在词边界换行；必要时让绘图区水平滚动，保持行标签固定，并提供可访问的文字详情。网格线降低视觉重量，选择实际数据点时显示数值和证据量。保留当前 clinical 的量表、聚合、窗口和 missing 行为；不能为让图表更满而补值，也不能把表单 0–5 的样式修改误当成临床数学修改。

最终付费 Patterns 20/21 比 Record 更有清楚的阅读结构：三个内容分区和有名字的 category drill-down 值得保留。它的问题是主标题前仍有两行工具链接，较长介绍占据首屏，数据的单位／证据解释离数值较远。后续应让范围、已观察周期和当前分区更紧凑，把原始日期与方法学放入明确的详情入口；本次图片不能证明选点反馈是否足够快。

## 统一的交互反馈与动效配方

这里的时长是**建议值**，不是对现有产品性能的测量结果。

| 交互 | 即时状态 | 建议时长与轨迹 | 成功／失败 | Reduce Motion |
| --- | --- | --- | --- | --- |
| 按钮／卡片按下 | 下一帧开始表面变亮或 0.98 scale；保持文字清楚 | 按下约 60–90 ms；松开 100–140 ms decelerating，无强弹跳 | 拖出／取消回到原状，不触发动作 | 去除 scale，保留即时表面变化 |
| 离散选择 | 标签、选中面、勾同时改变；有选中语义 | 140–180 ms，已有 animation 从当前值改目标 | 草稿选中不冒充已保存；写入失败仍有错误／重试 | 立即切换，可用极短透明度变化 |
| 命名展开行 | 箭头与内容立即响应，保留标题位置 | 180–220 ms easeOut；影响高度要避免移动正在操作的控件 | 保存／错误区域稳定；重复点击可反向 | 不做空间运动，直接展开 |
| 日历月份 | 标题和网格一起更新，旧月份方向一致 | 160–200 ms 小距离方向变化；不延迟点选 | 快速连续点不排队，不跳回旧月 | 网格即时更新或短 crossfade |
| 月经 range | 端点立即选中，连续底带随草稿更新 | 120–180 ms 色／透明度变化 | 当前只是草稿；最终成功才有保存确认 | 即时颜色与清楚区间文字 |
| 本地保存 | 按下立即回应；控件／相关行显示 pending，不让整页卡住 | 无人为等待；成功后 220–280 ms 的小勾／表面 settle | durable callback 成功后才说 Saved、给轻触感；失败保留编辑内容和清楚重试 | 保留文字、勾和 live region，取消 pulse／scale |
| sheet／编辑器进入 | 遵循 push 与 sheet 的空间关系 | 约 240–320 ms；退出更短，支持原生手势中断 | 不重复叠开同一 editor；来源页保留 | crossfade 或平台约定的减少运动路径 |
| 图表点选择 | 下一帧亮起实际点并显示实际数据 | 100–160 ms 的点／crosshair 变化 | missing 不画成 0；不插值补事实 | 立即显示选点与文字详情 |
| Care 场景 | 遵循场景目的的呼吸／释放节奏 | 保留已有场景规律，必要时改善与手势连续性 | Exit 与 safety 从始至终可用 | 使用已有静态／减少运动场景，不影响步骤和文字 |

**代码推断：** Build17 已存在 `ExperienceHaptics`、`ExperienceMotion` 与 `SavedRhythm`，含 150 ms chip、300 ms saved、450 ms world transition 与 Care 场景行为；不是「完全没有动效」。当前 Record 的 `_write` 等待真实写入是正确的，但其反馈主要是一行文字，并未统一使用这些既有 primitive。应补齐覆盖，而不是再建一套互不关联的动画系统。

**实际画面观察：** calendar month 的 04→05 有可见按压与月份更新；degree 的 08 有 ink splash，09 的状态与 07 不同。它们证明现有控件已有反馈，不足以量化响应时间或持久写入边界。用户的不满意更准确地说，是反馈风格、持久选中状态与动作后的结果不够统一、直接、可感知。

实现规则：

- haptics 必须 best effort，不 `await` 它来阻塞选中、导航或 durable save UI。
- 区分 pointer-down、draft-selected、saving、saved、error。可提前改变草稿视觉；不能在加密存储成功之前显示已保存。
- 动画允许中断与改向，从当前进度继续；快速重复点击不把旧动画或旧 async 结果排队播放。
- 保存防重入、generation token、widget disposal、日期午夜变化、dirty draft、返回来源路由继续使用现有状态机；动效不能绕过它们。
- 不用长庆祝、纸屑、奖励、连续成绩或「完成一天」来评价症状记录。
- 优先使用 Flutter 现有 implicit animation、`AnimationController`、`AnimatedSwitcher`、`AnimatedSize` 与已存在的 Care seam。没有充分复杂度理由，不添加动画依赖。
- 仅为必要变化动效。持续 backdrop blur、整页 shader、所有列表逐条入场和滚动驱动表演会增加成本与干扰；不作为首批方案。

## 视觉与组件的共同约束

保持 Build17 背景及文字的品牌关系。统一三层材料：canvas、轻抬升的内容面、必要的 modal 面；不要每个内容片段都套一个明亮描边框。强调色主要用于当前动作与选中状态，次级导航用较安静的文字与箭头。

保留现有衬线的品牌识别，但缩小其职责：页面 title、少数 Care 话语、用户自己的文字。控件、字段、状态、日期与数值使用清楚的无衬线；数值保持 tabular figures。功能标题大小应形成紧凑层级，不让每个分组看起来都是新封面。

控件共同拥有 default、pressed、selected、pending、disabled、error 状态。选择不能只靠颜色；采用对比清楚的勾或位置标志。保持 44 点以上命中区、Dynamic Type、自适应换行、语义标签与 live region。当前只按用户范围采集一个正常尺寸 iPhone；这些实现要求不等于已经完成大字、屏幕阅读器或实体设备验收。

Care 的安静不应误判为陈旧：缓慢的场景呼吸与记录时的快速反馈有不同任务。高级质感来自精确的层级、一致的触感与真实结果；不要求所有页面同样活跃。

## 参考：借什么，怎样变成我们的组件

| 参考 | 取用的具体机制 | Letter Within 的转译 | 不作为产品承诺 |
| --- | --- | --- | --- |
| [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion) | 有目的、清楚、适当的运动 | 快速触摸反馈、导航关系、可减少运动 | 不据文档声称当前 App 已流畅 |
| [Apple Designing Fluid Interfaces, WWDC 2018](https://developer.apple.com/videos/play/wwdc2018/803/) | 反馈与手势连续；动作可中断 | 按压从接触开始、弹层跟随手势、反向从当前值继续 | 不复制系统完整交互或使用固定时长冒充跟手 |
| [Airbnb 2023 mobile calendar upgrade](https://www.airbnb.com/resources/hosting-homes/a/upgrades-make-your-calendar-easier-to-manage-on-mobile-585) | 文档展示的移动端连续日期范围选择／编辑 | 一个可点击完成的 period range；以后才考虑可选拖动 | 这是历史机制参考，不是当前 Airbnb 实时功能审计；不复制预订／价格语义 |
| [Apple Health cycle logging](https://support.apple.com/guide/iphone/log-menstrual-cycle-information-iph51a822b18/ios) | cycle logging 的直接日期与记录操作 | 单日 fact 与多日 period 边界保持可理解的区别 | 不把系统健康功能等同于我们已有能力 |
| [Oura Cycle Insights](https://support.ouraring.com/hc/en-us/articles/4410663885331-Cycle-Insights) | cycle 详情、记录／预计状态和输入路径 | 清楚区分 recorded 与 estimated；从状态进入编辑 | 不引入 wearable 推断，不改现有确定性算法 |
| [Gentler Streak](https://gentler.app) | 面向个人的状态呈现与克制的 wellness 调性 | Today 先呈现状态再给短行动，减少后台式字段目录 | 不移植 fitness 分数、训练负担或奖励 |
| [Amie historical product art](https://amie.so/art) | 历史展示中的统一组件、移动反馈与细节 | 控件有明确材质和状态，页面保持短任务连续性 | 不把历史展示与其当前产品定位混为一谈；不引入 AI 功能 |

以上网页由主代理实际检索核对，本审阅依据其提供的原始链接；设计适用性属于本审阅的推断。App 本身保持 No AI，研究参考与本地设计审阅不构成产品内模型调用。

## 推广顺序与样板验收

1. **共享基础 + Today / Record / Period range：** 明确状态材料、按压、选中、pending 与 saved；完成前述三个相连样板。在同一个正常尺寸 Simulator 中体验一次完整操作，而非仅比较静态配色。
2. **所有子编辑器 + Cycle / Care landing：** 传播共享控件，修正选中可见性与标题节奏；Care 场景保持其目的和安全行为。
3. **Patterns / Programme / Preparation / Reports / Settings：** 分层组织数据、方法学和工具入口；把状态与短动作放到首位，保留来源和付费边界。

首批样板应通过以下具体场景：

- Today 打开已有 feeling 与尚未记录两种状态；点 Moment 得到即时反馈，全 12 个值仍可达；没有用后台表格展示所有记录类别。
- 点 Body／Sleep／Private note 到聚焦 editor，完成后返回原 Today 并更新真实摘要；从 Cycle 或 Patterns 进入 Record 时仍回到原路由。
- 选择 degree 0、改为其它值、重复选择移除、Undo、写入失败、快速重复点击；看得见每个状态并保留原有数据政策。
- Record 单日选择历史日期；dirty draft 保留／丢弃；未来日期不可写；无需月经 range 操作来完成单日记录。
- 月经同日区间、跨周、跨月、进行中、修改端点、重叠、相邻合并确认、关联来源的影响预览；每天 flow 不因范围高亮被补写。
- 打开 Reduce Motion 后，仍清楚看见选中、保存和失败；可以立即取消或返回，不必等待动画完成。
- 实体设备触感与性能、完整辅助功能、购买及临床审阅仍是各自验收事项。截图与一段录屏不能把它们标成完成。

## 首批实施清单：可审阅的修改边界

本清单是下一轮实施提案，尚未执行。已有数据、账户、提醒、临床数学和付费合同不在视觉重构范围内。

| 文件／范围 | 允许的首批目的 | 必须保留 |
| --- | --- | --- |
| `lib/experience/theme/experience_foundation.dart` | 补齐统一的 pressed / selected / pending / saved 材料与时长，不改变 Build17 canvas | 已有 theme、字号扩展、`ExperienceMotion`、`ExperienceHaptics`、`SavedRhythm` 公共入口与减少运动解析 |
| 一个新的 `lib/experience/components/interaction_controls.dart` | 可复用按压表面、离散选择、稳定保存反馈；采用 SDK 和既有 primitive | 44 点触摸区、语义选中、键盘／屏幕阅读器激活、指针取消、无阻塞 haptic |
| `lib/experience/today/today_experience_visual_baseline.dart` | 重组 Today 状态与短动作；Moment 状态卡和完整 feeling 面板 | 现有 widget 构造参数、`saveMood` 回调、全部 12 个值、今天日期、Care 条件、真实保存与失败状态 |
| `lib/experience/today/today_visual_port.dart`（仅确有必要） | 为 Today 快捷卡提供只读的实际当天摘要 | 既有公共 port 方法兼容；不从 null 推断正常；不建立第二套健康事实 |
| `lib/experience/letter_experience_shell.dart`（仅导航接线） | Today 的有名字快捷入口进入 Record 的对应编辑任务，保留来源路由 | 四目的地与全局 Record、重复打开 guard、origin、route stack、现有调用者兼容 |
| `lib/features/record_hub/presentation/record_hub_screen.dart` | 去重默认症状入口；聚焦编辑、类别摘要、即刻反馈与真实保存 | 现有公共构造参数、key／callback、selectedDate、写入 controller、provenance、0／missing、Undo 与 draft guard |
| `lib/experience/records/observation_picker.dart` | 聚焦的六位 degree 选择与统一状态；完整分类进入 browse 面板 | `onSave` / `onDelete` / `onWithdraw` / `onEditImpacts` / safety 回调及实际保存语义 |
| `lib/features/record_hub/presentation/record_calendar.dart` | 统一视觉单元和月份反馈，单日模式保留 | `showRecordCalendar` / `RecordCalendar` 的兼容 API、future bound、savedDates 与选择行为 |
| 一个新的 `lib/features/cycle/presentation/period_range_editor.dart` | 与单日模式共享样式的 range draft 编辑器 | 不存储任何 flow；返回 typed start / nullable end；明确取消、进行中和可访问端点 |
| `lib/experience/cycle/cycle_experience.dart`（仅 dates editor） | 用 range 面板替代两次日期 dialog，并接回现有 period preview/save | 原 period repository API、预览／提交、stale guard、overlap、adjacent merge 与来源影响确认 |

Today 的 Body／Sleep／Private note 卡片目前尚没有完整的「直接聚焦对应类别」公共导航参数：现有 Today `onOpenRecord` 是无参数回调，shell 可带 date 与 symptom，Record 构造器可带 initialSymptom。该深入口是 **IA／导航能力提案**，不能把它写成已经存在的功能。实施时若需要扩展，应新增向后兼容、typed 的 optional section intent，传递来源和真实今天；不得改变既有调用者或通过原始 UI 文本识别类别。

首批聚焦这组文件，不同时改遍所有 Care 场景或迁移全部 Reports 结构。针对修改运行现有行为与语义测试，并补充真正需要验证的状态转换：Today feeling 成功／失败、快速反复按压、degree 0／移除／Undo、range 边界和取消、Reduce Motion、路由来源与 dirty draft。正常尺寸原生演示应包含一次选中到 durable saved 的完整过程；新增静态 golden 的目的只在稳定布局，不能用 golden 证明交互。

推荐方向已经明确：**保留背景，重做任务结构与统一触摸反馈，先把 Today、Record 和月经区间做成一个可体验的移动端样板。**
