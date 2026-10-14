# =============================================================================
# LosAngeles_F0AM_RealCase_Isopleths_REVIEWED_Publication.R
#
# PURPOSE
# -------
# Recreate publication-quality Los Angeles HISTORICAL REAL-CASE maximum-O3
# isopleths from the FINAL real-case F0AM output files.
#
# THIS SCRIPT DOES NOT RERUN F0AM.
#
# Historical blocks and temperatures from the current MATLAB real-case script:
#   1996-2000 : 290.6 K
#   2001-2005 : 290.4 K
#   2006-2010 : 290.9 K
#   2011-2015 : 290.7 K
#   2016-2020 : 293.0 K
#
# Current MATLAB output structure:
#   <realcase_root>/1996_2000/1996_2000_Isopleth_T290_6K.csv
#   <realcase_root>/2001_2005/2001_2005_Isopleth_T290_4K.csv
#   <realcase_root>/2006_2010/2006_2010_Isopleth_T290_9K.csv
#   <realcase_root>/2011_2015/2011_2015_Isopleth_T290_7K.csv
#   <realcase_root>/2016_2020/2016_2020_Isopleth_T293K.csv
#
# Expected columns from current MATLAB real-case output:
#   VOC_ppb
#   NOx_ppb
#   VOC_factor
#   NOx_factor
#   MaxO3_08_20_ppb
#   TempK
#   Block
#
# PLOTTING CONVENTION
# -------------------
#   x-axis  = VOC_ppb
#   y-axis  = NOx_ppb
#   z-field = MaxO3_08_20_ppb
#
# IMPORTANT
# ---------
# The physical surface is reconstructed directly from the explicit saved
# (VOC_ppb, NOx_ppb) coordinates. No blind matrix transpose is applied.
#
# COMMON SCALE
# ------------
# All five historical panels use the SAME O3-to-color mapping.
# This version uses 0-150 ppb, matching the expanded base-case scale.
#
# OUTPUT
# ------
# 1) Five individual publication figures
# 2) One combined five-panel figure:
#       top row    = 1996-2000, 2001-2005, 2006-2010
#       bottom row = 2011-2015, 2016-2020
#    with ONE shared maximum-O3 colorbar
# 3) PNG 600 dpi
# 4) TIFF 600 dpi, LZW
# 5) PDF vector
# 6) SVG editable vector
# 7) Input-verification CSV
# 8) Coordinate-reconstructed plotting-grid CSVs
#
# The original F0AM output files are NEVER modified.
# =============================================================================


# =============================================================================
# 0. CLEAN ENVIRONMENT
# =============================================================================

rm(list = ls())
graphics.off()


# =============================================================================
# 1. PACKAGES
# =============================================================================

required_packages <- c(
  "ggplot2",
  "readxl",
  "readr",
  "dplyr",
  "tidyr",
  "metR",
  "scales",
  "patchwork",
  "svglite"
)

new_packages <- required_packages[
  !(required_packages %in% rownames(installed.packages()))
]

if (length(new_packages) > 0) {
  install.packages(new_packages, dependencies = TRUE)
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(readxl)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(metR)
  library(scales)
  library(patchwork)
  library(svglite)
})


# =============================================================================
# 2. CURRENT REAL-CASE ROOT DIRECTORY
# =============================================================================
#
# This matches the current MATLAB real-case script:
#
# out_root =
# D:\Final_Temp_inf_on_Ozone_analysis\
# Finalization_spinuobasecase\latest\final\Realcase2
#
# Each historical block is saved in its own subfolder.
#
# If you later move the MATLAB outputs, edit ONLY realcase_root.
# =============================================================================

realcase_root <- file.path(
  "C:/Users/beg24003/OneDrive - University of Connecticut/Desktop",
  "2025-2026 Session/Summer/Paper review",
  "Final Isopleth justification for F0am paper",
  "Basecasefinal_forpaper/Realcase_with_VOCholdme/finalizedRealcase_withVOCholdme"
)

if (!dir.exists(realcase_root)) {
  stop(
    paste0(
      "\nREAL-CASE ROOT DIRECTORY DOES NOT EXIST:\n",
      realcase_root,
      "\n\nEdit ONLY 'realcase_root' in Section 2 so it points to the ",
      "folder containing the five historical block folders.\n"
    )
  )
}


# =============================================================================
# 3. OUTPUT DIRECTORY
# =============================================================================

output_dir <- file.path(
  realcase_root,
  "R_Publication_RealCase_Isopleths"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}


# =============================================================================
# 4. HISTORICAL BLOCK / TEMPERATURE MAPPING
# =============================================================================

