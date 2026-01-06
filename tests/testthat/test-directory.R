# ==============================================================================
# Directory Data Tests
# ==============================================================================

context("Directory data fetching")

# Helper function to check network connectivity
skip_if_offline <- function() {
  tryCatch({
    response <- httr::HEAD("https://www.google.com", httr::timeout(5))
    if (httr::http_error(response)) skip("No network connectivity")
  }, error = function(e) skip("No network connectivity"))
}

# Test that URL returns HTTP 200
test_that("Directory URL returns HTTP 200", {
  skip_if_offline()

  response <- httr::HEAD(
    "https://www.dpi.nc.gov/documents/program-monitoring/directory-priv-schools-jan172025-2025-26-rev/download",
    httr::timeout(30)
  )

  expect_equal(httr::status_code(response), 200)
})


# Test that file downloads correctly
test_that("Can download directory Excel file", {
  skip_if_offline()

  url <- "https://www.dpi.nc.gov/documents/program-monitoring/directory-priv-schools-jan172025-2025-26-rev/download"

  temp <- tempfile(fileext = ".xlsx")

  response <- httr::GET(
    url,
    httr::write_disk(temp, overwrite = TRUE),
    httr::user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"),
    httr::timeout(120)
  )

  expect_equal(httr::status_code(response), 200)
  expect_gt(file.info(temp)$size, 1000)

  # Verify it's a valid Excel file
  sheets <- readxl::excel_sheets(temp)
  expect_true(length(sheets) > 0)

  unlink(temp)
})


# Test fetch_directory function
test_that("fetch_directory returns valid data structure", {
  skip_if_offline()

  # Get all schools
  dir_all <- fetch_directory(use_cache = FALSE)

  expect_s3_class(dir_all, "data.frame")
  expect_true(nrow(dir_all) > 0)

  # Check for required columns
  required_cols <- c("directory_type", "school_name", "state")
  expect_true(all(required_cols %in% names(dir_all)))

  # Check state is always NC
  expect_true(all(dir_all$state == "NC"))
})


test_that("fetch_directory can get specific directory type", {
  skip_if_offline()

  # Get only private schools
  private <- fetch_directory("private_schools", use_cache = FALSE)

  expect_s3_class(private, "data.frame")
  expect_true(all(private$directory_type == "private_schools"))
  expect_true(nrow(private) > 0)

  # NC has several hundred private schools
  expect_gt(nrow(private), 100)
  expect_lt(nrow(private), 2000)  # Sanity check
})


test_that("fetch_directory_multi combines types", {
  skip_if_offline()

  # Currently only one type available, but test the function works
  schools <- fetch_directory_multi(c("private_schools"), use_cache = FALSE)

  expect_s3_class(schools, "data.frame")
  expect_true(nrow(schools) > 0)
  expect_true("private_schools" %in% unique(schools$directory_type))
})


# Data quality tests
test_that("Directory data has no missing school names", {
  skip_if_offline()

  dir_data <- fetch_directory(use_cache = FALSE)

  expect_false(any(is.na(dir_data$school_name) | dir_data$school_name == ""))
})


test_that("Phone numbers are cleaned properly", {
  skip_if_offline()

  dir_data <- fetch_directory(use_cache = FALSE)

  # Phone column should contain only digits (or NA)
  phones <- dir_data$phone[!is.na(dir_data$phone)]
  if (length(phones) > 0) {
    expect_true(all(grepl("^[0-9]+$", phones)))
  }
})


test_that("Zip codes are cleaned properly", {
  skip_if_offline()

  dir_data <- fetch_directory(use_cache = FALSE)

  # Zip column should contain only digits and hyphens (or NA)
  zips <- dir_data$zip[!is.na(dir_data$zip)]
  if (length(zips) > 0) {
    expect_true(all(grepl("^[0-9-]+$", zips)))
  }
})


# Known value tests (fidelity tests)
test_that("Expected number of private schools", {
  skip_if_offline()

  private <- fetch_directory("private_schools", use_cache = FALSE)

  # NC has several hundred private schools
  expect_gt(nrow(private), 100)
  expect_lt(nrow(private), 2000)  # Sanity check
})


test_that("Data contains counties", {
  skip_if_offline()

  private <- fetch_directory(use_cache = FALSE)

  # Check that county field is populated
  expect_false(all(is.na(private$county) | private$county == ""))

  # Should have at least some counties
  unique_counties <- unique(private$county)
  expect_true(length(unique_counties) > 50, info = "Should have many counties")
})


test_that("Required columns are present", {
  skip_if_offline()

  dir_data <- fetch_directory(use_cache = FALSE)

  expected_cols <- c("directory_type", "school_name", "city", "state", "zip")

  for (col in expected_cols) {
    expect_true(col %in% names(dir_data), info = paste("Missing column:", col))
  }
})


test_that("School names are unique", {
  skip_if_offline()

  dir_data <- fetch_directory(use_cache = FALSE)

  # Check that school names are mostly unique (some may legitimately have duplicates)
  school_duplicates <- sum(duplicated(dir_data$school_name))
  expect_true(school_duplicates < nrow(dir_data) * 0.1,
              info = paste("Too many duplicate school names:", school_duplicates))
})
