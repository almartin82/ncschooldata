# Clear assessment cache

Removes cached assessment data files.

## Usage

``` r
clear_assessment_cache(end_year = NULL)
```

## Arguments

- end_year:

  Optional school year to clear. If NULL, clears all years.

## Value

Invisibly returns the number of files removed

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear all cached assessment data
clear_assessment_cache()

# Clear only 2024 data
clear_assessment_cache(2024)
} # }
```
