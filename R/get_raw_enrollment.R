# ==============================================================================
# Raw Enrollment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw enrollment data from NC DPI.
#
# Data comes from NC DPI Statistical Profile API (2006-present): Oracle APEX REST endpoints
#
# North Carolina uses:
# - LEA Codes: 3-digit codes (e.g., 920 = Wake County)
# - School Codes: 6-digit codes (LEA code + 3-digit school number)
#
# Format Eras:
# - Era 1 (2006-2010): Pre-standardized race categories (Asian/Pacific Islander combined)
# - Era 2 (2011-present): Standardized 7 race/ethnicity categories
#
# ==============================================================================

#' Get available years
#'
#' Returns the range of years for which enrollment data is available
#' from the North Carolina Department of Public Instruction (NC DPI).
#'
#' @return A list with:
#'   \item{min_year}{First available year (2006)}
#'   \item{max_year}{Last available year (2025)}
#'   \item{description}{Description of data availability}
#' @export
#' @examples
#' years <- get_available_years()
#' print(years$min_year)
#' print(years$max_year)
get_available_years <- function() {
  list(
    min_year = 2006,
    max_year = 2025,
    description = paste(
      "North Carolina enrollment data from NC DPI Statistical Profile.",
      "Available years: 2006-2025."
    )
  )
}


#' Download raw enrollment data from NC DPI
#'
#' Downloads LEA and school enrollment data from NC DPI's Statistical Profile
#' system.
#'
#' @param end_year School year end (2023-24 = 2024)
#' @return List with lea and school data frames
#' @keywords internal
get_raw_enr <- function(end_year) {

  validate_year(end_year, min_year = 2006, max_year = 2025)

  message(paste("Downloading NC enrollment data for", end_year, "..."))

  # Try NC DPI Statistical Profile
  result <- tryCatch({
    download_nc_stat_profile(end_year)
  }, error = function(e) {
    stop(paste("Failed to download data for year", end_year,
               "\nNC DPI unavailable.",
               "\nError:", e$message))
  })

  # Add end_year column
  result$lea$end_year <- end_year
  result$school$end_year <- end_year

  result
}


#' Download from NC DPI Statistical Profile
#'
#' Downloads enrollment data from NC DPI's Oracle APEX REST API.
#' Uses the Statistical Profile interactive reports which support CSV export.
#'
#' @param end_year School year end
#' @return List with lea and school data frames
#' @keywords internal
download_nc_stat_profile <- function(end_year) {

  message("  Downloading from NC DPI Statistical Profile...")

  # NC DPI Statistical Profile uses an Oracle APEX application

  # The base URL for the application
  base_url <- "https://apps.schools.nc.gov/ords/f"

  # Build school year string (e.g., "2023-24" for end_year 2024)
  school_year <- paste0(end_year - 1, "-", substr(end_year, 3, 4))

  # Download LEA-level data (Table A1 - Final Pupils by Grade)
  message("    Downloading LEA enrollment...")
  lea_data <- download_stat_profile_table(
    end_year = end_year,
    table_type = "lea_enrollment"
  )

  # Download race/ethnicity data (Table 10 - Pupils by Race & Sex)
  message("    Downloading race/ethnicity data...")
  race_data <- download_stat_profile_table(
    end_year = end_year,
    table_type = "lea_race"
  )

  # Download school-level data
  message("    Downloading school enrollment...")
  school_data <- download_stat_profile_table(
    end_year = end_year,
    table_type = "school_enrollment"
  )

  # Merge LEA data with race data
  if (!is.null(race_data) && nrow(race_data) > 0 && !is.null(lea_data) && nrow(lea_data) > 0) {
    # Find common ID column
    id_col <- intersect(c("LEA_CODE", "LEA", "LEACODE", "lea_code"), names(lea_data))
    if (length(id_col) > 0) {
      id_col <- id_col[1]
      race_id_col <- intersect(c("LEA_CODE", "LEA", "LEACODE", "lea_code"), names(race_data))
      if (length(race_id_col) > 0) {
        lea_data <- dplyr::left_join(lea_data, race_data, by = stats::setNames(race_id_col[1], id_col))
      }
    }
  }

  list(
    lea = lea_data,
    school = school_data
  )
}


