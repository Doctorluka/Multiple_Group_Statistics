suppressPackageStartupMessages({
  library(openxlsx)
  library(tibble)
  library(tidyverse)
  library(ggpubr)
})


get_plot_para <- function(data, draw_column, stat_summary){
  # extract data
  stat_data <- stat_summary[["stat_test"]]
  post_hoc_row <- which(stat_data$step == "Post hoc test")
  
  if (length(post_hoc_row) > 0) {
    # get p value
    p_adj_df <- stat_data[post_hoc_row:nrow(stat_data),]
    p_adj_res <- setNames(p_adj_df$p.value, p_adj_df$group)
  } else {
    p_adj_res <- NULL
    warning("Post hoc results not found!")
  }
  
  # na.omit
  filter_value <- data[,draw_column][!is.na(data[,draw_column])]
  
  # set segment position
  add_position = max(filter_value)/30
  segment_position = max(filter_value) + add_position
  y_lim <- segment_position + add_position*7
  
  # combine the results
  plot.paras <- list(
    p_value  = p_adj_res,
    segment_position = segment_position,
    add_position = add_position,
    y_lim = y_lim
  )
  
  return(plot.paras)
}


plot_bar_basic <- function(data, x="group", y, ylab){
  
  # set segment position
  rm_na <- data[,y][!is.na(data[,y])]
  
  add_position = max(rm_na)/30
  segment_position = max(rm_na) + add_position
  
  # set y limitation
  y_lim <- segment_position + add_position*10
  
  set.seed(1)
  p <- ggbarplot(
    data, 
    x = x, 
    y = y,
    fill = x, 
    add = c("mean_sd"),
    add.params = list(width = 0.4)
  ) +
    geom_jitter(aes_string(fill = x), shape = 21, size = 2, width = 0.15)+
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
      legend.position = "none"
    )+
    labs(x = NULL, y = ylab)+
    scale_y_continuous(expand = c(0,0), limits = c(0,y_lim))
  plot(p)
  return(p)
}


