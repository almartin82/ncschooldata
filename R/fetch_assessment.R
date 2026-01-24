# ==============================================================================
# Assessment Data Fetching Functions
# ==============================================================================
#
# This file contains the main user-facing functions for fetching North Carolina
# assessment data.
#
# NC Assessment Systems:
# - EOG (End-of-Grade): Grades 3-8, subjects: Reading, Math, Science
# - EOC (End-of-Course): High school courses like NC Math 1, NC Math 3,
#   English II, Biology
#
# Available years: 2014-2019, 2021-2024 (no 2020 due to COVID-19)
#
# ==============================================================================


#' Fetch North Carolina assessment data
#'
#' Downloads and returns assessment data from the North Carolina Department of
#' Public Instruction. Includes EOG (End-of-Grade) and EOC (End-of-Course) test
#' results.
#'
#' Assessment data includes proficiency rates (College & Career Ready standard)
#' for all students and subgroups at the state, district, and school levels.
#'
#' @param end_year School year end (2023-24 = 2024). Valid range: 2014-2024 (no 2020).
#' @param tidy If TRUE (default), returns data with aggregation flags and clean labels.
#'   If FALSE, returns minimally processed data.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#' @return Data frame with assessment data
#' @export
#' @examples
#' \dontrun{
#' # Get 2024 assessment data
#' assess_2024 <- fetch_assessment(2024)
#'
#' # Get 2023 assessment data
#' assess_2023 <- fetch_assessment(2023)
#'
#' # Force fresh download
#' assess_fresh <- fetch_assessment(2024, use_cache = FALSE)
#'
#' # Filter to state-level math results
#' state_math <- assess_2024 |>
#'   dplyr::filter(is_district, subject == "MA", subgroup == "ALL")
#' }
fetch_assessment <- function(end_year, tidy = TRUE, use_cache = TRUE) {

  # Get available years
  available <- get_available_assessment_years()

  # Special handling for 2020 (COVID waiver year)
  if (end_year == 2020) {
    stop("2020 assessment data is not available due to COVID-19 testing waiver. ",
         "No statewide testing was administered in Spring 2020.")
  }

  # Validate year
  if (!end_year %in% available$years) {
    stop(paste0(
      "end_year must be one of: ", paste(available$years, collapse = ", "), ". ",
      "Got: ", end_year, "\n",
      "Note: 2020 had no testing due to COVID-19 pandemic."
    ))
  }

  # Determine cache type
  cache_type <- if (tidy) "assessment_tidy" else "assessment_raw"

  # Check cache first
  if (use_cache && assessment_cache_exists(end_year, cache_type)) {
    message(paste("Using cached assessment data for", end_year))
    return(read_assessment_cache(end_year, cache_type))
  }

  # Get raw data
  raw <- get_raw_assessment(end_year)

  # Check if data was returned
  if (nrow(raw) == 0) {
    warning(paste("No assessment data available for year", end_year))
    return(data.frame())
  }

  # Process the data
  processed <- process_assessment(raw, end_year)

  # Tidy if requested
  if (tidy) {
    processed <- tidy_assessment(processed)
  }

  # Cache the result
  if (use_cache) {
    write_assessment_cache(processed, end_year, cache_type)
  }

  processed
}


#' Fetch assessment data for multiple years
#'
#' Downloads and combines assessment data for multiple school years.
#' Note: 2020 is automatically excluded (COVID-19 testing waiver).
#'
#' @param end_years Vector of school year ends (e.g., c(2022, 2023, 2024))
#' @param tidy If TRUE (default), returns data with aggregation flags.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#' @return Combined data frame with assessment data for all requested years
#' @export
#' @examples
#' \dontrun{
#' # Get 3 years of data
#' assess_multi <- fetch_assessment_multi(2022:2024)
#'
#' # Get all available years
#' years <- get_available_assessment_years()$years
#' all_data <- fetch_assessment_multi(years)
#' }
fetch_assessment_multi <- function(end_years, tidy = TRUE, use_cache = TRUE) {

  # Get available years
  available <- get_available_assessment_years()

  # Remove 2020 if present (COVID waiver year)
  if (2020 %in% end_years) {
    warning("2020 excluded: No assessment data due to COVID-19 testing waiver.")
    end_years <- end_years[end_years != 2020]
  }

  # Validate years
  invalid_years <- end_years[!end_years %in% available$years]
  if (length(invalid_years) > 0) {
    stop(paste0(
      "Invalid years: ", paste(invalid_years, collapse = ", "), "\n",
      "Valid years are: ", paste(available$years, collapse = ", ")
    ))
  }

  if (length(end_years) == 0) {
    stop("No valid years to fetch")
  }

  # Fetch each year
  results <- purrr::map(
    end_years,
    function(yr) {
      message(paste("Fetching", yr, "..."))
      tryCatch({
        fetch_assessment(yr, tidy = tidy, use_cache = use_cache)
      }, error = function(e) {
        warning(paste("Failed to fetch year", yr, ":", e$message))
        data.frame()
      })
    }
  )

  # Combine, filtering out empty data frames
  results <- results[!sapply(results, function(x) nrow(x) == 0)]
  dplyr::bind_rows(results)
}


