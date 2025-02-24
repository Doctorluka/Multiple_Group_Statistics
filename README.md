## 前言

尽管在R中，类似`ggpubr`等R包已经提供了便捷的统计学可视化的函数，但是在实际应用过程中，却不是那么简单。尤其是这些R包通常只提供简单的两组之间对比，或提供全局检验。但这些便捷的功能仅能快速简单地查看，既无法判断统计方法选择的合理性，也无法便捷的形成可供发表的统计学结果整理。

对于实际的文章要求，尤其是高质量的SCI杂志，通常会有统计学编辑或审稿人对文章每一个数据的统计方法和结果进行严格的审查，**这些统计学编辑具有一票否决权**，无论你的学术审稿人的意见多么nice，一旦你的统计学方法有问题，且无法满足他的修改要求，你将会迎来无情的拒稿。

为了解决这个问题，经过多方的探索和汇总，并经过了专业的统计学老师指导，我整理了一份多分组统计检验的代码，以供读者参考。由于本人非统计学出身，且因课题需求无法拓展太多，提供的代码难免存在使用上的局限性。本文主要的目的是抛砖引玉，希望读者**根据自己的实际需求来形成合适的工作流程**。

为了降低阅读困难，我把统计函数打包为一个脚本，同时还提供了自身使用的、简单的绘图脚本。主要以整理工作流程为目的，从头梳理多分组统计检验的工作流程和结果解读。如果读者对封装的流程感兴趣，可以自行拆解和改编内容。

## 参考数据和函数

示例数据： `test_data.xlsx`  
函数：`stat_test.R`, `stat_plot.R`

---

事实上，最重要的仍然是对统计学知识的正确认知，才能帮助你做出正确的选择，任何既定的流程都是辅助。

对于统计学方法选择，我认为这一篇推文已经足够解释清楚：

https://mp.weixin.qq.com/s/IF4F0W2ghWRq4ILVP3T49A

## 工作流程图：

