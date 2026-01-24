# ==============================================================================
# Assessment Data Tidying Functions
# ==============================================================================
#
# This file contains functions for adding aggregation flags and transforming
# assessment data for analysis.
#
# ==============================================================================


#' Tidy assessment data
#'
#' Adds aggregation flags and ensures consistent column ordering for
#' analysis-ready assessment data.
#'
#' @param df A data frame of processed assessment data from process_assessment
#' @return A data frame with aggregation flags and cleaned data
#' @export
#' @examples
#' \dontrun{
#' raw <- get_raw_assessment(2024)
#' processed <- process_assessment(raw, 2024)
#' tidy_data <- tidy_assessment(processed)
#' }
tidy_assessment <- function(df) {

  if (is.null(df) || nrow(df) == 0) {
    return(df)
  }

  # Add aggregation boolean flags
  df <- df |>
    dplyr::mutate(
      is_state = level == "state",
      is_district = level == "district",
      is_school = level == "school"
    )

  # Ensure consistent column ordering
  col_order <- c(
    # Identifiers
    "end_year", "agency_code", "district_id", "school_id", "level",
    # Aggregation flags
    "is_state", "is_district", "is_school",
    # Assessment dimensions
    "standard", "standard_label",
    "subject", "subject_label",
    "grade", "grade_label",
    "subgroup", "subgroup_label",
    # Metrics
    "n_tested", "pct_proficient", "n_proficient",
    # Suppression
    "masking", "is_suppressed", "suppression_reason"
  )

  # Select columns that exist
  existing_cols <- col_order[col_order %in% names(df)]
  other_cols <- setdiff(names(df), col_order)

  df <- df |>
    dplyr::select(dplyr::all_of(c(existing_cols, other_cols)))

  df
}


#' Identify assessment aggregation levels
#'
#' Adds boolean flags to identify state, district, and school level records.
#' This is called internally by tidy_assessment but can be used separately.
#'
#' @param df Assessment dataframe with 'level' column
#' @return data.frame with boolean aggregation flags
#' @export
#' @examples
#' \dontrun{
#' assess <- fetch_assessment(2024, tidy = FALSE)
#' assess_with_flags <- id_assessment_aggs(assess)
#' }
id_assessment_aggs <- function(df) {

  if (!"level" %in% names(df)) {
    # Try to infer level from agency_code
    if ("agency_code" %in% names(df)) {
      school_id <- extract_school_id(df$agency_code)
      df$level <- dplyr::case_when(
        grepl("^SEA", df$agency_code) ~ "state",
        !is.na(school_id) & school_id != "000" & school_id != "" ~ "school",
        TRUE ~ "district"
      )
    } else {
      df$level <- "unknown"
    }
  }

  df |>
    dplyr::mutate(
      is_state = level == "state",
      is_district = level == "district",
      is_school = level == "school"
    )
}


#' Filter assessment data to proficiency results
#'
#' Filters assessment data to include only rows with CCR (College and Career Ready)
#' or GLP (Grade Level Proficiency) standards, which are the main proficiency metrics.
#'
#' @param df A tidy assessment data frame
#' @param standard Which proficiency standard to filter: "CCR" (default), "GLP", or "both"
#' @return Filtered data frame
#' @export
#' @examples
#' \dontrun{
#' assess <- fetch_assessment(2024)
#' ccr_only <- filter_proficiency(assess, "CCR")
#' }
filter_proficiency <- function(df, standard = "CCR") {

  if (!"standard" %in% names(df)) {
    warning("No 'standard' column found in data")
    return(df)
  }

  standard <- toupper(standard)

  if (standard == "BOTH") {
    df <- df |>
      dplyr::filter(standard %in% c("CCR", "GLP"))
  } else if (standard %in% c("CCR", "GLP")) {
    df <- df |>
      dplyr::filter(standard == !!standard)
  } else {
    warning(paste("Unknown standard:", standard, ". Using CCR."))
    df <- df |>
      dplyr::filter(standard == "CCR")
  }

  df
}


#' Calculate proficiency gap between subgroups
#'
#' Calculates the gap in proficiency rates between two subgroups.
#'
#' @param df A tidy assessment data frame
#' @param group1 First subgroup code (e.g., "WH7" for White)
#' @param group2 Second subgroup code (e.g., "BL7" for Black)
#' @return Data frame with gap calculations
#' @export
#' @examples
#' \dontrun{
#' assess <- fetch_assessment(2024)
#' # Calculate White-Black gap
#' gap <- calc_proficiency_gap(assess, "WH7", "BL7")
#' }
calc_proficiency_gap <- function(df, group1, group2) {

  # Filter to relevant subgroups
  df1 <- df |>
    dplyr::filter(subgroup == group1) |>
    dplyr::select(
      end_year, agency_code, district_id, school_id, level,
      standard, subject, grade,
      n_tested_1 = n_tested,
      pct_proficient_1 = pct_proficient
    )

  df2 <- df |>
    dplyr::filter(subgroup == group2) |>
    dplyr::select(
      end_year, agency_code, district_id, school_id, level,
      standard, subject, grade,
      n_tested_2 = n_tested,
      pct_proficient_2 = pct_proficient
    )

  # Join and calculate gap
  result <- dplyr::inner_join(
    df1, df2,
    by = c("end_year", "agency_code", "district_id", "school_id", "level",
           "standard", "subject", "grade")
  ) |>
    dplyr::mutate(
      subgroup_1 = group1,
      subgroup_2 = group2,
      gap = pct_proficient_1 - pct_proficient_2
    )

  result
}
