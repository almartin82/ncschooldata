# ==============================================================================
# Assessment Year Coverage Tests for ncschooldata
# ==============================================================================
#
# Per-year tests for NC assessment data (2014-2019, 2021-2024; no 2020 COVID).
# Validates data loads, subject/grade/subgroup coverage, entity structure,
# proficiency ranges, and pinned values from NC DPI School Report Cards.
#
# All pinned values come from cached NC DPI data (rcd_acc_pc.txt).
#
# ==============================================================================

library(testthat)


# Helper: fetch assessment, skip if data unavailable
try_fetch_assessment <- function(end_year, tidy = TRUE, use_cache = TRUE) {
  tryCatch(
    fetch_assessment(end_year, tidy = tidy, use_cache = use_cache),
    error = function(e) {
      skip(paste("NC assessment data unavailable for year", end_year, "-", e$message))
    }
  )
}


# ==============================================================================
# Section 1: Available Years Configuration
# ==============================================================================

test_that("get_available_assessment_years returns correct year set", {
  years_info <- get_available_assessment_years()

  expected_years <- c(2014L, 2015L, 2016L, 2017L, 2018L, 2019L, 2021L, 2022L, 2023L, 2024L)
  expect_equal(years_info$years, expected_years)
})

test_that("2020 is excluded from available assessment years", {
  years_info <- get_available_assessment_years()
  expect_false(2020 %in% years_info$years)
})

test_that("fetch_assessment explicitly rejects 2020 with COVID message", {
  expect_error(fetch_assessment(2020), "COVID-19")
})


# ==============================================================================
# Section 2: Per-Year Data Load
# ==============================================================================

# All assessment years
assessment_years <- c(2014, 2015, 2016, 2017, 2018, 2019, 2021, 2022, 2023, 2024)

for (yr in assessment_years) {

  test_that(paste("assessment data loads with >0 rows for year", yr), {
    a <- try_fetch_assessment(yr)
    expect_true(nrow(a) > 0, info = paste("Year", yr, "returned 0 rows"))
  })
}


# ==============================================================================
# Section 3: Subject Coverage
# ==============================================================================

# Standard NC subjects: EOG, EOC, MA (Math), RD (Reading), SC (Science)
# Plus EOC subjects: BI (Biology), E2 (English II), M1 (NC Math 1), M3 (NC Math 3)
core_subjects <- c("EOG", "MA", "RD", "SC")

for (yr in assessment_years) {

  test_that(paste("core subjects (EOG, MA, RD, SC) present for year", yr), {
    a <- try_fetch_assessment(yr)

    available_subjects <- unique(a$subject)
    for (s in core_subjects) {
      expect_true(s %in% available_subjects,
                  info = paste("Missing subject", s, "in year", yr))
    }
  })
}

test_that("EOC and EOC subjects present in 2024", {
  a <- try_fetch_assessment(2024)

  available_subjects <- unique(a$subject)
  expect_true("EOC" %in% available_subjects)
  expect_true("BI" %in% available_subjects, info = "Biology missing")
  expect_true("E2" %in% available_subjects, info = "English II missing")
  expect_true("M1" %in% available_subjects, info = "NC Math 1 missing")
})


# ==============================================================================
# Section 4: Grade Coverage
# ==============================================================================

# EOG grades: 03-08
eog_grades <- c("03", "04", "05", "06", "07", "08")

for (yr in assessment_years) {

  test_that(paste("EOG grades 03-08 present for year", yr), {
    a <- try_fetch_assessment(yr)

    available_grades <- unique(a$grade)
    for (g in eog_grades) {
      expect_true(g %in% available_grades,
                  info = paste("Missing EOG grade", g, "in year", yr))
    }
  })

  test_that(paste("ALL grade aggregate present for year", yr), {
    a <- try_fetch_assessment(yr)

    expect_true("ALL" %in% unique(a$grade),
                info = paste("Missing ALL grade aggregate in year", yr))
  })
}


# ==============================================================================
# Section 5: Proficiency Standards
# ==============================================================================

# Core standards: CCR and GLP
for (yr in assessment_years) {

  test_that(paste("CCR and GLP standards present for year", yr), {
    a <- try_fetch_assessment(yr)

    available_standards <- unique(a$standard)
    expect_true("CCR" %in% available_standards,
                info = paste("Missing CCR standard in year", yr))
    expect_true("GLP" %in% available_standards,
                info = paste("Missing GLP standard in year", yr))
  })
}

test_that("2024 has all expected proficiency levels", {
  a <- try_fetch_assessment(2024)

  expected_standards <- c("CCR", "GLP", "L3", "L4", "L5", "NotProf")
  available_standards <- unique(a$standard)

  for (s in expected_standards) {
    expect_true(s %in% available_standards,
                info = paste("Missing standard", s, "in 2024"))
  }
})


