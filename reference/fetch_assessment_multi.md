# Fetch assessment data for multiple years

Downloads and combines assessment data for multiple school years. Note:
2020 is automatically excluded (COVID-19 testing waiver).

## Usage

``` r
fetch_assessment_multi(end_years, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_years:

  Vector of school year ends (e.g., c(2022, 2023, 2024))

- tidy:

  If TRUE (default), returns data with aggregation flags.

- use_cache:

  If TRUE (default), uses locally cached data when available.

## Value

Combined data frame with assessment data for all requested years

## Examples

``` r
if (FALSE) { # \dontrun{
# Get 3 years of data
assess_multi <- fetch_assessment_multi(2022:2024)

# Get all available years
years <- get_available_assessment_years()$years
all_data <- fetch_assessment_multi(years)
} # }
```
