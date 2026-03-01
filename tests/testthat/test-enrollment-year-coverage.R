# ==============================================================================
# Enrollment Year Coverage Tests for ncschooldata
# ==============================================================================
#
# Per-year tests across ALL available enrollment years (2006-2025).
# Validates data loads, pinned totals, subgroup/grade completeness,
# entity flags, and cross-year consistency.
#
# All pinned values come from cached NC DPI data. No fabricated values.
#
# Cached years at time of writing: 2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024
# Years without cache will be skipped in CI (NC DPI APEX requires browser session).
#
# ==============================================================================

library(testthat)


# Helper: fetch enrollment, skip if data unavailable
try_fetch_enr <- function(end_year, tidy = TRUE, use_cache = TRUE) {
  tryCatch(
    fetch_enr(end_year, tidy = tidy, use_cache = use_cache),
    error = function(e) {
      skip(paste("NC DPI data unavailable for year", end_year, "-", e$message))
    }
  )
}


# ==============================================================================
# Pinned State Totals
# ==============================================================================
# Source: NC DPI Statistical Profile cached data
# NC enrollment is ~1.4-1.5M students statewide

pinned_state_totals <- list(
  "2006" = 1390168,
  "2010" = 1440212,
  "2015" = 1502009,
  "2018" = 1521108,
  "2019" = 1535687,
  "2020" = 1525592,
  "2021" = 1469401,
  "2024" = 1508194
)

# Pinned Wake County totals (district_id = "920")
pinned_wake_totals <- list(

  "2006" = 120367,
  "2010" = 139064,
  "2015" = 153488,
  "2018" = 158970,
  "2019" = 160666,
  "2020" = 160622,
  "2021" = 156767,
  "2024" = 159675
)

# Pinned Charlotte-Mecklenburg totals (district_id = "600")
pinned_cms_totals <- list(
  "2006" = 122261,
  "2010" = 132075,
  "2015" = 144497,
  "2018" = 146693,
  "2019" = 147639,
  "2020" = 146255,
  "2021" = 137578,
  "2024" = 140415
)

# Pinned demographic totals for 2024
pinned_2024_demographics <- list(
  asian = 64402,
  black = 369522,
  econ_disadv = 757944,
  female = 735876,
  hispanic = 328041,
  lep = 168383,
  male = 772499,
  multiracial = 88180,
  native_american = 14840,
  pacific_islander = 2141,
  special_ed = 202380,
  white = 643051
)


# ==============================================================================
# Section 1: Per-Year Data Load and Row Count
# ==============================================================================

for (yr in c(2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024)) {

  test_that(paste("enrollment data loads with >0 rows for year", yr), {
    enr <- try_fetch_enr(yr)
    expect_true(nrow(enr) > 0, info = paste("Year", yr, "returned 0 rows"))
  })
}


# ==============================================================================
# Section 2: Pinned State Totals
# ==============================================================================

for (yr_str in names(pinned_state_totals)) {
  yr <- as.integer(yr_str)

  test_that(paste("state total matches pinned value for year", yr), {
    enr <- try_fetch_enr(yr)

    state_total <- enr[enr$is_state &
                       enr$subgroup == "total_enrollment" &
                       enr$grade_level == "TOTAL", ]

    expect_equal(nrow(state_total), 1,
                 info = paste("Expected exactly 1 state total row for year", yr))
    expect_equal(state_total$n_students, pinned_state_totals[[yr_str]],
                 info = paste("State total mismatch for year", yr))
  })
}


# ==============================================================================
# Section 3: Pinned Wake County Totals
# ==============================================================================

for (yr_str in names(pinned_wake_totals)) {
  yr <- as.integer(yr_str)

  test_that(paste("Wake County (920) total matches pinned value for year", yr), {
    enr <- try_fetch_enr(yr)

    wake <- enr[enr$is_district &
                enr$district_id == "920" &
                enr$subgroup == "total_enrollment" &
                enr$grade_level == "TOTAL", ]

    expect_equal(nrow(wake), 1,
                 info = paste("Expected exactly 1 Wake County total row for year", yr))
    expect_equal(wake$n_students, pinned_wake_totals[[yr_str]],
                 info = paste("Wake County total mismatch for year", yr))
  })
}


# ==============================================================================
# Section 4: Pinned Charlotte-Mecklenburg Totals
# ==============================================================================

