# ==============================================================================
# Raw Directory Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw directory data from the
# North Carolina Department of Public Instruction (NCDPI).
#
# Data source:
# - Private Schools: Excel file updated periodically
# - URL: https://www.dpi.nc.gov/documents/program-monitoring/directory-priv-schools-jan172025-2025-26-rev/download
#
# Note: This implementation currently covers private schools only.
# Public schools require separate implementation.
#
# ==============================================================================

#' Get the download URL for directory type
#'
#' Constructs the download URL for North Carolina school directory.
#'
#' @param directory_type Type of directory ("private_schools", "all")
#' @return Character string with download URL or named list of URLs
#' @keywords internal
get_directory_url <- function(directory_type = "all") {

  urls <- list(
    private_schools = "https://www.dpi.nc.gov/documents/program-monitoring/directory-priv-schools-jan172025-2025-26-rev/download"
  )

  if (directory_type == "all") {
    return(urls)
  }

  urls[[directory_type]]
}


#' Download raw directory data from NCDPI
#'
#' Downloads the North Carolina school directory Excel file(s).
#'
#' @param directory_type Type of directory ("private_schools", "all")
#' @return List with raw data frames for each directory type requested
#' @keywords internal
get_raw_directory <- function(directory_type = "all") {

  message(paste("Downloading North Carolina directory data:", directory_type, "..."))

  urls <- get_directory_url(directory_type)

  # Handle single type vs all types
  if (directory_type != "all") {
    urls <- setNames(list(urls), directory_type)
  }

  # Download each file
  results <- lapply(seq_along(urls), function(i) {
    type <- names(urls)[[i]]
    url <- urls[[i]]

    message(paste("  Downloading", type, "..."))

    # Create temp file
    temp_file <- tempfile(fileext = ".xlsx")

    # Download with proper headers
    tryCatch({
      response <- httr::GET(
        url,
        httr::write_disk(temp_file, overwrite = TRUE),
        httr::user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"),
        httr::timeout(120)
      )

      if (httr::http_error(response)) {
        stop(paste("HTTP error:", httr::status_code(response)))
      }

      # Verify file is a valid Excel file
      file_info <- file.info(temp_file)
      if (file_info$size < 1000) {
        content <- readLines(temp_file, n = 5, warn = FALSE)
        if (any(grepl("Access Denied|error|not found", content, ignore.case = TRUE))) {
          stop("Server returned an error page instead of data file")
        }
      }

      # Read Excel file
      # NC file has multiple header rows - skip first 6 rows
      # Rows 1-5: Title and instructions
      # Row 6: Column headers
      # Row 7+: Data
      df <- readxl::read_xlsx(temp_file, skip = 6)

      # Add metadata
      df$directory_type <- type
      df$data_source <- "North Carolina Department of Public Instruction"

      # Clean up temp file
      unlink(temp_file)

      message(paste("  Downloaded", nrow(df), "rows for", type))

      df

    }, error = function(e) {
      unlink(temp_file)
      stop(paste("Failed to download directory data for", type,
                 "\nError:", e$message,
                 "\nURL:", url))
    })
  })

  names(results) <- names(urls)
  results
}
