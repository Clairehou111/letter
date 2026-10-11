# Kimi UI 优化交接 — Letter Within / Build17

日期：2026-10-10；当前状态更新：2026-10-11。交接对象：接下来负责 Flutter UI/交互优化的 Kimi。交接由 Codex 整理。

**2026-10-11 当前真值：** `feat/record-hub-kimi-ui-2026-10-11` 已包含 V6 实现提交 `88ab032`；接手时仍以 `git rev-parse HEAD` 与 remote 为当前提交真值。V6 第一切片已经实现：Today Quick records 扁平化与到达编排、全屏症状编辑重构、全局按压反馈强化；完整结果与下一批顺序见 `apps/mobile/validation/ui-pilot-2026-10-10/kimi-diagnosis-v6.md`。不要重做这批。

## 1. 从哪里接手

**请接手下面的当前分支完整实现，不要只 checkout 已发布 Build17 基线重做。** 用户随后明确要求“先 commit&push remote 当前分支”；本 handoff 随当前实现一起提交。接手时以 `git rev-parse HEAD` 和 remote 分支为当前提交真值。

| 项目 | 当前实际值 |
| --- | --- |
| 共享工作区 | `/Users/clairehou/pyProjects/pms-research-agent` |
| 正在开发的 Git 工作树 | `/Users/clairehou/pyProjects/pms-research-agent/.worktrees/record-hub-build17` |
| Flutter 项目 / 命令 cwd | `/Users/clairehou/pyProjects/pms-research-agent/.worktrees/record-hub-build17/apps/mobile` |
| 基础 branch（已推送 checkpoint `2c6de85`） | **`feat/record-hub-build17-2026-10-10`** |
| Kimi 开发 branch / V6 实现提交 | **`feat/record-hub-kimi-ui-2026-10-11` / `88ab032`** |
| 已发布 Build17 基线（不是新 checkpoint HEAD） | `cf12e70791c14acb2735415b8c51b1ce6047fac2` |
| 最新生产源码指纹 | `de2e1ea5840808d9a5619b2916d67b86c8736bf1a8f6b6fc7e417139a7467eba` |
| 提交状态 | 清理与 V6 第一切片已提交并推送；没有 merge/release 授权 |

`product/letter` 中有较早的 Build8 工作及未提交内容，**不是这次 UI 优化的运行/修改目录**。此前背景色错误就是基线混用造成的。不要 reset/clean、覆盖其它 dirty 文件、全仓库 add 或换回旧工作树。当前 checkpoint 相对已发布 Build17 的 diff 包含此前 Record Hub 功能实现和后续 UI 修改，不能把它们都算成最后这一次 UI 的变更。

用户最新指令：**“现在我要让kimi来做UI优化，你写一个handoff”**，并要求写清方向、讨论重点、spec、当前分支。这覆盖旧文档中的“本轮不用 Kimi、Codex + GPT 完成”作者限制。旧限制是历史决定，不应成为 Kimi 接手的阻塞点。当前请求是准备交接，Codex 没有因此调用或上传资料给外部 Kimi 服务。

## 2. 用户真正要的方向

这是消费者每天使用的移动健康应用。用户可能疲惫、疼痛或情绪低落，录入内容本身已经确定，主要问题是**如何让它易用、赏心悦目、有质量和空气感**。

用户的原话与含义：

- “是否觉得现在太丑了，没有高级质感的感觉，只有背景色还不错，其它动效完全没有，不像这个时代的产物。” 保留 Build17 的背景与产品身份，重做不足的构图、组件和反馈。
- “特别像后台表单和页面，不像给移动端的。” 不要把健康分类逐项铺成管理系统表单，或只是换一套圆角卡片。
- “record还是很多排列卡片”；“更像是卡片拆分成子tab，但是没有我给你的参考视频中的那种动效和美感。” 加几个子 Tab、淡入或按压缩放不足以解决问题，需要连贯的空间关系和任务聚焦。
- “方向就是要有质量和空气感”；“如果用户点击一下就会反应，会觉得不死板。” 手指按下、选择、进入编辑、保存、返回都应有即时且自然的回应。
- 用户希望学习漂亮、现代的新 App；她能辨认好看的效果，但不容易逐个描述组件。设计者需要主动判断、提出完整而一致的方向。
- “you are always have the right to critisize and reject my proposals”；“不合适的你告诉我，然后你不用就可以了。” 用户建议不是机械执行清单；不适合时说明理由，选择更合理的方案。

“高级”在这里应体现为清晰的视觉主次、恰当留白、细腻状态、自然的层次转换和低操作成本。不是堆积发光、玻璃、粒子、巨大装饰或每次保存都放一段慢动画。产品内容和使用场景优先。