# ==============================================================================
# Section 6: Subgroup Coverage
# ==============================================================================

# Core subgroups that should be present in all years
core_subgroups <- c("ALL", "BL7", "WH7", "HI7", "EDS", "SWD")

for (yr in assessment_years) {

  test_that(paste("core subgroups present for year", yr), {
    a <- try_fetch_assessment(yr)

    available_subgroups <- unique(a$subgroup)
    for (sg in core_subgroups) {
      expect_true(sg %in% available_subgroups,
                  info = paste("Missing subgroup", sg, "in year", yr))
    }
  })
}

test_that("2024 has 21 distinct subgroups", {
  a <- try_fetch_assessment(2024)
  expect_equal(length(unique(a$subgroup)), 21)
})

test_that("2024 includes gender subgroups", {
  a <- try_fetch_assessment(2024)

  available_subgroups <- unique(a$subgroup)
  expect_true("FEM" %in% available_subgroups)
  expect_true("MALE" %in% available_subgroups)
})

test_that("2024 includes special population subgroups", {
  a <- try_fetch_assessment(2024)

  available_subgroups <- unique(a$subgroup)
  expect_true("ELS" %in% available_subgroups, info = "English Learners missing")
  expect_true("FCS" %in% available_subgroups, info = "Foster Care missing")
  expect_true("HMS" %in% available_subgroups, info = "Homeless missing")
  expect_true("MIG" %in% available_subgroups, info = "Migrant missing")
  expect_true("MIL" %in% available_subgroups, info = "Military Connected missing")
})


# ==============================================================================
# Section 7: Entity Structure
# ==============================================================================

for (yr in assessment_years) {

  test_that(paste("entity level flags exist for year", yr), {
    a <- try_fetch_assessment(yr)

    expect_true("is_state" %in% names(a))
    expect_true("is_district" %in% names(a))
    expect_true("is_school" %in% names(a))

    expect_type(a$is_state, "logical")
    expect_type(a$is_district, "logical")
    expect_type(a$is_school, "logical")
  })

  test_that(paste("district and school level data both present for year", yr), {
    a <- try_fetch_assessment(yr)

    expect_true(sum(a$is_district) > 0,
              info = paste("No district-level rows in year", yr))
    expect_true(sum(a$is_school) > 0,
              info = paste("No school-level rows in year", yr))
  })
}


# ==============================================================================
# Section 8: District Count
# ==============================================================================

# Note: Assessment district IDs are alphanumeric (00A, 01B, etc.),
# different from enrollment numeric IDs (010, 920, etc.)
for (yr in assessment_years) {

  test_that(paste("reasonable district count for assessment year", yr), {
    a <- try_fetch_assessment(yr)

    n_districts <- length(unique(a$district_id[a$is_district]))
    expect_true(n_districts > 100,
              info = paste("Too few districts in year", yr))
    expect_true(n_districts < 300,
              info = paste("Too many districts in year", yr))
  })
}


# ==============================================================================
# Section 9: School Count
# ==============================================================================

for (yr in assessment_years) {

  test_that(paste("reasonable school count for assessment year", yr), {
    a <- try_fetch_assessment(yr)

    n_schools <- length(unique(a$agency_code[a$is_school]))
    expect_true(n_schools > 2000,
              info = paste("Too few schools in year", yr))
    expect_true(n_schools < 4000,
              info = paste("Too many schools in year", yr))
  })
}


# ==============================================================================
# Section 10: Pinned Values - Wake County School 920302
# ==============================================================================

# School 920302 in 2024: EOG ALL ALL = 810 tested, 31.6% CCR
test_that("pinned: Wake school 920302 EOG ALL ALL 2024 = 810 tested, 31.6% CCR", {
  a <- try_fetch_assessment(2024)

  school_row <- a[a$agency_code == "920302" &
                  a$standard == "CCR" &
                  a$subgroup == "ALL" &
                  a$subject == "EOG" &
                  a$grade == "ALL", ]

  expect_equal(nrow(school_row), 1)
  expect_equal(school_row$n_tested, 810)
  expect_equal(school_row$pct_proficient, 31.6)
})

# School 920302 in 2024: Math ALL ALL = 344 tested, 28.2% CCR
test_that("pinned: Wake school 920302 MA ALL ALL 2024 = 344 tested, 28.2% CCR", {
  a <- try_fetch_assessment(2024)

  school_row <- a[a$agency_code == "920302" &
                  a$standard == "CCR" &
                  a$subgroup == "ALL" &
                  a$subject == "MA" &
                  a$grade == "ALL", ]

  expect_equal(nrow(school_row), 1)
  expect_equal(school_row$n_tested, 344)
  expect_equal(school_row$pct_proficient, 28.2)
})

