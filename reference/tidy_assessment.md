# Tidy assessment data

Adds aggregation flags and ensures consistent column ordering for
analysis-ready assessment data.

## Usage

``` r
tidy_assessment(df)
```

## Arguments

- df:

  A data frame of processed assessment data from process_assessment

## Value

A data frame with aggregation flags and cleaned data

## Examples

``` r
if (FALSE) { # \dontrun{
raw <- get_raw_assessment(2024)
processed <- process_assessment(raw, 2024)
tidy_data <- tidy_assessment(processed)
} # }
```