#' Download a specific table from NC DPI Statistical Profile
#'
#' @param end_year School year end
#' @param table_type Type of table: "lea_enrollment", "lea_race", "school_enrollment"
#' @return Data frame
#' @keywords internal
download_stat_profile_table <- function(end_year, table_type) {

  # NC Statistical Profile APEX application parameters
  # App ID: 145
  # Page IDs vary by table type

  # Table mappings based on NC DPI Statistical Profile structure
  table_params <- switch(table_type,
    "lea_enrollment" = list(
      page = "73",  # LEA Final Pupils by Grade
      region = "TABLE_A1"
    ),
    "lea_race" = list(
      page = "76",  # LEA Membership by Race and Sex
      region = "TABLE_10"
    ),
    "school_enrollment" = list(
      page = "79",  # School enrollment by grade
      region = "TABLE_B2"
    ),
    stop("Unknown table_type: ", table_type)
  )

  # Build school year filter
  school_year <- paste0(end_year - 1, "-", substr(end_year, 3, 4))

  # Try to get data via the APEX REST endpoint
  # NC DPI uses Oracle APEX which has a specific URL pattern for downloads

  # Build the download URL - APEX apps typically use f?p=APP:PAGE:SESSION::NO:::
  # and allow CSV export via ir_report_download=Y

  url <- paste0(
    "https://apps.schools.nc.gov/ords/f?p=145:",
    table_params$page,
    ":::NO:::"
  )

  # Create temp file
  temp_file <- tempfile(fileext = ".csv")

  # Try to download - this is a best-effort approach since APEX apps

  # don't always expose data via simple URLs
  tryCatch({
    response <- httr::GET(
      url,
      httr::timeout(120),
      httr::user_agent("ncschooldata R package")
    )

    # Check if we got HTML (login page) instead of data
    content_type <- httr::headers(response)$`content-type`

    if (!is.null(content_type) && grepl("text/html", content_type)) {
      # APEX returned HTML - need to use alternative approach
      stop("APEX returned HTML instead of data - API requires session")
    }

    if (httr::http_error(response)) {
      stop(paste("HTTP error:", httr::status_code(response)))
    }

    # Write content to temp file
    writeBin(httr::content(response, "raw"), temp_file)

    # Read the CSV
    df <- readr::read_csv(
      temp_file,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE
    )

    unlink(temp_file)
    return(df)

  }, error = function(e) {
    unlink(temp_file)
    # Fall through to alternative data source
    stop(e$message)
  })
}


#' Create empty enrollment data frame with expected structure
#'
#' Used as fallback when downloads fail.
#'
#' @param level "lea" or "school"
#' @return Empty data frame with expected columns
#' @keywords internal
create_empty_enrollment_df <- function(level) {

  if (level == "lea") {
    data.frame(
      LEAID = character(),
      LEA_NAME = character(),
      TOTAL = numeric(),
      AM = numeric(),
      AS = numeric(),
      HI = numeric(),
      BL = numeric(),
      WH = numeric(),
      HP = numeric(),
      TR = numeric(),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      NCESSCH = character(),
      SCHNAME = character(),
      LEAID = character(),
      LEA_NAME = character(),
      TOTAL = numeric(),
      AM = numeric(),
      AS = numeric(),
      HI = numeric(),
      BL = numeric(),
      WH = numeric(),
      HP = numeric(),
      TR = numeric(),
      PK = numeric(),
      KG = numeric(),
      G01 = numeric(),
      G02 = numeric(),
      G03 = numeric(),
      G04 = numeric(),
      G05 = numeric(),
      G06 = numeric(),
      G07 = numeric(),
      G08 = numeric(),
      G09 = numeric(),
      G10 = numeric(),
      G11 = numeric(),
      G12 = numeric(),
      stringsAsFactors = FALSE
    )
  }
}
