# 05_model_dataset.R
# Build the one-row-per-town analysis table (351 rows) for scripts/06_models.R.
# Inputs : data/raw/OOD_DeathsAll-DataDownload.csv, data/processed/{town_to_coc,coc_summary_ma,acs_town_covariates}.csv,
#          data/interim/samhsa_ma_facilities.csv
# Output : data/processed/model_dataset.csv
# Run from the RStudio project. Read every CHECK printed below before moving on.

library(here); library(sf); library(tigris); library(dplyr); library(readr); library(stringr); library(tidyr)
options(tigris_use_cache = TRUE); sf_use_s2(FALSE)

# ---- 1. Town deaths (race summed), 2024 and 2025 ----
dph <- read_csv(here("data", "raw", "OOD_DeathsAll-DataDownload.csv"), show_col_types = FALSE) |>
  filter(DASHBOARD_VISUAL == "Opioid-Related Overdose Deaths Trend", COMMUNITY_TYPE == "City/Town") |>
  mutate(year = as.integer(str_sub(DATE_RANGE, -4)), deaths = as.numeric(METRIC_VALUE))
deaths <- dph |> group_by(town = CITY_TOWN, year) |> summarise(deaths = sum(deaths), .groups = "drop") |>
  filter(year %in% c(2024, 2025)) |>
  pivot_wider(names_from = year, values_from = deaths, names_prefix = "deaths_") |>
  mutate(deaths_2024_25 = deaths_2024 + deaths_2025)

# ---- 2. Join crosswalk, covariates, CoC-level exposures ----
xw  <- read_csv(here("data", "processed", "town_to_coc.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "processed", "acs_town_covariates.csv"), show_col_types = FALSE) |>
  select(town, pct_poverty, pct_age_25_44, pct_black_nh, pct_hispanic, rent_pct_income)
coc <- read_csv(here("data", "processed", "coc_summary_ma.csv"), show_col_types = FALSE) |>
  transmute(coc_number, pit_overall, coc_pop = population,
            homeless_per_10k = 1e4 * pit_overall / coc_pop,
            moud_per_100k    = 1e5 * fac_moud / coc_pop,
            a2_per_100k      = 1e5 * fac_narrow_a2 / coc_pop,
            otp_per_100k     = 1e5 * fac_otp / coc_pop)

dat <- xw |> rename(pop = pop) |>
  left_join(deaths, by = "town") |> left_join(cov, by = "town") |> left_join(coc, by = "coc_number") |>
  mutate(small_town = pop < 1000)

# ---- 3. Town-level distance to nearest MOUD facility (km, straight line) ----
towns_sf <- county_subdivisions("MA", cb = FALSE, year = 2024) |>
  filter(!str_detect(NAME, "not defined")) |>
  mutate(town = str_remove(NAME, " Town$"), town = if_else(town == "Manchester-by-the-Sea", "Manchester", town)) |>
  select(town, geometry) |> st_transform(26986) |> st_make_valid()
pts <- st_point_on_surface(towns_sf)

# Facilities: use real coordinates when SAMHSA has them; otherwise place the facility at the
# point-on-surface of its town (accurate to town scale; fine for a distance covariate).
fac_all <- read_csv(here("data", "interim", "samhsa_ma_facilities.csv"), show_col_types = FALSE) |>
  filter(is_moud) |>                                      # A2 is a subset of MOUD
  mutate(def_narrow_a2 = is_moud & sliding_fee, fac_id = row_number())
has_xy <- !is.na(fac_all$lat) & !is.na(fac_all$lon)
village_to_town <- c("Feeding Hills" = "Agawam", "Jamaica Plain" = "Boston", "Roxbury" = "Boston",
                     "Dorchester Center" = "Boston", "Vineyard Haven" = "Tisbury")
miss <- fac_all[!has_xy, ] |> mutate(town_key = coalesce(unname(village_to_town[city]), city))
idx <- match(miss$town_key, pts$town)
if (anyNA(idx)) print(miss$city[is.na(idx)])               # CHECK: must print nothing
stopifnot(!anyNA(idx))
fac_sf <- rbind(
  st_as_sf(fac_all[has_xy, ], coords = c("lon", "lat"), crs = 4326) |> st_transform(26986) |>
    select(fac_id, is_moud, def_narrow_a2),
  st_sf(miss |> select(fac_id, is_moud, def_narrow_a2), geometry = st_geometry(pts)[idx])
)
message("MOUD facilities used: ", nrow(fac_sf), " (", sum(has_xy), " with coordinates, ", sum(!has_xy),
        " placed by town); A2: ", sum(fac_sf$def_narrow_a2), " (expect 275 MOUD, 71 A2)")
stopifnot(nrow(fac_sf) == 275, sum(fac_sf$def_narrow_a2) == 71)

nearest_km <- function(pts, facs) {
  d <- st_distance(pts, facs)                              # metres, towns x facilities
  apply(d, 1, min) / 1000
}
dist_tbl <- tibble(town = pts$town,
                   dist_moud_km = nearest_km(pts, fac_sf[fac_sf$is_moud, ]),
                   dist_a2_km   = nearest_km(pts, fac_sf[fac_sf$def_narrow_a2, ]))
dat <- dat |> left_join(dist_tbl, by = "town")

# ---- 4. Checks (all must pass; the script stops otherwise) ----
stopifnot(nrow(dat) == 351, !anyDuplicated(dat$town))
prim <- c("deaths_2025", "pop", "coc_number", "homeless_per_10k", "moud_per_100k", "dist_moud_km",
          "pct_poverty", "pct_age_25_44", "pct_black_nh", "pct_hispanic")
na_ct <- colSums(is.na(dat[prim])); print(na_ct); stopifnot(all(na_ct == 0))
cat("\nTotal deaths 2025:", sum(dat$deaths_2025), "(expect 971)\n"); stopifnot(sum(dat$deaths_2025) == 971)
chk <- dat |> group_by(coc_number) |> summarise(d = sum(deaths_2025), p = sum(pop)) |>
  left_join(read_csv(here("data", "processed", "coc_summary_ma.csv"), show_col_types = FALSE) |>
              select(coc_number, deaths_2025, population), by = "coc_number")
stopifnot(all(chk$d == chk$deaths_2025), all(chk$p == chk$population))   # town rows tie out to CoC table
cat("Towns under 1,000 residents:", sum(dat$small_town), "\n")
cat("Towns with zero 2025 deaths:", sum(dat$deaths_2025 == 0), "of 351\n")
print(summary(dat |> select(deaths_2025, homeless_per_10k, moud_per_100k, dist_moud_km)))
cat("\nTowns farthest from a MOUD facility:\n"); print(dat |> arrange(desc(dist_moud_km)) |> select(town, coc_number, dist_moud_km) |> head(5))

write_csv(dat, here("data", "processed", "model_dataset.csv"))
