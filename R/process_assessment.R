# ==============================================================================
# Assessment Data Processing Functions
# ==============================================================================
#
# This file contains functions for processing raw NC assessment data into a
# clean, standardized format.
#
# NC DPI Assessment Data Structure:
# - agency_code: 6-character code (3-digit LEA + 3-digit school, or LEA + "000" for district)
# - standard: CCR (College and Career Ready), GLP (Grade Level Proficiency), etc.
# - subject: EOG, EOC, MA (Math), RD (Reading), SC (Science), BI (Biology), etc.
# - grade: 03-08 for EOG, EOC for end-of-course, ALL for aggregates
# - subgroup: ALL, demographic codes (BL7=Black, WH7=White, etc.)
# - den: Denominator (number of students tested)
# - pct: Percent proficient
# - masking: Suppression code (0=none, 1=>95%, 2=<5%, 3=<10, 4=insufficient)
#
# ==============================================================================


#' Process raw NC assessment data
#'
#' Transforms raw data from NC DPI into a standardized schema with
#' clear column names and identifiers.
#'
#' @param raw_data Data frame from get_raw_assessment
#' @param end_year School year end
#' @return Processed data frame with standardized columns
#' @keywords internal
process_assessment <- function(raw_data, end_year) {

  if (is.null(raw_data) || nrow(raw_data) == 0) {
    return(create_empty_assessment_processed())
  }

  df <- raw_data

  # Standardize column names
  # Map NC DPI columns to standard names
  result <- data.frame(
    end_year = end_year,
    agency_code = df$agency_code,
    stringsAsFactors = FALSE
  )

  # Parse agency_code to extract district_id and school_id
  # Format: LLLLSS where LLLL is LEA code (3 digits + suffix) and SS is school
  # Examples: "920000" = Wake County (district), "920305" = Wake school 305
  result$district_id <- extract_district_id(df$agency_code)
  result$school_id <- extract_school_id(df$agency_code)

  # Determine aggregation level
  result$level <- dplyr::case_when(
    # State aggregate - typically has specific agency code patterns
    grepl("^SEA", df$agency_code) | df$agency_code %in% c("SEA", "NC", "State") ~ "state",
    # School level - has non-zero school suffix
    !is.na(result$school_id) & result$school_id != "000" & result$school_id != "" ~ "school",
    # District level - school suffix is "000" or empty
    TRUE ~ "district"
  )

  # Standard/proficiency measure
  result$standard <- df$standard
  result$standard_label <- dplyr::case_when(
    df$standard == "CCR" ~ "College and Career Ready",
    df$standard == "GLP" ~ "Grade Level Proficiency",
    df$standard == "L1" ~ "Level 1",
    df$standard == "L2" ~ "Level 2",
    df$standard == "L3" ~ "Level 3",
    df$standard == "L4" ~ "Level 4",
    df$standard == "L5" ~ "Level 5",
    df$standard == "NotProf" ~ "Not Proficient",
    TRUE ~ df$standard
  )

  # Subject
  result$subject <- df$subject
  result$subject_label <- dplyr::case_when(
    df$subject == "EOG" ~ "End-of-Grade (All)",
    df$subject == "EOC" ~ "End-of-Course (All)",
    df$subject == "MA" ~ "Math",
    df$subject == "RD" ~ "Reading",
    df$subject == "SC" ~ "Science",
    df$subject == "BI" ~ "Biology",
    df$subject == "E2" ~ "English II",
    df$subject == "M1" ~ "NC Math 1",
    df$subject == "M3" ~ "NC Math 3",
    df$subject == "ALL" ~ "All Subjects",
    df$subject == "RDRG" ~ "Reading (Regular)",
    df$subject == "RDX1" ~ "Reading (NCExtend1)",
    TRUE ~ df$subject
  )

  # Grade
  result$grade <- df$grade
  result$grade_label <- dplyr::case_when(
    df$grade == "03" ~ "Grade 3",
    df$grade == "04" ~ "Grade 4",
    df$grade == "05" ~ "Grade 5",
    df$grade == "06" ~ "Grade 6",
    df$grade == "07" ~ "Grade 7",
    df$grade == "08" ~ "Grade 8",
    df$grade == "48" ~ "Grades 4-8",
    df$grade == "ALL" ~ "All Grades",
    df$grade == "EOC" ~ "EOC Grades",
    df$grade == "GS" ~ "Grade School (3-8)",
    df$grade == "HS" ~ "High School",
    TRUE ~ paste("Grade", df$grade)
  )

  # Subgroup
  result$subgroup <- df$subgroup
  result$subgroup_label <- dplyr::case_when(
    df$subgroup == "ALL" ~ "All Students",
    df$subgroup == "AIG" ~ "Academically Gifted",
    df$subgroup == "AM7" ~ "American Indian",
    df$subgroup == "AS7" ~ "Asian",
    df$subgroup == "BL7" ~ "Black",
    df$subgroup == "EDS" ~ "Economically Disadvantaged",
    df$subgroup == "ELS" ~ "English Learners",
    df$subgroup == "FCS" ~ "Foster Care",
    df$subgroup == "FEM" ~ "Female",
    df$subgroup == "HI7" ~ "Hispanic",
    df$subgroup == "HMS" ~ "Homeless",
    df$subgroup == "MALE" ~ "Male",
    df$subgroup == "MIG" ~ "Migrant",
    df$subgroup == "MIL" ~ "Military Connected",
    df$subgroup == "MU7" ~ "Two or More Races",
    df$subgroup == "NAIG" ~ "Not Academically Gifted",
    df$subgroup == "NEDS" ~ "Not Economically Disadvantaged",
    df$subgroup == "NELS" ~ "Not English Learners",
    df$subgroup == "NSWD" ~ "Not Students with Disabilities",
    df$subgroup == "PI7" ~ "Pacific Islander",
    df$subgroup == "SWD" ~ "Students with Disabilities",
    df$subgroup == "WH7" ~ "White",
    TRUE ~ df$subgroup
  )

  # Numeric columns
  result$n_tested <- safe_numeric(df$den)
  result$pct_proficient <- safe_numeric(df$pct)

  # Calculate count of proficient students
  result$n_proficient <- round(result$n_tested * result$pct_proficient / 100)

  # Masking/suppression info
  result$masking <- df$masking
  result$is_suppressed <- !is.na(df$masking) & df$masking != "0" & df$masking != ""
  result$suppression_reason <- dplyr::case_when(
    is.na(df$masking) | df$masking == "0" | df$masking == "" ~ NA_character_,
    df$masking == "1" ~ "Greater than 95%",
    df$masking == "2" ~ "Less than 5%",
    df$masking == "3" ~ "Fewer than 10 students",
    df$masking == "4" ~ "Insufficient data",
    TRUE ~ "Unknown suppression"
  )

  result
}


