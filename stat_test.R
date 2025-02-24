suppressPackageStartupMessages({
  library(tidyverse)
  library(car)
  library(FSA) # dunn检验
})
options(scipen = 10)


# stat test functions -----------------------------------------------------

# Test Normality and Homogeneity of Variance
test_assumptions <- function(data, response_col, group_col, method = "levene") {
  # Perform Shapiro-Wilk Normality Test
  st <- perform_shapiro_by_group(data, response_col, group_col)
  # Perform test for Homogeneity of Variances
  bt <- perform_variances_homogeneity_test(data, response_col, group_col, method)
  # Return the results as a named list
  res <- rbind(st, bt)
  pass <- !any(res$sig != "")
  res.list <- list(
    "test.results" = res,
    "pass" = pass
  )
  return(res.list)
}


# Statistical Test Function
auto_stat_test <- function(data, test_assumptions_res, 
                           response_col, 
                           group_col, 
                           factors = NULL,
                           interaction = TRUE,
                           aov_post_hoc = "holm", 
                           kw_post_hoc = "dunn") {
  # if test_assumptions_res pass
  pass <- test_assumptions_res$pass
  # group number
  group_numb <- length(unique(data[[group_col]]))
  
  # Check assumptions and perform appropriate test
  if (group_numb > 2) {
    # multiple group
    if (pass) {
      # If normality and homogeneity of variances are met, perform ANOVA
      message("Normality and homogeneity of variances assumptions are met.")
      message(glue::glue("Number of group is {group_numb}.\nPerforming parametric test: ANOVA."))
      res.list <- perform_anova_test(data,  response_col, group_col, factors = factors,
                                     interaction = interaction, post_hoc_method = aov_post_hoc)
    } else {
      # If assumptions are not met, perform non-parametric test (Wilcoxon rank-sum test)
      message("Normality or homogeneity of variances assumptions are not met.\nPerforming non-parametric test: Kruskal-Wallis")
      # Perform Non-parameter test
      res.list <- perform_kw_test(data, response_col, group_col, kw_post_hoc)
    }
    
  } else {
    # two group 
    if (pass) {
      message("Normality and homogeneity of variances assumptions are met.")
      message(glue::glue("Number of group is {group_numb}.\nPerforming parametric test: Student's t-test."))
      res.list <- perfrom_stat_for_two_group(data,  response_col, group_col, method = "t.test")
    } else {
      message("Normality and homogeneity of variances assumptions are met.")
      message(glue::glue("Number of group is {group_numb}.\nPerforming parametric test: Wilcox.test."))
      res.list <- perfrom_stat_for_two_group(data,  response_col, group_col, method = "wilcox.test")
    }
    
  }
  
  return(res.list)
}

# collect data --------------------------------------------------------------------