## 3. 设计与功能边界

- **一切以已发布 Build17 为底。** Quiet Dusk 主画布 `#1E1224`，Care 更深的 `#170D1C`；使用 `ExperienceFoundation` / `ExperienceColors` / `ExperienceType` 等现有 tokens。历史 `lightTheme()` 方法名并不表示当前画布应改成浅色。
- 用户批准：“当 letterwithin 组件和原型冲突时，使用 letterwithin 中的组件。” HTML 原型解释功能/信息架构，不是像素权威，也不能代替原生实现。
- 本次可调整 Today + Record 全流程的布局、组件、文案清晰度、动效与呈现方式；不要顺便全面重做 Care、预测、Patterns 图表或付费规则。
- **保持数据层、API、算法、原记录身份和临床含义。** 数据/domain/application/generated API 是本轮 UI 的保护区。要增加字段、改变持久化、预测/Kit 计算或行为合同，应明确作为独立产品变更提出。
- UI 和按钮文案使用英文；交接和讨论可用中文。
- Today / Cycle / Care / Patterns 四个目的地；中央 `+ Record` 是动作。Settings 保留 You 原有账户、隐私、备份、报告、购买等能力。
- Today 始终实际当地今天。历史记录在独立 Record 中完成，不创造“历史 Today”。Record 可以记录任何已经发生的日期，不要求先有经期。
- Moment 和症状是两种事实；Moment 只在 Today，保留全部 12 个状态。Good/Calm 不意味着当天所有症状为零。
- 症状 `0 Not present` 是明确保存；未记录是 missing。1–5 保留原始名称/数值。重复点击已保存程度是移除；Undo 恢复同一个源 ID、日期、值、时间戳。
- 指定日期、原始 recordedAt、original provenance、当前值的 same-day / later recall / unknown 不可被视觉操作重写。实际当天保存才算 same-day；没有凌晨四点 grace。
- 子编辑器继承 Record 日期。普通 Record 关闭后返回准确来源/滚动位置。V5 的 Today 指定症状快捷入口是明确例外：编辑关闭后直接回 Today，普通 Record/Patterns 路径不受影响。
- 页面打开、浏览、预览、取消、切 Tab 都不能偷偷保存；成功反馈在持久化 callback 成功之后；失败保留可重试草稿。
- 交互 ≥44 logical px、可读标签/semantics、动态字体、Reduce Motion、键盘/安全区域都必须保留。动效可打断，快速反向操作不排队，不阻塞实际保存。
- 本轮正常尺寸 iPhone 截图足够；用户不要大小屏及另一套深色页面截图批次。这不代表改成浅色，也不免除自动化大字体检查。
- 真实健康记录不得放入外部设计材料、截图、日志或测试。截图用隔离的虚构数据。不要重置用户模拟器数据库。

## 4. 讨论重点与当前实现

### Today：直接、个性化、少一步

用户认为 More / Add more 不够方便，提出常用项直接做卡片；最新提出：**“把 bleeding symptom 等常用卡片直接放到 today 中……或者把 pinned 放到 today 中……总之就是方便。”**

V5 已将 broad Body 概览替换为 Quick records：Bleeding 独立行；实际 pins 按用户保存顺序排列为紧凑横向快捷卡，显示真实当天程度；没有 pins 时从现有 curated catalog 取少量默认 quick picks，标为 Quick symptoms，绝不伪称 Pinned by you。Sleep、Private note 是简洁入口，All records 保留完整记录访问。大字体时快捷项纵向堆叠。

Moment 目前是一张聚焦入口卡，打开全 12 选项的 sheet；取消旧六项加 More 的割裂。顶部与 shell 共用一个 masthead/Settings，避免双标题。

**这些是现在的实现，不是用户已经认可的最终构图。** Kimi 应重新审视首屏主次、pins 横向是否易发现、Bleeding 与症状的比重、Sleep/note 的层级，避免 Today 再变成卡片目录。保留“具体常用项可直接点进去”和真实状态。

### Symptom：全屏聚焦编辑

最新用户要求：**“Symptom 编辑的时候也可以弹窗覆盖整页，这样子有足够多的空间。”**

V5 已实现原生全屏编辑层：通用 Symptom 导航栏/关闭、实际日期、完整症状名称（现有 24px serif token）、共享程度控件、保存/错误状态、原记录的功能影响编辑、移除和 guarded Undo。普通 Record 底层 picker/list 保持 mounted，关闭返回原滚动位置；Today 指定快捷项直接回 retained Today。