for (yr_str in names(pinned_cms_totals)) {
  yr <- as.integer(yr_str)

  test_that(paste("CMS (600) total matches pinned value for year", yr), {
    enr <- try_fetch_enr(yr)

    cms <- enr[enr$is_district &
               enr$district_id == "600" &
               enr$subgroup == "total_enrollment" &
               enr$grade_level == "TOTAL", ]

    expect_equal(nrow(cms), 1,
                 info = paste("Expected exactly 1 CMS total row for year", yr))
    expect_equal(cms$n_students, pinned_cms_totals[[yr_str]],
                 info = paste("CMS total mismatch for year", yr))
  })
}


# ==============================================================================
# Section 5: Pinned 2024 Demographic Totals
# ==============================================================================

for (subgrp in names(pinned_2024_demographics)) {

  test_that(paste("2024 state demographic matches pinned value:", subgrp), {
    enr <- try_fetch_enr(2024)

    state_demo <- enr[enr$is_state &
                      enr$subgroup == subgrp &
                      enr$grade_level == "TOTAL", ]

    expect_equal(nrow(state_demo), 1,
                 info = paste("Expected exactly 1 state row for subgroup", subgrp))
    expect_equal(state_demo$n_students, pinned_2024_demographics[[subgrp]],
                 info = paste("Demographic total mismatch for", subgrp))
  })
}


# ==============================================================================
# Section 6: Subgroup Completeness
# ==============================================================================

# Years with full demographics (2018+)
full_demo_years <- c(2018, 2019, 2020, 2021, 2024)

# Standard subgroups that should always exist when demographics are present
standard_demographic_subgroups <- c(
  "total_enrollment", "white", "black", "hispanic", "asian",
  "native_american", "pacific_islander", "multiracial",
  "male", "female", "special_ed", "lep"
)

for (yr in full_demo_years) {

  test_that(paste("all standard demographic subgroups present for year", yr), {
    enr <- try_fetch_enr(yr)

    available_subgroups <- unique(enr$subgroup)

    for (sg in standard_demographic_subgroups) {
      expect_true(sg %in% available_subgroups,
                  info = paste("Missing subgroup", sg, "in year", yr))
    }
  })
}

# Early years (2006, 2010, 2015) only have total_enrollment
for (yr in c(2006, 2010, 2015)) {

  test_that(paste("total_enrollment subgroup present for year", yr), {
    enr <- try_fetch_enr(yr)

    available_subgroups <- unique(enr$subgroup)
    expect_true("total_enrollment" %in% available_subgroups,
                info = paste("Missing total_enrollment for year", yr))
  })
}


# ==============================================================================
# Section 7: Grade Completeness
# ==============================================================================

# Standard grades for non-2020 years (K through 08, no HS, no PK in cached data)
standard_grades_k8 <- c("K", "01", "02", "03", "04", "05", "06", "07", "08", "TOTAL")

for (yr in c(2006, 2010, 2015, 2018, 2019, 2021, 2024)) {

  test_that(paste("K-08 grades and TOTAL present for year", yr), {
    enr <- try_fetch_enr(yr)

    available_grades <- unique(enr$grade_level)

    for (g in standard_grades_k8) {
      expect_true(g %in% available_grades,
                  info = paste("Missing grade", g, "in year", yr))
    }
  })
}

# 2020 only has TOTAL grades
test_that("2020 enrollment only has TOTAL grade level", {
  enr <- try_fetch_enr(2020)

  available_grades <- unique(enr$grade_level)
  expect_equal(available_grades, "TOTAL",
               info = "2020 should only have TOTAL grade level")
})


# ==============================================================================
# Section 8: Entity Flags
# ==============================================================================

for (yr in c(2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024)) {

  test_that(paste("entity flags present and correct for year", yr), {
    enr <- try_fetch_enr(yr)

    # Boolean flags must exist
    expect_true("is_state" %in% names(enr))
    expect_true("is_district" %in% names(enr))
    expect_true("is_campus" %in% names(enr))
    expect_true("is_charter" %in% names(enr))

    # Each flag should be logical
    expect_type(enr$is_state, "logical")
    expect_type(enr$is_district, "logical")
    expect_type(enr$is_campus, "logical")
    expect_type(enr$is_charter, "logical")

    # Exactly one state row per subgroup/grade combo
    state_totals <- enr[enr$is_state &
                        enr$subgroup == "total_enrollment" &
                        enr$grade_level == "TOTAL", ]
    expect_equal(nrow(state_totals), 1,
                 info = paste("Expected 1 state total row for year", yr))
  })
}


