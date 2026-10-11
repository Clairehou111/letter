# V4 正常尺寸原生最终复核

2026-10-10。**本轮有限视觉复核通过，没有发现阻止展示／操作冻结 V4 的实质问题。** 三个产品管理页已把「这一天的记录」与管理／历史分开；精确体温显示歧义已补足。没有提出下一批产品修改，不更改 V3 历史报告。本结论不是用户已经接受整体美感或全 App 已完成重设计的声明。

## 实际证据

冻结 production fingerprint：`94d052fc6c892062e1c8e919bc357966bc4838572754cbebca8dead93cc4a6d3`。

依据 `v4/screenshots/manifest.json`：43 / 43 PNG、402 × 874 logical、1206 × 2622 pixels、DPR 3、textScale 1.0、synthetic fixture、schema 18、render exceptions 0。child preview、product manager 与 period preview cancellation 及 durable reopen 均为 true；fixture 保存 12 个 use periods 与 9 个 dated uses。主代理报告 1041 full PASS / 1 optional SKIP、analyzer clean；本审阅不重复执行这些检查，也不以图片推断它们。

对照最终 PNG 与 V3 已审阅文件的 SHA-256：18 张逐字节相同，沿用已做的实际图像观察；10 张变化图与 15 张新图全部逐张查看，覆盖当前 43 个状态。没有以旧版本截图／clip 替代新增状态。

两段本轮最终实际原生录像经 ffprobe 确认：

- `ios-record-pane-interactions.mov`：39.181667 秒。查看整段范围每两秒采样 overview，确认工作面、症状聚焦、四章往返、真实 Notes 保存仍连续。
- `ios-product-manager-interactions.mov`：44.656667 秒。查看整段范围每两秒采样 overview，观察实际 Medication 进入、产品收展、管理 sheet、额外 entry 的选择／取消保护、回到管理页、过去／归档内容与原版本展开。

录像和 PNG 证明可见状态与实际操作路径，不证明 FPS、physical haptics、输入延迟或所有无障碍场景。操作 sheet 的完整标签按独立 PNG 复核，未用小 overview 的临时截取判断按钮缺失。

## 新管理页的实际构图

Medication、Supplement、Birth control 各五个 native 状态均通过可读性复核：

| 状态 | 实际观察 |
| --- | --- |
| Manager | 日期与简短记录提示之后是家族专用 Add 动作；两个 current 产品各以名称、实际日期、必要详情和 selected-day 状态形成紧凑摘要。Past and archived 独立折叠。不再为每个产品常驻一墙橙色管理动作。 |
| Daily and additional | 只展开一个产品，另一个仍为摘要。已有每日 Taken 通过 check 与选中表面持续表达，摘要同时说明 `1 additional entry`。Birth control 保持 Taken / Missed / Late / Emergency contraception 的具体语义，没有改成其它家族状态。 |
| Manage actions | 原生 sheet 有明确 product title、Edit details、End use、Archive use period 与独立 Cancel；Archive 的破坏性色有区别。管理离开主记录面，不和每日状态抢同等位置。 |
| Additional use | 独立标题 `Record another use`，完整日期／产品／必要详情，明确说明创建 separate entry；已有 entries 分别标为 Daily entry、Additional entry。提交文字是 `Save additional entry`，不冒充重复选择每日 shortcut。 |
| Archived snapshot | Archived 明确说明旧 records 保留、新 entry 不可用；无实际 end 时显示 `No end date · Archived`。旧记录保留 original 名称／剂量和原日期，Saved detail versions 可展开为 original / updated 的有效日期与不同详情。没有将 Archive 画成实际停止、删除或可恢复动作。 |

Medication / Supplement 的额外 entry 显示 updated 的 12.5 mg 与 As needed，但旧 daily entry 仍是 original 的 10 mg 与 Taken。管理面 daily 仍选 Taken。这个真实区分使「新详情」「追加事实」「旧事实」不会视觉合并。避孕方式用自己的 Late 额外记录对应同样关系。

管理录像实际看到了 additional editor 离开时的 `Leave without saving?`、Cancel / Discard changes，随后回到原 records；这支持可见的取消路径。取消没有写入由 fixture 的 cancellation 验证证明，不能仅从返回画面推断数据库。

## 表单、精确值与既有 Record 家族

新建三类表单都先显示产品／方法名称输入，再是明确 Actual use dates，类型／方法改成命名 picker，dose 与 details 归为一个内容组。类型选择的芯片云不再压在身份输入之前。它仍是需要滚动的完整新增任务，不能因为名称前置就宣称所有表单都变成单步输入；当前正常尺寸没有看到溢出或不可读标签。

精确体温图清楚显示 **36.555 °C**，字段也为 36.555；邻近提示为 `Exact reading kept. Moving a wheel selects 0.01 steps.`。两位 wheel 的性质与精确权威值现在可理解。普通 37.56 wheel 状态不显示不必要的额外精度提示。这解决 V3 对两个显示值争夺权威的跟进，而不重新舍入已输入值。

Today / Moment 与四章 Record、Sleep / Activity / Appetite / Event、What I tried / Check back、两种 period preview 继续保持已审阅家族：原 Build17 背景、清楚类别、degree 的可见选中与完整标签、Duration 的区间／Enter exact、Notes 按钮 Saved 与附近 Undo、closed / ongoing 的实际 period band。五张变化的 press／origin／stage 捕获显示中间态正常，没有把 fixture 十字解释为产品装饰。

18 张与 V3 相同的状态继续适用 V3 的观察边界：名字从触点附近进入聚焦编辑的定位接续，不等于完整卡片逐角 morph；当前滚动 viewport 的边缘裁切不等于动作永久不可达；range band 不等于每天写入同一 flow。

## 范围与结论

此次没有从源码代替视觉结果。每日／额外记录标志、旧版本保存、pending、隐藏草稿与日期 guard 的真实性仍由冻结版本行为检查支持；实际图片证明这些事实如何显示给用户。没有对 schema、账户、Patterns clinical 范围或跨页面信息架构提出新变更。

V4 已完成这轮可复核目标：Record 有实际前景接续，产品多 use periods 以短摘要浏览，一个展开任务负责当日记录，额外 entry 与管理明确分开，归档后的原记录仍可读，精确值权威明确。**不需要因为本次复核再启动无边界的美化或新原生 capture 批次，可以回到用户实际操作与反馈。**