#' Get assessment data for a specific district
#'
#' Convenience function to fetch assessment data for a single district.
#'
#' @param end_year School year end
#' @param district_id 3-digit district ID (e.g., "920" for Wake County)
#' @param tidy If TRUE (default), returns tidy format
#' @param use_cache If TRUE (default), uses cached data
#' @return Data frame filtered to specified district
#' @export
#' @examples
#' \dontrun{
#' # Get Wake County (district 920) assessment data
#' wake_assess <- fetch_district_assessment(2024, "920")
#'
#' # Get Charlotte-Mecklenburg (district 600) data
#' cms_assess <- fetch_district_assessment(2024, "600")
#' }
fetch_district_assessment <- function(end_year, district_id, tidy = TRUE, use_cache = TRUE) {

  # Normalize district_id to 3 digits
  district_id <- sprintf("%03d", as.integer(district_id))

  # Fetch all data
  df <- fetch_assessment(end_year, tidy = tidy, use_cache = use_cache)

  # Filter to requested district (includes district and school level)
  df |>
    dplyr::filter(district_id == !!district_id)
}


#' Get assessment data for a specific school
#'
#' Convenience function to fetch assessment data for a single school.
#'
#' @param end_year School year end
#' @param agency_code Full 6-character agency code (e.g., "920305")
#' @param tidy If TRUE (default), returns tidy format
#' @param use_cache If TRUE (default), uses cached data
#' @return Data frame filtered to specified school
#' @export
#' @examples
#' \dontrun{
#' # Get a specific school's assessment data
#' school_assess <- fetch_school_assessment(2024, "920305")
#' }
fetch_school_assessment <- function(end_year, agency_code, tidy = TRUE, use_cache = TRUE) {

  # Fetch all data
  df <- fetch_assessment(end_year, tidy = tidy, use_cache = use_cache)

  # Filter to requested school
  df |>
    dplyr::filter(agency_code == !!agency_code)
}


# ==============================================================================
# Assessment Cache Functions
# ==============================================================================


#' Get assessment cache path
#'
#' @param end_year School year end
#' @param type Cache type ("assessment_tidy" or "assessment_raw")
#' @return Path to cache file
#' @keywords internal
get_assessment_cache_path <- function(end_year, type) {
  cache_dir <- get_cache_dir()
  file.path(cache_dir, paste0(type, "_", end_year, ".rds"))
}


#' Check if assessment cache exists
#'
#' @param end_year School year end
#' @param type Cache type
#' @param max_age Maximum age in days (default 30)
#' @return TRUE if valid cache exists
#' @keywords internal
assessment_cache_exists <- function(end_year, type, max_age = 30) {
  cache_path <- get_assessment_cache_path(end_year, type)

  if (!file.exists(cache_path)) {
    return(FALSE)
  }

  # Check age
  file_info <- file.info(cache_path)
  age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))

  age_days <= max_age
}


#' Read assessment data from cache
#'
#' @param end_year School year end
#' @param type Cache type
#' @return Cached data frame
#' @keywords internal
read_assessment_cache <- function(end_year, type) {
  cache_path <- get_assessment_cache_path(end_year, type)
  readRDS(cache_path)
}


#' Write assessment data to cache
#'
#' @param df Data frame to cache
#' @param end_year School year end
#' @param type Cache type
#' @return Invisibly returns the cache path
#' @keywords internal
write_assessment_cache <- function(df, end_year, type) {
  cache_path <- get_assessment_cache_path(end_year, type)
  saveRDS(df, cache_path)
  invisible(cache_path)
}


#' Clear assessment cache
#'
#' Removes cached assessment data files.
#'
#' @param end_year Optional school year to clear. If NULL, clears all years.
#' @return Invisibly returns the number of files removed
#' @export
#' @examples
#' \dontrun{
#' # Clear all cached assessment data
#' clear_assessment_cache()
#'
#' # Clear only 2024 data
#' clear_assessment_cache(2024)
#' }
clear_assessment_cache <- function(end_year = NULL) {
  cache_dir <- get_cache_dir()

  if (!is.null(end_year)) {
    # Clear specific year
    files <- list.files(cache_dir, pattern = paste0("assessment.*_", end_year, "\\.rds$"),
                        full.names = TRUE)
  } else {
    # Clear all assessment cache
    files <- list.files(cache_dir, pattern = "^assessment_", full.names = TRUE)
  }

  if (length(files) > 0) {
    file.remove(files)
    message(paste("Removed", length(files), "cached assessment file(s)"))
  } else {
    message("No cached assessment files to remove")
  }

  invisible(length(files))
}
