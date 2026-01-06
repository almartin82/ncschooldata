# North Carolina School Data Expansion Research

**Last Updated:** 2026-01-04 **Theme Researched:** Graduation (Cohort
Graduation Rates)

## Executive Summary

NC DPI provides comprehensive cohort graduation rate data through the
“School Assessment and Other Indicator Data” Excel files. Data is
available from 2020-21 through 2024-25 (and beyond as new years are
released). The data includes 4-year and 5-year cohort graduation rates
at state, LEA (district), and school levels, with breakdowns by 21
student subgroups.

**Recommendation:** HIGH priority, MEDIUM complexity. Data is
well-structured, consistent across years, and available via direct HTTP
download.

------------------------------------------------------------------------

## Data Sources Found

### Source 1: School Assessment and Other Indicator Data (PRIMARY)

**Description:** Annual Excel files containing accountability data
including cohort graduation rates.

| Year    | URL                                                                               | HTTP Status | File Size |
|---------|-----------------------------------------------------------------------------------|-------------|-----------|
| 2024-25 | `https://www.dpi.nc.gov/2024-25-school-assessment-and-other-indicator-data/open`  | 200 OK      | ~112 MB   |
| 2023-24 | `https://www.dpi.nc.gov/2023-24-school-assessment-and-other-indicator-data/open`  | 200 OK      | ~102 MB   |
| 2022-23 | `https://www.dpi.nc.gov/2022-23-school-assessment-and-other-indicator-data/open`  | 200 OK      | ~95 MB    |
| 2021-22 | `https://www.dpi.nc.gov/2021-22-school-assessment-and-other-indicator-data/open`  | 200 OK      | ~93 MB    |
| 2020-21 | `https://www.dpi.nc.gov/2020-21-school-assessment-and-other-indicator-data2/open` | 200 OK      | ~107 MB   |
| 2019-20 | `https://www.dpi.nc.gov/2019-20-school-assessment-and-other-indicator-data/open`  | 404         | N/A       |
| 2018-19 | `https://www.dpi.nc.gov/2018-19-school-assessment-and-other-indicator-data/open`  | 404         | N/A       |

**Notes:** - 2020-21 uses alternate URL pattern (`*-data2` suffix) -
Pre-2020 files return 404 - may need to search archive - URL pattern is
NOT fully predictable - must enumerate each year

**Format:** Excel (.xlsx) with multiple sheets **Update Frequency:**
Annual (released September) **Access Method:** Direct HTTP download (no
auth required)

### Source 2: School Report Card Data Set (ALTERNATIVE)

| Resource               | URL                                                         | HTTP Status | Format    |
|------------------------|-------------------------------------------------------------|-------------|-----------|
| SRC Data Set 2023-2024 | `https://www.dpi.nc.gov/src-data-set-2023-2024/open`        | 200 OK      | ZIP       |
| SRC Data Dictionary    | `https://www.dpi.nc.gov/src-data-dictionary-2023-2024/open` | 200 OK      | PDF/Excel |

**Notes:** ZIP file contains comprehensive report card data. May include
graduation rates but would need schema analysis.

### Source 3: Tableau Dashboard (NOT RECOMMENDED)

**URL:** `https://go.ncdpi.gov/AccountabilityDashboards` **Redirects
to:** `https://public.tableau.com/views/NCDPIAccountabilityLandingPage/`

**Notes:** JavaScript-based, no direct API access. Not suitable for
programmatic data extraction.

------------------------------------------------------------------------

## Schema Analysis

### Sheet Structure (School Assessment Excel Files)

Each file contains the following relevant sheets: -
`Other High Sch Ind` - Human-readable summary with graduation rates -
`Assess-Ind Data Set` - Machine-readable raw data (PRIMARY for
implementation) - `Asses-Ind Data Set Format` - Column definitions and
code tables

### Column Names (Assess-Ind Data Set)

| Column           | Description                         | Example Values        |
|------------------|-------------------------------------|-----------------------|
| `reporting_year` | YYYY format                         | “2025”                |
| `lea_code`       | 3-character LEA code or “NC”        | “010”, “920”, “NC”    |
| `lea_name`       | District name                       | “Wake County Schools” |
| `school_code`    | 6-character school code or LEA code | “920358”, “NC”        |
| `school_name`    | School name                         | “Athens Drive High”   |
| `sbe_region`     | State Board of Education region     | numeric               |
| `grade_span`     | Grade span of school                | “09-12”               |
| `title_1`        | Title I served school               | “Y” or NULL           |
| `subgroup`       | Student subgroup code               | “ALL”, “BLCK”, “EDS”  |
| `subject`        | Subject/indicator code              | “CGRS”, “CGRE”        |
| `den`            | Denominator (cohort size)           | numeric               |
| `total_pct`      | Percentage or suppression marker    | “87.7”, “\>95”, “\<5” |

**Schema Changes Noted:**

| Year    | Notes                                               |
|---------|-----------------------------------------------------|
| 2024-25 | Added `missed_days` column (Hurricane Helene)       |
| 2023-24 | Standard schema                                     |
| 2022-23 | Standard schema                                     |
| 2021-22 | Requires `skip = 1` when reading (extra header row) |
| 2020-21 | Different format sheet, different column order      |

