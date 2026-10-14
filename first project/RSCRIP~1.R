# =============================================================================
# F0AM DILUTION-LIFETIME SENSITIVITY
# FINAL PUBLICATION FIGURES
#
# FIGURE 1:
#   Observed and modeled diurnal O3
#   tau_dil = 6, 12, 24, 48 h
#
# FIGURE 2:
#   Mean ridge VOC/NOx vs Temperature
#   tau_dil = 6, 12, 24, 48 h
#
# 24 h = baseline dilution lifetime
#
# Outputs:
#   PNG  - 600 dpi
#   TIFF - 600 dpi, LZW
#   PDF  - vector
#   SVG  - editable vector
#   CSV  - exact data used in figures
# =============================================================================


# =============================================================================
# 0. CLEAN ENVIRONMENT
# =============================================================================

rm(list = ls())
graphics.off()


# =============================================================================
# 1. PACKAGES
# =============================================================================

packages <- c(
  "ggplot2",
  "readr",
  "dplyr",
  "tidyr",
  "purrr",
  "svglite"
)

new_packages <- packages[
  !(packages %in% rownames(installed.packages()))
]

if (length(new_packages) > 0) {
  install.packages(new_packages, dependencies = TRUE)
}

library(ggplot2)
library(readr)
library(dplyr)
library(tidyr)
library(purrr)
library(svglite)


# =============================================================================
# 2. ROOT DIRECTORY
# =============================================================================

input_root <- file.path(
  "C:/Users/beg24003/OneDrive - University of Connecticut/Desktop",
  "2025-2026 Session/Summer/Paper review",
  "Final Isopleth justification for F0am paper",
  "Basecasefinal_forpaper/RealDilutionsensitivityanalysis"
)

if (!dir.exists(input_root)) {
  
  stop(
    paste0(
      "\nROOT DIRECTORY NOT FOUND:\n",
      input_root
    )
  )
}


# =============================================================================
# 3. OUTPUT DIRECTORY
# =============================================================================

output_dir <- file.path(
  input_root,
  "R_Publication_DilutionSensitivity"
)

if (!dir.exists(output_dir)) {
  dir.create(
    output_dir,
    recursive = TRUE
  )
}


cat("\n============================================================\n")
cat("F0AM DILUTION-LIFETIME PUBLICATION FIGURES\n")
cat("============================================================\n")
cat("\nRoot:\n", input_root, "\n")
cat("\nOutput:\n", output_dir, "\n")


# =============================================================================
# 4. DILUTION LIFETIMES
# =============================================================================

tau_values <- c(6, 12, 24, 48)

tau_folders <- file.path(
  input_root,
  sprintf("tau_%02dh", tau_values)
)

missing_folders <- tau_folders[
  !dir.exists(tau_folders)
]

if (length(missing_folders) > 0) {
  
  stop(
    paste0(
      "\nMissing dilution folders:\n",
      paste(
        missing_folders,
        collapse = "\n"
      )
    )
  )
}


# =============================================================================
# 5. COMMON PUBLICATION COLORS
# =============================================================================

series_colors <- c(
  
  "Observed" = "#000000",
  
  "6 h" = "#0072B2",
  
  "12 h" = "#D55E00",
  
  "24 h" = "#E69F00",
  
  "48 h" = "#7A1FDB"
)


# =============================================================================
# 6. COMMON LINE TYPES
# =============================================================================

series_linetypes <- c(
  
  "Observed" = "solid",
  
  "6 h" = "dotted",
  
  "12 h" = "dashed",
  
  "24 h" = "solid",
  
  "48 h" = "dotdash"
)


# =============================================================================
# 7. COMMON SHAPES
# =============================================================================

series_shapes <- c(
  
  "Observed" = 21,
  
  "6 h" = 21,
  
  "12 h" = 22,
  
  "24 h" = 23,
  
  "48 h" = 24
)


# =============================================================================
# PART A
# DIURNAL O3 DILUTION-LIFETIME SENSITIVITY
# =============================================================================


# =============================================================================
# 8. FUNCTION TO FIND CORRECT DIURNAL CSV
# =============================================================================
#
# We DO NOT assume the exact MATLAB filename.
#
# The correct file is identified by its contents:
#
#   Hour
#   ObservedO3_ppb
#   ModeledO3_ppb
#
# =============================================================================

