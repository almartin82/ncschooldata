# Identify assessment aggregation levels

Adds boolean flags to identify state, district, and school level
records. This is called internally by tidy_assessment but can be used
separately.

## Usage

``` r
id_assessment_aggs(df)
```

## Arguments

- df:

  Assessment dataframe with 'level' column

## Value

data.frame with boolean aggregation flags

## Examples

``` r
if (FALSE) { # \dontrun{
assess <- fetch_assessment(2024, tidy = FALSE)
assess_with_flags <- id_assessment_aggs(assess)
} # }
```
