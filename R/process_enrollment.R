# ==============================================================================
# Enrollment Data Processing Functions
# ==============================================================================
#
# This file contains functions for processing raw NC enrollment data into a
# clean, standardized format.
#
# NC DPI uses the following identifier system:
# - LEA codes: 3 digits (e.g., 920 = Wake County Schools)
# - School codes: 3 additional digits appended to LEA code
# - Full school ID: 6 digits (LEA + school)
#
# ==============================================================================

#' Process raw NC enrollment data
#'
#' Transforms raw data from NC DPI or NCES into a standardized schema
#' combining LEA and school data.
#'
#' @param raw_data List containing lea and school data frames from get_raw_enr
#' @param end_year School year end
#' @return Processed data frame with standardized columns
#' @keywords internal
process_enr <- function(raw_data, end_year) {

  # Process LEA data
  lea_processed <- process_lea_enr(raw_data$lea, end_year)

  # Process school data
  school_processed <- process_school_enr(raw_data$school, end_year)

  # Create state aggregate
  state_processed <- create_state_aggregate(lea_processed, end_year)

  # Combine all levels
  result <- dplyr::bind_rows(state_processed, lea_processed, school_processed)

  result
}


#' Process LEA-level (district) enrollment data
#'
#' @param df Raw LEA data frame
#' @param end_year School year end
#' @return Processed LEA data frame
#' @keywords internal
process_lea_enr <- function(df, end_year) {

  if (is.null(df) || nrow(df) == 0) {
    return(data.frame())
  }

  cols <- names(df)
  n_rows <- nrow(df)

  # Helper to find column by pattern (case-insensitive)
  find_col <- function(patterns) {
    for (pattern in patterns) {
      matched <- grep(paste0("^", pattern, "$"), cols, value = TRUE, ignore.case = TRUE)
      if (length(matched) > 0) return(matched[1])
    }
    NULL
  }

  # Build result dataframe
  result <- data.frame(
    end_year = rep(end_year, n_rows),
    type = rep("District", n_rows),
    stringsAsFactors = FALSE
  )

  # District/LEA ID - NC uses 3-digit LEA codes
  # NCES uses LEAID which includes state FIPS prefix (37XXX)
  lea_col <- find_col(c("LEAID", "LEA_CODE", "LEA", "LEACODE", "lea_code",
                        "DIST_ID", "DISTRICT_ID"))
  if (!is.null(lea_col)) {
    lea_id <- trimws(as.character(df[[lea_col]]))
    # If NCES format (5+ digits with state FIPS), extract last 3
    lea_id <- ifelse(nchar(lea_id) >= 5,
                     substr(lea_id, nchar(lea_id) - 2, nchar(lea_id)),
                     lea_id)
    # Pad to 3 digits
    result$district_id <- sprintf("%03d", as.integer(lea_id))
  }

  # Campus ID is NA for district rows
  result$campus_id <- rep(NA_character_, n_rows)

  # District name
  name_col <- find_col(c("LEA_NAME", "LEANAME", "NAME", "DISTRICT_NAME",
                         "DISTNAME", "lea_name", "LEACD_NM"))
  if (!is.null(name_col)) {
    result$district_name <- clean_name(df[[name_col]])
  }

  result$campus_name <- rep(NA_character_, n_rows)

  # County - NC LEAs often map directly to counties
  county_col <- find_col(c("COUNTY", "COUNTY_NAME", "CNTYNAME", "CONAME"))
  if (!is.null(county_col)) {
    result$county <- clean_name(df[[county_col]])
  }

  # Region - NC uses 8 education regions
  region_col <- find_col(c("REGION", "REG", "EDREGION"))
  if (!is.null(region_col)) {
    result$region <- trimws(df[[region_col]])
  }

  # Charter flag - NA for districts (would be at school level)
  result$charter_flag <- rep(NA_character_, n_rows)

  # Total enrollment
  total_col <- find_col(c("TOTAL", "MEMBER", "MEMBERSHIP", "ENROLL",
                          "ENROLLMENT", "TOTAL_MEMBERSHIP", "TOT"))
  if (!is.null(total_col)) {
    result$row_total <- safe_numeric(df[[total_col]])
  }

  # Demographics by race/ethnicity
  # NCES CCD codes: AM=American Indian, AS=Asian, HI=Hispanic, BL=Black,
  #                 WH=White, HP=Hawaiian/Pacific Islander, TR=Two or More
  demo_map <- list(
    white = c("WH", "WHITE", "MEMBER_WH", "WHI"),
    black = c("BL", "BLACK", "MEMBER_BL", "BLA"),
    hispanic = c("HI", "HISPANIC", "MEMBER_HI", "HIS"),
    asian = c("AS", "ASIAN", "MEMBER_AS", "ASI"),
    pacific_islander = c("HP", "PACIFIC", "MEMBER_HP", "PAC", "HAWAIIAN"),
    native_american = c("AM", "AMERICAN_INDIAN", "MEMBER_AM", "IND", "NATIVE"),
    multiracial = c("TR", "TWO_OR_MORE", "MEMBER_TR", "MULTI", "TWOMORE")
  )

  for (name in names(demo_map)) {
    col <- find_col(demo_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Gender
  gender_map <- list(
    male = c("MALE", "M", "MEMBER_M"),
    female = c("FEMALE", "F", "MEMBER_F", "FEM")
  )

  for (name in names(gender_map)) {
    col <- find_col(gender_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Special populations
  special_map <- list(
    econ_disadv = c("FREE_LUNCH", "REDUCED_LUNCH", "FRL", "FRELUNCH", "ECONDIS"),
    lep = c("LEP", "EL", "ELL", "LIMITED_ENGLISH"),
    special_ed = c("SPED", "SPECIAL_ED", "IEP", "SPECIALED")
  )

  for (name in names(special_map)) {
    col <- find_col(special_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Grade levels
  grade_map <- list(
    grade_pk = c("PK", "PREKINDERGARTEN", "PRE_K", "PREK"),
    grade_k = c("KG", "KINDERGARTEN", "K", "KINDER"),
    grade_01 = c("G01", "GRADE_01", "GRADE01", "GR01", "G1"),
    grade_02 = c("G02", "GRADE_02", "GRADE02", "GR02", "G2"),
    grade_03 = c("G03", "GRADE_03", "GRADE03", "GR03", "G3"),
    grade_04 = c("G04", "GRADE_04", "GRADE04", "GR04", "G4"),
    grade_05 = c("G05", "GRADE_05", "GRADE05", "GR05", "G5"),
    grade_06 = c("G06", "GRADE_06", "GRADE06", "GR06", "G6"),
    grade_07 = c("G07", "GRADE_07", "GRADE07", "GR07", "G7"),
    grade_08 = c("G08", "GRADE_08", "GRADE08", "GR08", "G8"),
    grade_09 = c("G09", "GRADE_09", "GRADE09", "GR09", "G9"),
    grade_10 = c("G10", "GRADE_10", "GRADE10", "GR10"),
    grade_11 = c("G11", "GRADE_11", "GRADE11", "GR11"),
    grade_12 = c("G12", "GRADE_12", "GRADE12", "GR12")
  )

  for (name in names(grade_map)) {
    col <- find_col(grade_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  result
}


#' Process school-level (campus) enrollment data
#'
#' @param df Raw school data frame
#' @param end_year School year end
#' @return Processed school data frame
#' @keywords internal
process_school_enr <- function(df, end_year) {

  if (is.null(df) || nrow(df) == 0) {
    return(data.frame())
  }

  cols <- names(df)
  n_rows <- nrow(df)

  # Helper to find column by pattern (case-insensitive)
  find_col <- function(patterns) {
    for (pattern in patterns) {
      matched <- grep(paste0("^", pattern, "$"), cols, value = TRUE, ignore.case = TRUE)
      if (length(matched) > 0) return(matched[1])
    }
    NULL
  }

  # Build result dataframe
  result <- data.frame(
    end_year = rep(end_year, n_rows),
    type = rep("Campus", n_rows),
    stringsAsFactors = FALSE
  )

  # School ID - NCES uses NCESSCH (12 digits), NC uses 6 digits
  school_col <- find_col(c("NCESSCH", "SCHOOL_ID", "SCHCODE", "SCH_ID",
                           "SCHID", "SCHOOL_CODE"))
  if (!is.null(school_col)) {
    sch_id <- trimws(as.character(df[[school_col]]))
    # If NCES format (12 digits), extract last 6
    sch_id <- ifelse(nchar(sch_id) >= 12,
                     substr(sch_id, nchar(sch_id) - 5, nchar(sch_id)),
                     sch_id)
    result$campus_id <- sch_id
  }

  # District ID from school ID (first 3 digits) or LEA column
  lea_col <- find_col(c("LEAID", "LEA_CODE", "LEA", "LEACODE"))
  if (!is.null(lea_col)) {
    lea_id <- trimws(as.character(df[[lea_col]]))
    lea_id <- ifelse(nchar(lea_id) >= 5,
                     substr(lea_id, nchar(lea_id) - 2, nchar(lea_id)),
                     lea_id)
    result$district_id <- sprintf("%03d", as.integer(lea_id))
  } else if (!is.null(result$campus_id)) {
    # Extract from school ID
    result$district_id <- substr(result$campus_id, 1, 3)
  }

  # School name
  name_col <- find_col(c("SCHNAME", "SCHOOL_NAME", "SCH_NAME", "NAME", "SCHOOLNAME"))
  if (!is.null(name_col)) {
    result$campus_name <- clean_name(df[[name_col]])
  }

  # District name
  dist_name_col <- find_col(c("LEA_NAME", "LEANAME", "DISTNAME", "DISTRICT_NAME"))
  if (!is.null(dist_name_col)) {
    result$district_name <- clean_name(df[[dist_name_col]])
  }

  # County
  county_col <- find_col(c("COUNTY", "COUNTY_NAME", "CNTYNAME", "CONAME"))
  if (!is.null(county_col)) {
    result$county <- clean_name(df[[county_col]])
  }

  # Region
  region_col <- find_col(c("REGION", "REG", "EDREGION"))
  if (!is.null(region_col)) {
    result$region <- trimws(df[[region_col]])
  }

  # Charter flag
  charter_col <- find_col(c("CHARTER", "CHARTEFLAG", "CHARTER_FLAG", "CHARTER_TEXT",
                            "IS_CHARTER", "CHARTSTATUS"))
  if (!is.null(charter_col)) {
    charter_val <- trimws(toupper(as.character(df[[charter_col]])))
    result$charter_flag <- ifelse(charter_val %in% c("Y", "YES", "1", "TRUE", "CHARTER"),
                                  "Y",
                                  ifelse(charter_val %in% c("N", "NO", "0", "FALSE", "NOT A CHARTER"),
                                         "N", NA_character_))
  }

  # Total enrollment
  total_col <- find_col(c("TOTAL", "MEMBER", "MEMBERSHIP", "ENROLL",
                          "ENROLLMENT", "TOTAL_MEMBERSHIP", "TOT", "TOTMEMB"))
  if (!is.null(total_col)) {
    result$row_total <- safe_numeric(df[[total_col]])
  }

  # Demographics by race/ethnicity
  demo_map <- list(
    white = c("WH", "WHITE", "MEMBER_WH", "WHI"),
    black = c("BL", "BLACK", "MEMBER_BL", "BLA"),
    hispanic = c("HI", "HISPANIC", "MEMBER_HI", "HIS"),
    asian = c("AS", "ASIAN", "MEMBER_AS", "ASI"),
    pacific_islander = c("HP", "PACIFIC", "MEMBER_HP", "PAC", "HAWAIIAN"),
    native_american = c("AM", "AMERICAN_INDIAN", "MEMBER_AM", "IND", "NATIVE"),
    multiracial = c("TR", "TWO_OR_MORE", "MEMBER_TR", "MULTI", "TWOMORE")
  )

  for (name in names(demo_map)) {
    col <- find_col(demo_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Gender
  gender_map <- list(
    male = c("MALE", "M", "MEMBER_M"),
    female = c("FEMALE", "F", "MEMBER_F", "FEM")
  )

  for (name in names(gender_map)) {
    col <- find_col(gender_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Special populations
  special_map <- list(
    econ_disadv = c("FREE_LUNCH", "REDUCED_LUNCH", "FRL", "FRELUNCH", "ECONDIS",
                    "LUNCH_PROGRAM", "TOTFRL"),
    lep = c("LEP", "EL", "ELL", "LIMITED_ENGLISH"),
    special_ed = c("SPED", "SPECIAL_ED", "IEP", "SPECIALED")
  )

  for (name in names(special_map)) {
    col <- find_col(special_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Grade levels
  grade_map <- list(
    grade_pk = c("PK", "PREKINDERGARTEN", "PRE_K", "PREK"),
    grade_k = c("KG", "KINDERGARTEN", "K", "KINDER"),
    grade_01 = c("G01", "GRADE_01", "GRADE01", "GR01", "G1"),
    grade_02 = c("G02", "GRADE_02", "GRADE02", "GR02", "G2"),
    grade_03 = c("G03", "GRADE_03", "GRADE03", "GR03", "G3"),
    grade_04 = c("G04", "GRADE_04", "GRADE04", "GR04", "G4"),
    grade_05 = c("G05", "GRADE_05", "GRADE05", "GR05", "G5"),
    grade_06 = c("G06", "GRADE_06", "GRADE06", "GR06", "G6"),
    grade_07 = c("G07", "GRADE_07", "GRADE07", "GR07", "G7"),
    grade_08 = c("G08", "GRADE_08", "GRADE08", "GR08", "G8"),
    grade_09 = c("G09", "GRADE_09", "GRADE09", "GR09", "G9"),
    grade_10 = c("G10", "GRADE_10", "GRADE10", "GR10"),
    grade_11 = c("G11", "GRADE_11", "GRADE11", "GR11"),
    grade_12 = c("G12", "GRADE_12", "GRADE12", "GR12")
  )

  for (name in names(grade_map)) {
    col <- find_col(grade_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  result
}


#' Create state-level aggregate from LEA data
#'
#' @param lea_df Processed LEA data frame
#' @param end_year School year end
#' @return Single-row data frame with state totals
#' @keywords internal
create_state_aggregate <- function(lea_df, end_year) {

  if (is.null(lea_df) || nrow(lea_df) == 0) {
    return(data.frame())
  }

  # Columns to sum
  sum_cols <- c(
    "row_total",
    "white", "black", "hispanic", "asian",
    "pacific_islander", "native_american", "multiracial",
    "male", "female",
    "econ_disadv", "lep", "special_ed",
    "grade_pk", "grade_k",
    "grade_01", "grade_02", "grade_03", "grade_04",
    "grade_05", "grade_06", "grade_07", "grade_08",
    "grade_09", "grade_10", "grade_11", "grade_12"
  )

  # Filter to columns that exist
  sum_cols <- sum_cols[sum_cols %in% names(lea_df)]

  # Create state row
  state_row <- data.frame(
    end_year = end_year,
    type = "State",
    district_id = NA_character_,
    campus_id = NA_character_,
    district_name = NA_character_,
    campus_name = NA_character_,
    county = NA_character_,
    region = NA_character_,
    charter_flag = NA_character_,
    stringsAsFactors = FALSE
  )

  # Sum each column
  for (col in sum_cols) {
    state_row[[col]] <- sum(lea_df[[col]], na.rm = TRUE)
  }

  state_row
}
