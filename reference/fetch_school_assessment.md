# Get assessment data for a specific school

Convenience function to fetch assessment data for a single school.

## Usage

``` r
fetch_school_assessment(end_year, agency_code, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_year:

  School year end

- agency_code:

  Full 6-character agency code (e.g., "920305")

- tidy:

  If TRUE (default), returns tidy format

- use_cache:

  If TRUE (default), uses cached data

## Value

Data frame filtered to specified school

## Examples

``` r
if (FALSE) { # \dontrun{
# Get a specific school's assessment data
school_assess <- fetch_school_assessment(2024, "920305")
} # }
```
