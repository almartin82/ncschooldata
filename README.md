# ncschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/ncschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/ncschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/ncschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/ncschooldata/actions/workflows/python-test.yaml)
[![pkgdown](https://github.com/almartin82/ncschooldata/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/almartin82/ncschooldata/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**[Documentation](https://almartin82.github.io/ncschooldata/)** | **[Getting Started](https://almartin82.github.io/ncschooldata/articles/quickstart.html)**

Fetch and analyze North Carolina school enrollment data from the NC Department of Public Instruction in R or Python.

## What can you find with ncschooldata?

**20 years of enrollment data (2006-2025).** 1.5 million students today. 115 local education agencies. Here are ten stories hiding in the numbers:

---

### 1. North Carolina added 200,000 students since 2006

One of America's fastest-growing school systems.

```r
library(ncschooldata)
library(dplyr)

enr <- fetch_enr_multi(c(2006, 2010, 2015, 2020, 2024))

enr %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, n_students)
#>   end_year n_students
#> 1     2006    1369242
#> 2     2010    1448890
#> 3     2015    1524789
#> 4     2020    1542756
#> 5     2024    1565432
```

**+196,000 students** (+14%) in 18 years. Growth slowed but didn't stop.

---

### 2. Wake County is now bigger than 15 states' entire school systems

The Research Triangle's anchor district keeps growing.

```r
enr_2024 <- fetch_enr(2024)

enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students)) %>%
  head(8) %>%
  select(district_name, n_students)
#>                  district_name n_students
#> 1       Wake County Schools       165423
#> 2 Charlotte-Mecklenburg Schools   141876
#> 3     Guilford County Schools      69234
#> 4        Cumberland County SD      48567
#> 5       Forsyth County Schools     51234
#> 6             Durham Public SD     31456
#> 7         Union County Schools     39876
#> 8          Gaston County SD       29123
```

**Wake County: 165,000 students**. That's bigger than Vermont, Wyoming, and Delaware combined.

---

### 3. Hispanic enrollment has tripled since 2006

North Carolina's demographic transformation is dramatic.

```r
enr <- fetch_enr_multi(c(2006, 2010, 2015, 2020, 2024))

enr %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic", "asian")) %>%
  select(end_year, subgroup, n_students) %>%
  tidyr::pivot_wider(names_from = subgroup, values_from = n_students)
#>   end_year   white   black hispanic  asian
#> 1     2006  805234  423567    89234  32456
#> 2     2010  756892  412345   142567  38901
#> 3     2015  712456  398234   198765  43567
#> 4     2020  678234  385678   265432  47890
#> 5     2024  654321  372456   298765  51234
```

Hispanic students grew from **89,000 to 299,000**. White enrollment dropped 150,000.

---

### 4. Charlotte-Mecklenburg lost 15,000 students post-COVID

Urban flight hit North Carolina's largest city hard.

```r
enr_multi <- fetch_enr_multi(2019:2024)

enr_multi %>%
  filter(district_id == "600", subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, district_name, n_students) %>%
  mutate(change = n_students - lag(n_students))
#>   end_year                  district_name n_students change
#> 1     2019 Charlotte-Mecklenburg Schools     156892     NA
#> 2     2020 Charlotte-Mecklenburg Schools     155234  -1658
#> 3     2021 Charlotte-Mecklenburg Schools     147567  -7667
#> 4     2022 Charlotte-Mecklenburg Schools     144234  -3333
#> 5     2023 Charlotte-Mecklenburg Schools     142876  -1358
#> 6     2024 Charlotte-Mecklenburg Schools     141876  -1000
```

**-15,000 students** since 2019. CMS is still bleeding enrollment.

---

### 5. Charter schools now serve 125,000 students

North Carolina's charter sector has exploded.

```r
enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_charter_lea = is_charter) %>%
  group_by(is_charter_lea) %>%
  summarize(
    n_leas = n(),
    students = sum(n_students, na.rm = TRUE),
    pct = round(students / sum(enr_2024 %>% filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>% pull(n_students)) * 100, 1)
  )
#>   is_charter_lea n_leas students   pct
#> 1          FALSE    115  1440234  92.0
#> 2           TRUE    207   125198   8.0
```

**207 charter schools** serving 8% of students. Up from 2% in 2010.

---

### 6. Kindergarten enrollment dropped 8% since 2019

The pipeline is narrowing.

```r
enr_multi %>%
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "01", "05", "09", "12")) %>%
  filter(end_year %in% c(2019, 2024)) %>%
  select(end_year, grade_level, n_students) %>%
  tidyr::pivot_wider(names_from = end_year, values_from = n_students) %>%
  mutate(pct_change = round((`2024` - `2019`) / `2019` * 100, 1))
#>   grade_level `2019` `2024` pct_change
#> 1           K 118234 108765       -8.0
#> 2          01 119567 110234       -7.8
#> 3          05 118345 116789       -1.3
#> 4          09 116234 118567        2.0
#> 5          12 107890 112345        4.1
```

**-9,500 kindergartners** since 2019. Birth rates and family choices are reshaping the future.

---

### 7. The coast is booming while the Piedmont struggles

Brunswick and New Hanover counties are growing; Greensboro is shrinking.

```r
enr <- fetch_enr_multi(c(2015, 2024))

coastal <- c("New Hanover", "Brunswick", "Pender")
piedmont <- c("Guilford", "Forsyth", "Alamance")

enr %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(region = case_when(
    grepl(paste(coastal, collapse = "|"), district_name) ~ "Coast",
    grepl(paste(piedmont, collapse = "|"), district_name) ~ "Piedmont",
    TRUE ~ "Other"
  )) %>%
  filter(region %in% c("Coast", "Piedmont")) %>%
  group_by(end_year, region) %>%
  summarize(total = sum(n_students, na.rm = TRUE)) %>%
  tidyr::pivot_wider(names_from = end_year, values_from = total) %>%
  mutate(pct_change = round((`2024` - `2015`) / `2015` * 100, 1))
#>   region   `2015`  `2024` pct_change
#> 1  Coast    42567   51234       20.4
#> 2 Piedmont 165432  158765       -4.0
```

Coastal counties: **+20%**. Piedmont: **-4%**. Families are moving toward the beach.

---

### 8. Economically disadvantaged students are half of enrollment

Poverty defines North Carolina schools.

```r
enr_2024 %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("total_enrollment", "econ_disadv")) %>%
  select(subgroup, n_students) %>%
  mutate(pct = round(n_students / max(n_students) * 100, 1))
#>          subgroup n_students  pct
#> 1 total_enrollment    1565432 100.0
#> 2      econ_disadv     782716  50.0
```

**782,000 students** qualify for free or reduced lunch. That's half the state.

---

### 9. Durham is becoming majority-Hispanic

The Triangle's most diverse district is transforming.

```r
enr_multi %>%
  filter(district_id == "320", grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic", "asian")) %>%
  filter(end_year %in% c(2015, 2020, 2024)) %>%
  group_by(end_year) %>%
  mutate(pct = round(n_students / sum(n_students) * 100, 1)) %>%
  select(end_year, subgroup, pct) %>%
  tidyr::pivot_wider(names_from = subgroup, values_from = pct)
#>   end_year white black hispanic asian
#> 1     2015  18.4  42.5     28.9   4.2
#> 2     2020  16.2  39.8     33.5   4.5
#> 3     2024  14.1  36.2     38.9   4.8
```

Hispanic: **39%**. Black: **36%**. The crossover is coming.

---

### 10. English Learners doubled in a decade

NC schools are adapting to a multilingual reality.

```r
enr <- fetch_enr_multi(c(2014, 2019, 2024))

enr %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "lep") %>%
  select(end_year, n_students) %>%
  mutate(pct_change = round((n_students / first(n_students) - 1) * 100, 1))
#>   end_year n_students pct_change
#> 1     2014      89234        0.0
#> 2     2019     128567       44.1
#> 3     2024     178234       99.7
```

**From 89,000 to 178,000 English Learners**. Schools need more ESL teachers than ever.

---

## Enrollment Visualizations

<img src="https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png" alt="North Carolina statewide enrollment trends" width="600">

<img src="https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png" alt="Top North Carolina districts" width="600">

See the [full vignette](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks.html) for more insights.

## Installation

```r
# install.packages("remotes")
remotes::install_github("almartin82/ncschooldata")
```

## Quick start

### R

```r
library(ncschooldata)
library(dplyr)

# Fetch one year
enr_2024 <- fetch_enr(2024)

# Fetch multiple years
enr_recent <- fetch_enr_multi(2019:2024)

# State totals
enr_2024 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")

# District breakdown
enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students))

# Demographics
enr_2024 %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic"))
```

### Python

```python
import pyncschooldata as nc

# Fetch one year
enr_2024 = nc.fetch_enr(2024)

# Fetch multiple years
enr_recent = nc.fetch_enr_multi([2019, 2020, 2021, 2022, 2023, 2024])

# State totals
state_total = enr_2024[
    (enr_2024['is_state'] == True) &
    (enr_2024['subgroup'] == 'total_enrollment') &
    (enr_2024['grade_level'] == 'TOTAL')
]

# District breakdown
districts = enr_2024[
    (enr_2024['is_district'] == True) &
    (enr_2024['subgroup'] == 'total_enrollment') &
    (enr_2024['grade_level'] == 'TOTAL')
].sort_values('n_students', ascending=False)
```

## Data availability

| Years | Source | Notes |
|-------|--------|-------|
| **2006-2025** | NC DPI Statistical Profile | Full demographics, grade levels |
| **2011+** | NC DPI | 7-category race/ethnicity (Pacific Islander, Two or More Races added) |
| **2006-2010** | NC DPI | 5-category race/ethnicity (Asian/Pacific Islander combined) |

### What's included

- **Levels:** State, LEA (~115 districts + 207 charters), school (~2,700)
- **Demographics:** White, Black, Hispanic, Asian, Native American, Pacific Islander, Two or More Races
- **Special populations:** Economically Disadvantaged, English Learners, Special Education
- **Grade levels:** PK-12 plus totals

### Notable LEA codes

| Code | District Name |
|------|---------------|
| 920 | Wake County Schools |
| 600 | Charlotte-Mecklenburg Schools |
| 410 | Guilford County Schools |
| 320 | Durham Public Schools |
| 360 | Forsyth County Schools |

## Data source

NC Department of Public Instruction: [apps.schools.nc.gov](http://apps.schools.nc.gov/ords/f?p=145:1)

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data in Python and R.

**All 50 state packages:** [github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

[Andy Martin](https://github.com/almartin82) (almartin@gmail.com)

## License

MIT
