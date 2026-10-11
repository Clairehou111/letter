# V5：Today 直接短记录，症状独占全屏

2026-10-10。有限设计建议，未修改产品代码。V4 原生复核报告保留；这份是用户新批准范围的提案，尚未以 V5 原生画面验收。

## 观察与源码事实

已查看 V4 `ios-1x-today-default.png`。Moment 后的 Body / Sleep 两张等高卡清楚，但 Body 仍要先进 Record 才选具体症状，Bleeding 也没有直接名字入口。现有 cycle hero 约占首屏一大块；再追加多排同尺寸卡会把主要记录动作推得更远。

读取 `today_experience_visual_baseline.dart`：生产 routed 模式使用 body / sleep / note 的 typed section callback；旧 standalone 模式已经有实际 `_pins` 与 `_symptoms` 的记录显示。Pinned 展示可识别 saved severity，包含明确 zero；不是空值时默认 zero。当前生产构图没有逐症状 typed callback，需由主代理按既有 typed symptom / initialSymptom 合同增加入口，不能把视觉字符串当 ID。

读取 `observation_picker.dart`：已有 experiencedDate、provenance、existingRecords、pinnedSymptoms、initialSymptom、onSave / onDelete / onWithdraw、onDraftChanged、onEditImpacts 与 medical boundary 行为。空 pins 时使用 curated quick picks。下一轮只改变 presentation 与进入／返回，不应重写健康记录合同。

## 一个明确 Today 构图

保留共享标题、原 cycle 事实与 Moment。**用 Quick records 区替换 Body 卡，而不是在 Body 卡后再堆一份快捷网格。**

```text
Moment：现在的感受／真实已存状态

Quick records                           Browse symptoms
Bleeding             Not recorded／真实 flow            >

Pinned by you              （仅实际用户 pin）
[ Cramp · Not present ] [ Anxiety · Not recorded ] …

Common shortcuts            （现有 curated picks）
[ 非重复常用项 ] [ 非重复常用项 ] …

Sleep                 真实摘要／未记录                   >
Private note          自己的文字／添加提示               >

Record more／全局 Record 仍可进入完整 dated hub
```

Bleeding 是一条全宽有名字的 InteractionSurface，约 56–64 pt 高，状态与标题同一行或两行自然增长；不要在 Today 默认展开五个 flow 选项。点击直接进入当日的聚焦 bleeding 编辑，不先找 Record section。

实际 pins 用紧凑命名 tile，每项显示完整症状名、真实今日 severity 或 Not recorded，小 degree 图只是补充。默认每项约 140–170 pt 宽、72–88 pt 高，沿一条可横向滚动的 strip；不用巨大等高 Body 风格 grid，不截断症状名以保持固定高度。所有用户 pins 可达，已记录后也不能消失。若没有 pins，省略 Pinned by you，不伪称默认 picks 为用户定制。

Common shortcuts 只用现有 curated picks，去除与 pins 重复项，首批 2–4 个即可，保持与 pins 同一控件家族、不同真实标题；不是根据 forecast 预测今天有什么症状。不得把 Common 声称为用户最常发生或统计排名。已 pin 常用项只出现一次。Browse symptoms 仍能查找完整目录。

Sleep 和 Private note 改成短的有名字的行，而非为了与两个症状 tile 配平再做一排大卡。它们仍是直接动作，保留真实 sleep 摘要与用户文字。Quick records 没有自己的大外壳，标题与内容共享一个明确区域。允许 Today 自然滚动；不要用压缩字体把所有内容硬塞进首屏。

颜色／字体／图标／press 沿用 Letter Within 与 Build17 Quiet Dusk；强调色只给实际选中／当前动作。区域不增加新的健康评分、phase 动画或独立悬浮导航。

## 真正全屏的症状编辑

进入一个专注的原生全屏 editor，**不在 Record 的带 rail 工作面里继续插入 picker，也不把同一工作面放大成一张巨卡。** 保留正常 SafeArea，与现有 child editor 的关闭关系一致。

```text
Close                 日期：Fri, Oct 9

Cramp                         （当前症状为主标题）
简短 degree 操作提示

       六位 existing degree 控件
Not present                                  Extreme
       当前完整文字／Not recorded

       真正提交后：Saved for Fri, Oct 9 · Undo

记录详情／功能影响／已有安全边界保持可达
```

标题、提示、degree 与真实结果是唯一主任务。Record rail、pinned / search、其它症状、Daily impact 总表与 Bleeding 不在这个编辑器里同时展开。更换症状回到 Browse／来源目录，不在专注页再复制一整份目录。

使用既有 degree graphic、InteractionSurface 与固定文字语义。正常手机六位有足够的 44–48 pt 触区；大字可以 Wrap／自然滚动，不能缩小文字或减少等级。当前选中值完整文字紧邻，零值 Not present 与缺失 Not recorded 持续区别。功能影响属于这一个 record 的原有操作，medical boundary 也不得因全屏简化而消失。

沿用当前 tap-degree 的写入／再点已存 degree 移除行为；**不新增一个看似还需要再次 Save 的按钮。** Close / Back 是退出，不自动创造一次记录。pending / failure / durable success / Undo 仍由原 callbacks 与 session 状态管理；失败保留草稿并可重试。

从 Today 的命名 tile 进入就带具体 symptom、当日 date 与 provenance。返回直接回 Today，重新加载真实事实；从 Record／Patterns 的来源进入则回原来源，日期与 hidden drafts 保留。不要让 Today 用户退出编辑后意外停在一个未请求的 Record Hub 页面，也不要靠无条件连续 pop 绕过 draft guard。

## 点击与空间回应

- Today tile：touch-down 即现有短 press，release 可取消；saved selection 不依赖 toast，不让 haptic await 阻塞进入。
- Full-screen route：沿已有 native transition，约 240–300 ms；症状名与发起 tile 建立简短位置接续即可。不要复制健康截图作临时前景，也不新增长时间透明文字叠影。
- Degree：当前 pressed / selected 图形继续使用，真提交结果才更新 Today 摘要。退出后选中不丢，缺失不填零。
- Reduce Motion：去掉空间接续，仍即时显示标题、当前值、pending／saved／error。没有 compulsory swipe 或长按才能编辑。

## 首轮实现与一次 focused native 验收

修改 Today 快捷构图、typed symptom / bleeding entry 与全屏 presentation；复用当前写入／来源／会话逻辑。保留 public defaults、全局四目的地与 Record 行动、单日与 period range 的区别。不改变 schema、临床评分、产品 managers、Cycle reflections 或 Comfort Kit。

Focused native 只需一个正常尺寸流程：Today 显示 missing／明确 zero／真实 flow → 点实际 pin → 全屏 six-degree 与保存结果 → 退出直接回 Today → 点 Bleeding → 修改／取消 → Browse 一项非 pinned 常用症状。再确认无 pins 的标题真实、已记录 pin 不消失、common 不重复；旧日期／midnight／来源和 draft guard 用有意义行为检查验证。

验收标准是「Today 上看见想记的名字并直接开始，全屏里有足够空间完成一件事」，不是卡片数量增加或另一排 tab 出现。