#' Extract district ID from agency code
#'
#' NC agency codes are typically 6 characters: 3-digit LEA + 3-digit school.
#' Some codes may have additional characters for special entities.
#'
#' @param agency_code Character vector of agency codes
#' @return Character vector of district IDs (3 digits)
#' @keywords internal
extract_district_id <- function(agency_code) {
  # Most agency codes are 6 characters (LLL + SSS)
  # Extract first 3 characters as district ID
  ifelse(
    nchar(agency_code) >= 3,
    substr(agency_code, 1, 3),
    NA_character_
  )
}


#' Extract school ID from agency code
#'
#' @param agency_code Character vector of agency codes
#' @return Character vector of school IDs (3 characters)
#' @keywords internal
extract_school_id <- function(agency_code) {
  # Extract characters 4-6 as school ID
  ifelse(
    nchar(agency_code) >= 6,
    substr(agency_code, 4, 6),
    NA_character_
  )
}


#' Create empty processed assessment data frame
#'
#' @return Empty data frame with processed assessment columns
#' @keywords internal
create_empty_assessment_processed <- function() {
  data.frame(
    end_year = integer(0),
    agency_code = character(0),
    district_id = character(0),
    school_id = character(0),
    level = character(0),
    standard = character(0),
    standard_label = character(0),
    subject = character(0),
    subject_label = character(0),
    grade = character(0),
    grade_label = character(0),
    subgroup = character(0),
    subgroup_label = character(0),
    n_tested = integer(0),
    pct_proficient = double(0),
    n_proficient = integer(0),
    masking = character(0),
    is_suppressed = logical(0),
    suppression_reason = character(0),
    stringsAsFactors = FALSE
  )
}
