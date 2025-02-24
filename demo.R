rm(list = ls())
gc()

suppressPackageStartupMessages({
  library(openxlsx)
  library(tibble)
  library(tidyverse)
  library(ggpubr)
  source("utils/stat_test.R")
  source("utils/stat_plot.R")
})

test_data <- read.xlsx("data/test.xlsx")
test_data$ko <- ifelse(test_data$group %in% c("WT_Serum_starved", "WT_Normal_culture"), "no", "yes")
test_data$culture <- ifelse(test_data$group %in% c("WT_Serum_starved", "KO_Serum_starved"), "Serum_starved", "Normal_culture")
test_data


nor_res <- test_assumptions(test_data, "value", "group")
stat_res <- auto_stat_test(test_data, nor_res, "value", "group", factors = c("ko", "culture"))

stat_summary <- stat_res_collect(test_data, nor_res, stat_res, "demo_data")


