# =============================================================================
# REAL-CASE TEMPORAL ANALYSIS
# TEMPERATURE AND MEAN RIDGE VOC/NOx RATIO
#
# Final hard-coded real-case values
#
# X-axis       : Five-year period
# Left y-axis  : Mean ridge VOC/NOx ratio
# Right y-axis : Temperature (K)
#
# Publication-quality output:
#   PNG  - 600 dpi
#   TIFF - 600 dpi
#   PDF  - vector
#   SVG  - editable vector
#   CSV  - exact plotted data
#
# Legend is positioned ABOVE the plotting panel so that it does not
# obscure either vertical axis, the trend lines, or the data labels.
# =============================================================================


# =============================================================================
# 0. CLEAN ENVIRONMENT
# =============================================================================

rm(list = ls())
graphics.off()


# =============================================================================
# 1. LOAD PACKAGE
# =============================================================================

library(ggplot2)


# =============================================================================
# 2. OUTPUT DIRECTORY
# =============================================================================

output_dir <- file.path(
  "C:/Users/beg24003/OneDrive - University of Connecticut/Desktop",
  "2025-2026 Session/Summer/Paper review",
  "Final Isopleth justification for F0am paper",
  "Basecasefinal_forpaper/Realcase_with_VOCholdme/finalizedRealcase_withVOCholdme"
)

if (!dir.exists(output_dir)) {
  dir.create(
    output_dir,
    recursive = TRUE
  )
}


# =============================================================================
# 3. FINAL REAL-CASE DATA
# =============================================================================

df <- data.frame(
  
  Block = c(
    "1996-2000",
    "2001-2005",
    "2006-2010",
    "2011-2015",
    "2016-2020"
  ),
  
  TempK = c(
    290.6,
    290.4,
    290.9,
    290.7,
    293.0
  ),
  
  Mean_Ridge_VOC_to_NOx = c(
    2.802540136,
    3.061218845,
    3.238562768,
    2.143958922,
    2.963844642
  )
)


# =============================================================================
# 4. SET CHRONOLOGICAL ORDER
# =============================================================================

block_order <- c(
  "1996-2000",
  "2001-2005",
  "2006-2010",
  "2011-2015",
  "2016-2020"
)

df$Block <- factor(
  df$Block,
  levels = block_order,
  ordered = TRUE
)

df <- df[
  order(df$Block),
]


# Numeric coordinate for plotting
df$BlockIndex <- seq_len(nrow(df))


# =============================================================================
# 5. DISPLAY DATA
# =============================================================================

cat("\n============================================================\n")
cat("REAL-CASE TEMPORAL DATA\n")
cat("============================================================\n\n")

print(
  df[
    ,
    c(
      "Block",
      "TempK",
      "Mean_Ridge_VOC_to_NOx"
    )
  ]
)


# =============================================================================
# 6. SAVE EXACT DATA USED IN FIGURE
# =============================================================================

write.csv(
  
  df[
    ,
    c(
      "Block",
      "TempK",
      "Mean_Ridge_VOC_to_NOx"
    )
  ],
  
  file.path(
    output_dir,
    "RealCase_Temperature_Mean_Ridge_VOC_NOx_Data.csv"
  ),
  
  row.names = FALSE
)


# =============================================================================
# 7. PUBLICATION COLORS
# =============================================================================

# Blue = modeled ridge response
ridge_color <- "#0072B2"

# Orange = temperature
temp_color <- "#D55E00"


# =============================================================================
# 8. LINE AND MARKER SETTINGS
# =============================================================================

ridge_line_width <- 1.55
temp_line_width  <- 1.55

ridge_point_size <- 5.2
temp_point_size  <- 5.2

point_stroke <- 1.4


# =============================================================================
# 9. LABEL SETTINGS
# =============================================================================

show_ratio_labels       <- TRUE
show_temperature_labels <- TRUE

ratio_digits       <- 2
temperature_digits <- 1


# =============================================================================
# 10. DETERMINE DATA RANGES
# =============================================================================

ratio_min <- min(
  df$Mean_Ridge_VOC_to_NOx
)

ratio_max <- max(
  df$Mean_Ridge_VOC_to_NOx
)

temp_min <- min(
  df$TempK
)

temp_max <- max(
  df$TempK
)


ratio_range <- ratio_max - ratio_min
temp_range  <- temp_max - temp_min


if (ratio_range == 0) {
  stop("Mean ridge VOC/NOx ratio has no variation.")
}

if (temp_range == 0) {
  stop("Temperature has no variation.")
}