# School 920302 in 2024: Reading ALL ALL = 344 tested, 28.5% CCR
test_that("pinned: Wake school 920302 RD ALL ALL 2024 = 344 tested, 28.5% CCR", {
  a <- try_fetch_assessment(2024)

  school_row <- a[a$agency_code == "920302" &
                  a$standard == "CCR" &
                  a$subgroup == "ALL" &
                  a$subject == "RD" &
                  a$grade == "ALL", ]

  expect_equal(nrow(school_row), 1)
  expect_equal(school_row$n_tested, 344)
  expect_equal(school_row$pct_proficient, 28.5)
})


# ==============================================================================
# Section 11: Pinned Values - CMS School 600300
# ==============================================================================

# School 600300 in 2024: EOG ALL ALL = 879 tested, 20.9% CCR
test_that("pinned: CMS school 600300 EOG ALL ALL 2024 = 879 tested, 20.9% CCR", {
  a <- try_fetch_assessment(2024)

  school_row <- a[a$agency_code == "600300" &
                  a$standard == "CCR" &
                  a$subgroup == "ALL" &
                  a$subject == "EOG" &
                  a$grade == "ALL", ]

  expect_equal(nrow(school_row), 1)
  expect_equal(school_row$n_tested, 879)
  expect_equal(school_row$pct_proficient, 20.9)
})

# School 600300 in 2024: Science ALL ALL = 131 tested, 32.8% CCR
test_that("pinned: CMS school 600300 SC ALL ALL 2024 = 131 tested, 32.8% CCR", {
  a <- try_fetch_assessment(2024)

  school_row <- a[a$agency_code == "600300" &
                  a$standard == "CCR" &
                  a$subgroup == "ALL" &
                  a$subject == "SC" &
                  a$grade == "ALL", ]

  expect_equal(nrow(school_row), 1)
  expect_equal(school_row$n_tested, 131)
  expect_equal(school_row$pct_proficient, 32.8)
})


# ==============================================================================
# Section 12: Pinned Values - District Level
# ==============================================================================

# District 00A (first alphabetically) in 2024: EOG ALL ALL = 2578 tested, 27.2% CCR
test_that("pinned: district 00A EOG ALL ALL 2024 = 2578 tested, 27.2% CCR", {
  a <- try_fetch_assessment(2024)

  dist_row <- a[a$agency_code == "00A000" &
                a$standard == "CCR" &
                a$subgroup == "ALL" &
                a$subject == "EOG" &
                a$grade == "ALL", ]

  expect_equal(nrow(dist_row), 1)
  expect_equal(dist_row$n_tested, 2578)
  expect_equal(dist_row$pct_proficient, 27.2)
})

# District 01B in 2024: Math ALL ALL = 375 tested, 50.4% CCR
test_that("pinned: district 01B MA ALL ALL 2024 = 375 tested, 50.4% CCR", {
  a <- try_fetch_assessment(2024)

  dist_row <- a[a$agency_code == "01B000" &
                a$standard == "CCR" &
                a$subgroup == "ALL" &
                a$subject == "MA" &
                a$grade == "ALL", ]

  expect_equal(nrow(dist_row), 1)
  expect_equal(dist_row$n_tested, 375)
  expect_equal(dist_row$pct_proficient, 50.4)
})


# ==============================================================================
# Section 13: Subject Label Mapping
# ==============================================================================

test_that("all subject labels mapped correctly in 2024", {
  a <- try_fetch_assessment(2024)

  # Verify label mapping for core subjects
  expected_labels <- list(
    EOG = "End-of-Grade (All)",
    EOC = "End-of-Course (All)",
    MA = "Math",
    RD = "Reading",
    SC = "Science",
    BI = "Biology",
    E2 = "English II",
    M1 = "NC Math 1"
  )

  for (subj in names(expected_labels)) {
    rows_with_subject <- a[a$subject == subj, ]
    if (nrow(rows_with_subject) > 0) {
      expect_equal(unique(rows_with_subject$subject_label), expected_labels[[subj]],
                   info = paste("Label mismatch for subject", subj))
    }
  }
})


# ==============================================================================
# Section 14: Subgroup Label Mapping
# ==============================================================================

test_that("all subgroup labels mapped correctly in 2024", {
  a <- try_fetch_assessment(2024)

  expected_labels <- list(
    ALL = "All Students",
    BL7 = "Black",
    WH7 = "White",
    HI7 = "Hispanic",
    AS7 = "Asian",
    AM7 = "American Indian",
    MU7 = "Two or More Races",
    PI7 = "Pacific Islander",
    EDS = "Economically Disadvantaged",
    ELS = "English Learners",
    SWD = "Students with Disabilities",
    FEM = "Female",
    MALE = "Male"
  )

  for (sg in names(expected_labels)) {
    rows <- a[a$subgroup == sg, ]
    if (nrow(rows) > 0) {
      expect_equal(unique(rows$subgroup_label), expected_labels[[sg]],
                   info = paste("Label mismatch for subgroup", sg))
    }
  }
})