find_diurnal_file <- function(folder) {
  
  csv_files <- list.files(
    path = folder,
    pattern = "\\.csv$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )
  
  if (length(csv_files) == 0) {
    
    stop(
      paste0(
        "\nNo CSV files found inside:\n",
        folder
      )
    )
  }
  
  
  # Prefer filenames containing "diurnal"
  
  preferred <- csv_files[
    grepl(
      "diurnal",
      basename(csv_files),
      ignore.case = TRUE
    )
  ]
  
  search_order <- c(
    preferred,
    setdiff(csv_files, preferred)
  )
  
  
  for (f in search_order) {
    
    test <- tryCatch(
      
      suppressMessages(
        read_csv(
          f,
          n_max = 5,
          show_col_types = FALSE
        )
      ),
      
      error = function(e) NULL
    )
    
    
    if (is.null(test)) {
      next
    }
    
    
    required <- c(
      "Hour",
      "ObservedO3_ppb",
      "ModeledO3_ppb"
    )
    
    
    if (all(required %in% names(test))) {
      
      cat(
        "\nDiurnal file found for ",
        basename(folder),
        ":\n  ",
        basename(f),
        "\n",
        sep = ""
      )
      
      return(f)
    }
  }
  
  
  stop(
    paste0(
      "\nCould not identify diurnal O3 file in:\n",
      folder,
      "\n\nRequired columns:\n",
      "Hour\nObservedO3_ppb\nModeledO3_ppb"
    )
  )
}


# =============================================================================
# 9. FIND ALL FOUR DIURNAL FILES
# =============================================================================

diurnal_files <- map_chr(
  tau_folders,
  find_diurnal_file
)


source_inventory <- data.frame(
  
  DilutionLifetime_h = tau_values,
  
  Folder = basename(tau_folders),
  
  File = basename(diurnal_files),
  
  FullPath = diurnal_files
)


write_csv(
  source_inventory,
  file.path(
    output_dir,
    "DilutionSensitivity_Diurnal_SourceFiles.csv"
  )
)


# =============================================================================
# 10. READ DIURNAL FILES
# =============================================================================

read_diurnal <- function(file, tau) {
  
  x <- read_csv(
    file,
    show_col_types = FALSE
  )
  
  
  x %>%
    
    transmute(
      
      Hour =
        as.numeric(Hour),
      
      ObservedO3_ppb =
        as.numeric(ObservedO3_ppb),
      
      ModeledO3_ppb =
        as.numeric(ModeledO3_ppb),
      
      DilutionLifetime_h =
        tau
    ) %>%
    
    arrange(Hour)
}


diurnal_list <- map2(
  diurnal_files,
  tau_values,
  read_diurnal
)


# =============================================================================
# 11. CHECK OBSERVED O3
# =============================================================================
#
# Observed O3 should be the same for all four simulations.
# =============================================================================

obs_reference <- diurnal_list[[1]] %>%
  
  select(
    Hour,
    ObservedO3_ppb
  )


for (i in 2:length(diurnal_list)) {
  
  obs_test <- diurnal_list[[i]] %>%
    
    select(
      Hour,
      ObservedO3_ppb
    )
  
  
  if (!isTRUE(
    all.equal(
      obs_reference,
      obs_test,
      tolerance = 1e-8
    )
  )) {
    
    warning(
      paste0(
        "Observed O3 differs for tau = ",
        tau_values[i],
        " h."
      )
    )
  }
}


# =============================================================================
# 12. PREPARE DIURNAL DATA
# =============================================================================

observed_plot <- obs_reference %>%
  
  transmute(
    
    Hour,
    
    O3_ppb =
      ObservedO3_ppb,
    
    Series =
      "Observed"
  )


modeled_plot <- bind_rows(
  diurnal_list
) %>%
  
  transmute(
    
    Hour,
    
    O3_ppb =
      ModeledO3_ppb,
    
    Series =
      paste0(
        DilutionLifetime_h,
        " h"
      )
  )


diurnal_plot_data <- bind_rows(
  observed_plot,
  modeled_plot
)


diurnal_plot_data$Series <- factor(
  
  diurnal_plot_data$Series,
  
  levels = c(
    "Observed",
    "6 h",
    "12 h",
    "24 h",
    "48 h"
  )
)


# Save exact data plotted

write_csv(
  diurnal_plot_data,
  file.path(
    output_dir,
    "DilutionSensitivity_Diurnal_DataUsed.csv"
  )
)


# =============================================================================
# 13. DIURNAL Y AXIS
# =============================================================================

diurnal_max <- max(
  diurnal_plot_data$O3_ppb,
  na.rm = TRUE
)

diurnal_ymax <- ceiling(
  diurnal_max / 10
) * 10

if ((diurnal_ymax - diurnal_max) < 3) {
  diurnal_ymax <- diurnal_ymax + 10
}


# =============================================================================
# 14. DIURNAL FIGURE
# =============================================================================

p_diurnal <- ggplot(
  
  diurnal_plot_data,
  
  aes(
    x = Hour,
    y = O3_ppb,
    colour = Series,
    linetype = Series,
    shape = Series,
    group = Series
  )
  
) +
  
  geom_line(
    linewidth = 1.25,
    na.rm = TRUE
  ) +
  
  geom_point(
    size = 3.8,
    stroke = 1.3,
    fill = "white",
    na.rm = TRUE
  ) +
  
  
  scale_colour_manual(
    
    values = series_colors,
    
    breaks = c(
      "Observed",
      "6 h",
      "12 h",
      "24 h",
      "48 h"
    ),
    
    labels = c(
      
      "Observed",
      
      expression(
        tau[dil] == 6 ~ h
      ),
      
      expression(
        tau[dil] == 12 ~ h
      ),
      
      expression(
        tau[dil] == 24 ~ h
      ),
      
      expression(
        tau[dil] == 48 ~ h
      )
    )
  ) +
  
  
  scale_linetype_manual(
    values = series_linetypes
  ) +
  
  
  scale_shape_manual(
    values = series_shapes
  ) +
  
  
  scale_x_continuous(
    
    limits = c(
      0,
      23
    ),
    
    breaks = seq(
      0,
      21,
      3
    ),
    
    expand = expansion(
      mult = c(
        0,
        0
      )
    )
  ) +
  
  
  scale_y_continuous(
    
    limits = c(
      0,
      diurnal_ymax
    ),
    
    breaks = seq(
      0,
      diurnal_ymax,
      10
    ),
    
    expand = expansion(
      mult = c(
        0,
        0
      )
    )
  ) +
  
  
  labs(
    
    x =
      "Local time (h)",
    
    y =
      expression(
        O[3] ~ "(ppb)"
      ),
    
    colour = NULL,
    linetype = NULL,
    shape = NULL
  ) +
  
  
  theme_classic(
    base_size = 17
  ) +
  
  
  theme(
    
    axis.title.x =
      element_text(
        size = 20,
        colour = "black",
        margin = margin(t = 10)
      ),
    
    axis.title.y =
      element_text(
        size = 20,
        colour = "black",
        margin = margin(r = 10)
      ),
    
    axis.text =
      element_text(
        size = 15,
        colour = "black"
      ),
    
    axis.ticks =
      element_line(
        colour = "black",
        linewidth = 0.8
      ),
    
    axis.ticks.length =
      grid::unit(
        0.16,
        "cm"
      ),
    
    axis.line =
      element_blank(),
    
    panel.border =
      element_rect(
        colour = "black",
        fill = NA,
        linewidth = 1
      ),
    
    panel.grid =
      element_blank(),
    
    panel.background =
      element_rect(
        fill = "white",
        colour = NA
      ),
    
    plot.background =
      element_rect(
        fill = "white",
        colour = NA
      ),
    
    legend.position =
      c(
        0.025,
        0.965
      ),
    
    legend.justification =
      c(
        0,
        1
      ),
    
    legend.background =
      element_blank(),
    
    legend.key =
      element_blank(),
    
    legend.text =
      element_text(
        size = 15,
        colour = "black"
      ),
    
    legend.key.width =
      grid::unit(
        1.25,
        "cm"
      ),
    
    plot.margin =
      margin(
        12,
        15,
        12,
        15
      )
  ) +
  
  
  guides(
    
    colour =
      guide_legend(
        
        override.aes =
          list(
            linewidth = 1.25,
            size = 3.8
          )
      ),
    
    linetype =
      "none",
    
    shape =
      "none"
  )


print(p_diurnal)


# =============================================================================
# 15. SAVE DIURNAL FIGURE
# =============================================================================

ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_Diurnal_O3.png"
  ),
  p_diurnal,
  width = 9,
  height = 6.5,
  units = "in",
  dpi = 600,
  bg = "white"
)


ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_Diurnal_O3.tiff"
  ),
  p_diurnal,
  width = 9,
  height = 6.5,
  units = "in",
  dpi = 600,
  compression = "lzw",
  bg = "white"
)


ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_Diurnal_O3.pdf"
  ),
  p_diurnal,
  width = 9,
  height = 6.5,
  units = "in",
  device = cairo_pdf,
  bg = "white"
)


ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_Diurnal_O3.svg"
  ),
  p_diurnal,
  width = 9,
  height = 6.5,
  units = "in",
  device = svglite,
  bg = "white"
)