### Subject Codes for Graduation

| Code   | Description                                 |
|--------|---------------------------------------------|
| `CGRS` | Four-Year Cohort Graduation Rate (standard) |
| `CGRE` | Five-Year Cohort Graduation Rate (extended) |

### Subgroup Codes

| Code   | Description                           |
|--------|---------------------------------------|
| `ALL`  | All Students                          |
| `AIG`  | Academically or Intellectually Gifted |
| `AMIN` | American Indian                       |
| `ASIA` | Asian                                 |
| `BLCK` | Black                                 |
| `EDS`  | Economically Disadvantaged            |
| `ELS`  | English Learners                      |
| `FCS`  | Foster Care Students                  |
| `FEM`  | Female                                |
| `HISP` | Hispanic                              |
| `HMS`  | Homeless                              |
| `MALE` | Male                                  |
| `MIG`  | Migrant                               |
| `MIL`  | Military Connected                    |
| `MULT` | Multiracial                           |
| `NAIG` | Not AIG                               |
| `NEDS` | Not Economically Disadvantaged        |
| `NELS` | Not English Learners                  |
| `NSWD` | Not Students with Disabilities        |
| `SWD`  | Students with Disabilities            |
| `WHTE` | White                                 |

------------------------------------------------------------------------

## ID System

### LEA Codes

- **Format:** 3-character alphanumeric
- **Examples:** “010”, “020”, “920” (Wake County)
- **State-level:** Uses “NC”
- **Count:** ~200+ LEAs (traditional districts + charters)

### School Codes

- **Format:** 6-character alphanumeric
- **Structure:** `{LEA_CODE}{SCHOOL_NUM}` (3-digit LEA + 3-digit school)
- **Examples:** “920358” (Athens Drive High in Wake County)
- **LEA-level data:** Uses LEA code as school_code

### Data Hierarchy

    State (lea_code = "NC", school_code = "NC")
      |
      +-- LEA (lea_code = "920", school_code = "920")
            |
            +-- School (lea_code = "920", school_code = "920358")

------------------------------------------------------------------------

## Time Series Heuristics

### State-Level 4-Year Graduation Rate

| Year    | Rate  | YoY Change |
|---------|-------|------------|
| 2024-25 | 87.7% | +0.8%      |
| 2023-24 | 87.0% | +0.7%      |
| 2022-23 | 86.3% | -0.1%      |
| 2021-22 | 86.4% | +0.4%      |
| 2020-21 | 86.0% | (baseline) |

### Expected Ranges

| Metric              | Expected Range    | Red Flag If        |
|---------------------|-------------------|--------------------|
| State 4-year rate   | 85% - 92%         | Change \> 2% YoY   |
| School 4-year rate  | 14% - \>95%       | Below 10%          |
| Cohort size (state) | 120,000 - 130,000 | Change \> 10% YoY  |
| Schools with data   | 650 - 750         | Drop \> 50 schools |

### Suppression Rules

- `>95` indicates rate above 95% (small denominator suppression)
- `<5` indicates rate below 5% (small denominator suppression)
- Both should be handled as NA or estimated bounds

------------------------------------------------------------------------

## Known Data Issues

| Issue                 | Description                          | Handling                      |
|-----------------------|--------------------------------------|-------------------------------|
| Suppression markers   | “\>95” and “\<5” in total_pct        | Parse as NA or bounds         |
| Floating point errors | “68.900000000000006”                 | Round to reasonable precision |
| Schema variation      | 2021-22 needs skip=1                 | Detect by checking first row  |
| COVID impact          | 2020-21 had no accountability growth | Document in metadata          |
| Hurricane Helene      | 2024-25 has `missed_days` column     | Handle as optional column     |

------------------------------------------------------------------------

## Recommended Implementation

### Priority: HIGH

- Clean, structured data source
- Consistent annual updates
- Critical metric for education research

### Complexity: MEDIUM

- Schema variations require year-detection logic
- Multiple subgroups to handle
- Suppression markers need parsing

### Estimated Files to Modify

1.  `R/get_raw_graduation.R` - New file for data download
2.  `R/process_graduation.R` - New file for schema normalization
3.  `R/tidy_graduation.R` - New file for long format transformation
4.  `R/fetch_graduation.R` - New file for user-facing API
5.  `DESCRIPTION` - No new dependencies needed
6.  `tests/testthat/test-pipeline-graduation-live.R` - Live tests

### Implementation Steps

1.  Create `get_raw_grad()` function:
    - Build URL for each year (handle inconsistent patterns)
    - Download Excel file to temp location
    - Read “Assess-Ind Data Set” sheet with appropriate skip
    - Filter to CGRS/CGRE subjects only
    - Return raw data frame
2.  Create `process_grad()` function:
    - Standardize column names across years
    - Parse suppression markers (“\>95” -\> NA with flag)
    - Convert numeric fields
    - Add `end_year` column
