# Multiple_Group_Statistics
R Functions for Multiple Group Statistics


---

# R语言多分组统计检验教程

---

## 一、正态性与方差齐性检验

### 1.1 正态性检验
1. **Shapiro-Wilk检验**
   - 使用`perform_shapiro_by_group()`函数，按分组对响应变量进行正态性检验[^3]。
   - 解读结果：若任一分组数据的\( p \)-值<0.05，拒绝正态性假设[^3]。

### 1.2 方差齐性检验
1. **Levene检验**
   - 通过`perform_variances_homogeneity_test()`函数实现，默认方法为Levene检验[^4]。
   - 动态构建检验公式（`响应变量 ~ 分组变量`）并计算组间方差齐性[^4]。
2. **Bartlett检验**
   - 适用于正态性假设满足的数据，可在同一函数中通过参数`method = "bartlett"`调用[^4]。

### 1.3 综合假设判定
- 同时满足正态性（所有分组 \( p \)-值≥0.05）和方差齐性（\( p \)-值≥0.05）时，标记为通过检验[^1][^3]。

---

## 二、统计检验与事后检验

### 2.1 参数检验流程（ANOVA）
1. **单因素/多因素ANOVA**
   - 使用`perform_anova_test()`函数执行，支持交互作用分析（`interaction = TRUE`）[^1]。
2. **事后检验方法**
   - Tukey HSD或基于Holm校正的成对比较（通过参数`aov_post_hoc`指定）[^1][^3]。
   - 结果整合到标准化表格中，包含比较组、校正后\( p \)-值与显著性标记（*** <0.001）[^2]。

### 2.2 非参数检验流程（Kruskal-Wallis）
1. **Kruskal-Wallis检验**
   - 当假设检验未通过时，调用`perform_kw_test()`进行组间差异分析[^1]。
2. **事后检验方法**
   - **Dunn检验**：默认使用Bonferroni或Holm校正的多组比较，结果返回校正\( p \)-值[^6]。
   - **成对Wilcoxon检验**：当指定`kw_post_hoc = "pairwise.wilcoxon"`时执行，需二次校正多重比较[^6]。

### 2.3 结果整合与报告
1. **标准化输出结构**
   - 通过`stat_res_collect()`按任务汇总检验步骤、方法、比较组和\( p \)-值[^2]。
   - 数据格式包含正态性、方差齐性及事后检验三部分，\( p \)-值四舍五入至四位小数[^2]。
2. **判定逻辑**
   - 若ANOVA或Kruskal-Wallis \( p \)-值≥0.05，跳过事后检验；否则按预设方法生成多组比较结果[^1][^6]。

---

## 脚注
[^1]: 假设检验通过时执行参数检验（ANOVA），反之执行非参数检验（Kruskal-Wallis）[stat_test_readme.md]。
[^2]: 标准化结果表整合正态性、方差齐性及事后检验结果，包含显著性标记与校正方法信息[stat_test_readme.md]。
[^3]: 使用Shapiro-Wilk和Levene/Bartlett检验联合验证正态性与方差齐性假设[stat_test_readme.md]。
[^4]: Levene检验通过`car::leveneTest()`实现，公式动态生成`响应变量 ~ 分组变量`[stat_test_readme.md]。
[^6]: Kruskal-Wallis检验后的成对比较可选Dunn或Wilcoxon方法，输出校正后\( p \)-值[stat_test_readme.md]。