# =============================================================================
# PART B
# MEAN RIDGE VOC/NOx VS TEMPERATURE
# =============================================================================


# =============================================================================
# 16. FIND RIDGE SUMMARY FILE
# =============================================================================

ridge_file <- file.path(
  input_root,
  "Dilution_Lifetime_Ridge_Summary.csv"
)


if (!file.exists(ridge_file)) {
  
  # Try automatic search
  
  ridge_candidates <- list.files(
    
    input_root,
    
    pattern =
      "Dilution.*Lifetime.*Ridge.*Summary.*\\.csv$",
    
    full.names = TRUE,
    
    ignore.case = TRUE
  )
  
  
  # Avoid RUNNING file if final file exists
  
  ridge_candidates <- ridge_candidates[
    !grepl(
      "RUNNING",
      basename(ridge_candidates),
      ignore.case = TRUE
    )
  ]
  
  
  if (length(ridge_candidates) == 0) {
    
    stop(
      paste0(
        "\nCould not find final dilution ridge summary CSV in:\n",
        input_root
      )
    )
  }
  
  
  ridge_file <- ridge_candidates[1]
}


cat("\n============================================================\n")
cat("RIDGE SUMMARY FILE\n")
cat("============================================================\n")
cat(ridge_file, "\n")


# =============================================================================
# 17. READ RIDGE SUMMARY
# =============================================================================

