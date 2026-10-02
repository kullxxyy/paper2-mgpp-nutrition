# Paper 2：Stata / VS Code 模块化项目

按照参考截图整理为 `main.do + config.do + prep / analyses / output / archive`。
这是对你上传代码的结构整理；原有分析均有对应模块，不新增第三篇的 friction、bootstrap 等研究内容。

## 开始运行

1. 解压 ZIP，用 VS Code 的 **Open Folder** 打开 `paper2_stata_vscode` 整个文件夹。
2. 打开 `main.do`，将顶部 `local configured_root ""` 的空引号改成你解压后项目文件夹的实际完整路径（不包含末尾的 `/main.do`）。这样从 VS Code 的临时 do-file 运行也不依赖 Stata 原来的工作目录。再打开 `config.do`，检查 `P2_DATA_FILE`。默认先找 `data/paper2_data.dta`，没有时使用原来的 Mac 数据路径。
3. Stata 缺少扩展命令时，先手动执行 `install_dependencies.do`。
4. 在 Stata 命令窗口运行（把路径改成你解压后的实际位置）：

```stata
cd "/Users/lenovo/PhD papers/paper 2/do-file/paper2_stata_vscode"
do main.do
```

也可以从任意工作目录运行：

```stata
do "/Users/lenovo/PhD papers/paper 2/do-file/paper2_stata_vscode/main.do" "/Users/lenovo/PhD papers/paper 2/do-file/paper2_stata_vscode"
```

终端里的 `cd` 不会自动改变已打开 Stata 的工作目录。VS Code 如使用现有 Stata 扩展，请先在 Stata 设置上述目录，再发送 `do main.do`。
不要只运行选中的几行 `local`、循环或续行命令；发送整个 do-file 可避免宏作用域和不完整语句问题。

## 文件对应关系

| 文件 | 内容 |
|---|---|
| `main.do` | 按依赖顺序运行全部模块；每个分析前重新加载同一准备样本 |
| `config.do` | 数据路径、结果路径、分析开关及兼容性选项 |
| `prep/00_checks.do` | 数据、变量、面板唯一性、扩展命令检查 |
| `prep/01_data_prep.do` | 基线纯消费者样本、winsor、人口结构、log、工资、事件变量 |
| `prep/05_baseline_groups.do` | 基线热量/收入分组、不同阈值、share 和 Q2 |
| `analyses/02_nutrition_main.do` | 平均营养 DID、事件研究、事件图 |
| `analyses/03_kcal_heterogeneity.do` | 基线低热量异质性 DID 和事件研究 |
| `analyses/04_income_ddd.do` | 基线低收入异质性、热量×收入 DDD |
| `analyses/06_channels.do` | 收入、工资、自用消费、支出、职业、农业进入 |
| `analyses/07_robustness.do` | 阈值/连续变量及原有探索性分组回归 |
| `analyses/08_business_channel.do` | 家庭经营收入、行业和 lag-adjusted DID |
| `analyses/09_nutrition_shares.do` | 营养 share、Q2 与异质性 |
| `analyses/10_eventdd_shares.do` | 原有 eventdd 图；默认关闭，安装 eventdd 后可打开 |
| `output/11_descriptive.do` | 2000 年基线平衡表、营养趋势图 |
| `output/12_tables_diagnostics.do` | 样本与基线分组统计 |
| `archive/paper2_master_original.do` | 原上传文件的完整原样副本 |

每个模块都有 `%% PART` 和 `**# PART` 标记，方便在编辑器中定位。

## 结果位置

- `output/tables/`：原有 esttab 表的 RTF（Word 可打开）与 CSV（Excel 可打开），以及平衡表与样本统计。
- `output/figures/`：PNG 图。
- `output/models/`：每条回归对应的 `.ster` 估计结果。循环结果用变量名区分。
- `output/logs/paper2_run.log`：完整运行记录，包含未单独制表的回归、lincom 与 test。
- `output/data/paper2_analysis_ready.dta`：准备完毕的数据，便于单独重跑分析。

只跑一个模块：先完整运行过一次 `main.do`，然后在 Stata 中运行：

```stata
do config.do
use "$P2_READY", clear
do analyses/03_kcal_heterogeneity.do
```

新启动的 Stata 会话应先运行 `main.do`（或者先设置 `global P2_ROOT` 再执行 `config.do`）。
更改准备步骤或兼容性选项后，要重新运行 `main.do`，不能继续使用旧的 ready 数据。

## 原代码的统计设定

默认保留 pre_end=2003、2004 事件原点、2000 基准期、输入数据的 did、原有 FE 和控制变量组合、community 聚类以及 winsor 比例。
原代码中 DID 多用 individual FE，而事件研究多用 household FE；这里保留这个差异。
原代码没有启用 `keep if t2==1`，本版也未新增农村样本限制。

原代码还有影响估计的定义问题，不能把格式整理当作方法修订：

- `P2_CHILD_HHWAVE=0` 保留原来跨所有年份的家庭儿童计数；改为 1 才按 household-wave 计数。
- `P2_INCOME_HH_Q=0` 保留原来的观测加权基线收入四分位；改为 1 才按每户一条记录分组。
- `P2_ES_ADD_2015=0` 保留原事件项。如果存在 2015 波次，2015 会进入遗漏时期；改为 1 才在相应手写事件回归加入 2015 项。
- 缺失基线分组及农业参与的原有赋值规则暂保留，具体见 `CHANGES.md`。
- 当期热量/收入、ever_farmer 与 post_enter 分组是探索性分析，不应直接作为基线因果异质性证据。

## 验证范围

已检查文件依赖、原回归的模块覆盖、续行与括号/程序/preserve 结构、归档原样性和 ZIP 内容。
当前环境没有 Stata，也没有 `paper2_data.dta`，因此没有运行回归或核对估计系数。
首次本地运行如报错，请提供日志中第一处错误，便于对真实数据核查。
