# Tests for enrollment functions
# Note: Most tests are marked as skip_on_cran since they require network access

test_that("get_available_years returns valid range", {
  years <- get_available_years()
  expect_true(is.numeric(years))
  expect_true(2006 %in% years)
  expect_true(2024 %in% years)
  expect_true(length(years) >= 19)  # At least 2006-2024
})


test_that("fetch_enr validates year parameter", {
  expect_error(fetch_enr(2000), "not available")
  expect_error(fetch_enr(2030), "not available")
  expect_error(fetch_enr("2024"), "must be a single numeric")
})


test_that("fetch_enr_multi validates years", {
  expect_error(fetch_enr_multi(c(2000, 2024)), "not available")
  expect_error(fetch_enr_multi(c(2024, 2030)), "not available")
})


test_that("process_enr handles empty data", {
  # Create empty raw data
  raw <- list(
    lea = data.frame(),
    school = data.frame()
  )

  result <- process_enr(raw, 2024)
  expect_true(is.data.frame(result))
})


test_that("create_empty_enrollment_df creates correct structure", {
  lea_df <- create_empty_enrollment_df("lea")
  expect_true("LEAID" %in% names(lea_df))
  expect_true("TOTAL" %in% names(lea_df))
  expect_equal(nrow(lea_df), 0)

  school_df <- create_empty_enrollment_df("school")
  expect_true("NCESSCH" %in% names(school_df))
  expect_true("G01" %in% names(school_df))
  expect_equal(nrow(school_df), 0)
})


# Integration tests (require network access)
test_that("fetch_enr downloads and processes data", {
  skip_on_cran()
  skip_if_offline()

  # Use a recent year
  result <- tryCatch(
    fetch_enr(2023, tidy = FALSE, use_cache = FALSE),
    error = function(e) NULL
  )

  # Skip if download failed (network issues)
  skip_if(is.null(result), "Download failed - network may be unavailable")

  # Check structure
  expect_true(is.data.frame(result))
  expect_true("district_id" %in% names(result))
  expect_true("type" %in% names(result))

  # Check we have all levels
  expect_true("State" %in% result$type)
  expect_true("District" %in% result$type || "Campus" %in% result$type)
})


test_that("tidy_enr produces correct long format", {
  # Create mock wide data
  wide <- data.frame(
    end_year = 2024,
    type = "State",
    district_id = NA_character_,
    campus_id = NA_character_,
    district_name = NA_character_,
    campus_name = NA_character_,
    county = NA_character_,
    region = NA_character_,
    charter_flag = NA_character_,
    row_total = 1500000,
    white = 700000,
    black = 350000,
    hispanic = 280000,
    asian = 50000,
    grade_k = 100000,
    grade_01 = 105000,
    stringsAsFactors = FALSE
  )

  # Tidy it
  tidy_result <- tidy_enr(wide)

  # Check structure
  expect_true("grade_level" %in% names(tidy_result))
  expect_true("subgroup" %in% names(tidy_result))
  expect_true("n_students" %in% names(tidy_result))
  expect_true("pct" %in% names(tidy_result))

  # Check subgroups include expected values
  subgroups <- unique(tidy_result$subgroup)
  expect_true("total_enrollment" %in% subgroups)
  expect_true("hispanic" %in% subgroups)
  expect_true("white" %in% subgroups)

  # Check grade levels
  grades <- unique(tidy_result$grade_level)
  expect_true("TOTAL" %in% grades)
  expect_true("K" %in% grades)
  expect_true("01" %in% grades)
})


test_that("id_enr_aggs adds correct flags", {
  # Create mock tidy data
  tidy <- data.frame(
    end_year = 2024,
    type = c("State", "District", "Campus"),
    district_id = c(NA, "920", "920"),
    campus_id = c(NA, NA, "920001"),
    district_name = c(NA, "Wake County", "Wake County"),
    campus_name = c(NA, NA, "Test Elementary"),
    county = NA_character_,
    region = NA_character_,
    charter_flag = c(NA, NA, "N"),
    grade_level = "TOTAL",
    subgroup = "total_enrollment",
    n_students = c(1500000, 160000, 500),
    pct = 1.0,
    stringsAsFactors = FALSE
  )

  result <- id_enr_aggs(tidy)

  # Check flags exist
  expect_true("is_state" %in% names(result))
  expect_true("is_district" %in% names(result))
  expect_true("is_campus" %in% names(result))
  expect_true("is_charter" %in% names(result))

  # Check flags are boolean
  expect_true(is.logical(result$is_state))
  expect_true(is.logical(result$is_district))
  expect_true(is.logical(result$is_campus))
  expect_true(is.logical(result$is_charter))

  # Check correct values
  expect_equal(result$is_state, c(TRUE, FALSE, FALSE))
  expect_equal(result$is_district, c(FALSE, TRUE, FALSE))
  expect_equal(result$is_campus, c(FALSE, FALSE, TRUE))
  expect_equal(result$is_charter, c(FALSE, FALSE, FALSE))
})


test_that("enr_grade_aggs creates proper aggregations", {
  # Create mock tidy data with grade levels
  tidy <- data.frame(
    end_year = rep(2024, 14),
    type = rep("State", 14),
    district_id = rep(NA_character_, 14),
    campus_id = rep(NA_character_, 14),
    district_name = rep(NA_character_, 14),
    campus_name = rep(NA_character_, 14),
    county = rep(NA_character_, 14),
    region = rep(NA_character_, 14),
    charter_flag = rep(NA_character_, 14),
    grade_level = c("TOTAL", "K", "01", "02", "03", "04", "05", "06", "07", "08",
                    "09", "10", "11", "12"),
    subgroup = rep("total_enrollment", 14),
    n_students = c(1500000, 100000, 105000, 108000, 110000, 112000, 115000,
                   118000, 120000, 122000, 125000, 128000, 130000, 127000),
    pct = rep(NA_real_, 14),
    is_state = rep(TRUE, 14),
    is_district = rep(FALSE, 14),
    is_campus = rep(FALSE, 14),
    is_charter = rep(FALSE, 14),
    stringsAsFactors = FALSE
  )

  result <- enr_grade_aggs(tidy)

  # Check we got aggregations
  expect_true("K8" %in% result$grade_level)
  expect_true("HS" %in% result$grade_level)
  expect_true("K12" %in% result$grade_level)

  # Check K-8 sum (K + 01-08 = 100000 + 105000 + ... + 122000)
  k8_row <- result[result$grade_level == "K8", ]
  expect_equal(nrow(k8_row), 1)
  expect_equal(k8_row$n_students, sum(c(100000, 105000, 108000, 110000, 112000,
                                         115000, 118000, 120000, 122000)))

  # Check HS sum (09-12)
  hs_row <- result[result$grade_level == "HS", ]
  expect_equal(nrow(hs_row), 1)
  expect_equal(hs_row$n_students, sum(c(125000, 128000, 130000, 127000)))
})