# =============================================================================
# 11. DEFINE LEFT-AXIS PLOTTING RANGE
# =============================================================================

# Extra padding ensures that the point labels remain comfortably inside
# the plotting region.

ratio_plot_min <-
  ratio_min - 0.18 * ratio_range

ratio_plot_max <-
  ratio_max + 0.18 * ratio_range


# =============================================================================
# 12. TRANSFORM TEMPERATURE TO LEFT-AXIS COORDINATES
#
# ggplot2 secondary axes must be transformations of the primary axis.
# Therefore temperature is mapped linearly onto the left-axis coordinate
# system and transformed back to Kelvin on the right-hand axis.
# =============================================================================

temperature_scale_factor <-
  (ratio_plot_max - ratio_plot_min) /
  temp_range


df$Temp_scaled <-
  ratio_plot_min +
  (df$TempK - temp_min) *
  temperature_scale_factor


# =============================================================================
# 13. INVERSE TEMPERATURE TRANSFORMATION
# =============================================================================

inverse_temperature <- function(y) {
  
  temp_min +
    (y - ratio_plot_min) /
    temperature_scale_factor
}


# =============================================================================
# 14. CREATE DATA LABELS
# =============================================================================

df$Ratio_Label <- sprintf(
  paste0("%.", ratio_digits, "f"),
  df$Mean_Ridge_VOC_to_NOx
)


df$Temperature_Label <- sprintf(
  paste0("%.", temperature_digits, "f K"),
  df$TempK
)


# =============================================================================
# 15. MANUAL LABEL OFFSETS
#
# Order:
#
# 1 = 1996-2000
# 2 = 2001-2005
# 3 = 2006-2010
# 4 = 2011-2015
# 5 = 2016-2020
#
# These can be changed individually later if desired.
# =============================================================================


# -----------------------------------------------------------------------------
# RIDGE-RATIO LABELS
# -----------------------------------------------------------------------------

df$ratio_dx <- c(
  0.00,
  0.00,
  0.00,
  0.00,
  0.00
)

df$ratio_dy <- c(
  0.07,
  0.07,
  0.07,
  -0.11,
  0.07
)


# -----------------------------------------------------------------------------
# TEMPERATURE LABELS
# -----------------------------------------------------------------------------

df$temp_dx <- c(
  0.00,
  0.00,
  0.00,
  0.00,
  0.00
)

df$temp_dy <- c(
  -0.10,
  -0.10,
  -0.10,
  -0.10,
  0.10
)


# =============================================================================
# 16. CALCULATE LABEL POSITIONS
# =============================================================================

df$Ratio_Label_X <-
  df$BlockIndex +
  df$ratio_dx

df$Ratio_Label_Y <-
  df$Mean_Ridge_VOC_to_NOx +
  df$ratio_dy


df$Temperature_Label_X <-
  df$BlockIndex +
  df$temp_dx

df$Temperature_Label_Y <-
  df$Temp_scaled +
  df$temp_dy


# =============================================================================
# 17. START FIGURE
# =============================================================================

p <- ggplot()


# =============================================================================
# 18. MEAN RIDGE VOC/NOx SERIES
# =============================================================================

p <- p +
  
  geom_line(
    
    data = df,
    
    aes(
      x = BlockIndex,
      y = Mean_Ridge_VOC_to_NOx,
      colour = "Mean ridge VOC/NOx ratio",
      group = 1
    ),
    
    linewidth = ridge_line_width,
    lineend = "round"
  ) +
  
  geom_point(
    
    data = df,
    
    aes(
      x = BlockIndex,
      y = Mean_Ridge_VOC_to_NOx,
      colour = "Mean ridge VOC/NOx ratio"
    ),
    
    shape = 21,
    fill = "white",
    size = ridge_point_size,
    stroke = point_stroke
  )


# =============================================================================
# 19. TEMPERATURE SERIES
# =============================================================================

p <- p +
  
  geom_line(
    
    data = df,
    
    aes(
      x = BlockIndex,
      y = Temp_scaled,
      colour = "Temperature",
      group = 1
    ),
    
    linewidth = temp_line_width,
    linetype = "dashed",
    lineend = "round"
  ) +
  
  geom_point(
    
    data = df,
    
    aes(
      x = BlockIndex,
      y = Temp_scaled,
      colour = "Temperature"
    ),
    
    shape = 22,
    fill = "white",
    size = temp_point_size,
    stroke = point_stroke
  )


# =============================================================================
# 20. RIDGE-RATIO VALUE LABELS
# =============================================================================