同一个 picker state 持有 session maps、callback 和保存逻辑；没有复制第二套 writer。保存/Undo 正在进行时锁住关闭和竞争操作；失败的未保存改变有 Keep editing / Discard guard。普通程度点击即保存，不能为了统一界面加第二次 Save。退休的旧 Heart palpitations 等仅保留兼容读，不能重新开放成普通症状。

V5 尚无真实原生截图/录像；Kimi 尤其要看全屏后的比例、程度控件的手感、当前程度与保存状态的层次，不要认为全屏自然就精致了。

### Record：已有分类与动效，但仍需设计判断

现在有 Symptoms / Daily life / Products / Notes 四个稳定 mounted panes；一个前景工作面和两层 backing surfaces。类别切换有 320ms 可打断的方向位移、缩放、淡变和抬升，快速反转从当前姿态接续；只有当前 pane 可接收输入/semantics/ticker。切类别保留草稿；切日期、Done、离开子编辑器仍守护未保存输入。

日期是轻量工具，Saved on this day 是真实已存源的入口。Notes 有实际 Saving / Saved / Try again 状态变化。V3 的症状标题从点击来源移动到聚焦区域，但不是整张卡几何 morph；V5 Today/Record 已改用全屏症状编辑，generic 其它上下文仍能使用旧 inline 方式。

Kimi 可以改善工作区构图、转场和层级；不要仅“再加一排卡片/再拆一层 Tab”。所有记录类型需易发现，Medication / Supplement / What I tried / Temperature 不能消失到 Other 里。

### 统一所有 Today + Record 录入子页

用户明确要求：**“所有的 today+record 中的录入子页面你都要排查一遍，组件尽量统一或者风格一致。”** 范围包含嵌套 pickers、创建/编辑、历史源、确认与失败状态，而不只是入口页。完整 inventory 见下方 `entry-component-audit.md`。

| 组件族 | 已实现 / 必须保留 |
| --- | --- |
| 程度 | 症状、整体 impact、sleep quality、craving intensity、活动/event intensity、check-back 使用共享或相关 `RecordOptionScale<T>`；保留各自真正的选项数、标签和枚举。不能把 sleep quality 变成症状严重程度，或把三档强塞六档。 |
| 时长 | 共用 categorical ruler + Exact 交互家族；睡眠/活动/What I tried 各自 bucket 与 exact minutes 保持区别，不能从“2–4 hours”猜一个分钟值入库。 |
| 体温 | 两个 Cupertino wheels 快速选整数/百分位，同时保留 Exact 键入；typed `36.555` 不得变成 `36.56`。输入 precision 超过 wheel 时有说明；wheel 移动才选择 0.01 steps。换单位清空 draft，不偷偷转换或重解释。 |
| 通用触摸 | `InteractionSurface` 即时按压/释放、selected、focus 与 reduced motion；本身不保存、不声称成功。不能靠全页面同一缩放来代替完整交互设计。 |
| 日期 | Record calendar 单日；经期 start/end 是区间；产品 start/end/effective dates 是实际产品日期，三者不可混用。 |

### 日历 / 经期区间

用户指出月经开始/结束是区间。现有 `PeriodRangeEditor` 有连续区间填色/endcaps、Start / End、Still bleeding（null end）、同一天及跨月跨年等状态。原始 overlap/merge/detach/stale-preview 确认必须保留。

区间可视化不是每天 flow 的事实。Spotting 不自动开始/延长经期。Record 的日期选择保持单日，不把选日期改成一段范围。

### Medication / Supplement / Birth control

用户截图中指出：Add another event 后仍是 Taken / Skipped / As needed；Stop / correct end 其实改 end date；Archive 含义不清，多 episode 很丑。**三个 family 一起优化，不要只修 Medication。**

V4 已做共同 manager：紧凑产品行，同一时刻仅展开一个使用周期，当天真实 daily use 快捷状态；管理动作进入自适应 action sheet；额外使用进入聚焦编辑器，以 Save additional entry 明确提交。过去/归档周期及原始记录版本折叠在历史中。创建/编辑先身份 name/dose，再实际/effective date，再 compact type/unit/route catalog pickers，避免 chip cloud。

必须理解以下事实才能设计正确：

- 产品使用周期与当天 use 不同。创建周期不意味着当天 Taken。
- Taken / Skipped / As needed 是 use 的状态。daily shortcut 与 additional entry 是不同源；追加一次不应覆写或改变 daily 状态。
- daily 已保存的 name/dose 使用该记录自己的 details version；additional 使用对应日期适用版本。不能为了展示一致而重写旧剂量。
- End use / Change end date 修改实际区间。停止后，区间内的历史日仍可记录。
- Archive 移出日常录入并禁止新 entries，**保留真实日期、所有 uses 和 details versions**；不自动设 end date，不删除历史。无结束日期的 archive 显示 No end date · Archived，不能伪称 Ongoing。
- Emergency birth control 事件不假装为 daily method use。
- 不能 invent Restore/Undo/archive 撤销能力、推荐剂量、后台批处理或新的产品状态。