stat_res_collect <- function(data, nor, stat, task_name) {
  # Step 1: Collect normality and homogeneity of variance test results
  df1 <- nor$test.results
  # Step 2: Check normality, homogeneity of variance and post hoc test
  # if normality and homogeneity of variance pass
  nor_pass <- nor$pass
  # check post hoc method
  post_hoc_method <- stat$post_hoc_method
  
  # Step 3: Collect the stat results (ANOVA or KW)
  if (nor_pass) {
    stat_method <- "ANOVA"
    aov_res <- stat[[stat_method]]
    
    if (stat$avo_method == "one-way ANOVA") {
      df2 <- data.frame(
        "step" = c("Parametric tests", rep("", nrow(aov_res)-1)),
        "method" = c(stat_method, rep("", nrow(aov_res)-1)),
        "group" = c(aov_res$formula[1], rep("", nrow(aov_res)-1)),
        "p.value" = aov_res$`Pr(>F)`
      )
    } else {
      df2 <- data.frame(
        "step" = c("Parametric tests", rep("", nrow(aov_res)-1)),
        "method" = c(stat_method, rep("", nrow(aov_res)-1)),
        "group" = rownames(aov_res),
        "p.value" = aov_res$`Pr(>F)`
      )
    }
    
    df2$sig <- sapply(df2$p.value, p_to_stars)
    need_post_hoc <- any(aov_res$`Pr(>F)` < 0.05)
    
  } else {
    stat_method <- "Kruskal-Wallis"
    kw_res <- stat[[stat_method]]
    df2 <- data.frame(
      "step" = "Nonparametric tests",
      "method" = stat_method,
      "group" = kw_res$formula,
      "p.value" = kw_res$p.value
    )
    df2$sig <- sapply(df2$p.value, p_to_stars)
    need_post_hoc <- any(kw_res$p.value < 0.05)
  }
  
  # Merge data
  df_merge <- rbind(df1, df2) %>% 
    dplyr::mutate(task = c(task_name, rep("", nrow(.)-1))) %>% 
    dplyr::select(task, everything())
  
  # Step 4: Collect the post hoc result
  # Determine the final result list
  if (nor_pass) {
    # parameter test
    if (need_post_hoc) {
      post_hoc <- stat$post_hoc 
      # tidy result
      df3 <- data.frame(
        "task" = "",
        "step" = c("Post hoc test", rep("", nrow(post_hoc)-1)),
        "method" = post_hoc_method,
        "group" = post_hoc$comparison,
        "p.value" = post_hoc$p.value,
        "sig" = sapply(post_hoc$p.value, p_to_stars)
      )
      df_merge <- rbind(df_merge, df3)
    } 
    
    df_merge$p.value <- round(df_merge$p.value, 4)
    df_merge$p.value[df_merge$p.value < 0.0001] <- "<0.0001"
    res <- list("data" = data, "stat_test" = df_merge)
    message("Complete data cleaning!")
    
  } else {
    # nonparameter test
    if (need_post_hoc) {
      post_hoc <- stat$post_hoc
      # tidy result
      df3 <- data.frame(
        "task" = "",
        "step" = c("Post hoc test", rep("", nrow(post_hoc)-1)),
        "method" = post_hoc_method,
        "group" = post_hoc$comparison,
        "p.value" = post_hoc$p.value,
        "sig" = sapply(post_hoc$p.value, p_to_stars)
      )
      df_merge <- rbind(df_merge, df3)
    } 
    
    df_merge$p.value <- round(df_merge$p.value, 4)
    df_merge$p.value[df_merge$p.value < 0.0001] <- "<0.0001"
    res <- list("data" = data, "stat_test" = df_merge)
    
    message("Complete data cleaning!")
  }
  
  names(res)[1] <- task_name
  return(res)
}


stat_res_collect_two_group <- function(data, nor, stat, task_name){
  # merge stat res
  colnames(stat$test.results) <- colnames(nor$test.results)
  res_df <- rbind(nor$test.results, stat$test.results)
  
  res.list <- list("data" = data, "stat_test" = res_df)
  names(res.list)[1] <- task_name
  return(res.list)
}



# 二级函数 --------------------------------------------------------------------

# shapiro.test
perform_shapiro_by_group <- function(data, column_for_test, group_col) {
  # split by group
  data_split = split(data, data[[group_col]])
  
  # shapiro.test for each group
  shapiro_res_list <- lapply(names(data_split), function(x){
    data_by_group <- data_split[[x]]
    st <- shapiro.test(data_by_group[[column_for_test]])
    st_df <- data.frame(
      "method" = "shapiro.test",
      "group" = x,
      "p.value" = st$p.value
    )
    return(st_df)
  })
  shapiro_df <- do.call(rbind, shapiro_res_list)
  shapiro_df$step <- c("Normality", rep("", nrow(shapiro_df)-1))
  shapiro_df$sig <- sapply(shapiro_df$p.value, p_to_stars)
  shapiro_df <- select(shapiro_df, step, everything())
  
  message("Finish shapiro.test!")
  
  return(shapiro_df)
}