# ==============================================================================
# Section 9: District ID Format
# ==============================================================================

for (yr in c(2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024)) {

  test_that(paste("district_id is 3-char format for year", yr), {
    enr <- try_fetch_enr(yr)

    # Get district rows
    district_rows <- enr[enr$is_district, ]
    expect_true(nrow(district_rows) > 0)

    # All district IDs should be exactly 3 characters
    district_ids <- unique(district_rows$district_id)
    id_lengths <- nchar(district_ids)
    expect_true(all(id_lengths == 3), info = paste("Non-3-char district IDs found in year", yr,
                             ":", paste(district_ids[id_lengths != 3], collapse = ", ")))
  })
}


# ==============================================================================
# Section 10: District and Campus Counts
# ==============================================================================

# Pinned district counts (NC has ~115-116 districts)
pinned_district_counts <- list(
  "2006" = 115, "2010" = 115, "2015" = 115,
  "2018" = 115, "2019" = 116, "2020" = 116,
  "2021" = 116, "2024" = 115
)

for (yr_str in names(pinned_district_counts)) {
  yr <- as.integer(yr_str)

  test_that(paste("district count matches pinned value for year", yr), {
    enr <- try_fetch_enr(yr)

    n_districts <- length(unique(
      enr$district_id[enr$is_district &
                      enr$subgroup == "total_enrollment" &
                      enr$grade_level == "TOTAL"]
    ))

    expect_equal(n_districts, pinned_district_counts[[yr_str]],
                 info = paste("District count mismatch for year", yr))
  })
}

# Campus counts should be in reasonable range (2300-2700)
for (yr in c(2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024)) {

  test_that(paste("campus count in reasonable range for year", yr), {
    enr <- try_fetch_enr(yr)

    n_campuses <- length(unique(
      enr$campus_id[enr$is_campus &
                    enr$subgroup == "total_enrollment" &
                    enr$grade_level == "TOTAL"]
    ))

    expect_true(n_campuses > 2000,
              info = paste("Too few campuses for year", yr))
    expect_true(n_campuses < 3000,
              info = paste("Too many campuses for year", yr))
  })
}


# ==============================================================================
# Section 11: State Total Plausibility Across Years
# ==============================================================================

test_that("state enrollment stays between 1.3M and 1.6M across all cached years", {
  for (yr in c(2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024)) {
    enr <- try_fetch_enr(yr)

    state_total <- enr$n_students[enr$is_state &
                                  enr$subgroup == "total_enrollment" &
                                  enr$grade_level == "TOTAL"]

    expect_true(state_total > 1300000,
              info = paste("State total too low for year", yr))
    expect_true(state_total < 1600000,
              info = paste("State total too high for year", yr))
  }
})


# ==============================================================================
# Section 12: Cross-Year Consistency
# ==============================================================================

test_that("multi-year fetch returns correct number of year groups", {
  # Fetch 2 years that are cached
  multi <- tryCatch(
    fetch_enr_multi(c(2018, 2024), use_cache = TRUE),
    error = function(e) skip(paste("Multi-year fetch failed:", e$message))
  )

  years_in_data <- unique(multi$end_year)
  expect_true(2018 %in% years_in_data)
  expect_true(2024 %in% years_in_data)
})

test_that("columns are consistent across years", {
  enr_2018 <- try_fetch_enr(2018)
  enr_2024 <- try_fetch_enr(2024)

  # All columns in 2018 should be in 2024
  for (col in names(enr_2018)) {
    expect_true(col %in% names(enr_2024),
                info = paste("Column", col, "missing from 2024 that exists in 2018"))
  }
})

test_that("Wake County district_id is consistent across years", {
  for (yr in c(2006, 2010, 2015, 2018, 2019, 2020, 2021, 2024)) {
    enr <- try_fetch_enr(yr)

    wake_rows <- enr[enr$is_district &
                     enr$district_id == "920" &
                     enr$subgroup == "total_enrollment" &
                     enr$grade_level == "TOTAL", ]

    expect_equal(nrow(wake_rows), 1,
                 info = paste("Wake County not found or duplicated in year", yr))
  }
})


