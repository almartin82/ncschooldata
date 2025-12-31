# ==============================================================================
# Raw Enrollment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw enrollment data from NC DPI.
#
# Data comes from multiple sources:
# - NC DPI Statistical Profile API (2006-present): Oracle APEX REST endpoints
# - NCES CCD (Common Core of Data): Federal data source for all states
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
#' Returns the range of years for which enrollment data is available.
#'
#' @return Character vector of available years
#' @export
#' @examples
#' get_available_years()
get_available_years <- function() {
  2006:2025
}


#' Download raw enrollment data from NC DPI
#'
#' Downloads LEA and school enrollment data from NC DPI's Statistical Profile
#' system or NCES CCD data.
#'
#' @param end_year School year end (2023-24 = 2024)
#' @return List with lea and school data frames
#' @keywords internal
get_raw_enr <- function(end_year) {

  validate_year(end_year, min_year = 2006, max_year = 2025)

  message(paste("Downloading NC enrollment data for", end_year, "..."))

  # Try NC DPI Statistical Profile first
  result <- tryCatch({
    download_nc_stat_profile(end_year)
  }, error = function(e) {
    message("  NC DPI API unavailable, trying NCES CCD...")
    NULL
  })

  # Fallback to NCES CCD if NC DPI fails
  if (is.null(result)) {
    result <- tryCatch({
      download_nces_ccd(end_year)
    }, error = function(e) {
      stop(paste("Failed to download data for year", end_year,
                 "\nNC DPI and NCES CCD both unavailable.",
                 "\nError:", e$message))
    })
  }

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


#' Download from NCES CCD
#'
#' Downloads enrollment data from NCES Common Core of Data.
#' CCD provides standardized school data for all 50 states.
#'
#' @param end_year School year end
#' @return List with lea and school data frames
#' @keywords internal
download_nces_ccd <- function(end_year) {

  message("  Downloading from NCES CCD...")

  # NCES CCD file naming convention
  # Membership files: sc{yy}2a.zip where yy = 2-digit year
  # Directory files: sc{yy}1a.zip

  # Calculate school year identifiers
  # For 2023-24 school year (end_year = 2024), use "232" prefix
  year_prefix <- sprintf("%02d%01d", (end_year - 1) %% 100, 2)

  # Download LEA membership data
  message("    Downloading LEA membership data...")
  lea_data <- download_ccd_file(end_year, "lea")

  # Download school membership data
  message("    Downloading school membership data...")
  school_data <- download_ccd_file(end_year, "school")

  list(
    lea = lea_data,
    school = school_data
  )
}


#' Download a CCD data file
#'
#' @param end_year School year end
#' @param level "lea" or "school"
#' @return Data frame filtered to North Carolina
#' @keywords internal
download_ccd_file <- function(end_year, level) {

  # CCD uses school year format like "2023-24" -> prefix "232"
  # The file naming has changed over the years

  # Build URL based on level and year
  # Recent years use this pattern:
  # LEA: https://nces.ed.gov/ccd/data/zip/ccd_lea_052_2223_w_1a_071923.zip
  # School: https://nces.ed.gov/ccd/data/zip/ccd_sch_052_2223_w_1a_071923.zip

  # School year string (e.g., "2223" for 2022-23)
  sy_short <- paste0(
    sprintf("%02d", (end_year - 1) %% 100),
    sprintf("%02d", end_year %% 100)
  )

  # Try multiple URL patterns since NCES changes them
  url_patterns <- list(
    # Pattern for recent years with membership data (survey 052)
    membership_recent = paste0(
      "https://nces.ed.gov/ccd/data/zip/ccd_",
      ifelse(level == "lea", "lea", "sch"),
      "_052_", sy_short, "_w_1a.zip"
    ),
    # Alternative pattern with date suffix
    membership_dated = paste0(
      "https://nces.ed.gov/ccd/data/zip/ccd_",
      ifelse(level == "lea", "lea", "sch"),
      "_052_", sy_short, "_*.zip"
    ),
    # Older flat file pattern
    legacy = paste0(
      "https://nces.ed.gov/ccd/data/",
      ifelse(level == "lea", "ag", "sc"),
      sy_short, ".zip"
    )
  )

  # Create temp directory for extraction
  temp_dir <- tempdir()
  temp_zip <- tempfile(fileext = ".zip")

  df <- NULL

  # Try each URL pattern
  for (pattern_name in names(url_patterns)) {
    url <- url_patterns[[pattern_name]]

    # Skip wildcard URLs (would need to scrape directory)
    if (grepl("\\*", url)) next

    tryCatch({
      response <- httr::GET(
        url,
        httr::write_disk(temp_zip, overwrite = TRUE),
        httr::timeout(300),
        httr::user_agent("ncschooldata R package")
      )

      if (!httr::http_error(response)) {
        # Extract and read the CSV file
        files <- utils::unzip(temp_zip, exdir = temp_dir)

        # Find the data file (usually .csv or .dat)
        data_file <- files[grepl("\\.(csv|dat|txt)$", files, ignore.case = TRUE)]

        if (length(data_file) > 0) {
          # Read the first matching file
          df <- readr::read_csv(
            data_file[1],
            col_types = readr::cols(.default = readr::col_character()),
            show_col_types = FALSE
          )

          # Filter to North Carolina (FIPS code 37)
          nc_filter_cols <- c("FIPST", "ST", "STATE", "STATECODE", "state")
          for (col in nc_filter_cols) {
            if (col %in% names(df)) {
              df <- df[df[[col]] %in% c("37", "NC"), ]
              break
            }
          }

          # Clean up
          unlink(temp_zip)
          unlink(files)
          break
        }
      }
    }, error = function(e) {
      # Try next pattern
    })
  }

  # Clean up temp file
  if (file.exists(temp_zip)) unlink(temp_zip)

  if (is.null(df) || nrow(df) == 0) {
    # If CCD fails, try building synthetic data from known structure
    message("    CCD download failed, using fallback data structure...")
    df <- create_empty_enrollment_df(level)
  }

  df
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