# Homogeneity Variances test
perform_variances_homogeneity_test <- function(data, column_for_test, group_col, method = "levene"){
  # Dynamically construct the formula
  formula_str <- paste(column_for_test, "~", group_col)
  formula <- as.formula(formula_str)
  
  # Homogeneity of Variances
  if (method == "bartlett") {
    # Bartlett Test 
    bt <- bartlett.test(formula, data = data)
    bt_df <- data.frame(
      "step" = "Homogeneity of Variances",
      "method" = "bartlett.test",
      "group" = formula_str,
      "p.value" = bt$p.value
    )
    bt_df$sig <- p_to_stars(bt_df$p.value)
    
    message(glue::glue("Finish {method} test!"))
    return(bt_df)
    
  } else if (method == "levene") {
    # levene Test 
    library(car)  
    lt <- leveneTest(data[[column_for_test]] ~ data[[group_col]])
    lt_df <- data.frame(
      "step" = "Homogeneity of Variances",
      "method" = "leveneTest",
      "group" =  formula_str,
      "p.value" = lt$`Pr(>F)`[1]
    )
    lt_df$sig <- p_to_stars(lt_df$p.value)
    
    message(glue::glue("Finish {method} test!"))
    return(lt_df)
    
  } else {
    stop(glue::glue("Parameter 'method' should be 'levene' or 'bartlett', but now 'method'={method}." ))
  }
  
  
}




# anova
perform_anova_test <- function(data,
                               response_col, 
                               group_col, 
                               factors = NULL,
                               interaction = TRUE,
                               post_hoc_method = "holm"){
  # 1. bulid formula
  formula_str <- build_aov_formula(response_col, group_col, factors, interaction)
  formula <- as.formula(formula_str)
  message(glue::glue("Try to perform ANOVA test ...\n---> Formula = {formula_str} "))
  
  # 2. perform anova
  anova_result <- aov(formula, data = data)
  anova_summary <- summary(anova_result)
  anova_result_clean <- anova_summary[[1]]
  
  numb <- length(factors)
  if (numb == 2) {
    aov_method = glue::glue("two-way ANOVA")
  } else {
    aov_method = glue::glue("Multivariate ANOVA")
  }
  
  
  # 3. check correction of the formula
  interaction_performed <- nrow(anova_result_clean) > length(factors)+1
  if (!interaction_performed) {
    message(glue::glue("The design does not conform to multifactor analysis of variance.\nSwitch to one-way ANOVA ..."))
    formula_str <- build_aov_formula(response_col, group_col)
    formula <- as.formula(formula_str)
    message(glue::glue("---> Formula = {formula_str}"))
    # perform anova
    anova_result <- aov(formula, data = data)
    anova_summary <- summary(anova_result)
    # extract results
    anova_result_clean <- anova_summary[[1]]
    
    aov_method = "one-way ANOVA"
  }
  message("ANOVA results:")
  print(anova_summary)
  
  # 4. extract results
  anova_result_clean$formula <- c(formula_str, rep(NA, nrow(anova_result_clean)-1))  # 保存公式
  anova_result_clean <- anova_result_clean[-nrow(anova_result_clean),]
  
  # 5. 全局检验显著性时进行事后检验
  p_value_sig <- any(anova_result_clean$`Pr(>F)` < 0.05)
  if (p_value_sig) {
    message(glue::glue("ANOVA p<0.05. Performing post-hoc: {post_hoc_method}."))
    post_hoc.list <- preform_avo_post_hoc(anova_result, post_hoc_method, data, response_col, group_col)
    res.list <- list("ANOVA" = anova_result_clean, 
                     "post_hoc" = post_hoc.list$post_hoc, 
                     "post_hoc_method" = post_hoc.list$post_hoc_method)
    print(res.list[["post_hoc"]])
    
  } else {
    message("ANOVA p>0.05. No need for post hoc test.")
    res.list <- list("ANOVA" = anova_result_clean)
    res.list$post_hoc_method <- NULL
  }
  
  res.list[["avo_method"]] <- aov_method
  
  return(res.list)
}