Kimi 可重新组织这些动作、历史与表单，让它更适合拇指和重复使用；源身份、版本、归档语义不可改变。V4 技术及独立视觉复核通过，**用户没有因此给出最终审美认可**。

### 重复功能已被明确否决

- **Cycle letter archive 不需要新入口。** 用户说 Cycle 已承载反思。原始反思现在回到 Cycle history，原话、need、ID、日期/source anchor 保留；完成周期原有编辑保持。
- **My preparation plan 不应再作为重复入口。** Comfort Kit 已有个人录入与聚合最多使用的 Care 功能。可优化时机/UI，不另造一套同义计划。原有 Kit/plan 持久化及 reliable Comfort Window 算法保留。
- **Pattern Record 与 Patterns 需要进一步解释与设计。** 用户问它们差别、追踪是否为了“PMMS”。已批准合同是可选 PMS/PMDD shared-source tracking programme，不是另一个症状库；用户“PMMS”具体所指尚未澄清。不能擅自加诊断/PMSS 量表，也不能把 clinical completeness 与普通免费事实混为一谈。此项是尚未解决的产品问题，不靠更漂亮按钮假装解决。

## 5. 参考资料与 skills 怎么用

用户提供两个本地视频，目录：

`/Users/clairehou/pyProjects/wechat-dispatcher/output/research/reference_videos/`

1. 文件名以 **5个用VibeCoding做出来的高级交互动效，让你的App和小程序告别生硬的模板感** 开头，约 148 秒。
2. 文件名以 **6种App和小程序高级交互，一次教会你** 开头，约 88 秒；**实际文件名含换行**，不要手抄 shell 路径。

精确路径及已抽帧资料在 `/private/tmp/letter-motion-references/sources.json` 和同目录（临时文件可能随后不存在；届时从原目录重新枚举）。这些例子是质量/交互连续性的参考，不要求全部效果照搬。应看实际视频，而不是只看静态图。

