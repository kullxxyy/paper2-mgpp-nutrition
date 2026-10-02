# 改动说明

## 2026-09-30：运行入口修正

- main.do 顶部新增 `local configured_root ""`，可填写项目文件夹实际路径；明确传入的 do-file 参数仍优先。
- 找到 config.do 后才清空内存，并将 Stata 工作目录切换到项目目录；日志显示项目与输入数据路径。
- 01_data_prep.do 开始时检查配置和 job，避免在未运行主入口时继续处理当前内存中的其他论文数据。
- 用户尚未提供实际解压位置，因此没有把示例路径当作真实路径写死；需要填写 configured_root 或先 cd 到项目目录。

## 结构与输出

- 由单个 1,208 行 do-file 拆成主运行文件、配置文件、prep、analyses、output 和 archive。
- 所有实际回归移入对应模块；数据构造提前完成，各模块重新加载同一准备样本。
- 局部宏在各模块内定义；跨模块配置使用 P2_ 前缀的全局宏。
- 数据读取改用 `use ..., clear`，移除分散的硬编码 `cd`，输出集中管理。
- 原有屏幕 esttab 表另存 RTF/CSV；回归另存 .ster；图另存 PNG；日志改为文本格式。
- 原始文件在 archive 中原样保留，方便对照。

## 运行错误与明确笔误修正

| 原问题 | 处理 |
|---|---|
| 28、90、92 行孤立的 `*/` | 从活动代码移除；归档保留 |
| `use paper2_data.dta, replace` | 改用 `use ..., clear` |
| `COMMID` 与 `commid` 混用 | 活动命令统一 COMMID；仅有 commid 时重命名；二者都有时检查值一致 |
| `mean(d3kcal_pre)` 但生成的是 `d3kcal_pre1` | 改为引用 d3kcal_pre1 |
| `post_enter` 引用未定义 producer | 改用原文件实际构造的 producer_l1 |
| eventdd 定义 RD1 却使用 RD | 改用 RD1；会加入原作者列出的控制变量，因此该可选块不能保证与原空宏运行结果一致 |
| draw_es 重跑时 program 已存在 | 定义前 capture program drop |
| 事件图横轴写 relative to 2000 | 改为 relative to 2004；2000 仍为回归基准 |
| balance_pre2004 文件实际使用 wave==2000 | 输出改名 balance_pre2000.csv |
| estpost ttest 的差值标成 T-C | 改标 C-T，与 mu_1-mu_2 一致（treated=0 为第一组） |
| 热量第一条回归重复 c.age##c.age | 删除重复列项，保留 RD1 中的相同控制 |
| 原 lowS1=nq(2) 注释却写 bottom quartile | 改注释为 bottom half |
| evt_m7 探索性表注却写 did 与 household FE | 改成 evt_m7，并标明 individual FE |
| C8 被 rename 后下游依赖不明确 | prep 中生成 monthly_wage，不改原 C8 列；保留原三个特殊缺失码处理 |

## 明确保留的统计定义（默认没有更改）

1. 家庭儿童数原来按 hhid 汇总所有波次，未按 hhid-wave。默认保留；config 可切换正确波次计数。
2. 基线收入分位数原来在个人-年份面板上 xtile，家庭权重不同。默认保留；config 可改成一户一条。
3. 手写 ES 只有 1997/2004/2006/2009/2011 项。若数据还包含 2015，2000 不是唯一遗漏时期。默认保留；可打开 2015 附加项。
4. qkcal_hh 或 qinc 缺失时，原低组 binary 会变成 0；group3 的 q>=3、kcal_q 的 >=p75 也把 Stata 数字缺失视为较大值。原赋值保留，没有声称是正确的缺失处理。
5. producer_l1 全缺失时原代码赋 0；基线没有生产证据不等于确认非生产者。本版未引入第三篇 strict zero/missing 的样本规则。
6. pre_kcal_std1 的标准化沿用原面板加权；热量均值/分位阈值均在原 winsor 后数据上计算。
7. 原 did 来自数据，未重建；原年份、FE、控制组合、winsor 比例全部保留。
8. post_enter 原回归使用重复的个人-年份行，business channel 才按 tag_hhwave 一户一年一条。这里保持各自设定。
9. 原 DDD 不能自动解决平行趋势问题；原顶端的这句草稿注释未作为方法结论保留。

## 附加模块和输入

- eventdd 整块保留在 analyses/10_eventdd_shares.do，默认关闭；需要安装 eventdd 并设 P2_RUN_EVENTDD=1。原插入空行的绘图方式保留。
- share 的额外 index/comm 控制规格只有在两个字段存在时运行，否则日志明确记录跳过；常规 share 模型照常运行。
- 原开头 H4/hhexpense 支出诊断不进入估计，字段不存在时跳过。
- 平衡表保留原 tab job 的 indicator 顺序；如果 2000 样本缺少某个 job_N，只使用实际存在的原指定 indicator。
- 未提供原数据，无法核对变量编码、真实样本和模型结果；所有方法修订仍需本地运行后审核。