# two group
perfrom_stat_for_two_group <- function(data, response_col, group_col, method) {
  # extract group names
  group_names <- unique(data[[group_col]])
  group_A_loc <- data[[group_col]] == group_names[1]
  # extract values
  value_A <- data[[response_col]][group_A_loc]
  value_B <- data[[response_col]][!group_A_loc]
  
  if (method == "t.test") {
    t_res <- t.test(value_A, value_B)
    p_value <- t_res$p.value
    
  } else if (method == "wilcox.test") {
    wilcox_res <- wilcox.test(value_A, value_B)
    p_value <- wilcox_res$p.value
    
  } else {
    message("Parameter 'method' should be 't.test' or 'wilcox.test'.")
  }
  
  adjusted_p_value <- p.adjust(p_value, method = "holm")
  
  # tidy data
  step_use <- ifelse(method == "t.test", "Parametric tests", "Nonparametric tests")
  test_df <- data.frame(
    "step" = step_use,
    "method" = method,
    "comparison" = paste(group_names[2], group_names[1], sep = "-"),
    "p.value" = adjusted_p_value
  )
  test_df$sig <- sapply(test_df$p.value, p_to_stars)
  
  # collect
  res.list <- list("test.results" = test_df,
                   "test_method" = method)
  
  return(res.list)
}


# KW
perform_kw_test <- function(data, response_col, group_col, post_hoc_method = "dunn") {
  # Check if the input column names exist in the data
  if (!(response_col %in% colnames(data)) || !(group_col %in% colnames(data))) {
    stop("Response column or group column not found in the data.")
  }
  
  # Global test: Kruskal-Wallis test
  kruskal_result <- kruskal.test(as.formula(paste(response_col, "~", group_col)), data = data)
  message("Kruskal-Wallis Global Test Results:\n")
  print(kruskal_result)
  
  kruskal_result$formula <- paste(response_col, "~", group_col)
  
  # If the global test is significant, perform post-hoc tests
  if (kruskal_result$p.value < 0.05 & post_hoc_method == "dunn") {
    message("\nKW p<0.05. Proceeding with post-hoc Dunn's tests:\n")
    
    dunn_result <- dunnTest(as.formula(paste(response_col, "~", group_col)), data = data) # method = "bonferroni"/ "holm"(Default)
    dunn_result$res[["method"]] = "Dunn's test"
    cat("\nDunn's Test Results:\n")
    print(dunn_result)
    # tidy dunn result
    dunn_df <- data.frame(
      "comparison" = rev_dunn_comparision(dunn_result$res$Comparison),
      "p.value" = dunn_result$res$P.adj,
      "method" = dunn_result$res$method
    )
    # combine results
    res.list <- list(
      "Kruskal-Wallis" = kruskal_result, 
      "post_hoc" = dunn_df,
      "post_hoc_method" = "Dunn's test"
    )
  
  } else if (kruskal_result$p.value < 0.05 & post_hoc_method != "dunn") {
    message("\nKW p<0.05. Proceeding with pairwise-wilcoxon tests:\n")
    pairwise.wilcox_result <- perform_pairwise_wilcoxon(data, response_col, group_col)
    # combine results
    res.list <- list(
      "Kruskal-Wallis" = kruskal_result, 
      "post_hoc" = pairwise.wilcox_result,
      "post_hoc_method" = "pairwise.wilcoxon"
    )
    
  } else {
    message("\nKW p>0.05. No need for pairwise comparisons.\n")
    # combine results
    res.list <- list(
      "Kruskal-Wallis" = kruskal_result,
      "post_hoc_method" = NULL
    )
    
  }
  
  return(res.list)
  
}

rev_dunn_comparision <- function(dunn_comparision){
  split_comparison <- str_split(dunn_comparision, " - ")
  new_comparison <- sapply(split_comparison, function(x) paste(rev(x), collapse = "-"))
  return(new_comparison)
}