# ==============================================================================
# Section 15: Proficiency Rate Ranges
# ==============================================================================

for (yr in assessment_years) {

  test_that(paste("pct_proficient is 0-100 for year", yr), {
    a <- try_fetch_assessment(yr)

    valid_pcts <- a$pct_proficient[!is.na(a$pct_proficient)]
    if (length(valid_pcts) > 0) {
      expect_true(all(valid_pcts >= 0),
                  info = paste("Negative proficiency rate in year", yr))
      expect_true(all(valid_pcts <= 100),
                  info = paste("Proficiency rate >100 in year", yr))
    }
  })
}


# ==============================================================================
# Section 16: n_tested Non-Negative
# ==============================================================================

for (yr in assessment_years) {

  test_that(paste("n_tested is non-negative for year", yr), {
    a <- try_fetch_assessment(yr)

    valid_n <- a$n_tested[!is.na(a$n_tested)]
    if (length(valid_n) > 0) {
      expect_true(all(valid_n >= 0),
                  info = paste("Negative n_tested in year", yr))
    }
  })
}


# ==============================================================================
# Section 17: Suppression Handling
# ==============================================================================

test_that("suppression flags present in 2024 data", {
  a <- try_fetch_assessment(2024)

  expect_true("is_suppressed" %in% names(a))
  expect_true("suppression_reason" %in% names(a))
  expect_true("masking" %in% names(a))

  # Some rows should be suppressed (normal for assessment data)
  expect_true(sum(a$is_suppressed, na.rm = TRUE) > 0,
              info = "Expected some suppressed rows")
  # But not all
  expect_true(sum(!a$is_suppressed, na.rm = TRUE) > 0,
              info = "Expected some non-suppressed rows")
})


# ==============================================================================
# Section 18: Required Column Presence
# ==============================================================================

required_assessment_cols <- c(
  "end_year", "agency_code", "district_id", "school_id", "level",
  "is_state", "is_district", "is_school",
  "standard", "subject", "grade", "subgroup",
  "n_tested", "pct_proficient",
  "masking", "is_suppressed"
)

for (yr in assessment_years) {

  test_that(paste("all required columns present for assessment year", yr), {
    a <- try_fetch_assessment(yr)

    for (col in required_assessment_cols) {
      expect_true(col %in% names(a),
                  info = paste("Missing column", col, "in year", yr))
    }
  })
}


# ==============================================================================
# Section 19: Cross-Year Consistency
# ==============================================================================

test_that("multi-year assessment fetch combines correctly", {
  multi <- tryCatch(
    fetch_assessment_multi(c(2023, 2024), use_cache = TRUE),
    error = function(e) skip(paste("Multi-year fetch failed:", e$message))
  )

  years_in_data <- unique(multi$end_year)
  expect_true(2023 %in% years_in_data)
  expect_true(2024 %in% years_in_data)
})

test_that("assessment columns consistent across 2014 and 2024", {
  a_2014 <- try_fetch_assessment(2014)
  a_2024 <- try_fetch_assessment(2024)

  # Core columns should be consistent
  core_cols <- c("end_year", "agency_code", "district_id", "standard",
                 "subject", "grade", "subgroup", "n_tested", "pct_proficient")

  for (col in core_cols) {
    expect_true(col %in% names(a_2014),
                info = paste("Column", col, "missing from 2014"))
    expect_true(col %in% names(a_2024),
                info = paste("Column", col, "missing from 2024"))
  }
})


# ==============================================================================
# Section 20: Grade-Specific Pinned Values
# ==============================================================================

# School 920302 in 2024, grade 03, Math, CCR: 119 tested, 33.6%
test_that("pinned: Wake 920302 MA grade 03 2024 = 119 tested, 33.6% CCR", {
  a <- try_fetch_assessment(2024)

  row <- a[a$agency_code == "920302" &
           a$standard == "CCR" &
           a$subgroup == "ALL" &
           a$subject == "MA" &
           a$grade == "03", ]

  expect_equal(nrow(row), 1)
  expect_equal(row$n_tested, 119)
  expect_equal(row$pct_proficient, 33.6)
})

# School 600300 in 2024, grade 05, Science, CCR: 131 tested, 32.8%
test_that("pinned: CMS 600300 SC grade 05 2024 = 131 tested, 32.8% CCR", {
  a <- try_fetch_assessment(2024)

  row <- a[a$agency_code == "600300" &
           a$standard == "CCR" &
           a$subgroup == "ALL" &
           a$subject == "SC" &
           a$grade == "05", ]

  expect_equal(nrow(row), 1)
  expect_equal(row$n_tested, 131)
  expect_equal(row$pct_proficient, 32.8)
})
