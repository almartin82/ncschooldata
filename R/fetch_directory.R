# ==============================================================================
# Directory Data Fetching Functions
# ==============================================================================
#
# This file contains user-facing functions for fetching school directory data.
#
# ==============================================================================

#' Fetch North Carolina school directory
#'
#' Downloads and processes the North Carolina school directory.
#'
#' @param directory_type Type of directory to fetch ("private_schools" or "all")
#' @param use_cache If TRUE, use cached data if available (default: TRUE)
#' @return Data frame with school directory information
#' @export
#' @examples
#' \dontrun{
#' # Get all private schools
#' directory <- fetch_directory()
#'
#' # Get only private schools
#' private <- fetch_directory("private_schools")
#'
#' # Filter by county
#' wake_schools <- directory |>
#'   dplyr::filter(county == "Wake")
#' }
fetch_directory <- function(directory_type = "all", use_cache = TRUE) {

  # Validate directory_type
  valid_types <- c("private_schools", "all")
  if (!directory_type %in% valid_types) {
    stop(paste("Invalid directory_type:", directory_type,
               "\nValid types:", paste(valid_types, collapse = ", ")))
  }

  # Check cache
  cache_dir <- rappdirs::user_cache_dir(appname = "ncschooldata")
  cache_file <- file.path(cache_dir, "directory", paste0(directory_type, ".rds"))

  if (use_cache && file.exists(cache_file)) {
    message(paste("Using cached directory data:", directory_type))
    return(readRDS(cache_file))
  }

  # Download raw data
  raw_data <- get_raw_directory(directory_type)

  # Process data
  processed_data <- process_directory(raw_data)

  # Save to cache
  if (use_cache) {
    dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
    saveRDS(processed_data, cache_file)
    message(paste("Cached directory data:", cache_file))
  }

  processed_data
}


#' Fetch multiple directory types
#'
#' Convenience function for fetching multiple directory types at once.
#'
#' @param directory_types Character vector of directory types to fetch
#' @param use_cache If TRUE, use cached data if available (default: TRUE)
#' @return Data frame with combined directory information
#' @export
#' @examples
#' \dontrun{
#' # Get all available directory types
#' all_directories <- fetch_directory_multi()
#'
#' # Get specific types
#' schools <- fetch_directory_multi(c("private_schools"))
#' }
fetch_directory_multi <- function(directory_types = c("private_schools"), use_cache = TRUE) {

  # Validate types
  valid_types <- c("private_schools")
  invalid_types <- setdiff(directory_types, valid_types)

  if (length(invalid_types) > 0) {
    stop(paste("Invalid directory types:", paste(invalid_types, collapse = ", "),
               "\nValid types:", paste(valid_types, collapse = ", ")))
  }

  # Fetch each type
  results <- lapply(directory_types, function(type) {
    fetch_directory(type, use_cache = use_cache)
  })

  # Combine results
  dplyr::bind_rows(results)
}
