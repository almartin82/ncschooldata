# Filter assessment data to proficiency results

Filters assessment data to include only rows with CCR (College and
Career Ready) or GLP (Grade Level Proficiency) standards, which are the
main proficiency metrics.

## Usage

``` r
filter_proficiency(df, standard = "CCR")
```

## Arguments

- df:

  A tidy assessment data frame

- standard:

  Which proficiency standard to filter: "CCR" (default), "GLP", or
  "both"

## Value

Filtered data frame

## Examples

``` r
if (FALSE) { # \dontrun{
assess <- fetch_assessment(2024)
ccr_only <- filter_proficiency(assess, "CCR")
} # }
```
