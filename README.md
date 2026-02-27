# A Structured Workflow for Statistical Analysis of Multiple Groups in R

> 中文教程见：https://github.com/Doctorluka/Multiple_Group_Statistics/blob/main/Tutuorial-CN.md
> Version wrote by Python: https://github.com/huazhuofeng/statistics_in_python

## Preface

While R packages such as `ggpubr` offer convenient functions for statistical visualization, practical research applications often present complexities that extend beyond their capabilities. These packages typically accommodate only simple two-group comparisons or global tests. Although they can generate preliminary results efficiently, they fall short in helping users assess the appropriateness of selected statistical methods or in producing results that meet publication standards.

In high-impact SCI journals, statistical editors and reviewers rigorously scrutinize every statistical method and result presented in manuscripts. **Statistical editors possess veto power**—even if academic reviewers hold your research in high regard, your manuscript may still face rejection if statistical issues cannot be satisfactorily addressed during revision.

To address this challenge, I have synthesized insights from multiple sources, incorporating guidance from professional statisticians, to develop a comprehensive workflow for multi-group statistical comparisons. This workflow is presented here for reference. To enhance generalizability, I have also included procedures for two-group analyses. As a non-statistician with constraints imposed by specific research questions, the provided code may have limitations. The primary objective of this article is to stimulate discussion and **encourage readers to develop workflows tailored to their specific research needs**.

Fundamentally, sound statistical knowledge remains paramount for making appropriate methodological choices; any standardized workflow serves merely as a supplementary tool. For statistical method selection, I consider this article sufficiently comprehensive:
```
https://mp.weixin.qq.com/s/IF4F0W2ghWRq4ILVP3T49A
```

To facilitate comprehension, I have encapsulated statistical functions into scripts, accompanied by basic visualization scripts for personal use. This article focuses on delineating the workflow for multi-group statistical testing and result interpretation, aiming to assist readers in constructing complete analytical pipelines from scratch. Readers interested in the encapsulated procedures may deconstruct and adapt the content as needed.

---

## Reference Data and Functions

Example dataset: `test_data.xlsx`  
Functions: `stat_test.R`, `stat_plot.R`

---

## Workflow Diagram