已看过的官方 App 参考：[Gentler Streak 2025](https://gentlerstories.com/newsroom/20250317amoreintuitivestreak) 的聚焦/层次；[Moonlitt 官方介绍](https://developer.apple.com/news/?id=v1nphz91) 的直接操控。它们不是指定视觉皮肤，也不要为了新引用重做整轮研究。

用户询问 taste-skill、Finesse UI、GSAP。已有本地可用 skills：`ui-forge`（根工作区 `.agents/skills/ui-forge/SKILL.md`）、`impeccable`、`design-taste-frontend`、`gpt-taste` 等（`/Users/clairehou/.agents/skills/`）。远程 Finesse 曾只读，未全局安装。

- 可借鉴 Finesse 的 personal recurring recording、单一展开焦点、低输入负担、native sheets 和自然 state feedback。
- `design-taste-frontend` 是网页方向，原生 mobile forms 不在其主要范围；`gpt-taste` 的 AIDA、随机布局、landing-page 巨大留白等不适用本产品。
- GSAP 是 JavaScript 动效工具；本项目是 Flutter。可以学 interrupt/reverse/timeline/reduced motion 的原则，**不要为套 skill 引入 WebView/JS bridge/GSAP 依赖**。
- 用户明确允许拒绝不合适的规则。具体 brief、Build17 和真实产品使用场景优先，不能混入互相冲突的几套主题。

若通过 UI Forge / Moonshot / OpenRouter 上传设计材料，按该工具的 source/screenshot manifest 边界准备最小、虚构资料包；不把“让 Kimi 接手”解释为上传整个 dirty 仓库/真实健康数据库/凭据。当前 handoff 不选择付费网关、不触发生成请求。若 Kimi 是本地有工作区访问的编码会话，直接读本文件及相关源即可。

## 6. 必读 specs：顺序、用途与历史冲突

下面路径均相对 **当前 Build17 工作树**，不要误读旧 `product/letter` 副本。

| 顺序 | 文件 | 为什么要读 |
| --- | --- | --- |
| 1 | 本文件 + `AGENTS.md`、`apps/mobile/AGENTS.md` | 当前作者/目录/授权，保留未提交工作、原生验证和隐私边界；旧模型 exclusivity 不覆盖用户最新指令。 |
| 2 | `specs/features/release-2.0/record-hub/README.md` | 完整开发包索引、批准记录及已实施功能；位于 release-2.0 目录不代表已获本次发布批准。 |
| 3 | `.../requirements.md` | 32 条 RH 要求；完整 scope、共有来源、记录类型、排除项和访问边界。 |
| 4 | `.../data-contract.md` | 日期/原始与当前 provenance/zero/source ID/版本/迁移/产品 use/隐私，设计不能改变这些。 |
| 5 | `.../native-map.md` | 真正接入的代码路径与风险；随后以当前源为准，旧 preflight 缺口多已修复。 |
| 6 | `.../plan.md`、`.../validation.md` | 依赖分批计划与 30 项原生验收；区分已做/开放发布门槛，不从截图推导 storage/clinical PASS。 |
| 7 | `.../visual-brief.md` | Build17 的设计与原生交互约束；其中禁止 Kimi/旧 inline/Moment More 的陈述被最新指令与 V5 覆盖。 |
| 8 | `.../ui-pilot-2026-10-10.md` | 用户各轮真实反馈，包括动态质量、全子页统一、重复功能移除、产品 manager、全屏症状与 Today 快捷。 |
| 9 | `specs/brand-and-experience-system.md`、`specs/experience.md`、`specs/care-experience-system.md` | 品牌 ritual/utility/clinical 三层、letter 隐喻预算与 Care 身份。以当前 Build17 tokens 为颜色真值。 |
| 10 | `specs/mission.md`、`specs/product.md`、`specs/architecture.md` | 私密本地优先、使用场景与 presentation/domain/data 边界。 |

这里 `.../` 表示 `specs/features/release-2.0/record-hub/`。原型在共享根目录 `prototypes/record-hub-html/index.html` 及 README，只用于理解合同。

重要补充资料，位于 `apps/mobile/validation/ui-pilot-2026-10-10/`：

- `entry-component-audit.md`：**全 Today + Record + 嵌套子页面清单**，逐个控件族/类型/source contract，不遗漏 picker/history/confirmation。
- `motion-composition-v3.md`：用户否定“只拆子 Tab”后的动效 brief。
- `product-composition-v4.md`：三个产品 family 的 manager/表单/动作语义。
- `today-symptom-composition-v5.md`：独立 UI 专家对快捷记录和全屏症状的建议；是建议，不是用户最终批准的设计稿。
- `verification-v4.md`、`verification-v5.md` 及 `visual-review-v4.md`：保留的结果摘要和证据限制。V2/V3、失败 attempt、verbose reporters 与 generated hash inventories 已从 active tree 清理，必要时从 Git 历史读取。

共享根目录旧入口 `research/belle-reviews-2026-10-05/start_flutter_record_hub_2026-10-09.md` 和 10-08 handoff 是历史。它们的分支、Build8/背景、没有 zero、数据缺口、Kimi 禁用等状态均不能直接作为当前事实。更早 Today/Care 2026-08-15 brief 的 daylight/五档/no Not at all 也不覆盖当前 Build17 与显式零合同。

## 7. 实际代码入口

所有路径相对 `apps/mobile/`：

| 区域 | 入口 |
| --- | --- |
| 产品 theme/tokens | `lib/experience/theme/experience_foundation.dart` |
| Shell、Settings、Record 起始来源与返回 | `lib/experience/letter_experience_shell.dart` |
| Today adapter/真实当日数据 | `lib/experience/today/today_experience.dart`、`today_visual_port.dart` |
| Today 实际生产视觉 | `lib/experience/today/today_experience_visual_baseline.dart`（不是另起一个 Today） |
| 完整 Record / 日期 / drafts / Undo | `lib/features/record_hub/presentation/record_hub_screen.dart`、`record_entry_section.dart` |
| 类别空间转场 | `lib/features/record_hub/presentation/record_workspace_stage.dart` |
| 症状 picker 与同一 session 的全屏编辑 | `lib/experience/records/observation_picker.dart` |
| 程度原有图形 | `lib/experience/degree/degree_graphics.dart` |
| 共享触摸、程度/时长、体温 | `lib/experience/components/interaction_controls.dart`、`record_option_scale.dart`、`record_temperature_picker.dart` |
| Sleep/activity/appetite/event/BBT 子编辑 | `lib/features/record_hub/presentation/record_context_editor.dart` |
| 三个产品 family、额外 use、What I tried/check-back | `lib/features/record_hub/presentation/record_interventions_editor.dart` |
| Record 单日 / 经期区间 | `lib/features/record_hub/presentation/record_calendar.dart`、`lib/features/cycle/presentation/period_range_editor.dart` |
| 原反思保留 | `lib/features/cycle/presentation/cycle_reflection_history.dart`、`lib/experience/cycle/cycle_experience.dart` |
| 已有本地预览入口 | `tool/record_hub_build17_preview.dart` |

现有 typed models/catalog/repositories 可以只读理解，不要在 UI 优化中编辑它们。特别保留 component 公共构造、callback、stable keys、draft guard；若有必要调整 presentation seam，同步调用方及真实行为测试，不用删测试解决。

## 8. 截止交接的验证与模拟器状态

| 批次 | 真实状态 |
| --- | --- |
| 最初功能实现 | Build17 功能基线 966 tests / 1 optional skip，iOS/Android encrypted schema18 reopen 及 Build17 schema12 migration；见 `implementation-evidence-build17-2026-10-10.md`。 |
| V4 | 完整 **1041 PASS / 1 optional SKIP / 0 failure**；whole analyzer clean；正常 iPhone **43/43** PNG + Record 39.18s / Products 44.66s 真录像；render exception0，取消/source preservation/reopen 验证通过，独立有限视觉复核无实质 blocker。不是用户审美最终接受。 |
| V5 | 完整 **1055 PASS / 1 optional SKIP / 0 failure**，执行 exit0；新全屏/Record/navigation scoped67 PASS，Today scoped25 PASS（有重叠）；最后 whole analyzer 无问题（4.3秒）。尚无原生 captures、录像或视觉复核。 |
| V5 最后微调 | 完整测试后仅去掉一个不必要的 non-null `!`，行为不变；full-test summary 保留实际测试指纹 `a541b54...`，最后交接指纹为 `22fe6548...`。不是两个相互矛盾的 Build。 |
| V6 第一切片 | Today / symptom / press UI 已实现；定向64 PASS；完整 **1055 PASS / 1 optional SKIP / 0 failure**；whole analyzer clean。当前 fingerprint `de2e1ea...`。尚未做新原生截图/录像。 |
| UI 数据边界 | UI 前整合基线230 files；当前237 files，UI合计17个 changed/new presentation files；V5 相对 V4 仅6个 presentation files，`protectedChanged: []`。此前功能实现本身有数据变更，不要声称整个 Git dirty tree 从未改 data。 |

视觉基线只保留十张正常尺寸代表图：`apps/mobile/validation/kimi-current-reference/`。它们来自 V4，**不包含 V5 Today 快捷/全屏症状，也不是 V6 像素目标**。V4/V5 测试结果只保留小型 summary；完整 reporter、旧截图批次和视频可从 Git 历史恢复，默认不要读取。

原生专项 fixture 文件名仍为 V5，但 fingerprint 已更新到当前 V6 第一切片；**尚未执行**：

```sh
flutter drive --no-pub -d 7A533533-EA45-4735-AC28-10FA095A65FF --target integration_test/record_hub_ui_pilot_v5_test.dart --driver test_driver/record_hub_ui_pilot_v5_driver.dart --dart-define=NATIVE_VISUAL_HOST_DRIVER=true
```

准备了9个状态和一段真实交互录像，包含 pin顺序/zero-vs-null、打开不写、移除/Undo/同 ID impact、Today准确返回、普通Record滚动保持、Bleeding展开与关闭不写、schema18/reopen。运行前比对源码指纹；改过UI后更新 fixture 指纹和截图期望。不要把未执行的脚本当成 PASS，也不要拿 V4 screenshot 验证当前 V6。

模拟器：

- **用户正在看的 preview**：iPhone17Pro `E45EAC1A-381E-44B0-AE71-684E3C693581`，402×874 logical，iOS26.5。驻留 Flutter preview PID `84984`，target `tool/record_hub_build17_preview.dart`。**目前仍为 V4，V5 未 hot reload**。确认进程存活再操作；保留其现有数据/页面，不重置。
- **隔离 synthetic review device**：`7A533533-EA45-4735-AC28-10FA095A65FF`，正常402×874，DPR3。原生测试/录像在这个设备完成，不碰用户数据。
- 其它 booted simulators 不是本轮对象，不关闭/重置。
- 当前没有新的 native drive 在后台运行；V5 完整 regression 已结束。不要依赖 Codex tool session IDs 作为跨会话操作接口。

## 9. Kimi 接手后的工作顺序与交付标准

1. 先确认当前 branch/worktree/dirty files，阅读上面必读合同、组件 inventory、真实 V4 图/录像和用户两个参考视频。运行/截图当前源时注明是 V5，不把旧图当最新。
2. 对 Today、Record、全屏症状、Sleep/BBT 与三个产品 family 做一次整体诊断：指出最影响品质和效率的具体问题，给出一致的构图、组件、motion方向。已有320ms和press反馈只算现状，不是不可更改设计。
3. 在保留已定产品/数据合同下实施真实 Flutter UI。先做能连起来体验的关键路径，再统一其它子页；避免每一页独立风格。无需再次询问“是否开始常规 UI 优化”，用户已明确让 Kimi 接手；如果要改变持久化/clinical含义/发布范围，则另列产品问题。
4. 验证真正操作：触摸立即回应、快速重复/反向、实际保存后反馈、失败草稿重试、零与 missing、remove/Undo、取消不写、正确来源返回、隐藏 drafts、大字体/Reduce Motion、exact temperature/剂量、历史版本。
5. 稳定后做相关 tests、whole analyzer/full regression、正常 iPhone 原生 key-state captures 和实际动效录像；有限一轮视觉检查及必要一轮修正确认。截图证明 layout/state，录像可看 continuity；不能凭视频就声称60fps或物理haptic合格。
6. 给用户实际模拟器效果、主要变化、验证与剩余限制。不要只交设计建议、网页 mock、漂亮截图或空 callback；也不要无限 polish。用户审美反馈仍是实际验收。

用户已给当前开发范围较强行动授权，并反复要求不要重复 Python/常规执行许可问题；同时运行环境实际 sandbox 边界仍须遵守，不能用 Python/env 包装绕过限制。用户已追加授权 **commit + push 当前分支这个 checkpoint**；不包含 merge、上传真实健康资料或 release，也不自动授权 Kimi 后续修改的发布。

## 10. 可直接给 Kimi 的开工指令

> 接手 `/Users/clairehou/pyProjects/pms-research-agent/.worktrees/record-hub-build17` 的 branch `feat/record-hub-kimi-ui-2026-10-11`；以 `git rev-parse HEAD` 与 remote 为确切真值。V6 UI 实现提交是 `88ab032`。先读本 handoff、必读 specs、全录入页 inventory、真实参考录像和 `kimi-diagnosis-v6.md`。V6 第一切片已经完成 Today Quick records 扁平化与到达编排、全屏症状编辑重构、全局按压反馈强化，不要重做。下一批从 Record stage/Record Symptoms 构图开始，再统一 Daily life 与三个产品 family。以 Build17 Quiet Dusk、Letter Within 组件和现有功能/data/API 为底，做有质量、空气感和自然即时反馈的消费者移动界面。可以批评并不采用不合适的建议/skills，不机械套网页或 GSAP。保留 zero/null、精确值、来源/版本、timing、草稿与返回语义；不要新增 letter archive / preparation-plan 重复入口或擅自诊断量表。当前 V6 第一切片已通过完整1055项回归但尚未原生捕获/热更新；不要拿 V4截图当新页面验收。保留用户模拟器数据，不 merge/release。

## 11. 执行约束：把“高级/空气感”落成数值

第 2 节是方向层（视觉母题、构图、气质），可自由发挥；本节是执行层（工艺标准）数值，不得漂移，除非另外记录明确理由。完整版在根工作区 `.agents/skills/ui-forge/references/motion-system.md`；**若无法读取该路径，以本节为准**（该文件不在本工作树内）。

### 11.1 动效

| 事件 | 时长 | Flutter 曲线 |
| --- | --- | --- |
| 按压 / 开关 / hover 反馈 | 100–200ms | `easeOutCubic` |
| 组件进出（卡、sheet、菜单、tooltip） | 200–300ms | 进 `easeOutCubic`，出 `easeInCubic` |
| 路由转场 | 300–450ms | fade-through |
| 场景 / hero / 全屏 | 500–900ms | `easeInOutQuart` |
| 手势跟手 | 无固定时长 | 仅 spring：`SpringDescription(mass: 1, stiffness: 300–500, damping: 25–35)` |

- 进场：上移 12–24px + opacity 0→1（可选 scale 0.98→1）；禁止 0→1 的 scale pop。退场反向。
- 错峰：列表 / 网格子项 30–50ms 间隔、同方向；父级先于子级。
- 可打断：新手势从当前值接续，不回跳起点。滚动联动用滚动偏移 0→1 插值，不用计时器。
- Reduce Motion：仅 ≤150ms opacity 淡入。
- 禁止：除纯 opacity 外的 `linear`、bounce / elastic / overshoot、>1s 的微交互。

### 11.2 交互反馈

- 按压：scale 0.97 + opacity 0.88，~120ms spring 回弹（`InteractionSurface` 已有，强化其全站一致性而非另造一套）。
- 每个可交互元素声明六态：default / hover / pressed / focused / disabled / loading。
- 任何输入 100ms 内必须有视觉响应。手势松手 spring 到 snap 点或按速度 fling，不瞬移。
- 加载用 skeleton / shimmer；空态与错误态是设计过的界面，不是默认文案。

### 11.3 表面与质感

- 抬升阶梯全站固定：0 背景 / 1 卡片 / 2 浮层 / 3 弹层，每层一个固定阴影或模糊。
- 圆角阶梯 4 / 8 / 12 / 16 / 24，按容器大小取值；不要到处同一个圆角。
- 深色下用 hairline `rgba(255,255,255,0.06–0.10)` 1px 替代重阴影；**不改变 Quiet Dusk 画布** `#1E1224` / `#170D1C`。
- 字阶 3–4 级；大标题 `letterSpacing: -1–2%`；正文行高 1.5–1.6；图标全站统一 stroke。

### 11.4 反模板与自审清单（交付前逐条自查）

- 每个动效都要有声明的时长与曲线，未声明 = 未完成。
- 间距是 4 的倍数阶梯；跨屏不出现圆角 / 阴影 / 字阶漂移。
- 每个可交互元素六态完整；存在 Reduce Motion 路径。
- 没有紫色渐变模板、卡片墙、全居中布局、无理由玻璃拟态；相关页面有与产品语义相关的视觉母题。

### 11.5 从参考视频提取数值

不要只把视频当“感觉”看。抽帧换算再入库：

1. `ffmpeg -i <video> -vf "fps=10" frames/frame-%03d.png`（已有抽帧在 `/private/tmp/letter-motion-references/`）。
2. 每个动画取 3–5 张关键帧（起 / 中 / 末）。
3. 帧号 ÷ 帧率 = 毫秒（60fps 下帧数 ÷ 60）。
4. 每个动画写一行：事件 → 时长 → 缓动形态 → 位移 → 错峰。
5. 两个视频是质量与交互连续性参考，不要求逐条照搬；提取的是节奏与物理，不是皮肤。

## 12. 工作方式与自主权（补第 9 节）

### 授权与审批

- 用户已授权 Kimi 直接做常规 UI 优化，不要反复询问“是否开始”。唯一需要停下确认的是：改动持久化 / clinical 含义 / 发布范围，或新增字段与行为合同——这些列为独立产品问题，不夹带在 UI 里。
- 仓库 `AGENTS.md` 的“requirements/validation 未批准不得实现”针对新功能立项，**不适用于本次已获授权的 UI 优化**；两者冲突时以本 handoff 与用户最新指令为准。
- 用户允许批评并拒绝不合适的建议、skill 或旧决定；不机械执行清单，也不做无休止 polish。

### 分支与提交

- 在 `feat/record-hub-kimi-ui-2026-10-11`（已包含 V6 实现提交 `88ab032`）上继续开发。不 rewrite history、不 force-push。
- 按逻辑单元小步提交，信息说明“改了什么 / 为什么”，便于逐块回退；不要把 UI、测试、无关清理混进一个巨型提交。
- 不要 reset / clean、不要全仓库 add、不要覆盖其它 dirty 文件；不 merge / release，不上传真实健康资料。用户若要 push 会另行指示。

### 节奏（无审批，但保留检查点）

1. 先输出整体诊断 + 一致方向（写文件，见下），再动手。
2. 先做一条能连通体验的**关键路径切片**（Today 入口 + 一个全屏症状编辑 + Record 一类），在模拟器渲染并截图 / 录像给用户看；用户按“看效果”反馈：继续 / 换方向 / 重做。此步替代文档审批。
3. 铺开其余子页，统一组件与动效。
4. 自审循环：`dart format` → `flutter analyze` → 相关 tests → 关键状态截图与录像 → 对照 11.4 自查 → 修漂移。用户说“全做完再给我看”时可跳过第 2 步的中间检查点。

### 记录位置

诊断与选定方向写到 `apps/mobile/validation/ui-pilot-2026-10-10/kimi-diagnosis-v6.md`（含视觉母题、动效 / 交互 / state 规则、依赖顺序与逐屏计划）；代码、截图、录像作为证据。它不是审批稿，是用户“看效果”时的对照。

### 环境

- 本次 Kimi 通过 OpenCodex 以 `kimi/k3` 运行（`codex` CLI 已路由到 OpenCodex 代理，`127.0.0.1:10100`）。注意 `k3` 上下文为 **262k**；多屏大重构与长上下文需切 `k3[1m]`（**1049k**，或 `kimi-k3`）：在 Codex 会话里选模型，或 `opencodex provider selected kimi --set 'k3[1m]'`。
- 用户 preview 模拟器 iPhone17Pro `E45EAC1A-381E-44B0-AE71-684E3C693581`（当前 V4，V5 未热更新，保留其数据）；隔离验证设备 `7A533533-EA45-4735-AC28-10FA095A65FF`。不要重置用户数据。