![](https://secure2.wostatic.cn/static/7mk7Adtt9cWnSeTGXTagpT/image.png?auth_key=1740405837-cLtLWZn3NgUEEs77h5j9Gk-0-a2eac34a2ae5c3ccb909f2b4512fb5d3)

## 主要函数包含关系

![](https://secure2.wostatic.cn/static/ttvsekmyNSdUVgrLvE4HXP/image.png?auth_key=1740405837-sHLGaRX94PP8FNSZowzsLW-0-d1f3fbe87fcd486ab4f8fc8ee21f5df9)

## 函数使用

#### 1. 首先我们新建一个R project，并进入工作目录，通常我会在工作目录下创建以下文件夹

```Bash
.
├── data        # 原始数据
├── figures     # 绘图
├── test.Rproj  
├── results     # 输出
├── scripts     # 脚本
└── utils       # 存放当前项目使用的封装函数
```

#### 2. 导入必要的R包和函数

```R
suppressPackageStartupMessages({
  library(openxlsx)
  library(tibble)
  library(tidyverse)
  library(ggpubr)
  source("utils/stat_test.R")
  source("utils/stat_plot.R")
})
```

#### 3. 读入数据。

> 这是graphpad prism的双因素方差分析的示例数据，主要包括两个干预因素：某基因的敲除（KO vs. WT）和不同培养条件（Serum_starved vs. Normal_culture）下检测的某项指标。
`group`列为分组，`value`列为检测指标的值。
实验设计为典型的两两组合设计，符合双因素方差分析的需求。

```R
test_data <- read.xlsx("data/test.xlsx")
#                group value
# 1   WT_Serum_starved    34
# 2   WT_Serum_starved    36
# 3   WT_Serum_starved    41
# 4   WT_Serum_starved    43
# 5   KO_Serum_starved    98
# 6   KO_Serum_starved    87
# 7   KO_Serum_starved    95
# 8   KO_Serum_starved    99
# 9   KO_Serum_starved    88
# 10 WT_Normal_culture    23
# 11 WT_Normal_culture    19
# 12 WT_Normal_culture    26
# 13 WT_Normal_culture    29
# 14 WT_Normal_culture    25
# 15 KO_Normal_culture    32
# 16 KO_Normal_culture    29
# 17 KO_Normal_culture    26
# 18 KO_Normal_culture    33
# 19 KO_Normal_culture    30
```

#### 4. 为数据加入干预因素的标记

```R
test_data$ko <- ifelse(test_data$group %in% c("WT_Serum_starved", "WT_Normal_culture"), "no", "yes")
test_data$culture <- ifelse(test_data$group %in% c("WT_Serum_starved", "KO_Serum_starved"), "Serum_starved", "Normal_culture")

#                group value  ko        culture
# 1   WT_Serum_starved    34  no  Serum_starved
# 2   WT_Serum_starved    36  no  Serum_starved
# 3   WT_Serum_starved    41  no  Serum_starved
# 4   WT_Serum_starved    43  no  Serum_starved
# 5   KO_Serum_starved    98 yes  Serum_starved
# 6   KO_Serum_starved    87 yes  Serum_starved
# 7   KO_Serum_starved    95 yes  Serum_starved
# 8   KO_Serum_starved    99 yes  Serum_starved
# 9   KO_Serum_starved    88 yes  Serum_starved
# 10 WT_Normal_culture    23  no Normal_culture
# 11 WT_Normal_culture    19  no Normal_culture
# 12 WT_Normal_culture    26  no Normal_culture
# 13 WT_Normal_culture    29  no Normal_culture
# 14 WT_Normal_culture    25  no Normal_culture
# 15 KO_Normal_culture    32 yes Normal_culture
# 16 KO_Normal_culture    29 yes Normal_culture
# 17 KO_Normal_culture    26 yes Normal_culture
# 18 KO_Normal_culture    33 yes Normal_culture
# 19 KO_Normal_culture    30 yes Normal_culture

```

#### 5. 检测正态性与方差齐性

> 使用参数说明：
1. `data`：输入数据，需要为“清洁数据”，即同一指标的连续型/分类变量归为一列
2. `response_col`：需要检测的数据的列名（此处为`value`）
3. `group_col`：分组信息的列名（此处为`group`）
4. `method`（optional）：方差齐性检验的方法，默认为`"levene"`，还可以选择`"bartlett"`。

```R
nor_res <- test_assumptions(data = test_data, response_col = "value", group_col = "group", method = "levene")
# Finish shapiro.test!
# Finish levene test!
# Warning message:
# In leveneTest.default(y = y, group = group, ...) : group coerced to factor.

```

查看一下数据

> 输出结果为`list`结构：
1. `test.results`：
    - step：标记这一步的意义，同样的步骤（例如正态性检验）有多个结果时，只标记一次
    - method：对应step使用的统计学方法
    - group：分组。正态性检验按照分开各组独立检验；而方差齐性则是检验各组之间的方差是否相等，标记为使用公式
    - p.value：统计结果
    - sig：显著性标记。如果存在p<0.05，则以`*`标记。最高为`****`代表p<0.0001。
2. `pass`：`TRUE`代表同时符合正态性和方差齐性；`FALSE`代表正态性和方差齐性两者或其一不符合。

```R
$test.results
                      step       method             group   p.value sig
1                Normality shapiro.test KO_Normal_culture 0.8326528    
2                          shapiro.test  KO_Serum_starved 0.2359466    
3                          shapiro.test WT_Normal_culture 0.9554189    
4                          shapiro.test  WT_Serum_starved 0.5887706    
5 Homogeneity of Variances   leveneTest     value ~ group 0.4012227    

$pass
[1] TRUE
```



#### 6. 全局检验和事后检验

进行正态性检验后，应该选择合适的检验方法。这里提供了自动选择的函数。

> 使用参数说明（与上面重复的参数不作说明）：
`test_assumptions_res`：正态性与方差齐性检验结果，即上面的`nor_res`
`factors`：实验设计中的干预因素对应的列名，这里为`c("ko", "culture")`
`interaction`：是否考虑干预因素之间的交互效应，默认为`TRUE`
`aov_post_hoc`：ANOVA的事后检验方法，默认为`holm`，可选`tukey`
`kw_post_hoc`：KW的事后检验方法，默认为`dunn`，可选`wilcox`（任何非`dunn`的输入都会自动转为`wilcox`）

【备注】统计学老师告诉我，wilcoxon.test只有在没得选的时候才使用，并不是一种严谨的统计学方法，非必要不使用。

执行后，会自动打印检验信息。如果你的设计不符合two-way ANOVA，例如缺少了其中一组，则`interaction`无法计算，会自动转为one-way ANOVA，仅考虑`group_col`的主效应。

在这里，我们能看到`ko`和`culture`都具有显著性，且两者的交互作用`ko:culture`也是具有显著性。如果全局检验没有显著性，则会跳过事后检验步骤，并结束计算。

```R
stat_res <- auto_stat_test(data = test_data, 
                           test_assumptions_res = nor_res, 
                           response_col = "value", 
                           group_col = "group", 
                           factors = c("ko", "culture"), 
                           interaction = TRUE, 
                           aov_post_hoc = "holm", 
                           kw_post_hoc = "dunn")
                           
# Normality and homogeneity of variances assumptions are met.
# Performing parametric test: ANOVA.
# Try to perform ANOVA test ...
# ---> Formula = value ~ ko*culture 
# ANOVA results:
#             Df Sum Sq Mean Sq F value           Pr(>F)    
# ko           1   4562    4562   259.8 0.00000000007008 ***
# culture      1   7631    7631   434.6 0.00000000000173 ***
# ko:culture   1   2859    2859   162.8 0.00000000185783 ***
# Residuals   15    263      18                             
# ---
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
# ANOVA p<0.05. Performing post-hoc: holm.
#                            comparison               p.value     method
# 1  KO_Serum_starved-KO_Normal_culture 0.0000000000011615406 Holm-Sidak
# 2 WT_Normal_culture-KO_Normal_culture 0.0517738262855162654 Holm-Sidak
# 3  WT_Serum_starved-KO_Normal_culture 0.0170968348865750026 Holm-Sidak
# 4  WT_Normal_culture-KO_Serum_starved 0.0000000000004027528 Holm-Sidak
# 5   WT_Serum_starved-KO_Serum_starved 0.0000000000178067761 Holm-Sidak
# 6  WT_Serum_starved-WT_Normal_culture 0.0004606831583011530 Holm-Sidak


```

#### 7. 数据整合和清洁

为了更加符合文章发表的需求，这里还提供了一个函数，用于整理上述数据并方便导出。

> `nor`：为正态性与方差齐性检验结果
`stat`：为全局检验与事后检验结果
`tast_name`：该数据的名称（方便记录和查看）

```R
stat_summary <- stat_res_collect(data = test_data, nor = nor_res, stat = stat_res, task_name = "demo_data")
# Complete data cleaning!
```

查看数据结构，为`list`结构：

> `demo_data`：该命名源自`tast_name`参数，储存纳入统计的数据
`stat_test`：为上述两步的结果整合，具体内容可参考正态性与方差齐性的结果解读。

```R
$demo_data
               group value  ko        culture
1   WT_Serum_starved    34  no  Serum_starved
2   WT_Serum_starved    36  no  Serum_starved
3   WT_Serum_starved    41  no  Serum_starved
4   WT_Serum_starved    43  no  Serum_starved
5   KO_Serum_starved    98 yes  Serum_starved
6   KO_Serum_starved    87 yes  Serum_starved
7   KO_Serum_starved    95 yes  Serum_starved
8   KO_Serum_starved    99 yes  Serum_starved
9   KO_Serum_starved    88 yes  Serum_starved
10 WT_Normal_culture    23  no Normal_culture
11 WT_Normal_culture    19  no Normal_culture
12 WT_Normal_culture    26  no Normal_culture
13 WT_Normal_culture    29  no Normal_culture
14 WT_Normal_culture    25  no Normal_culture
15 KO_Normal_culture    32 yes Normal_culture
16 KO_Normal_culture    29 yes Normal_culture
17 KO_Normal_culture    26 yes Normal_culture
18 KO_Normal_culture    33 yes Normal_culture
19 KO_Normal_culture    30 yes Normal_culture

$stat_test
        task                     step       method                               group p.value  sig
1  demo_data                Normality shapiro.test                   KO_Normal_culture  0.8327     
2                                     shapiro.test                    KO_Serum_starved  0.2359     
3                                     shapiro.test                   WT_Normal_culture  0.9554     
4                                     shapiro.test                    WT_Serum_starved  0.5888     
5            Homogeneity of Variances   leveneTest                       value ~ group  0.4012     
6                    Parametric tests        ANOVA                         ko          <0.0001 ****
7                                                                          culture     <0.0001 ****
8                                                                          ko:culture  <0.0001 ****
9                       Post hoc test   Holm-Sidak  KO_Serum_starved-KO_Normal_culture <0.0001 ****
10                                      Holm-Sidak WT_Normal_culture-KO_Normal_culture  0.0518     
11                                      Holm-Sidak  WT_Serum_starved-KO_Normal_culture  0.0171    *
12                                      Holm-Sidak  WT_Normal_culture-KO_Serum_starved <0.0001 ****
13                                      Holm-Sidak   WT_Serum_starved-KO_Serum_starved <0.0001 ****
14                                      Holm-Sidak  WT_Serum_starved-WT_Normal_culture  0.0005  ***
```

最后我们可以导出为excel文件，`list`结构会自动变成sheets。

这样一个规范整理的表格，可以直接用于投稿，也可以用于数据的备份与检查。

```R
write.xlsx(stat_summary, "results/demo_stat_res.xlsx", rowNames = F)
```

#### 8. 补充：两组比较

在实际数据统计中，两组与多组数据比较都会频繁出现。为了提高函数的泛用性，我还把两组比较纳入流程之中，仍然是这两个函数。

首先我们截取前两组。

```R
test_data_filter <- test_data %>% 
  filter(culture == "Serum_starved")
```

还是进行同样的流程，如果同时符合正态性和方差齐性，则会使用`t.test`检验，否则使用`wilcox.test`。p值矫正使用`holm`。

```R
# 1. 正态性与方差齐性检验
nor_filter_res <- test_assumptions(data = test_data_filter, response_col = "value", group_col = "group")
# Finish shapiro.test!
# Finish levene test!
# Warning message:
# In leveneTest.default(y = y, group = group, ...) : group coerced to factor.

# 2. 两组比较
stat_filter_res <- auto_stat_test(data = test_data_filter, 
                                  test_assumptions_res = nor_filter_res, 
                                  response_col = "value", 
                                  group_col = "group")
# Normality and homogeneity of variances assumptions are met.
# Number of group is 2.
# Performing parametric test: Student's t-test.

```

在数据整理这一步，我额外写了一个函数（避免主函数层次过于复杂）

```R
filter_stat_summary <- stat_res_collect_two_group(test_data_filter, nor_filter_res, stat_filter_res, "demo_two_group")

```

查看输出结果，保存的时候仍然同前即可。

```R
$demo_two_group
             group value  ko       culture
1 WT_Serum_starved    34  no Serum_starved
2 WT_Serum_starved    36  no Serum_starved
3 WT_Serum_starved    41  no Serum_starved
4 WT_Serum_starved    43  no Serum_starved
5 KO_Serum_starved    98 yes Serum_starved
6 KO_Serum_starved    87 yes Serum_starved
7 KO_Serum_starved    95 yes Serum_starved
8 KO_Serum_starved    99 yes Serum_starved
9 KO_Serum_starved    88 yes Serum_starved

$stat_test
                      step       method                             group p.value  sig
1                Normality shapiro.test                  KO_Serum_starved  0.2359     
2                          shapiro.test                  WT_Serum_starved  0.5888     
3 Homogeneity of Variances   leveneTest                     value ~ group  0.6138     
4         Parametric tests       t.test KO_Serum_starved-WT_Serum_starved <0.0001 ****
```



#### 9. 绘图（可选）

我们还提供了一些简单的用于绘图的函数，储存在`stat_plot.R`这个脚本中，这里提供一些简单的示例。

风格上主要是模仿GraphPad Prism。

1. 自动计算画图参数

> `p_value`：提取p值
`segment_position`：线段y轴高度，用于表示两组比较最低绘图线段的位置
`add_position`：y轴增量，用于调整位置
`y_lim`：根据数据自动计算合适的y轴范围

```R
plot_para <- get_plot_para(test_data, "value", stat_summary)
# $p_value
# KO_Serum_starved-KO_Normal_culture WT_Normal_culture-KO_Normal_culture 
#                          "<0.0001"                            "0.0518" 
# WT_Serum_starved-KO_Normal_culture  WT_Normal_culture-KO_Serum_starved 
#                           "0.0171"                           "<0.0001" 
# WT_Serum_starved-KO_Serum_starved  WT_Serum_starved-WT_Normal_culture 
#                          "<0.0001"                            "0.0005" 
# 
# $segment_position
# [1] 102.3
# 
# $add_position
# [1] 3.3
# 
# $y_lim
# [1] 125.4

```

1. 基础绘图

```R
plot_basic <- plot_bar_basic(test_data, x = "group", y = "value", ylab = "plot for value")
```

![](https://secure2.wostatic.cn/static/2KHiEfC1K16XogyYCeDj9o/image.png?auth_key=1740405837-uQaEiEWH4KcTr1oKYjQUwE-0-833021b2753e6ff91244a3da3b62e31f)



1. 根据参数进一步标记显著性

```R
plot_stat <- plot_basic +
  scale_fill_manual(
    values = c("#60c3a6", "#f18e5f", "#8a9eca", "#de8ab7")
  ) + 
  scale_y_continuous(breaks = seq(0, 160, by = 20), expand = c(0,0), limits = c(0,plot_para$y_lim)) + 
  # WT_Serum_starved vs. KO_Serum_starved
  annotate("segment", x = 1.05, xend = 1.95, y = plot_para[[2]])+
  annotate("text", x = 1.5, y = plot_para[[2]] + plot_para[[3]]*1.5, label = plot_para[[1]]["WT_Serum_starved-KO_Serum_starved"])+
  # WT_Normal_culture vs. KO_Serum_starved
  annotate("segment", x = 3.05, xend = 3.95, y = plot_para[[2]])+
  annotate("text", x = 3.5, y = plot_para[[2]] + plot_para[[3]]*1.5, label = plot_para[[1]]["WT_Normal_culture-KO_Serum_starved"])+
  # KO_Serum_starved vs. KO_Normal_culture
  annotate("segment", x = 2.05, xend = 3.95, y = plot_para[[2]]+ plot_para[[3]]*3.5)+
  annotate("text", x = 3, y = plot_para[[2]] + plot_para[[3]]*5, label = plot_para[[1]]["KO_Serum_starved-KO_Normal_culture"])
plot_stat
```

![](https://secure2.wostatic.cn/static/u2sQzGCm5R4TbZxTVcGZKy/image.png?auth_key=1740405837-nuYsxgU6ub8ZLZRPMKaaE8-0-efd2e64c495c814f6d202fdc4bb0c6e6)



对于两组来说，就不需要`get_plot_para`这个函数了，我们`plot_bar_basic`基础上在简单编辑可以。

这里提供脚本封装内的函数`p_to_star`的使用示例，可以把p值转换为星号。

```R
filter_basic <- plot_bar_basic(test_data_filter, x = "group", y = "value", ylab = "plot for value")

# 转换为星号（单个p值转换）
p_label <- p_to_stars(stat_filter_res[[1]]$p.value)
# 如果是多组多个p值，可以是这样使用：
# p_label <- sapply(stat_filter_res[[1]]$p.value, p_to_stars)

filter_stat_plot <- filter_basic +
  scale_fill_manual(
    values = c("#60c3a6", "#00a54f")
  ) + 
  scale_y_continuous(breaks = seq(0, 120, by = 20), expand = c(0,0), limits = c(0, 120)) + 
  # aov/kw p.value
  annotate("segment", x = 1, xend = 2, y = 110) +
  annotate("text", x = 1.5, y = 112, label = p_label, size = 8)

filter_stat_plot
```

![](https://secure2.wostatic.cn/static/sfyKPD4LvYWQsoaAVGwsvg/image.png?auth_key=1740405837-gkc7gSAFbcWZMbSUEAapH8-0-31da21f634cf6b6c712e92a28cfc1de7)
