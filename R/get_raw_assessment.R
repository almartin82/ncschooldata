# ==============================================================================
# Raw Assessment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw assessment data from the
# North Carolina Department of Public Instruction (NC DPI).
#
# Data source: NC School Report Cards Data Sets
# URL: https://www.dpi.nc.gov/data-reports/school-report-cards/school-report-card-resources-researchers
#
# The rcd_acc_pc.txt file contains Performance Counts data with:
# - Years: 2014-2024 (no 2020 due to COVID-19)
# - Subjects: EOG (End-of-Grade), EOC (End-of-Course), Reading, Math, Science, etc.
# - Grades: 03-08 for EOG, EOC for end-of-course tests
# - Subgroups: ALL, race/ethnicity, EDS, ELS, SWD, gender, etc.
#
# ==============================================================================


#' Get available assessment years
#'
#' Returns the range of years for which assessment data is available
#' from the NC DPI School Report Cards data.
#'
#' @return A list with:
#'   \item{years}{Vector of available years}
#'   \item{note}{Description of data availability}
#' @export
#' @examples
#' years <- get_available_assessment_years()
#' print(years$years)
get_available_assessment_years <- function() {
  list(
    years = c(2014:2019, 2021:2024),
    note = paste(
      "NC assessment data available from NC DPI School Report Cards.",
      "Years: 2014-2019, 2021-2024 (no 2020 due to COVID-19 testing waiver).",
      "Note: 2025 data may be available in future releases."
    )
  )
}


#' Download raw assessment data from NC DPI
#'
#' Downloads assessment data from the NC DPI School Report Cards data file.
#' The data includes EOG (End-of-Grade) and EOC (End-of-Course) test results
#' at the school and district (LEA) level.
#'
#' @param end_year School year end (e.g., 2024 for 2023-24 school year).
#'   Valid years: 2014-2019, 2021-2024 (no 2020 due to COVID waiver).
#' @return Data frame with assessment data
#' @keywords internal
get_raw_assessment <- function(end_year) {

  # Validate year
  available <- get_available_assessment_years()

  if (end_year == 2020) {
    stop("2020 assessment data is not available due to COVID-19 testing waiver. ",
         "No statewide testing was administered in Spring 2020.")
  }

  if (!end_year %in% available$years) {
    stop(paste0(
      "end_year must be one of: ", paste(available$years, collapse = ", "), ". ",
      "Got: ", end_year
    ))
  }

  message(paste("Downloading NC assessment data for", end_year, "..."))

  # Download full assessment data and filter to requested year
  full_data <- download_assessment_data()

  if (is.null(full_data) || nrow(full_data) == 0) {
    warning("No assessment data available from NC DPI")
    return(create_empty_assessment_raw())
  }

  # Filter to requested year
  df <- full_data[full_data$year == end_year, ]

  if (nrow(df) == 0) {
    warning(paste("No assessment data found for year", end_year))
    return(create_empty_assessment_raw())
  }

  # Add end_year column for consistency with other packages
  df$end_year <- end_year

  df
}


#' Download assessment data from NC DPI
#'
#' Downloads the School Report Cards data set which contains assessment
#' performance counts. The file is a large text file (~900MB uncompressed)
#' inside a zip archive.
#'
#' @return Data frame with all years of assessment data
#' @keywords internal
download_assessment_data <- function() {

  message("  Downloading NC DPI School Report Cards data set...")

  # URL for the SRC data set
  # This contains rcd_acc_pc.txt with performance counts
  url <- "https://www.dpi.nc.gov/src-data-set-2023-2024/open"

  # Create temp directory for extraction
  temp_dir <- tempfile(pattern = "nc_src_")
  dir.create(temp_dir, showWarnings = FALSE)
  zip_file <- file.path(temp_dir, "src_data.zip")

  # Download zip file
  result <- tryCatch({
    response <- httr::GET(
      url,
      httr::write_disk(zip_file, overwrite = TRUE),
      httr::timeout(600),  # 10 minute timeout for large file
      httr::user_agent("ncschooldata R package"),
      httr::progress()
    )

    if (httr::http_error(response)) {
      stop(paste("HTTP error:", httr::status_code(response)))
    }

    # Check file was downloaded
    if (!file.exists(zip_file) || file.info(zip_file)$size < 10000) {
      stop("Downloaded file is too small or missing")
    }

    message("  Extracting performance counts data...")

    # Extract just the performance counts file
    utils::unzip(zip_file, files = "rcd_acc_pc.txt", exdir = temp_dir)

    pc_file <- file.path(temp_dir, "rcd_acc_pc.txt")

    if (!file.exists(pc_file)) {
      stop("rcd_acc_pc.txt not found in archive")
    }

    message("  Reading performance counts file...")

    # Read the tab-delimited file
    df <- readr::read_tsv(
      pc_file,
      col_types = readr::cols(
        year = readr::col_integer(),
        agency_code = readr::col_character(),
        standard = readr::col_character(),
        subject = readr::col_character(),
        grade = readr::col_character(),
        subgroup = readr::col_character(),
        den = readr::col_integer(),
        pct = readr::col_double(),
        masking = readr::col_character()
      ),
      show_col_types = FALSE
    )

    # Clean up
    unlink(temp_dir, recursive = TRUE)

    df

  }, error = function(e) {
    # Clean up on error
    unlink(temp_dir, recursive = TRUE)
    stop(paste("Failed to download assessment data from NC DPI.",
               "\nError:", e$message))
  })

  result
}


#' Get assessment data URL
#'
#' Returns the URL for downloading assessment data from NC DPI.
#'
#' @return URL string
#' @keywords internal
get_assessment_data_url <- function() {
  "https://www.dpi.nc.gov/src-data-set-2023-2024/open"
}


#' Create empty assessment raw data frame
#'
#' Returns an empty data frame with expected column structure for assessment data.
#'
#' @return Empty data frame with assessment columns
#' @keywords internal
create_empty_assessment_raw <- function() {
  data.frame(
    year = integer(0),
    agency_code = character(0),
    standard = character(0),
    subject = character(0),
    grade = character(0),
    subgroup = character(0),
    den = integer(0),
    pct = double(0),
    masking = character(0),
    end_year = integer(0),
    stringsAsFactors = FALSE
  )
}
