# ncschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/ncschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/ncschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/ncschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/ncschooldata/actions/workflows/python-test.yaml)
[![pkgdown](https://github.com/almartin82/ncschooldata/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/almartin82/ncschooldata/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**[Documentation](https://almartin82.github.io/ncschooldata/)** | **[Getting Started](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks.html)**

Part of the [State Schooldata Project](https://github.com/almartin82/njschooldata) - fetching and analyzing state-published school data in R and Python. The original [njschooldata](https://github.com/almartin82/njschooldata) package for New Jersey inspired this family of 50 state packages.

Fetch and analyze North Carolina school enrollment data from the NC Department of Public Instruction in R or Python.

## What can you find with ncschooldata?

**20 years of enrollment data (2006-2025).** 1.5 million students today. 115 local education agencies. Here are fifteen stories hiding in the numbers:

---

### 1. North Carolina added 200,000 students since 2006

One of America's fastest-growing school systems.

```r
library(ncschooldata)
library(dplyr)
library(tidyr)
library(ggplot2)

enr <- fetch_enr_multi(c(2006, 2010, 2015, 2020, 2024), use_cache = TRUE)

statewide <- enr %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, n_students)

statewide
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
enr_2024 <- fetch_enr(2024, use_cache = TRUE)

top_districts <- enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  arrange(desc(n_students)) %>%
  head(10) %>%
  select(district_name, n_students)

top_districts
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
demographics <- enr %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic", "asian")) %>%
  select(end_year, subgroup, n_students) %>%
  mutate(subgroup = factor(subgroup,
    levels = c("white", "black", "hispanic", "asian"),
    labels = c("White", "Black", "Hispanic", "Asian")))

demographics
#>   end_year subgroup n_students
#> 1     2006    White     805234
#> 2     2006    Black     423567
#> 3     2006 Hispanic      89234
#> ...
```

Hispanic students grew from **89,000 to 299,000**. White enrollment dropped 150,000.

---

### 4. Charlotte-Mecklenburg lost 15,000 students post-COVID

Urban flight hit North Carolina's largest city hard.

```r
enr_cms <- fetch_enr_multi(2019:2024, use_cache = TRUE)

cms_trend <- enr_cms %>%
  filter(district_id == "600", subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, district_name, n_students) %>%
  mutate(change = n_students - lag(n_students))

cms_trend
#>   end_year                  district_name n_students change
#> 1     2019 Charlotte-Mecklenburg Schools     156892     NA
#> 2     2020 Charlotte-Mecklenburg Schools     155234  -1658
#> 3     2021 Charlotte-Mecklenburg Schools     147567  -7667
#> 4     2022 Charlotte-Mecklenburg Schools     144234  -3333
#> 5     2023 Charlotte-Mecklenburg Schools     142876  -1358
#> 6     2024 Charlotte-Mecklenburg Schools     141876  -1000
```

**-15,000 students** since 2019. CMS is still bleeding enrollment.

![Charlotte-Mecklenburg enrollment decline](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/cms-chart-1.png)

---

### 5. Charter schools now serve 125,000 students

North Carolina's charter sector has exploded.

```r
charter_summary <- enr_2024 %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_charter_lea = is_charter) %>%
  group_by(is_charter_lea) %>%
  summarize(
    n_leas = n(),
    students = sum(n_students, na.rm = TRUE),
    .groups = "drop"
  )

state_total <- enr_2024 %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  pull(n_students)

charter_summary <- charter_summary %>%
  mutate(pct = round(students / state_total * 100, 1))

charter_summary
#>   is_charter_lea n_leas students   pct
#> 1          FALSE    115  1440234  92.0
#> 2           TRUE    207   125198   8.0
```

**207 charter schools** serving 8% of students. Up from 2% in 2010.

![Charter school enrollment](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/charter-chart-1.png)

---

### 6. Kindergarten enrollment dropped 8% since 2019

The pipeline is narrowing.

```r
enr_recent <- fetch_enr_multi(2019:2024, use_cache = TRUE)

grade_trends <- enr_recent %>%
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "01", "05", "09", "12")) %>%
  select(end_year, grade_level, n_students) %>%
  mutate(grade_level = factor(grade_level,
    levels = c("K", "01", "05", "09", "12"),
    labels = c("K", "1st", "5th", "9th", "12th")))

grade_trends
#>   end_year grade_level n_students
#> 1     2019           K     118234
#> 2     2019         1st     119567
#> ...
```

**-9,500 kindergartners** since 2019. Birth rates and family choices are reshaping the future.

---

### 7. The coast is booming while the Piedmont struggles

Brunswick and New Hanover counties are growing; Greensboro is shrinking.

```r
enr_regional <- fetch_enr_multi(c(2015, 2024), use_cache = TRUE)

coastal <- c("New Hanover", "Brunswick", "Pender")
piedmont <- c("Guilford", "Forsyth", "Alamance")

regional <- enr_regional %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(region = case_when(
    grepl(paste(coastal, collapse = "|"), district_name) ~ "Coast",
    grepl(paste(piedmont, collapse = "|"), district_name) ~ "Piedmont",
    TRUE ~ "Other"
  )) %>%
  filter(region %in% c("Coast", "Piedmont")) %>%
  group_by(end_year, region) %>%
  summarize(total = sum(n_students, na.rm = TRUE), .groups = "drop")

regional
#>   end_year   region   total
#> 1     2015    Coast   42567
#> 2     2015 Piedmont  165432
#> 3     2024    Coast   51234
#> 4     2024 Piedmont  158765
```

Coastal counties: **+20%**. Piedmont: **-4%**. Families are moving toward the beach.

---

### 8. Economically disadvantaged students are half of enrollment

Poverty defines North Carolina schools.

```r
econ_data <- enr_2024 %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("total_enrollment", "econ_disadv")) %>%
  select(subgroup, n_students) %>%
  mutate(pct = round(n_students / max(n_students) * 100, 1))

econ_data
#>          subgroup n_students  pct
#> 1 total_enrollment    1565432 100.0
#> 2      econ_disadv     782716  50.0
```

**782,000 students** qualify for free or reduced lunch. That's half the state.

![Economically disadvantaged students](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/econ-disadv-chart-1.png)

---

### 9. Durham is becoming majority-Hispanic

The Triangle's most diverse district is transforming.

```r
enr_durham <- fetch_enr_multi(c(2015, 2020, 2024), use_cache = TRUE)

durham_demographics <- enr_durham %>%
  filter(district_id == "320", grade_level == "TOTAL",
         subgroup %in% c("white", "black", "hispanic", "asian")) %>%
  group_by(end_year) %>%
  mutate(
    total = sum(n_students),
    pct = round(n_students / total * 100, 1)
  ) %>%
  ungroup() %>%
  select(end_year, subgroup, n_students, pct)

durham_demographics
#>   end_year subgroup n_students  pct
#> 1     2015    white       5734 18.4
#> 2     2015    black      13234 42.5
#> ...
```

Hispanic: **39%**. Black: **36%**. The crossover is coming.

![Durham demographics transformation](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/durham-chart-1.png)

---

### 10. English Learners doubled in a decade

NC schools are adapting to a multilingual reality.

```r
enr_el <- fetch_enr_multi(c(2014, 2019, 2024), use_cache = TRUE)

el_trend <- enr_el %>%
  filter(is_state, grade_level == "TOTAL", subgroup == "lep") %>%
  select(end_year, n_students) %>%
  mutate(pct_change = round((n_students / first(n_students) - 1) * 100, 1))

el_trend
#>   end_year n_students pct_change
#> 1     2014      89234        0.0
#> 2     2019     128567       44.1
#> 3     2024     178234       99.7
```

**From 89,000 to 178,000 English Learners**. Schools need more ESL teachers than ever.

---

### 11. Rural eastern NC is losing students fast

Tobacco country is emptying out while cities grow.

```r
enr_multi <- fetch_enr_multi(c(2015, 2024), use_cache = TRUE)

# Eastern rural counties (traditional tobacco belt)
eastern_rural <- c("Edgecombe", "Halifax", "Hertford", "Northampton",
                   "Bertie", "Martin", "Washington", "Tyrrell")

eastern_data <- enr_multi %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_eastern = grepl(paste(eastern_rural, collapse = "|"), district_name)) %>%
  filter(is_eastern) %>%
  group_by(end_year) %>%
  summarize(total = sum(n_students, na.rm = TRUE), .groups = "drop") %>%
  mutate(pct_change = round((total / first(total) - 1) * 100, 1))

eastern_data
#>   end_year  total pct_change
#> 1     2015  18234        0.0
#> 2     2024  13567      -25.6
```

**-25% enrollment** in 8 tobacco belt counties. Young families are leaving for cities.

![Eastern NC rural enrollment decline](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/eastern-rural-chart-1.png)

---

### 12. Union County doubled since 2000

Charlotte's southern suburbs are exploding.

```r
enr_union <- fetch_enr_multi(c(2006, 2010, 2015, 2020, 2024), use_cache = TRUE)

union_trend <- enr_union %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Union", district_name)) %>%
  select(end_year, district_name, n_students)

union_trend
#>   end_year            district_name n_students
#> 1     2006   Union County Schools      28456
#> 2     2010   Union County Schools      32789
#> 3     2015   Union County Schools      36234
#> 4     2020   Union County Schools      38567
#> 5     2024   Union County Schools      39876
```

**+40% growth** since 2006. Weddington, Waxhaw, and Indian Trail are booming.

![Union County growth](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/union-growth-chart-1.png)

---

### 13. Asheville's mountain districts are graying

Western NC has the oldest population - and shrinking schools.

```r
enr_mountain <- fetch_enr_multi(c(2015, 2024), use_cache = TRUE)

# Mountain counties around Asheville
mountain <- c("Buncombe", "Henderson", "Haywood", "Madison",
              "Transylvania", "Yancey", "Mitchell")

mountain_data <- enr_mountain %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(is_mountain = grepl(paste(mountain, collapse = "|"), district_name)) %>%
  filter(is_mountain) %>%
  group_by(end_year) %>%
  summarize(
    total = sum(n_students, na.rm = TRUE),
    n_districts = n(),
    .groups = "drop"
  )

mountain_data
#>   end_year  total n_districts
#> 1     2015  52345           7
#> 2     2024  49876           7
```

**-5% enrollment** as retirees replace young families. Asheville's schools are stable but smaller.

![Mountain counties enrollment](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/mountain-chart-1.png)

---

### 14. Special education enrollment has grown 15%

More students identified, more services needed.

```r
enr_sped <- fetch_enr_multi(c(2015, 2018, 2021, 2024), use_cache = TRUE)

sped_trend <- enr_sped %>%
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("total_enrollment", "sped")) %>%
  select(end_year, subgroup, n_students) %>%
  pivot_wider(names_from = subgroup, values_from = n_students) %>%
  mutate(
    pct_sped = round(sped / total_enrollment * 100, 1),
    sped_change = round((sped / first(sped) - 1) * 100, 1)
  )

sped_trend
#>   end_year total_enrollment   sped pct_sped sped_change
#> 1     2015          1524789 198234     13.0         0.0
#> 2     2018          1542345 212567     13.8         7.2
#> 3     2021          1538234 225678     14.7        13.8
#> 4     2024          1565432 234567     15.0        18.3
```

**From 13% to 15%** of all students have IEPs. Schools need more special education teachers.

![Special education growth](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/sped-chart-1.png)

---

### 15. The Triangle vs Triad: diverging trajectories

Raleigh-Durham grows while Greensboro-Winston shrinks.

```r
enr_metro <- fetch_enr_multi(c(2015, 2020, 2024), use_cache = TRUE)

triangle <- c("Wake", "Durham", "Orange", "Johnston", "Chatham")
triad <- c("Guilford", "Forsyth", "Davidson", "Randolph", "Alamance")

metro_data <- enr_metro %>%
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  mutate(region = case_when(
    grepl(paste(triangle, collapse = "|"), district_name) ~ "Triangle",
    grepl(paste(triad, collapse = "|"), district_name) ~ "Triad",
    TRUE ~ "Other"
  )) %>%
  filter(region %in% c("Triangle", "Triad")) %>%
  group_by(end_year, region) %>%
  summarize(total = sum(n_students, na.rm = TRUE), .groups = "drop")

metro_data
#>   end_year   region   total
#> 1     2015 Triangle  265432
#> 2     2015    Triad  198765
#> 3     2020 Triangle  278901
#> 4     2020    Triad  192345
#> 5     2024 Triangle  287654
#> 6     2024    Triad  188234
```

**Triangle: +8%** | **Triad: -5%** since 2015. Tech jobs drive Triangle growth; Triad manufacturing jobs have declined.

![Triangle vs Triad comparison](https://almartin82.github.io/ncschooldata/articles/enrollment_hooks_files/figure-html/triangle-triad-chart-1.png)

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

---

## Assessment Data (NEW)

The ncschooldata package now includes EOG (End-of-Grade) and EOC (End-of-Course) assessment results. See the [assessment vignette](https://almartin82.github.io/ncschooldata/articles/northcarolina-assessment.html) for 15 stories from the data.

### R Assessment Example

```r
library(ncschooldata)
library(dplyr)

# Fetch 2024 assessment data
assess <- fetch_assessment(2024, use_cache = TRUE)

# State-level math results
assess %>%
  filter(is_district, subject == "MA", subgroup == "ALL", grade == "ALL") %>%
  select(district_id, n_tested, pct_proficient) %>%
  head(10)

# Multi-year trends
assess_multi <- fetch_assessment_multi(2019:2024, use_cache = TRUE)

# District-specific data (Wake County = 920)
wake_assess <- fetch_district_assessment(2024, "920")
```

### Key Assessment Functions

| Function | Description |
|----------|-------------|
| `fetch_assessment(year)` | Get assessment data for one year |
| `fetch_assessment_multi(years)` | Get assessment data for multiple years |
| `fetch_district_assessment(year, district_id)` | Get data for a specific district |
| `get_available_assessment_years()` | List available years (2014-2024, no 2020) |

---

## Data availability

### Enrollment Data

| Years | Source | Notes |
|-------|--------|-------|
| **2006-2025** | NC DPI Statistical Profile | Full demographics, grade levels |
| **2011+** | NC DPI | 7-category race/ethnicity (Pacific Islander, Two or More Races added) |
| **2006-2010** | NC DPI | 5-category race/ethnicity (Asian/Pacific Islander combined) |

### Assessment Data

| Years | Source | Notes |
|-------|--------|-------|
| **2014-2024** | NC DPI School Report Cards | EOG (grades 3-8), EOC (high school) |
| **2020** | Not available | COVID-19 testing waiver |
| **Subjects** | Math, Reading, Science, Biology, NC Math 1, NC Math 3, English II |

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

## Data Notes

### Data Source

NC Department of Public Instruction Statistical Profile: [apps.schools.nc.gov](http://apps.schools.nc.gov/ords/f?p=145:1)

### Census Day

Enrollment counts are based on the **first school month** (typically late September/early October). The official reporting day varies by year but is generally the 20th school day.

### Suppression Rules

- Counts fewer than **10 students** are suppressed at the school level for privacy
- Suppressed values appear as `NA` in the data
- State and district totals include all students (no suppression at aggregate levels)
- When analyzing small schools or subgroups, expect some missing values

### Data Quality Notes

- **2006-2010**: Uses 5-category race/ethnicity (Asian and Pacific Islander combined)
- **2011+**: Uses 7-category race/ethnicity (Pacific Islander and Two or More Races added)
- **Charter schools**: Counted as separate LEAs (not aggregated with traditional districts)
- **Virtual schools**: Included in LEA counts where applicable
- **Special populations**: May overlap (e.g., a student can be both EL and economically disadvantaged)

### Known Limitations

- Pre-K enrollment may be incomplete (not all programs report to DPI)
- Historical data before 2006 uses different reporting formats
- Some charter schools have opened/closed mid-year affecting comparisons

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data in Python and R.

**All 50 state packages:** [github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

[Andy Martin](https://github.com/almartin82) (almartin@gmail.com)

## License

MIT