if (show_ratio_labels) {
  
  p <- p +
    
    geom_text(
      
      data = df,
      
      aes(
        x = Ratio_Label_X,
        y = Ratio_Label_Y,
        label = Ratio_Label
      ),
      
      colour = ridge_color,
      size = 4.4,
      fontface = "bold",
      family = "sans"
    )
}


# =============================================================================
# 21. TEMPERATURE VALUE LABELS
# =============================================================================

if (show_temperature_labels) {
  
  p <- p +
    
    geom_text(
      
      data = df,
      
      aes(
        x = Temperature_Label_X,
        y = Temperature_Label_Y,
        label = Temperature_Label
      ),
      
      colour = temp_color,
      size = 4.4,
      fontface = "bold",
      family = "sans"
    )
}


# =============================================================================
# 22. X AXIS
# =============================================================================

p <- p +
  
  scale_x_continuous(
    
    name = "Five-year period",
    
    breaks = df$BlockIndex,
    
    labels = as.character(df$Block),
    
    limits = c(
      0.72,
      nrow(df) + 0.28
    ),
    
    expand = expansion(
      mult = c(0, 0)
    )
  )


# =============================================================================
# 23. LEFT AND RIGHT Y AXES
# =============================================================================

p <- p +
  
  scale_y_continuous(
    
    # -------------------------------------------------------------------------
    # LEFT AXIS
    # -------------------------------------------------------------------------
    
    name = expression(
      "Mean ridge VOC/NO"[x] * " ratio"
    ),
    
    limits = c(
      ratio_plot_min - 0.16,
      ratio_plot_max + 0.16
    ),
    
    breaks = pretty(
      c(
        ratio_min,
        ratio_max
      ),
      n = 5
    ),
    
    
    # -------------------------------------------------------------------------
    # RIGHT AXIS
    # -------------------------------------------------------------------------
    
    sec.axis = sec_axis(
      
      trans = inverse_temperature,
      
      name = "Temperature (K)",
      
      breaks = seq(
        290.0,
        293.0,
        by = 0.5
      ),
      
      labels = function(x) {
        sprintf("%.1f", x)
      }
    ),
    
    expand = expansion(
      mult = c(0, 0)
    )
  )


# =============================================================================
# 24. COLORS
# =============================================================================

p <- p +
  
  scale_colour_manual(
    
    name = NULL,
    
    values = c(
      
      "Mean ridge VOC/NOx ratio" =
        ridge_color,
      
      "Temperature" =
        temp_color
    ),
    
    breaks = c(
      "Mean ridge VOC/NOx ratio",
      "Temperature"
    ),
    
    labels = c(
      
      expression(
        "Mean ridge VOC/NO"[x] * " ratio"
      ),
      
      "Temperature"
    )
  )


# =============================================================================
# 25. LEGEND STYLE
#
# IMPORTANT:
# The legend is horizontal and placed ABOVE the plotting panel.
# It therefore cannot obscure:
#
#   - the left y-axis,
#   - the right y-axis,
#   - either trend line,
#   - or the point-value annotations.
# =============================================================================

p <- p +
  
  guides(
    
    colour = guide_legend(
      
      nrow = 1,
      
      byrow = TRUE,
      
      override.aes = list(
        
        linewidth = c(
          ridge_line_width,
          temp_line_width
        ),
        
        linetype = c(
          "solid",
          "dashed"
        ),
        
        shape = c(
          21,
          22
        ),
        
        fill = "white",
        
        size = 4.5
      )
    )
  )


# =============================================================================
# 26. PUBLICATION THEME
# =============================================================================