# 三级函数 --------------------------------------------------------------------
# build formula for avo
build_aov_formula <- function(response_col, group_col, factors = NULL, interaction = TRUE){
  if (is.null(factors)) {
    # no factors -> one-way anova
    formula_str <- paste(response_col, "~", group_col)
  } else {
    # two and multiple-way anova
    if (interaction) {
      # 考虑主效应+交互作用
      formula_str <- paste(response_col, "~", paste(factors, collapse = "*"))
    } else {
      # 只考虑主效应，不考虑交互作用
      formula_str <- paste(response_col, "~", paste(factors, collapse = "+"))
    }
  }
  return(formula_str)
}

# anova post hoc
preform_avo_post_hoc <- function(anova_result, method = "holm",
                                 data, response_col, group_col){
  if (method == "tukey") {
    tukey_result <- TukeyHSD(anova_result)
    # tidy tukey result
    tukey_df <- tukey_result[[1]] %>% 
      as.data.frame() %>% 
      dplyr::mutate(method = "Tukey HSD") %>% 
      rownames_to_column(var = "comparison") %>% 
      dplyr::select(comparison, `p adj`, method)
    colnames(tukey_df) <- c("comparison", "p.value", "method")
    
    post_hoc_method <- "Tukey HSD"
    res.list <- list(tukey_df)
    
  } else if (method == "holm") {
    holm_result <- pairwise.t.test(data[[response_col]], data[[group_col]], p.adjust.method = "holm")
    # extract holm result
    p_value_matrix <- holm_result$p.value
    comparisons <- which(!is.na(p_value_matrix), arr.ind = TRUE)
    holm_res <- data.frame(
      "comparison" = paste(rownames(p_value_matrix)[comparisons[, 1]], colnames(p_value_matrix)[comparisons[, 2]], sep = "-"),
      "p.value" = p_value_matrix[!is.na(p_value_matrix)],
      "method" = "Holm-Sidak"
    )
    post_hoc_method <- "Holm-Sidak"
    res.list <- list(holm_res)
  }
  
  names(res.list) <- c("post_hoc")
  res.list$post_hoc_method <- post_hoc_method
  
  return(res.list)
}


perform_pairwise_wilcoxon <- function(data, response_col, group_col) {
  # Ensure the input column names exist in the data
  if (!(response_col %in% colnames(data)) || !(group_col %in% colnames(data))) {
    stop("Response column or group column not found in the data.")
  }
  
  # Perform pairwise Wilcoxon tests
  test_result <- pairwise.wilcox.test(data[[response_col]], data[[group_col]], p.adjust.method = "bonferroni")
  print(test_result)
  
  # Extract results
  p_value_matrix <- test_result$p.value
  comparisons <- which(!is.na(p_value_matrix), arr.ind = TRUE)
  
  res <- data.frame(
    "comparison" = paste(rownames(p_value_matrix)[comparisons[, 1]], colnames(p_value_matrix)[comparisons[, 2]], sep = "-"),
    "p.value" = p_value_matrix[!is.na(p_value_matrix)],
    "method" = "pairwise wilcoxon"
  )
  
  return(res)
}


# 显著性转换
p_to_stars <- function(p) {
  # 尝试将输入转换为数值型
  p_numeric <- tryCatch({
    p_new <- as.numeric(p)
    p_new
  }, warning = function(w) {
    return(NULL)
  }, error = function(e) {
    return(NULL)
  })
  
  # 如果转换失败或输入为空，返回空字符串
  if (is.null(p_numeric)) {
    return("")
  }
  
  # 检查p值并返回对应的星号
  if (p_numeric < 0.0001) {
    return("****")
  } else if (p_numeric < 0.001) {
    return("***")
  } else if (p_numeric < 0.01) {
    return("**")
  } else if (p_numeric < 0.05) {
    return("*")
  } else {
    return("")
  }
}