# ==============================================================================
# Section 13: Pinned 2018 Demographics (first year with full demographics)
# ==============================================================================

pinned_2018_demographics <- list(
  asian = 51706,
  black = 393618,
  female = 755651,
  hispanic = 271304,
  lep = 118569,
  male = 797768,
  multiracial = 66111,
  native_american = 19035,
  pacific_islander = 2148,
  special_ed = 208352,
  white = 749498
)

for (subgrp in names(pinned_2018_demographics)) {

  test_that(paste("2018 state demographic matches pinned value:", subgrp), {
    enr <- try_fetch_enr(2018)

    state_demo <- enr[enr$is_state &
                      enr$subgroup == subgrp &
                      enr$grade_level == "TOTAL", ]

    expect_equal(nrow(state_demo), 1)
    expect_equal(state_demo$n_students, pinned_2018_demographics[[subgrp]],
                 info = paste("2018 demographic mismatch for", subgrp))
  })
}


# ==============================================================================
# Section 14: Pinned 2021 Demographics (COVID recovery year)
# ==============================================================================

pinned_2021_demographics <- list(
  asian = 56197,
  black = 373647,
  female = 730436,
  hispanic = 285867,
  lep = 131322,
  male = 764952,
  multiracial = 73687,
  native_american = 16430,
  pacific_islander = 2069,
  special_ed = 204434,
  white = 687491
)

for (subgrp in names(pinned_2021_demographics)) {

  test_that(paste("2021 state demographic matches pinned value:", subgrp), {
    enr <- try_fetch_enr(2021)

    state_demo <- enr[enr$is_state &
                      enr$subgroup == subgrp &
                      enr$grade_level == "TOTAL", ]

    expect_equal(nrow(state_demo), 1)
    expect_equal(state_demo$n_students, pinned_2021_demographics[[subgrp]],
                 info = paste("2021 demographic mismatch for", subgrp))
  })
}


# ==============================================================================
# Section 15: Charter School Detection
# ==============================================================================

test_that("charter schools detected in 2024 data", {
  enr <- try_fetch_enr(2024)

  charter_rows <- enr[enr$is_charter &
                      enr$subgroup == "total_enrollment" &
                      enr$grade_level == "TOTAL", ]

  # NC had 219 charter schools in 2024
  expect_true(nrow(charter_rows) > 150,
            info = "Too few charter schools detected")
  expect_true(nrow(charter_rows) < 300,
            info = "Too many charter schools detected")
})

test_that("charter schools are subset of campus-level rows", {
  enr <- try_fetch_enr(2024)

  charter_rows <- enr[enr$is_charter, ]

  # All charters should be campus-level

  expect_true(all(charter_rows$is_campus),
              info = "Some charter rows are not campus-level")
})


# ==============================================================================
# Section 16: Non-Negative Enrollment Counts
# ==============================================================================

for (yr in c(2006, 2018, 2024)) {

  test_that(paste("all enrollment counts are non-negative for year", yr), {
    enr <- try_fetch_enr(yr)

    non_na_counts <- enr$n_students[!is.na(enr$n_students)]
    expect_true(all(non_na_counts >= 0),
                info = paste("Negative enrollment counts found in year", yr))
  })
}


# ==============================================================================
# Section 17: econ_disadv Availability
# ==============================================================================

test_that("econ_disadv subgroup available in 2024", {
  enr <- try_fetch_enr(2024)

  econ_state <- enr[enr$is_state &
                    enr$subgroup == "econ_disadv" &
                    enr$grade_level == "TOTAL", ]

  expect_equal(nrow(econ_state), 1)
  expect_equal(econ_state$n_students, 757944)
})

test_that("econ_disadv is approximately half of total enrollment in 2024", {
  enr <- try_fetch_enr(2024)

  state_total <- enr$n_students[enr$is_state &
                                enr$subgroup == "total_enrollment" &
                                enr$grade_level == "TOTAL"]
  econ_total <- enr$n_students[enr$is_state &
                               enr$subgroup == "econ_disadv" &
                               enr$grade_level == "TOTAL"]

  pct_econ <- econ_total / state_total
  expect_true(pct_econ > 0.40, info = "econ_disadv percentage unexpectedly low")
  expect_true(pct_econ < 0.60, info = "econ_disadv percentage unexpectedly high")
})
