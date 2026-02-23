# ==============================================================================
# Enrollment Data Fetching Functions
# ==============================================================================
#
# This file contains functions for downloading enrollment data from the
# North Carolina Department of Public Instruction (NC DPI).
#
# ==============================================================================

#' Fetch North Carolina enrollment data
#'
#' Downloads and processes enrollment data from the North Carolina Department
#' of Public Instruction Statistical Profile.
#'
#' @param end_year A school year. Year is the end of the academic year - eg 2023-24
#'   school year is year '2024'. Valid values are 2006-2025.
#' @param tidy If TRUE (default), returns data in long (tidy) format with subgroup
#'   column. If FALSE, returns wide format.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#'   Set to FALSE to force re-download from NC DPI.
#' @return Data frame with enrollment data. Wide format includes columns for
#'   district_id, campus_id, names, and enrollment counts by demographic/grade.
#'   Tidy format pivots these counts into subgroup and grade_level columns.
#' @export
#' @examples
#' \dontrun{
#' # Get 2024 enrollment data (2023-24 school year)
#' enr_2024 <- fetch_enr(2024)
#'
#' # Get wide format
#' enr_wide <- fetch_enr(2024, tidy = FALSE)
#'
#' # Force fresh download (ignore cache)
#' enr_fresh <- fetch_enr(2024, use_cache = FALSE)
#'
#' # Filter to Wake County Schools
#' wake <- enr_2024 |>
#'   dplyr::filter(district_id == "920")
#' }
fetch_enr <- function(end_year, tidy = TRUE, use_cache = TRUE) {

  # Validate year
  validate_year(end_year, min_year = 2006, max_year = 2025)

  # Determine cache type based on tidy parameter
  cache_type <- if (tidy) "tidy" else "wide"

  # Check cache first
  if (use_cache && cache_exists(end_year, cache_type)) {
    message(paste("Using cached data for", end_year))
    return(read_cache(end_year, cache_type))
  }

  # Try to get raw data from NC DPI
  processed <- tryCatch({
    raw <- get_raw_enr(end_year)
    proc <- process_enr(raw, end_year)
    if (tidy) {
      proc <- tidy_enr(proc) |> id_enr_aggs()
    }
    proc
  }, error = function(e) {
    message(paste("NC DPI download failed:", e$message))
    NULL
  })

  # If download produced empty/minimal data, try bundled fallback
  needs_fallback <- is.null(processed) || nrow(processed) < 100
  if (needs_fallback) {
    bundled <- load_bundled_enr(end_year, cache_type)
    if (!is.null(bundled)) {
      message(paste("Using bundled data for", end_year))
      processed <- bundled
    } else if (is.null(processed)) {
      stop(paste("No data available for year", end_year,
                 "- NC DPI unavailable and no bundled data."))
    }
  }

  # Cache the result (only if we got real data)
  if (use_cache && !is.null(processed) && nrow(processed) >= 100) {
    write_cache(processed, end_year, cache_type)
  }

  processed
}


#' Load bundled enrollment data as fallback
#'
#' When NC DPI is unreachable and no local cache exists, falls back to
#' bundled data included in the package. This ensures vignettes and
#' CI can always render. Data sourced from NC DPI School Report Cards.
#'
#' @param end_year School year end
#' @param cache_type "tidy" or "wide"
#' @return Data frame or NULL if no bundled data available for the year
#' @keywords internal
load_bundled_enr <- function(end_year, cache_type) {
  filename <- paste0("enr_", cache_type, "_", end_year, ".rds")
  bundled_path <- system.file("extdata", filename, package = "ncschooldata")

  if (bundled_path == "" || !file.exists(bundled_path)) {
    return(NULL)
  }

  readRDS(bundled_path)
}


#' Fetch enrollment data for multiple years
#'
#' Downloads and combines enrollment data for multiple school years.
#'
#' @param end_years Vector of school year ends (e.g., c(2022, 2023, 2024))
#' @param tidy If TRUE (default), returns data in long (tidy) format.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#' @return Combined data frame with enrollment data for all requested years
#' @export
#' @examples
#' \dontrun{
#' # Get 3 years of data
#' enr_multi <- fetch_enr_multi(2022:2024)
#'
#' # Track enrollment trends
#' enr_multi |>
#'   dplyr::filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
#'   dplyr::select(end_year, n_students)
#' }
fetch_enr_multi <- function(end_years, tidy = TRUE, use_cache = TRUE) {

  # Validate all years
  for (yr in end_years) {
    validate_year(yr, min_year = 2006, max_year = 2025)
  }

  # Fetch each year
  results <- purrr::map(
    end_years,
    function(yr) {
      message(paste("Fetching", yr, "..."))
      fetch_enr(yr, tidy = tidy, use_cache = use_cache)
    }
  )

  # Combine
  dplyr::bind_rows(results)
}
