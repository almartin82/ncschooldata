# Calculate proficiency gap between subgroups

Calculates the gap in proficiency rates between two subgroups.

## Usage

``` r
calc_proficiency_gap(df, group1, group2)
```

## Arguments

- df:

  A tidy assessment data frame

- group1:

  First subgroup code (e.g., "WH7" for White)

- group2:

  Second subgroup code (e.g., "BL7" for Black)

## Value

Data frame with gap calculations

## Examples

``` r
if (FALSE) { # \dontrun{
assess <- fetch_assessment(2024)
# Calculate White-Black gap
gap <- calc_proficiency_gap(assess, "WH7", "BL7")
} # }
```