ridge_raw <- read_csv(
  ridge_file,
  show_col_types = FALSE
)


cat("\nRidge summary columns:\n")

print(
  names(ridge_raw)
)


# =============================================================================
# 18. AUTOMATIC COLUMN IDENTIFICATION
# =============================================================================
#
# We identify:
#
#   dilution lifetime
#   temperature
#   mean ridge VOC/NOx
#
# without assuming the exact MATLAB column spelling.
# =============================================================================


find_column <- function(
    column_names,
    patterns,
    description
) {
  
  for (pattern in patterns) {
    
    hit <- column_names[
      grepl(
        pattern,
        column_names,
        ignore.case = TRUE
      )
    ]
    
    if (length(hit) > 0) {
      return(hit[1])
    }
  }
  
  
  stop(
    paste0(
      "\nCould not identify ",
      description,
      " column.\n\nAvailable columns:\n",
      paste(
        column_names,
        collapse = "\n"
      )
    )
  )
}


# Dilution lifetime
tau_col <- find_column(
  
  names(ridge_raw),
  
  c(
    "^Tau_h$",
    "Lifetime.*h",
    "Dilution.*Lifetime",
    "Tau",
    "Lifetime"
  ),
  
  "dilution lifetime"
)


# Temperature
temp_col <- find_column(
  
  names(ridge_raw),
  
  c(
    "^TempK$",
    "Temperature.*K",
    "Temp"
  ),
  
  "temperature"
)


# Mean ridge ratio
ratio_col <- find_column(
  
  names(ridge_raw),
  
  c(
    "^MeanRidgeRatio$",
    "Mean.*Ridge.*VOC.*NO",
    "Mean.*VOC.*NO",
    "Ridge.*Ratio",
    "VOC.*NOx"
  ),
  
  "mean ridge VOC/NOx"
)


cat("\nAutomatically identified columns:\n")
cat("  Dilution lifetime :", tau_col, "\n")
cat("  Temperature       :", temp_col, "\n")
cat("  Ridge ratio       :", ratio_col, "\n")


# =============================================================================
# 19. BUILD CLEAN RIDGE DATA
# =============================================================================