3.  Create `tidy_grad()` function:
    - Keep long format (already long)
    - Rename columns to standard names:
      - `grad_rate_pct` from `total_pct`
      - `cohort_size` from `den`
      - `rate_type` from `subject` (4yr/5yr)
    - Add `is_state`, `is_lea`, `is_school` flags
4.  Create `fetch_grad()` user API:
    - Parameters: `end_year`, `tidy = TRUE`, `use_cache = TRUE`
    - Support `fetch_grad_multi()` for multiple years

------------------------------------------------------------------------

## Test Requirements

### Raw Data Fidelity Tests Needed

``` r
test_that("2024-25: State 4-year rate matches raw Excel", {
  # Raw value from Excel: 87.7%
  data <- fetch_grad(2025, tidy = TRUE)
  state_rate <- data |>
    filter(is_state, subgroup == "ALL", rate_type == "4yr") |>
    pull(grad_rate_pct)
  expect_equal(state_rate, 87.7, tolerance = 0.1)
})

test_that("2024-25: Wake County 4-year rate matches raw Excel", {
  # Raw value from Excel: need to verify
  data <- fetch_grad(2025, tidy = TRUE)
  wake_rate <- data |>
    filter(lea_code == "920", school_code == "920",
           subgroup == "ALL", rate_type == "4yr") |>
    pull(grad_rate_pct)
  expect_true(!is.na(wake_rate))
  expect_true(wake_rate > 80 & wake_rate < 100)
})
```

### Data Quality Checks

``` r
test_that("No negative graduation rates", {
  data <- fetch_grad(2025, tidy = TRUE)
  expect_true(all(data$grad_rate_pct >= 0 | is.na(data$grad_rate_pct)))
})

test_that("All rates <= 100%", {
  data <- fetch_grad(2025, tidy = TRUE)
  expect_true(all(data$grad_rate_pct <= 100 | is.na(data$grad_rate_pct)))
})

test_that("All subgroups present at state level", {
  data <- fetch_grad(2025, tidy = TRUE)
  state_subgroups <- data |>
    filter(is_state, rate_type == "4yr") |>
    pull(subgroup) |>
    unique()
  expect_true(length(state_subgroups) >= 20)
})

test_that("State rate in expected range", {
  data <- fetch_grad(2025, tidy = TRUE)
  state_rate <- data |>
    filter(is_state, subgroup == "ALL", rate_type == "4yr") |>
    pull(grad_rate_pct)
  expect_true(state_rate > 85 & state_rate < 92)
})
```

### Pipeline Tests

``` r
test_that("URL returns HTTP 200", {
  skip_if_offline()
  url <- "https://www.dpi.nc.gov/2024-25-school-assessment-and-other-indicator-data/open"
  response <- httr::HEAD(url, httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})

test_that("Downloaded file is valid Excel", {
  skip_if_offline()
  temp <- tempfile(fileext = ".xlsx")
  download.file(url, temp, mode = "wb", quiet = TRUE)
  sheets <- readxl::excel_sheets(temp)
  expect_true("Assess-Ind Data Set" %in% sheets)
  unlink(temp)
})
```

------------------------------------------------------------------------

## Data Source URLs Summary

### Working URLs (Verified 2026-01-04)

``` r
# URL pattern function (note: not fully predictable!)
get_grad_url <- function(end_year) {
  urls <- c(
    "2025" = "https://www.dpi.nc.gov/2024-25-school-assessment-and-other-indicator-data/open",
    "2024" = "https://www.dpi.nc.gov/2023-24-school-assessment-and-other-indicator-data/open",
    "2023" = "https://www.dpi.nc.gov/2022-23-school-assessment-and-other-indicator-data/open",
    "2022" = "https://www.dpi.nc.gov/2021-22-school-assessment-and-other-indicator-data/open",
    "2021" = "https://www.dpi.nc.gov/2020-21-school-assessment-and-other-indicator-data2/open"
  )
  urls[as.character(end_year)]
}
```

### Schema Detection

``` r
# Detect if file needs skip parameter
needs_skip <- function(file_path) {
  first_row <- readxl::read_excel(file_path, sheet = "Assess-Ind Data Set", n_max = 1)
  # If first column is "Back to Introduction", need skip = 1
  grepl("Back to", names(first_row)[1])
}
```

------------------------------------------------------------------------

## References

- [NC DPI Cohort Graduation
  Rates](https://www.dpi.nc.gov/districts-schools/accountability-and-testing/school-accountability-and-reporting/cohort-graduation-rates)
- [Accountability Data Sets and
  Reports](https://www.dpi.nc.gov/districts-schools/accountability-and-testing/school-accountability-and-reporting/accountability-data-sets-and-reports)
- [Accountability Report
  Archive](https://www.dpi.nc.gov/districts-schools/accountability-and-testing/school-accountability-and-reporting/accountability-data-sets-and-reports/accountability-report-archive)
- [2024-25 Cohort Graduation Rate Manual
  (PDF)](https://www.dpi.nc.gov/2024-25-cohort-graduation-rate/download?attachment=)
