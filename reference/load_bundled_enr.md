# Load bundled enrollment data as fallback

When NC DPI is unreachable and no local cache exists, falls back to
bundled data included in the package. This ensures vignettes and CI can
always render. Data sourced from NC DPI School Report Cards.

## Usage

``` r
load_bundled_enr(end_year, cache_type)
```

## Arguments

- end_year:

  School year end

- cache_type:

  "tidy" or "wide"

## Value

Data frame or NULL if no bundled data available for the year
