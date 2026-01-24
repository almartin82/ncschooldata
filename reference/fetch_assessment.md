# Fetch North Carolina assessment data

Downloads and returns assessment data from the North Carolina Department
of Public Instruction. Includes EOG (End-of-Grade) and EOC
(End-of-Course) test results.

## Usage

``` r
fetch_assessment(end_year, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_year:

  School year end (2023-24 = 2024). Valid range: 2014-2024 (no 2020).

- tidy:

  If TRUE (default), returns data with aggregation flags and clean
  labels. If FALSE, returns minimally processed data.

- use_cache:

  If TRUE (default), uses locally cached data when available.

## Value

Data frame with assessment data

## Details

Assessment data includes proficiency rates (College & Career Ready
standard) for all students and subgroups at the state, district, and
school levels.

## Examples

``` r
if (FALSE) { # \dontrun{
# Get 2024 assessment data
assess_2024 <- fetch_assessment(2024)

# Get 2023 assessment data
assess_2023 <- fetch_assessment(2023)

# Force fresh download
assess_fresh <- fetch_assessment(2024, use_cache = FALSE)

# Filter to state-level math results
state_math <- assess_2024 |>
  dplyr::filter(is_district, subject == "MA", subgroup == "ALL")
} # }
```