panel_info <- data.frame(
  Panel = c("a", "b", "c", "d", "e"),
  
  BlockFolder = c(
    "1996_2000",
    "2001_2005",
    "2006_2010",
    "2011_2015",
    "2016_2020"
  ),
  
  BlockLabel = c(
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
  
  stringsAsFactors = FALSE
)


# =============================================================================
# 5. PUBLICATION / ISOPLETH SETTINGS
# =============================================================================

# SAME common scale as the expanded base-case plotting script.
O3_COLOR_MIN <- 0
O3_COLOR_MAX <- 140

# O3 isolines
line_breaks <- seq(10, 140, by = 10)

# Colorbar ticks
colorbar_breaks <- seq(0, 140, by = 10)

# Display window. Clipped automatically to actual saved data domain.
VOC_AXIS_MIN <- 20
VOC_AXIS_MAX <- 140
NOX_AXIS_MIN <- 5
NOX_AXIS_MAX <- 50

# Axis ticks
VOC_TICK_BY <- 10
NOX_TICK_BY <- 5

# Contour labels
CONTOUR_LABEL_FRACTION <- 0.72
CONTOUR_LABEL_SIZE <- 3.0
CONTOUR_LABEL_STROKE <- 0.16

# Output resolution
figure_dpi <- 600

# Individual figure size
single_width <- 10.5
single_height <- 7.0

# Combined five-panel figure size
combined_width <- 19.0
combined_height <- 11.5


# =============================================================================
# 6. MATLAB-LIKE JET PALETTE
# =============================================================================

jet_palette <- grDevices::colorRampPalette(
  c(
    "#000080",
    "#0000FF",
    "#0080FF",
    "#00FFFF",
    "#80FF80",
    "#FFFF00",
    "#FFAA00",
    "#FF5500",
    "#FF0000",
    "#800000"
  )
)(256)


# =============================================================================
# 7. TEMPERATURE -> MATLAB FILE TOKEN
# =============================================================================
#
# MATLAB current script uses:
#   strrep(num2str(TK),'.','_')
#
# Therefore:
#   290.6 -> 290_6
#   290.4 -> 290_4
#   290.9 -> 290_9
#   290.7 -> 290_7
#   293.0 -> 293
# =============================================================================

matlab_temp_token <- function(temp_k) {
  
  if (abs(temp_k - round(temp_k)) < 1e-9) {
    token <- as.character(as.integer(round(temp_k)))
  } else {
    token <- format(
      temp_k,
      scientific = FALSE,
      trim = TRUE,
      nsmall = 1
    )
  }
  
  gsub(".", "_", token, fixed = TRUE)
}


# =============================================================================
# 8. ROBUST REAL-CASE FILE LOCATOR
# =============================================================================
#
# Search order:
#   1) Exact filename expected from current MATLAB script
#   2) Exact stem with CSV/XLSX
#   3) Isopleth files inside the block folder whose names contain the block
#      and temperature token
#
# The search remains confined to the CORRECT historical block folder so an
# older result from another period cannot be silently substituted.
# =============================================================================

locate_realcase_isopleth <- function(block_folder, temp_k) {
  
  block_dir <- file.path(
    realcase_root,
    block_folder
  )
  
  if (!dir.exists(block_dir)) {
    stop(
      paste0(
        "\nHistorical block folder does not exist:\n  ",
        block_dir,
        "\n"
      )
    )
  }
  
  temp_token <- matlab_temp_token(temp_k)
  
  expected_stem <- paste0(
    block_folder,
    "_Isopleth_T",
    temp_token,
    "K"
  )
  
  exact_candidates <- c(
    file.path(block_dir, paste0(expected_stem, ".csv")),
    file.path(block_dir, paste0(expected_stem, ".CSV")),
    file.path(block_dir, paste0(expected_stem, ".xlsx")),
    file.path(block_dir, paste0(expected_stem, ".XLSX"))
  )
  
  exact_hit <- exact_candidates[file.exists(exact_candidates)]
  
  if (length(exact_hit) > 0) {
    return(
      normalizePath(
        exact_hit[1],
        winslash = "/",
        mustWork = TRUE
      )
    )
  }
  
  all_files <- list.files(
    block_dir,
    full.names = TRUE,
    recursive = FALSE
  )
  
  if (length(all_files) > 0) {
    
    bn <- basename(all_files)
    ext <- tolower(tools::file_ext(all_files))
    
    # Strictly require:
    # - correct block
    # - "Isopleth"
    # - current temperature token
    # - CSV/XLSX
    candidate_mask <-
      grepl(block_folder, bn, fixed = TRUE) &
      grepl("Isopleth", bn, ignore.case = TRUE) &
      grepl(
        paste0("T", temp_token, "K"),
        bn,
        fixed = TRUE
      ) &
      ext %in% c("csv", "xlsx")
    
    hits <- all_files[candidate_mask]
    
    # Do not accidentally select the PeakFullState metadata file.
    hits <- hits[
      !grepl(
        "PeakFullState",
        basename(hits),
        ignore.case = TRUE
      )
    ]
    
    if (length(hits) == 1) {
      return(
        normalizePath(
          hits[1],
          winslash = "/",
          mustWork = TRUE
        )
      )
    }
    
    if (length(hits) > 1) {
      stop(
        paste0(
          "\nMore than one candidate isopleth file was found for ",
          block_folder,
          " at ",
          temp_k,
          " K:\n  ",
          paste(basename(hits), collapse = "\n  "),
          "\n\nPlease remove/rename ambiguous duplicates rather than allowing ",
          "the plotting script to guess.\n"
        )
      )
    }
  }
  
  available <- list.files(
    block_dir,
    pattern = "Isopleth.*\\.(csv|xlsx)$",
    ignore.case = TRUE,
    full.names = FALSE
  )
  
  stop(
    paste0(
      "\nCould not find the required REAL-CASE isopleth for:\n",
      "  Block       : ",
      block_folder,
      "\n",
      "  Temperature : ",
      temp_k,
      " K\n",
      "  Expected    : ",
      expected_stem,
      ".csv\n\n",
      "Searched folder:\n  ",
      block_dir,
      "\n\nAvailable isopleth-like files:\n  ",
      if (length(available) == 0) {
        "<none>"
      } else {
        paste(available, collapse = "\n  ")
      },
      "\n"
    )
  )
}


# =============================================================================
# 9. READ AND STANDARDIZE ONE REAL-CASE ISOPLETH
# =============================================================================

read_realcase_isopleth <- function(
    block_folder,
    expected_temp
) {
  
  input_file <- locate_realcase_isopleth(
    block_folder,
    expected_temp
  )
  
  ext <- tolower(
    tools::file_ext(input_file)
  )
  
  if (ext == "csv") {
    
    dat <- readr::read_csv(
      input_file,
      show_col_types = FALSE,
      progress = FALSE
    )
    
  } else if (ext == "xlsx") {
    
    dat <- readxl::read_excel(
      input_file,
      sheet = 1
    )
    
  } else {
    
    stop(
      "Unsupported file extension: ",
      ext
    )
  }
  
  dat <- as.data.frame(dat)
  
  # ---------------------------------------------------------------------------
  # Required physical coordinates
  # ---------------------------------------------------------------------------
  
  required_coordinates <- c(
    "VOC_ppb",
    "NOx_ppb"
  )
  
  missing_coordinates <- setdiff(
    required_coordinates,
    names(dat)
  )
  
  if (length(missing_coordinates) > 0) {
    
    stop(
      paste0(
        "\nMissing required coordinate column(s) in:\n",
        input_file,
        "\nMissing: ",
        paste(
          missing_coordinates,
          collapse = ", "
        ),
        "\n\nColumns present:\n  ",
        paste(
          names(dat),
          collapse = ", "
        ),
        "\n"
      )
    )
  }
  
  # ---------------------------------------------------------------------------
  # O3 response column
  # ---------------------------------------------------------------------------
  
  if ("MaxO3_08_20_ppb" %in% names(dat)) {
    
    o3_source <- "MaxO3_08_20_ppb"
    
  } else if ("MaxO3_ppb" %in% names(dat)) {
    
    # Legacy compatibility only.
    o3_source <- "MaxO3_ppb"
    
  } else {
    
    stop(
      paste0(
        "\nNo recognized maximum-O3 response column found in:\n",
        input_file,
        "\n\nExpected:\n",
        "  MaxO3_08_20_ppb  [CURRENT]\n",
        "or\n",
        "  MaxO3_ppb        [legacy]\n\n",
        "Columns present:\n  ",
        paste(
          names(dat),
          collapse = ", "
        ),
        "\n"
      )
    )
  }
  
  # ---------------------------------------------------------------------------
  # Standardize plotting fields
  # ---------------------------------------------------------------------------
  
  dat$VOC_ppb <- suppressWarnings(
    as.numeric(dat$VOC_ppb)
  )
  
  dat$NOx_ppb <- suppressWarnings(
    as.numeric(dat$NOx_ppb)
  )
  
  dat$MaxO3_ppb <- suppressWarnings(
    as.numeric(dat[[o3_source]])
  )
  
  if ("TempK" %in% names(dat)) {
    
    dat$TempK <- suppressWarnings(
      as.numeric(dat$TempK)
    )
    
  } else {
    
    dat$TempK <- expected_temp
  }
  
  if ("Block" %in% names(dat)) {
    
    dat$Block <- as.character(
      dat$Block
    )
    
  } else {
    
    dat$Block <- block_folder
  }
  
  dat <- dat %>%
    filter(
      is.finite(VOC_ppb),
      is.finite(NOx_ppb),
      is.finite(MaxO3_ppb)
    )
  
  if (nrow(dat) == 0) {
    
    stop(
      "\nNo finite isopleth values remained after reading:\n",
      input_file
    )
  }
  
  # ---------------------------------------------------------------------------
  # Verify historical block identity
  # ---------------------------------------------------------------------------
  
  block_values <- unique(
    dat$Block[
      !is.na(dat$Block) &
        nzchar(dat$Block)
    ]
  )
  
  if (
    length(block_values) > 0 &&
    !any(
      gsub("-", "_", block_values) ==
      block_folder
    )
  ) {
    
    warning(
      basename(input_file),
      " contains Block values that do not appear to match expected ",
      block_folder,
      "."
    )
  }
  
  # ---------------------------------------------------------------------------
  # Verify temperature
  # ---------------------------------------------------------------------------
  
  finite_temp <- unique(
    dat$TempK[
      is.finite(dat$TempK)
    ]
  )
  
  if (
    length(finite_temp) > 0 &&
    all(
      abs(
        finite_temp -
        expected_temp
      ) > 0.051
    )
  ) {
    
    warning(
      basename(input_file),
      " contains temperature value(s) that do not match expected ",
      expected_temp,
      " K."
    )
  }
  
  # ---------------------------------------------------------------------------
  # Duplicate coordinate check
  # ---------------------------------------------------------------------------
  
  dup <- dat %>%
    count(
      VOC_ppb,
      NOx_ppb,
      name = "n"
    ) %>%
    filter(
      n > 1
    )
  
  if (nrow(dup) > 0) {
    
    warning(
      basename(input_file),
      " contains duplicated VOC/NOx coordinates. ",
      "Duplicate maximum-O3 values will be averaged for plotting."
    )
    
    dat <- dat %>%
      group_by(
        VOC_ppb,
        NOx_ppb
      ) %>%
      summarise(
        MaxO3_ppb = mean(
          MaxO3_ppb,
          na.rm = TRUE
        ),
        TempK = first(TempK),
        Block = first(Block),
        .groups = "drop"
      )
  }
  
  list(
    data = dat,
    file = input_file,
    ozone_column = o3_source
  )
}


# =============================================================================
# 10. RECONSTRUCT PHYSICAL GRID FROM SAVED COORDINATES
# =============================================================================
#
# No matrix transpose is assumed.
#
# This is safer than reconstructing by row order because the MATLAB CSV already
# contains explicit VOC_ppb and NOx_ppb coordinates for every maximum-O3 value.
# =============================================================================

build_physical_grid <- function(dat) {
  
  voc_levels <- sort(
    unique(dat$VOC_ppb)
  )
  
  nox_levels <- sort(
    unique(dat$NOx_ppb)
  )
  
  expected_n <-
    length(voc_levels) *
    length(nox_levels)
  
  grid <- expand.grid(
    VOC_ppb = voc_levels,
    NOx_ppb = nox_levels
  )
  
  grid <- grid %>%
    left_join(
      dat %>%
        select(
          VOC_ppb,
          NOx_ppb,
          MaxO3_ppb
        ),
      by = c(
        "VOC_ppb",
        "NOx_ppb"
      )
    ) %>%
    arrange(
      NOx_ppb,
      VOC_ppb
    )
  
  missing_n <- sum(
    !is.finite(
      grid$MaxO3_ppb
    )
  )
  
  if (missing_n > 0) {
    
    warning(
      "Physical isopleth grid has ",
      missing_n,
      " missing cell(s) out of ",
      expected_n,
      "."
    )
  }
  
  list(
    data = grid,
    VOC_levels = voc_levels,
    NOx_levels = nox_levels,
    n_expected = expected_n,
    n_missing = missing_n
  )
}


# =============================================================================
# 11. READ AND VERIFY ALL FIVE HISTORICAL ISOPLETHS
# =============================================================================

raw_list <- vector(
  "list",
  nrow(panel_info)
)

grid_list <- vector(
  "list",
  nrow(panel_info)
)

verification <- data.frame(
  Panel = panel_info$Panel,
  Block = panel_info$BlockLabel,
  TempK_Expected = panel_info$TempK,
  File = NA_character_,
  O3_Response_Column = NA_character_,
  Rows = NA_integer_,
  VOC_Min = NA_real_,
  VOC_Max = NA_real_,
  NOx_Min = NA_real_,
  NOx_Max = NA_real_,
  O3_Min = NA_real_,
  O3_Max = NA_real_,
  Missing_Grid_Cells = NA_integer_,
  stringsAsFactors = FALSE
)

cat("\n")
cat("====================================================================\n")
cat("REAL-CASE ISOPLETH INPUT VERIFICATION\n")
cat("====================================================================\n")

for (i in seq_len(nrow(panel_info))) {
  
  read_i <- read_realcase_isopleth(
    panel_info$BlockFolder[i],
    panel_info$TempK[i]
  )
  
  raw_list[[i]] <- read_i$data
  
  grid_list[[i]] <- build_physical_grid(
    read_i$data
  )
  
  verification$File[i] <-
    basename(
      read_i$file
    )
  
  verification$O3_Response_Column[i] <-
    read_i$ozone_column
  
  verification$Rows[i] <-
    nrow(
      read_i$data
    )
  
  verification$VOC_Min[i] <-
    min(
      read_i$data$VOC_ppb,
      na.rm = TRUE
    )
  
  verification$VOC_Max[i] <-
    max(
      read_i$data$VOC_ppb,
      na.rm = TRUE
    )
  
  verification$NOx_Min[i] <-
    min(
      read_i$data$NOx_ppb,
      na.rm = TRUE
    )
  
  verification$NOx_Max[i] <-
    max(
      read_i$data$NOx_ppb,
      na.rm = TRUE
    )
  
  verification$O3_Min[i] <-
    min(
      read_i$data$MaxO3_ppb,
      na.rm = TRUE
    )
  
  verification$O3_Max[i] <-
    max(
      read_i$data$MaxO3_ppb,
      na.rm = TRUE
    )
  
  verification$Missing_Grid_Cells[i] <-
    grid_list[[i]]$n_missing
  
  cat(
    sprintf(
      "%-9s | %5.1f K : FOUND  %-45s | O3 = %s\n",
      panel_info$BlockLabel[i],
      panel_info$TempK[i],
      basename(read_i$file),
      read_i$ozone_column
    )
  )
}

cat("--------------------------------------------------------------------\n")
cat("Physical axes          : x = VOC_ppb; y = NOx_ppb\n")
cat("Common O3 color scale  : 0-150 ppb\n")
cat("O3 isolines            : 10-150 ppb at 10-ppb intervals\n")
cat("Matrix transpose       : NO (coordinate-based reconstruction)\n")
cat("--------------------------------------------------------------------\n\n")

print(
  verification
)

write_csv(
  verification,
  file.path(
    output_dir,
    "00_RealCase_Isopleth_Input_Verification.csv"
  )
)


# =============================================================================
# 12. PUBLICATION THEME
# =============================================================================

publication_theme <- theme_classic(
  base_size = 13.5,
  base_family = "sans"
) +
  theme(
    
    plot.title = element_text(
      size = 15,
      face = "bold",
      hjust = 0.5,
      colour = "black",
      margin = margin(
        b = 8
      )
    ),
    
    plot.tag = element_text(
      size = 17,
      face = "bold",
      colour = "black"
    ),
    
    plot.tag.position = c(
      0.012,
      0.985
    ),
    
    axis.title.x = element_text(
      size = 14,
      face = "plain",
      colour = "black",
      margin = margin(
        t = 7
      )
    ),
    
    axis.title.y = element_text(
      size = 14,
      face = "plain",
      colour = "black",
      margin = margin(
        r = 7
      )
    ),
    
    axis.text = element_text(
      size = 11,
      face = "plain",
      colour = "black"
    ),
    
    axis.line = element_blank(),
    
    axis.ticks = element_line(
      colour = "black",
      linewidth = 0.65
    ),
    
    axis.ticks.length =
      grid::unit(
        0.14,
        "cm"
      ),
    
    panel.border = element_rect(
      fill = NA,
      colour = "black",
      linewidth = 0.9
    ),
    
    panel.grid.major = element_line(
      colour = scales::alpha(
        "black",
        0.12
      ),
      linewidth = 0.30
    ),
    
    panel.grid.minor =
      element_blank(),
    
    panel.background = element_rect(
      fill = "white",
      colour = NA
    ),
    
    plot.background = element_rect(
      fill = "white",
      colour = NA
    ),
    
    legend.title = element_text(
      size = 11.5,
      face = "plain",
      colour = "black"
    ),
    
    legend.text = element_text(
      size = 9.5,
      face = "plain",
      colour = "black"
    ),
    
    plot.margin = margin(
      t = 10,
      r = 12,
      b = 10,
      l = 12
    )
  )


# =============================================================================
# 13. CREATE ONE HISTORICAL ISOPLETH
# =============================================================================

make_realcase_isopleth <- function(
    grid_object,
    block_label,
    temperature,
    panel_letter,
    show_legend = TRUE
) {
  
  dat <- grid_object$data
  
  x_data_min <- min(
    dat$VOC_ppb,
    na.rm = TRUE
  )
  
  x_data_max <- max(
    dat$VOC_ppb,
    na.rm = TRUE
  )
  
  y_data_min <- min(
    dat$NOx_ppb,
    na.rm = TRUE
  )
  
  y_data_max <- max(
    dat$NOx_ppb,
    na.rm = TRUE
  )
  
  x_min <- max(
    VOC_AXIS_MIN,
    x_data_min
  )
  
  x_max <- min(
    VOC_AXIS_MAX,
    x_data_max
  )
  
  y_min <- max(
    NOX_AXIS_MIN,
    y_data_min
  )
  
  y_max <- min(
    NOX_AXIS_MAX,
    y_data_max
  )
  
  if (x_min >= x_max) {
    x_min <- x_data_min
    x_max <- x_data_max
  }
  
  if (y_min >= y_max) {
    y_min <- y_data_min
    y_max <- y_data_max
  }
  
  x_regular <- seq(
    ceiling(
      x_min /
        VOC_TICK_BY
    ) *
      VOC_TICK_BY,
    floor(
      x_max /
        VOC_TICK_BY
    ) *
      VOC_TICK_BY,
    by = VOC_TICK_BY
  )
  
  y_regular <- seq(
    ceiling(
      y_min /
        NOX_TICK_BY
    ) *
      NOX_TICK_BY,
    floor(
      y_max /
        NOX_TICK_BY
    ) *
      NOX_TICK_BY,
    by = NOX_TICK_BY
  )
  
  x_ticks <- sort(
    unique(
      c(
        x_min,
        x_regular,
        x_max
      )
    )
  )
  
  y_ticks <- sort(
    unique(
      c(
        y_min,
        y_regular,
        y_max
      )
    )
  )
  
  p <- ggplot(
    dat,
    aes(
      x = VOC_ppb,
      y = NOx_ppb
    )
  ) +
    
    geom_raster(
      aes(
        fill = MaxO3_ppb
      ),
      interpolate = TRUE,
      na.rm = TRUE
    ) +
    
    geom_contour(
      aes(
        z = MaxO3_ppb
      ),
      breaks = line_breaks,
      colour = "black",
      linewidth = 0.58,
      alpha = 0.92,
      na.rm = TRUE
    ) +
    
    metR::geom_text_contour(
      aes(
        z = MaxO3_ppb
      ),
      breaks = line_breaks,
      colour = "black",
      size = CONTOUR_LABEL_SIZE,
      fontface = "plain",
      stroke = CONTOUR_LABEL_STROKE,
      skip = 0,
      check_overlap = TRUE,
      label.placer =
        metR::label_placer_fraction(
          frac =
            CONTOUR_LABEL_FRACTION
        ),
      na.rm = TRUE
    ) +
    
    scale_fill_gradientn(
      colours = jet_palette,
      limits = c(
        O3_COLOR_MIN,
        O3_COLOR_MAX
      ),
      breaks = colorbar_breaks,
      labels = colorbar_breaks,
      oob = scales::squish,
      name =
        expression(
          "Maximum O"[3] *
            " (ppb)"
        ),
      guide =
        guide_colorbar(
          title.position = "right",
          title.hjust = 0.5,
          barheight =
            grid::unit(
              9.2,
              "cm"
            ),
          barwidth =
            grid::unit(
              0.60,
              "cm"
            ),
          ticks = TRUE,
          frame.colour = "black"
        )
    ) +
    
    scale_x_continuous(
      breaks = x_ticks,
      expand =
        expansion(
          mult = c(
            0,
            0
          )
        )
    ) +
    
    scale_y_continuous(
      breaks = y_ticks,
      expand =
        expansion(
          mult = c(
            0,
            0
          )
        )
    ) +
    
    coord_cartesian(
      xlim = c(
        x_min,
        x_max
      ),
      ylim = c(
        y_min,
        y_max
      ),
      expand = FALSE,
      clip = "on"
    ) +
    
    labs(
      x = "VOC (ppb)",
      y =
        expression(
          "NO"[x] *
            " (ppb)"
        ),
      title =
        paste0(
          block_label,
          " | ",
          format(
            temperature,
            nsmall = 1
          ),
          " K"
        ),
      tag = panel_letter
    ) +
    
    publication_theme +
    
    theme(
      legend.position =
        if (show_legend) {
          "right"
        } else {
          "none"
        }
    )
  
  return(p)
}


# =============================================================================
# 14. CREATE THE FIVE HISTORICAL PANELS
# =============================================================================

plots <- vector(
  "list",
  nrow(panel_info)
)

for (i in seq_len(nrow(panel_info))) {
  
  plots[[i]] <- make_realcase_isopleth(
    grid_object =
      grid_list[[i]],
    
    block_label =
      panel_info$BlockLabel[i],
    
    temperature =
      panel_info$TempK[i],
    
    panel_letter =
      panel_info$Panel[i],
    
    show_legend = TRUE
  )
}


# =============================================================================
# 15. DISPLAY INDIVIDUAL FIGURES
# =============================================================================

for (p in plots) {
  print(p)
}


# =============================================================================
# 16. SAFE SAVE FUNCTION
# =============================================================================

save_realcase_isopleth <- function(
    p,
    output_name
) {
  
  ggsave(
    filename = file.path(
      output_dir,
      paste0(
        output_name,
        ".png"
      )
    ),
    plot = p,
    width = single_width,
    height = single_height,
    units = "in",
    dpi = figure_dpi,
    bg = "white"
  )
  
  ggsave(
    filename = file.path(
      output_dir,
      paste0(
        output_name,
        ".tiff"
      )
    ),
    plot = p,
    width = single_width,
    height = single_height,
    units = "in",
    dpi = figure_dpi,
    compression = "lzw",
    bg = "white"
  )
  
  # Vector exports are attempted independently so a device problem does not
  # prevent the raster outputs from being retained.
  
  try(
    ggsave(
      filename = file.path(
        output_dir,
        paste0(
          output_name,
          ".pdf"
        )
      ),
      plot = p,
      width = single_width,
      height = single_height,
      units = "in",
      device = cairo_pdf,
      bg = "white"
    ),
    silent = TRUE
  )
  
  try(
    ggsave(
      filename = file.path(
        output_dir,
        paste0(
          output_name,
          ".svg"
        )
      ),
      plot = p,
      width = single_width,
      height = single_height,
      units = "in",
      device = svglite,
      bg = "white"
    ),
    silent = TRUE
  )
}


# =============================================================================
# 17. SAVE FIVE INDIVIDUAL FIGURES
# =============================================================================

for (i in seq_len(nrow(panel_info))) {
  
  output_name <- sprintf(
    "%02d_LosAngeles_RealCase_%s_T%sK",
    i,
    panel_info$BlockFolder[i],
    matlab_temp_token(
      panel_info$TempK[i]
    )
  )
  
  save_realcase_isopleth(
    plots[[i]],
    output_name
  )
}


# =============================================================================
# 18. COMBINED FIVE-PANEL PUBLICATION FIGURE
# =============================================================================
#
# Layout:
#
#     (a) 1996-2000   (b) 2001-2005   (c) 2006-2010
#     (d) 2011-2015   (e) 2016-2020   [blank]
#
# One shared O3 colorbar is collected on the right.
# =============================================================================

shared_colorbar <- guide_colorbar(
  title.position = "right",
  title.hjust = 0.5,
  barheight =
    grid::unit(
      11.0,
      "cm"
    ),
  barwidth =
    grid::unit(
      0.70,
      "cm"
    ),
  ticks = TRUE,
  frame.colour = "black"
)

plots_shared <- lapply(
  plots,
  function(p) {
    p +
      guides(
        fill =
          shared_colorbar
      )
  }
)

combined_plot <- (
  plots_shared[[1]] |
    plots_shared[[2]] |
    plots_shared[[3]]
) /
  (
    plots_shared[[4]] |
      plots_shared[[5]] |
      patchwork::plot_spacer()
  ) +
  plot_layout(
    guides = "collect"
  ) +
  plot_annotation(
    title =
      "Los Angeles Historical Real-Case Maximum Ozone Isopleths",
    theme = theme(
      plot.title = element_text(
        size = 21,
        face = "bold",
        hjust = 0.5,
        colour = "black",
        margin = margin(
          b = 12
        )
      )
    )
  ) &
  theme(
    
    legend.position = "right",
    
    legend.title = element_text(
      size = 13,
      face = "plain",
      colour = "black"
    ),
    
    legend.text = element_text(
      size = 10.5,
      face = "plain",
      colour = "black"
    ),
    
    plot.title = element_text(
      size = 13.5,
      face = "bold",
      hjust = 0.5
    ),
    
    plot.tag = element_text(
      size = 17,
      face = "bold",
      colour = "black"
    ),
    
    axis.title = element_text(
      size = 12.5,
      face = "plain"
    ),
    
    axis.text = element_text(
      size = 9.5,
      face = "plain",
      colour = "black"
    ),
    
    plot.margin = margin(
      t = 8,
      r = 8,
      b = 8,
      l = 8
    )
  )


# =============================================================================
# 19. DISPLAY COMBINED FIGURE
# =============================================================================

print(
  combined_plot
)


# =============================================================================
# 20. SAVE COMBINED FIGURE
# =============================================================================

combined_stem <-
  "06_LosAngeles_RealCase_Combined_5Panel"

ggsave(
  filename = file.path(
    output_dir,
    paste0(
      combined_stem,
      ".png"
    )
  ),
  plot = combined_plot,
  width = combined_width,
  height = combined_height,
  units = "in",
  dpi = figure_dpi,
  bg = "white"
)

ggsave(
  filename = file.path(
    output_dir,
    paste0(
      combined_stem,
      ".tiff"
    )
  ),
  plot = combined_plot,
  width = combined_width,
  height = combined_height,
  units = "in",
  dpi = figure_dpi,
  compression = "lzw",
  bg = "white"
)

try(
  ggsave(
    filename = file.path(
      output_dir,
      paste0(
        combined_stem,
        ".pdf"
      )
    ),
    plot = combined_plot,
    width = combined_width,
    height = combined_height,
    units = "in",
    device = cairo_pdf,
    bg = "white"
  ),
  silent = TRUE
)

try(
  ggsave(
    filename = file.path(
      output_dir,
      paste0(
        combined_stem,
        ".svg"
      )
    ),
    plot = combined_plot,
    width = combined_width,
    height = combined_height,
    units = "in",
    device = svglite,
    bg = "white"
  ),
  silent = TRUE
)


# =============================================================================
# 21. SAVE RECONSTRUCTED PHYSICAL GRIDS
# =============================================================================

for (i in seq_len(nrow(panel_info))) {
  
  write_csv(
    grid_list[[i]]$data,
    file.path(
      output_dir,
      paste0(
        panel_info$BlockFolder[i],
        "_T",
        matlab_temp_token(
          panel_info$TempK[i]
        ),
        "K_R_PhysicalPlotGrid.csv"
      )
    )
  )
}


# =============================================================================
# 22. O3 RANGE SUMMARY
# =============================================================================

cat("\n")
cat("====================================================================\n")
cat("REAL-CASE MAXIMUM-O3 RANGE SUMMARY\n")
cat("====================================================================\n")

for (i in seq_len(nrow(verification))) {
  
  cat(
    sprintf(
      "%-9s | %5.1f K : data O3 range = %7.2f to %7.2f ppb\n",
      verification$Block[i],
      verification$TempK_Expected[i],
      verification$O3_Min[i],
      verification$O3_Max[i]
    )
  )
}

cat("--------------------------------------------------------------------\n")

cat(
  sprintf(
    "ALL panels use the SAME displayed color scale: %.0f to %.0f ppb\n",
    O3_COLOR_MIN,
    O3_COLOR_MAX
  )
)

cat("====================================================================\n")


# =============================================================================
# 23. COMPLETION MESSAGE
# =============================================================================

cat("\n\n====================================================================\n")
cat("LOS ANGELES REAL-CASE ISOPLETH FIGURES COMPLETE\n")
cat("====================================================================\n")

cat(
  "\nReal-case root:\n",
  realcase_root,
  "\n"
)

cat(
  "\nOutput directory:\n",
  output_dir,
  "\n"
)

cat(
  "\nHistorical periods:\n",
  "1996-2000 | 290.6 K\n",
  "2001-2005 | 290.4 K\n",
  "2006-2010 | 290.9 K\n",
  "2011-2015 | 290.7 K\n",
  "2016-2020 | 293.0 K\n"
)

cat(
  "\nPhysical axes:\n",
  "x = VOC_ppb\n",
  "y = NOx_ppb\n"
)

cat(
  "\nO3 response:\n",
  "MaxO3_08_20_ppb from the current real-case MATLAB output.\n"
)

cat(
  "\nGrid reconstruction:\n",
  "Explicit VOC/NOx coordinates used; no blind transpose.\n"
)

cat(
  "\nCommon color scale:\n",
  "0-150 ppb for all five historical panels.\n"
)

cat(
  "\nIsolines:\n",
  "10-150 ppb in 10-ppb increments where those O3 values exist.\n"
)

cat(
  "\nOriginal F0AM output files were NOT modified.\n"
)

cat(
  "\nDONE.\n"
)