ridge_data <- ridge_raw %>%
  
  transmute(
    
    DilutionLifetime_h =
      as.numeric(
        .data[[tau_col]]
      ),
    
    Temperature_K =
      as.numeric(
        .data[[temp_col]]
      ),
    
    Mean_Ridge_VOC_NOx =
      as.numeric(
        .data[[ratio_col]]
      )
  ) %>%
  
  filter(
    DilutionLifetime_h %in% tau_values
  ) %>%
  
  filter(
    is.finite(Temperature_K),
    is.finite(Mean_Ridge_VOC_NOx)
  ) %>%
  
  arrange(
    DilutionLifetime_h,
    Temperature_K
  ) %>%
  
  mutate(
    
    Series =
      paste0(
        DilutionLifetime_h,
        " h"
      )
  )


ridge_data$Series <- factor(
  
  ridge_data$Series,
  
  levels = c(
    "6 h",
    "12 h",
    "24 h",
    "48 h"
  )
)


# =============================================================================
# 20. VERIFY RIDGE DATA
# =============================================================================

cat("\n============================================================\n")
cat("RIDGE DATA USED FOR FIGURE\n")
cat("============================================================\n\n")

print(ridge_data)


# We expect 4 temperatures x 4 lifetimes = 16 points

if (nrow(ridge_data) != 16) {
  
  warning(
    paste0(
      "Expected 16 ridge points ",
      "(4 temperatures x 4 dilution lifetimes), ",
      "but found ",
      nrow(ridge_data),
      "."
    )
  )
}


# Save exact data used

write_csv(
  ridge_data,
  file.path(
    output_dir,
    "DilutionSensitivity_Ridge_DataUsed.csv"
  )
)


# =============================================================================
# 21. RIDGE-SPECIFIC COLORS
# =============================================================================

ridge_colors <- c(
  
  "6 h" =
    series_colors["6 h"],
  
  "12 h" =
    series_colors["12 h"],
  
  "24 h" =
    series_colors["24 h"],
  
  "48 h" =
    series_colors["48 h"]
)


ridge_linetypes <- c(
  
  "6 h" = "dotted",
  
  "12 h" = "dashed",
  
  "24 h" = "solid",
  
  "48 h" = "dotdash"
)


ridge_shapes <- c(
  
  "6 h" = 21,
  
  "12 h" = 22,
  
  "24 h" = 23,
  
  "48 h" = 24
)


# =============================================================================
# 22. RIDGE Y AXIS
# =============================================================================

ridge_min <- min(
  ridge_data$Mean_Ridge_VOC_NOx,
  na.rm = TRUE
)

ridge_max <- max(
  ridge_data$Mean_Ridge_VOC_NOx,
  na.rm = TRUE
)


# Use 0.5 spacing similar to reference figure

ridge_ymin <- floor(
  ridge_min * 2
) / 2 - 0.5

ridge_ymax <- ceiling(
  ridge_max * 2
) / 2


# Prevent unnecessary negative lower limit

ridge_ymin <- max(
  0,
  ridge_ymin
)


# =============================================================================
# 23. RIDGE FIGURE
# =============================================================================