p <- p +
  
  coord_cartesian(
    clip = "off"
  ) +
  
  theme_classic(
    base_size = 18,
    base_family = "sans"
  ) +
  
  theme(
    
    
    # =========================================================================
    # LEGEND
    # =========================================================================
    
    legend.position = "top",
    
    legend.direction = "horizontal",
    
    legend.justification = "center",
    
    legend.box.just = "center",
    
    legend.background = element_blank(),
    
    legend.key = element_blank(),
    
    legend.text = element_text(
      size = 15,
      colour = "black",
      margin = margin(
        r = 14
      )
    ),
    
    legend.spacing.x = unit(
      0.20,
      "cm"
    ),
    
    legend.margin = margin(
      t = 0,
      r = 0,
      b = 8,
      l = 0
    ),
    
    
    # =========================================================================
    # X AXIS
    # =========================================================================
    
    axis.title.x = element_text(
      size = 20,
      colour = "black",
      margin = margin(
        t = 14
      )
    ),
    
    axis.text.x = element_text(
      size = 15,
      colour = "black",
      angle = 0,
      hjust = 0.5
    ),
    
    axis.line.x = element_line(
      linewidth = 0.9,
      colour = "black"
    ),
    
    axis.ticks.x = element_line(
      linewidth = 0.8,
      colour = "black"
    ),
    
    
    # =========================================================================
    # LEFT Y AXIS
    # =========================================================================
    
    axis.title.y.left = element_text(
      size = 20,
      colour = ridge_color,
      margin = margin(
        r = 14
      )
    ),
    
    axis.text.y.left = element_text(
      size = 16,
      colour = ridge_color
    ),
    
    axis.line.y.left = element_line(
      linewidth = 0.9,
      colour = ridge_color
    ),
    
    axis.ticks.y.left = element_line(
      linewidth = 0.8,
      colour = ridge_color
    ),
    
    
    # =========================================================================
    # RIGHT Y AXIS
    # =========================================================================
    
    axis.title.y.right = element_text(
      size = 20,
      colour = temp_color,
      margin = margin(
        l = 14
      )
    ),
    
    axis.text.y.right = element_text(
      size = 16,
      colour = temp_color
    ),
    
    axis.line.y.right = element_line(
      linewidth = 0.9,
      colour = temp_color
    ),
    
    axis.ticks.y.right = element_line(
      linewidth = 0.8,
      colour = temp_color
    ),
    
    
    # =========================================================================
    # TICKS
    # =========================================================================
    
    axis.ticks.length = unit(
      0.18,
      "cm"
    ),
    
    
    # =========================================================================
    # GRID
    #
    # Keep only subtle horizontal reference lines.
    # =========================================================================
    
    panel.grid.major.y = element_line(
      colour = "grey88",
      linewidth = 0.45
    ),
    
    panel.grid.major.x = element_blank(),
    
    panel.grid.minor = element_blank(),
    
    
    # =========================================================================
    # PLOT MARGINS
    #
    # Extra top margin provides comfortable space around the external legend.
    # =========================================================================
    
    plot.margin = margin(
      t = 12,
      r = 35,
      b = 22,
      l = 28
    )
  )


# =============================================================================
# 27. DISPLAY FIGURE
# =============================================================================

print(p)


# =============================================================================
# 28. OUTPUT FILE NAME
# =============================================================================

file_stub <-
  "RealCase_Temporal_Temperature_Mean_Ridge_VOC_NOx"


# =============================================================================
# 29. SAVE 600-DPI PNG
# =============================================================================

ggsave(
  
  filename = file.path(
    output_dir,
    paste0(
      file_stub,
      ".png"
    )
  ),
  
  plot = p,
  
  width = 10,
  height = 7.4,
  
  units = "in",
  
  dpi = 600,
  
  bg = "white"
)


# =============================================================================
# 30. SAVE 600-DPI TIFF
# =============================================================================

ggsave(
  
  filename = file.path(
    output_dir,
    paste0(
      file_stub,
      ".tiff"
    )
  ),
  
  plot = p,
  
  width = 10,
  height = 7.4,
  
  units = "in",
  
  dpi = 600,
  
  compression = "lzw",
  
  bg = "white"
)


# =============================================================================
# 31. SAVE VECTOR PDF
# =============================================================================

ggsave(
  
  filename = file.path(
    output_dir,
    paste0(
      file_stub,
      ".pdf"
    )
  ),
  
  plot = p,
  
  width = 10,
  height = 7.4,
  
  units = "in",
  
  device = cairo_pdf,
  
  bg = "white"
)


# =============================================================================
# 32. SAVE EDITABLE SVG
# =============================================================================

ggsave(
  
  filename = file.path(
    output_dir,
    paste0(
      file_stub,
      ".svg"
    )
  ),
  
  plot = p,
  
  width = 10,
  height = 7.4,
  
  units = "in",
  
  bg = "white"
)


# =============================================================================
# 33. COMPLETION MESSAGE
# =============================================================================

cat("\n")
cat("============================================================\n")
cat("REAL-CASE TEMPORAL FIGURE COMPLETE\n")
cat("============================================================\n\n")

cat("Output directory:\n")
cat(output_dir, "\n\n")

cat("Final values plotted:\n\n")

print(
  df[
    ,
    c(
      "Block",
      "TempK",
      "Mean_Ridge_VOC_to_NOx"
    )
  ]
)

cat("\nSaved files:\n")
cat("  1. 600-dpi PNG\n")
cat("  2. 600-dpi TIFF\n")
cat("  3. Vector PDF\n")
cat("  4. Editable SVG\n")
cat("  5. Exact plotted-data CSV\n")

cat("\n============================================================\n")