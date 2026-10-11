# V6 诊断与一致方向（Kimi UI 优化）

2026-10-11。当前 branch `feat/record-hub-kimi-ui-2026-10-11`，基于 Build17 Record Hub checkpoint。依据：保留的 V4 代表截图、V5 源码实际构图、两段参考视频抽帧、handoff 第 2/11 节的方向与执行数值。本文是"看效果"的对照稿，不是审批稿。

## 一、最影响品质的具体问题（按严重度排序）

### 1. 所有表面是同一种卡片，空间没有主次
Today 的 hero、Moment、quick record 行、pinned tile 全是同一材质、同一圆角、同一填充的圆角矩形，从上到下等距排列。Record 的四个 pane 被一张带边框的巨卡包住，内容不满时底部留一大块被边框圈出的空地（V4 `ios-1x-record-default.png` 直接可见）。这产生用户说的"后台表单"感：不是内容多，而是**每个元素都在争夺同一层级的注意力**。

### 2. 全屏症状编辑浪费了"全屏"
V5 已实现全屏路由，但内部仍是一个通用 AppBar（标题写死 "Symptom"）+ 正文小字日期 + 与 inline 模式完全相同的紧凑 detail card。症状名（产品最有个性的 serif 24 token）被压在 body 日期下面，程度控件缩在上半屏，底部大片空白。全屏没有带来聚焦感，只是"更大的表单页"。

### 3. 界面是"瞬间出现"的，没有到达感
页面所有区块同帧渲染完毕；参考视频的核心质量恰恰是**到达编排**（分层浮起、错峰、从触点生长）。当前唯一的动效词汇是按压 0.985 缩放和 pane 切换 320ms 位移。保存成功的反馈是纯文本行，没有状态绽放。

### 4. 工作台的"叠纸"backing surfaces 是装饰噪音
Record stage 顶部露出两条 hairline 叠边（`record_workspace_stage.dart` 两个 backing surface），在正常尺寸截图里读作"没对齐的边框"，而非层次。前层面卡的 1px 边框 + 投影把内容关进盒子里。

### 5. Today 首屏信息节奏平
Hero 的 "Start period" 是裸 TextButton 浮在卡里；Quick records 区每条都是 icon+两行文字+chevron 的同构行，Bleeding（最高频、最有临床意义）与 Sleep、note 视觉权重相同。

## 二、一致方向："一张安静的书桌"

Quiet Dusk 画布不动。视觉母题：**夜色书桌上只摆当前要做的一件事**。层次用深度（surface 阶梯）与留白表达，不用边框围合；ember 只给"当前动作 / 刚保存的事实"。

### 构图规则
- 每屏一个主任务面。Today 的主任务面是 hero（周期状态）+ Moment；Quick records 退为**扁平列表区**：取消行级卡片底色，用 hairline 分隔，密度提高，让"常用项直接点进去"读起来像一张清单而非一叠卡片。
- 全屏症状编辑是"打开的信"：顶部只有 Close 与日期 eyebrow；症状名用 serif 主标题独占视觉中心；程度控件是唯一操作区，放大触区与间距；当前值是一句完整的话；保存成功行带 Undo。
- Record 工作台保留 V3 的"一个前景面 + 交接动效"空间模型，但去掉叠纸边和前层边框，让 pane 内容直接坐在表面上；空出的底部是书桌的留白，不再是圈出来的空盒子。

### 动效语法（数值来自 handoff §11，逐项声明）
| 事件 | 时长 | 曲线 / 参数 |
| --- | --- | --- |
| 按压 | 按下 80ms / 释放 120ms | scale 0.97 + opacity 0.88，`easeOutCubic`（强化现有 InteractionSurface，从 0.985 加到 0.97） |
| 区块到达 | 300ms | 上移 16px + opacity 0→1，`easeOutCubic`，区块间错峰 50ms，父先子后 |
| 程度选中绽放 | 200ms | 选中 marker scale 0.92→1，`easeOutCubic` |
| 全屏症状路由 | 300ms | iOS 竖向推入（现有 CupertinoPageRoute），内容块再错峰 40ms |
| Record 类别交接 | 320ms（保留） | 现有可打断方向位移 |
| Reduce Motion | ≤150ms 纯 opacity | 无位移 |

### 状态规则
default / pressed / selected / focused / disabled / loading 六态全部由现有 `InteractionSurface` + `RecordOptionScale` 承载；本轮只统一视觉参数，不新增第六态之外的表面。保存成功 = 持久化 callback 之后的文案 + Undo，不用 toast 替代。

## 三、依赖顺序与逐屏计划

1. **切片 1（本次已实现）**：全屏症状编辑重构 + Today 到达编排与 Quick records 扁平化 + 全局按压反馈强化。
2. 切片 2：Record stage 去叠纸/去边框；Record Symptoms workspace 内部构图（pins 命名 tile 化、search/browse 层级）、Daily impact / Bleeding 行状态。
3. 切片 3：Daily life 五个子编辑（Sleep/Activity/Appetite/Event/Temperature）的版面统一与到达动效。
4. 切片 4：三个产品 family manager 列表密度与动作 sheet 统一；Moment sheet 到达编排。
5. 收尾：whole analyzer、全量回归、隔离设备原生截图 + 交互录像、对照 §11.4 自审。

## 四、明确不做

不改任何 domain/data/application/generated API；不改 zero/null、provenance、版本、归档语义；不加 letter archive / preparation-plan 入口；不引入 WebView/GSAP；不换主题色；不做紫色渐变、卡片墙、玻璃拟态堆叠。

## 五、本次验证

- 定向 UI / navigation 回归：64 项通过。
- 全量 Flutter 回归：1055 项通过，1 项既有可选测试跳过，0 失败。
- `flutter analyze --no-pub`：无问题。
- 当前 237 个 production Dart 文件 fingerprint：`de2e1ea5840808d9a5619b2916d67b86c8736bf1a8f6b6fc7e417139a7467eba`。
- 本轮没有改动 domain、data、application 或 generated API。