![](https://secure2.wostatic.cn/static/7mk7Adtt9cWnSeTGXTagpT/image.png?auth_key=1741054910-zVxvocq7ELY6HzA8PGLvQ-0-b028083e850aa41bca8e29d22d4e446d)

## Overview of Main and Subfunctions

|**Main Function**|**Description**|**Secondary Functions**|**Tertiary Functions**|
|-|-|-|-|
|`test_assumptions`|Normality and homogeneity of variance testing|`perform_shapiro_by_group` `perform_variances_homogeneity_test`||
|`auto_stat_test`|Automated global and post-hoc testing|`perform_anova_test` `perform_kw_test` `perfrom_stat_for_two_group`|`build_aov_formula` `preform_avo_post_hoc` `perform_pairwise_wilcoxon` `rev_dunn_comparision`|
|`stat_res_collect` `stat_res_collect_two_group`|Data organization||`p_to_stars`|

---

## Function Implementation

### 1. Project Initialization and Directory Structure

Begin by creating an R project with the following directory structure:

```Bash
.
├── data        # Raw data
├── figures     # Visualizations
├── test.Rproj  
├── results     # Output files
├── scripts     # Analysis scripts
└── utils       # Custom functions for current project
```

### 2. Loading Required Packages and Functions

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

### 3. Data Import

> This dataset represents example data for two-way ANOVA in GraphPad Prism, featuring two intervention factors: gene knockout (KO vs. WT) and culture conditions (Serum_starved vs. Normal_culture), with corresponding measurements.
> The `group` column denotes experimental groups, while the `value` column contains measurements.
> The experimental design follows a typical factorial arrangement, suitable for two-way ANOVA.

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

### 4. Annotating Intervention Factors

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

### 5. Testing Normality and Homogeneity of Variances

> Parameter specifications:
> 1. `data`: Input dataset in "tidy" format (each variable in a separate column)
> 2. `response_col`: Name of column containing response variable (here, `"value"`)
> 3. `group_col`: Name of column containing group information (here, `"group"`)
> 4. `method` (optional): Method for homogeneity of variance test, default `"levene"`, alternative `"bartlett"`

```R
nor_res <- test_assumptions(data = test_data, response_col = "value", group_col = "group", method = "levene")
# Finish shapiro.test!
# Finish levene test!
# Warning message:
# In leveneTest.default(y = y, group = group, ...) : group coerced to factor.
```

#### Output Interpretation

> The function returns a `list` object with the following structure:
> 1. `test.results`:
>    - `step`: Description of analytical step
>    - `method`: Statistical method employed
>    - `group`: Group identifier (for normality tests, each group is tested independently; homogeneity of variance tests across groups are denoted by formula)
>    - `p.value`: Resulting p-value
>    - `sig`: Significance notation (`*` for p<0.05, up to `****` for p<0.0001)
> 2. `pass`: `TRUE` if both normality and homogeneity assumptions are satisfied; `FALSE` otherwise.

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

### 6. Global Testing and Post-hoc Analysis

Following normality assessment, appropriate statistical methods should be selected. The automated selection function is provided below.

> Parameter specifications (excluding those previously described):
> `test_assumptions_res`: Results from assumption testing (the `nor_res` object)
> `factors`: Column names corresponding to intervention factors in the experimental design (here, `c("ko", "culture")`)
> `interaction`: Whether to consider interaction effects between factors, default `TRUE`
> `aov_post_hoc`: Post-hoc method for ANOVA, default `"holm"`, alternative `"tukey"`
> `kw_post_hoc`: Post-hoc method for Kruskal-Wallis test, default `"dunn"`, alternative `"wilcox"` (any input other than `"dunn"` automatically defaults to `"wilcox"`)

**Note**: According to statistical consultation, the Wilcoxon test should be employed only as a last resort, as it lacks rigor compared to alternative methods.

Upon execution, the function automatically displays test information. If the experimental design does not support two-way ANOVA (e.g., missing groups preventing interaction calculation), the analysis automatically reverts to one-way ANOVA, considering only the main effect of `group_col`.

In this example, both `ko` and `culture` demonstrate significance, and their interaction (`ko:culture`) is also significant. If the global test yields non-significant results, post-hoc testing is bypassed.

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

### 7. Data Integration and Cleaning

To enhance suitability for publication, a function is provided for organizing the aforementioned results into exportable formats.

> Parameter specifications:
> `nor`: Results from normality and homogeneity testing
> `stat`: Results from global and post-hoc testing
> `task_name`: Identifier for the dataset (facilitates record-keeping and review)

```R
stat_summary <- stat_res_collect(data = test_data, nor = nor_res, stat = stat_res, task_name = "demo_data")
# Complete data cleaning!
```

#### Output Structure

The function returns a `list` object:

> `demo_data`: Contains the analyzed data (named according to the `task_name` parameter)
> `stat_test`: Integrated results from both analytical steps, structured similarly to the assumption testing output

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

The organized results can be exported as an Excel file, with list elements automatically converted to separate sheets:

```R
write.xlsx(stat_summary, "results/demo_stat_res.xlsx", rowNames = F)
```

This systematically organized table is suitable for direct submission or for data backup and verification.

### 8. Supplementary: Two-Group Comparisons

In practical data analysis, both two-group and multi-group comparisons frequently occur. To enhance generalizability, the workflow incorporates two-group comparisons using the same functions.

First, subset the first two groups:

```R
test_data_filter <- test_data %>% 
  filter(culture == "Serum_starved")
```

Following the same workflow, if both normality and homogeneity assumptions are satisfied, a `t.test` is performed; otherwise, the `wilcox.test` is employed, with p-value adjustment using the `holm` method.

```R
# 1. Normality and homogeneity testing
nor_filter_res <- test_assumptions(data = test_data_filter, response_col = "value", group_col = "group")
# Finish shapiro.test!
# Finish levene test!
# Warning message:
# In leveneTest.default(y = y, group = group, ...) : group coerced to factor.

# 2. Two-group comparison
stat_filter_res <- auto_stat_test(data = test_data_filter, 
                                  test_assumptions_res = nor_filter_res, 
                                  response_col = "value", 
                                  group_col = "group")
# Normality and homogeneity of variances assumptions are met.
# Number of group is 2.
# Performing parametric test: Student's t-test.
```

For data organization, a specialized function is provided (to avoid excessive complexity in the main function):

```R
filter_stat_summary <- stat_res_collect_two_group(test_data_filter, nor_filter_res, stat_filter_res, "demo_two_group")
```

#### Output Examination

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

Exporting follows the same procedure as previously described.

### 9. Visualization (Optional)

Basic visualization functions are provided in the `stat_plot.R` script, with examples below. The visual style is designed to emulate GraphPad Prism.

#### 1. Automatic Calculation of Plot Parameters

> `p_value`: Extracted p-values
> `segment_position`: Y-axis position for the lowest comparison segment
> `add_position`: Y-axis increment for segment positioning
> `y_lim`: Automatically calculated appropriate y-axis range

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

#### 2. Basic Plot Generation

```R
plot_basic <- plot_bar_basic(test_data, x = "group", y = "value", ylab = "plot for value")
```

![basic_bar_plot](https://github.com/Doctorluka/Multiple_Group_Statistics/blob/main/stat_plots/basic_bar_plot.png)

#### 3. Annotation with Significance Markers

The following code demonstrates significance annotation based on calculated parameters. Manual adjustments may be applied as needed.

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

![add_stat_results](https://github.com/Doctorluka/Multiple_Group_Statistics/blob/main/stat_plots/stat_bar_plot.png)

For two-group comparisons, the `get_plot_para` function is unnecessary. Simple editing of the `plot_bar_basic` output suffices.

The following example demonstrates the `p_to_stars` function, which converts p-values to asterisk notation:

```R
filter_basic <- plot_bar_basic(test_data_filter, x = "group", y = "value", ylab = "plot for value")

# Convert single p-value to asterisks
p_label <- p_to_stars(stat_filter_res[[1]]$p.value)
# For multiple p-values:
# p_label <- sapply(stat_filter_res[[1]]$p.value, p_to_stars)

filter_stat_plot <- filter_basic +
  scale_fill_manual(
    values = c("#60c3a6", "#00a54f")
  ) + 
  scale_y_continuous(breaks = seq(0, 120, by = 20), expand = c(0,0), limits = c(0, 120)) + 
  # ANOVA/KW p-value annotation
  annotate("segment", x = 1, xend = 2, y = 110) +
  annotate("text", x = 1.5, y = 112, label = p_label, size = 8)

filter_stat_plot
```

![two_groups](https://github.com/Doctorluka/Multiple_Group_Statistics/blob/main/stat_plots/two_group.png)

### 10. Application Scenario: Multi-Group Bulk Transcriptome Analysis

This section demonstrates how to apply the aforementioned functions for statistical analysis of gene expression in a multi-group bulk transcriptome dataset.

#### 1. Data Examination

```R
# This is a DESeq2-normalized expression matrix
exprSet_vst[1:4,1:4]
#             W81      W83      W84      W80
# Lyz2   18.57773 18.81743 18.98225 18.92183
# Mt-co1 18.29783 18.89893 18.64288 18.55819
# Sftpc  17.59295 18.24031 18.13995 18.04844
# Mt-co3 16.58128 17.23893 17.41379 17.52487

# Corresponding metadata
head(datTraits)
#     sample group sample2     RVSP    Fulton     RVID  PAT.PET    TAPSE        CO group2
# W81    W81   CON  Cont_2  32.4500 0.2647000 1.678753 0.450777 2.389750 114.04988    CON
# W83    W83   CON  Cont_3  29.3237 0.2593000 1.530280 0.305483 2.518139  92.83599    CON
# W84    W84   CON  Cont_4  31.9598 0.2881500 1.357813 0.345269 2.241625  68.61000    CON
# W80    W80   CON  Cont_1  30.8033 0.2437100 1.589875 0.287154 2.103375  73.24000    CON
# A84    A84  SuHx  SuHx_6 106.6120 0.6791720 2.567500 0.132184 2.537875  44.53881   SuHx
# A96    A96  SuHx  SuHx_1 119.5660 0.8120392 2.853875 0.183333 2.024375  76.80200   SuHx 
```

#### 2. Data Restructuring and Gene Selection

```R
# Add intervention factor annotations
datTraits$suhx <- ifelse(datTraits$group == "CON", "con", "suhx")
datTraits$inulin <- ifelse(datTraits$group %in% c("CON", "SuHx"), "con", "inulin")
datTraits$gw <- ifelse(datTraits$group == "SuHx-IN+GW", "gw", "con")

# Extract gene expression information
datExpr2 <- t(exprSet_vst)
gene_to_use = c("Fanci", "Fancd2", "H2ax", "Fancl")
gene_to_use = gene_to_use[gene_to_use %in% colnames(datExpr2)]

# Merge and retain relevant columns
data <- cbind(datTraits, datExpr2[,gene_to_use]) %>% 
  select(all_of(c("sample", "group", "RVSP", "Fulton", "RVID", "PAT.PET", 
                  "TAPSE", "CO", "inulin", "suhx", "gw", "Fanci", "Fancd2", 
                  "H2ax", "Fancl")))

head(data)
#     sample group     RVSP    Fulton     RVID  PAT.PET    TAPSE        CO inulin suhx  gw    Fanci   Fancd2     H2ax    Fancl
# W81    W81   CON  32.4500 0.2647000 1.678753 0.450777 2.389750 114.04988    con  con con 6.479441 6.544456 8.813432 7.686432
# W83    W83   CON  29.3237 0.2593000 1.530280 0.305483 2.518139  92.83599    con  con con 6.713148 6.379477 8.215798 7.830406
# W84    W84   CON  31.9598 0.2881500 1.357813 0.345269 2.241625  68.61000    con  con con 6.782347 6.746125 8.837235 7.967137
# W80    W80   CON  30.8033 0.2437100 1.589875 0.287154 2.103375  73.24000    con  con con 6.610660 6.390644 8.596658 7.927415
# A84    A84  SuHx 106.6120 0.6791720 2.567500 0.132184 2.537875  44.53881    con suhx con 6.902632 6.851762 8.928339 7.597125
# A96    A96  SuHx 119.5660 0.8120392 2.853875 0.183333 2.024375  76.80200    con suhx con 6.621814 6.605791 8.838876 7.687908
```

#### 3. Encapsulating Functions for Batch Processing

```R
# Function for batch statistical analysis
stat_fc <- function(data, gene){
  nor <- test_assumptions(data, gene, "group")
  stat <- auto_stat_test(data, nor, gene, "group", factors = c("suhx", "inulin", "gw"))
  stat_summary <- stat_res_collect(data, nor, stat, glue::glue("Fig6_{gene}"))
  
  return(stat_summary)
}
```

#### 4. Execution

```R
stats_res_list <- lapply(gene_to_use, function(i) stat_fc(data = data, gene = i))
names(stats_res_list) <- gene_to_use
```

![](https://github.com/Doctorluka/Multiple_Group_Statistics/blob/main/stat_plots/stat1.png)

The resulting output is a list for each gene, structured as previously described. The first element contains the analyzed data (here, `data`), and the second contains the summary statistical dataframe:

![](https://github.com/Doctorluka/Multiple_Group_Statistics/blob/main/stat_plots/stat2.png)

#### 5. Batch Export

```R
for (g in gene_to_use) {
  res_use <- stats_res_list[[g]]
  openxlsx::write.xlsx(res_use, file = glue::glue("results/{g}_stat_res.xlsx"))
}
```