p_ridge <- ggplot(
  
  ridge_data,
  
  aes(
    x = Temperature_K,
    y = Mean_Ridge_VOC_NOx,
    colour = Series,
    linetype = Series,
    shape = Series,
    group = Series
  )
  
) +
  
  
  geom_line(
    linewidth = 1.35
  ) +
  
  
  geom_point(
    size = 4.5,
    stroke = 1.4,
    fill = "white"
  ) +
  
  
  scale_colour_manual(
    
    values =
      ridge_colors,
    
    breaks = c(
      "6 h",
      "12 h",
      "24 h",
      "48 h"
    ),
    
    labels = c(
      
      expression(
        tau[dil] == 6 ~ h
      ),
      
      expression(
        tau[dil] == 12 ~ h
      ),
      
      expression(
        tau[dil] == 24 ~ h
      ),
      
      expression(
        tau[dil] == 48 ~ h
      )
    )
  ) +
  
  
  scale_linetype_manual(
    values =
      ridge_linetypes
  ) +
  
  
  scale_shape_manual(
    values =
      ridge_shapes
  ) +
  
  
  scale_x_continuous(
    
    breaks = c(
      290,
      295,
      300,
      305
    ),
    
    limits = c(
      290,
      305
    ),
    
    expand =
      expansion(
        mult = c(
          0,
          0
        )
      )
  ) +
  
  
  scale_y_continuous(
    
    limits = c(
      ridge_ymin,
      ridge_ymax
    ),
    
    breaks = seq(
      ridge_ymin,
      ridge_ymax,
      by = 0.5
    ),
    
    expand =
      expansion(
        mult = c(
          0,
          0
        )
      )
  ) +
  
  
  labs(
    
    x =
      "Temperature (K)",
    
    y =
      expression(
        "Mean ridge VOC/NO"[x]
      ),
    
    colour = NULL,
    linetype = NULL,
    shape = NULL
  ) +
  
  
  theme_classic(
    base_size = 17
  ) +
  
  
  theme(
    
    axis.title.x =
      element_text(
        size = 20,
        colour = "black",
        margin = margin(t = 10)
      ),
    
    axis.title.y =
      element_text(
        size = 20,
        colour = "black",
        margin = margin(r = 10)
      ),
    
    axis.text =
      element_text(
        size = 15,
        colour = "black"
      ),
    
    axis.ticks =
      element_line(
        colour = "black",
        linewidth = 0.8
      ),
    
    axis.ticks.length =
      grid::unit(
        0.16,
        "cm"
      ),
    
    axis.line =
      element_blank(),
    
    panel.border =
      element_rect(
        colour = "black",
        fill = NA,
        linewidth = 1
      ),
    
    panel.grid =
      element_blank(),
    
    panel.background =
      element_rect(
        fill = "white",
        colour = NA
      ),
    
    plot.background =
      element_rect(
        fill = "white",
        colour = NA
      ),
    
    
    # Upper-right legend as in reference figure
    
    legend.position =
      c(
        0.965,
        0.965
      ),
    
    legend.justification =
      c(
        1,
        1
      ),
    
    legend.background =
      element_blank(),
    
    legend.key =
      element_blank(),
    
    legend.text =
      element_text(
        size = 15,
        colour = "black"
      ),
    
    legend.key.width =
      grid::unit(
        1.3,
        "cm"
      ),
    
    plot.margin =
      margin(
        12,
        15,
        12,
        15
      )
  ) +
  
  
  guides(
    
    colour =
      guide_legend(
        
        override.aes =
          list(
            linewidth = 1.35,
            size = 4.5
          )
      ),
    
    linetype =
      "none",
    
    shape =
      "none"
  )


print(p_ridge)


# =============================================================================
# 24. SAVE RIDGE FIGURE
# =============================================================================

ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_RidgeRatio_vs_T.png"
  ),
  p_ridge,
  width = 8.5,
  height = 6.5,
  units = "in",
  dpi = 600,
  bg = "white"
)


ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_RidgeRatio_vs_T.tiff"
  ),
  p_ridge,
  width = 8.5,
  height = 6.5,
  units = "in",
  dpi = 600,
  compression = "lzw",
  bg = "white"
)


ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_RidgeRatio_vs_T.pdf"
  ),
  p_ridge,
  width = 8.5,
  height = 6.5,
  units = "in",
  device = cairo_pdf,
  bg = "white"
)


ggsave(
  file.path(
    output_dir,
    "DilutionSensitivity_RidgeRatio_vs_T.svg"
  ),
  p_ridge,
  width = 8.5,
  height = 6.5,
  units = "in",
  device = svglite,
  bg = "white"
)


# =============================================================================
# 25. FINAL SUMMARY
# =============================================================================

cat("\n")
cat("============================================================\n")
cat("ALL PUBLICATION FIGURES COMPLETE\n")
cat("============================================================\n")

cat("\nFIGURE 1:\n")
cat("Observed + modeled diurnal O3\n")
cat("tau_dil = 6, 12, 24, 48 h\n")

cat("\nFIGURE 2:\n")
cat("Mean ridge VOC/NOx vs Temperature\n")
cat("tau_dil = 6, 12, 24, 48 h\n")

cat("\n24 h is the baseline dilution lifetime.\n")

cat("\nOutputs saved in:\n")
cat(output_dir, "\n")

cat("\nSource diurnal files used:\n")

print(
  source_inventory[
    c(
      "DilutionLifetime_h",
      "Folder",
      "File"
    )
  ]
)

cat("\nRidge summary used:\n")
cat(ridge_file, "\n")

cat("\nDONE.\n")
