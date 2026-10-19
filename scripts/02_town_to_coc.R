# 02_town_to_coc.R
# Assign every Massachusetts town and every SAMHSA facility to a HUD Continuum of Care (CoC)
# by point-in-polygon, then build one summary row per CoC.
# Method (decided 2026-10-15): town "point on surface" inside CoC polygon; spot-check
# against each CoC's published member towns (output: data/processed/town_to_coc.csv).
# Inputs : data/raw/OOD_DeathsAll-DataDownload.csv  (DPH dashboard download, opioid tab, All communities)
#          data/interim/samhsa_ma_facilities.csv     (from 01_download_samhsa.R)
#          data/processed/pit_2025_ma_coc.csv        (HUD PIT 2025, MA CoCs)
# Outputs: data/processed/town_to_coc.csv, data/processed/coc_summary_ma.csv
# NOT yet tested on your machine: run line by line the first time and read the checks.

library(here); library(sf); library(tigris); library(dplyr); library(readr); library(stringr); library(tidyr)
options(tigris_use_cache = TRUE)
sf_use_s2(FALSE)

dir.create(here("data", "raw", "hud_coc_ma"), recursive = TRUE, showWarnings = FALSE)
dpH_file <- here("data", "raw", "OOD_DeathsAll-DataDownload.csv")   # change if you named it differently
stopifnot(file.exists(dpH_file))

# ---- 1. HUD CoC boundaries for Massachusetts (2025) ----
coc_zip <- here("data", "raw", "CoC_GIS_State_Shapefile_MA_2025.zip")
if (!file.exists(coc_zip)) {
  ok <- try(download.file("https://files.hudexchange.info/reports/published/CoC_GIS_State_Shapefile_MA_2025.zip",
                          coc_zip, mode = "wb"), silent = TRUE)
  if (inherits(ok, "try-error") || !file.exists(coc_zip))
    stop("Download failed. Get the Massachusetts CoC shapefile from HUD Exchange (CoC GIS Tools page) ",
         "and save it as ", coc_zip)
}
unzip(coc_zip, exdir = here("data", "raw", "hud_coc_ma"))
shp <- list.files(here("data", "raw", "hud_coc_ma"), pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
message("Shapefiles found: ", paste(basename(shp), collapse = ", "))
# HUD ships ONE shapefile per CoC (one polygon each): read them all and stack them.
coc <- bind_rows(lapply(shp, st_read, quiet = TRUE))
stopifnot(nrow(coc) == 11)   # 11 MA CoCs in 2025
message("CoC columns: ", paste(names(coc), collapse = ", "))
num_col  <- names(coc)[str_detect(names(coc), regex("COCNUM|CoC_?Number", ignore_case = TRUE))][1]
name_col <- names(coc)[str_detect(names(coc), regex("COCNAME|CoC_?Name", ignore_case = TRUE))][1]
stopifnot(!is.na(num_col), !is.na(name_col))
coc <- coc |> transmute(coc_number = .data[[num_col]], coc_name_shp = .data[[name_col]], geometry) |>
  st_transform(26986) |> st_make_valid()
print(st_drop_geometry(coc))   # CHECK: expect the 11 MA CoCs (MA-500 ... MA-516)
message("CoC CRS (after transform): ", st_crs(coc)$input); print(st_bbox(coc))
print(st_is_valid(coc)); print(round(as.numeric(st_area(coc)) / 1e6))   # area in sq km

# ---- 2. Census town boundaries ----
towns_sf <- county_subdivisions("MA", cb = FALSE, year = 2024) |>
  filter(!str_detect(NAME, "not defined")) |>
  mutate(town = str_remove(NAME, " Town$"),                     # Census says "Agawam Town"; DPH says "Agawam"
         town = if_else(town == "Manchester-by-the-Sea", "Manchester", town)) |>
  select(town, geometry) |> st_transform(26986) |> st_make_valid()
message("Census towns: ", nrow(towns_sf), " (DPH dashboard has 351)")
print(st_bbox(towns_sf))   # CHECK: should be nearly the same box as the CoC bbox above

town_pts <- st_point_on_surface(towns_sf)
joined <- st_join(town_pts, coc, join = st_within)
unassigned <- is.na(joined$coc_number)
if (any(unassigned)) {
  message(sum(unassigned), " towns outside every CoC polygon, assigned to NEAREST CoC (flagged): ",
          paste(joined$town[unassigned], collapse = ", "))
  nn <- st_nearest_feature(joined[unassigned, ], coc)
  joined$coc_number[unassigned] <- coc$coc_number[nn]
}
joined$assign_method <- ifelse(unassigned, "nearest", "within")
if (anyDuplicated(joined$town)) warning("Some towns matched >1 CoC polygon: ", paste(joined$town[duplicated(joined$town)], collapse = ", "))
town_coc <- joined |> st_drop_geometry() |> distinct(town, .keep_all = TRUE) |> select(town, coc_number, assign_method)

# ---- 3. Opioid overdose deaths by town and year (race summed; race cells are too small to use) ----
dph <- read_csv(dpH_file, show_col_types = FALSE) |>
  filter(DASHBOARD_VISUAL == "Opioid-Related Overdose Deaths Trend", COMMUNITY_TYPE == "City/Town") |>
  mutate(year = as.integer(str_sub(DATE_RANGE, -4)), deaths = as.numeric(METRIC_VALUE))
town_deaths <- dph |> group_by(town = CITY_TOWN, year) |> summarise(deaths = sum(deaths), .groups = "drop")
town_pop <- dph |> distinct(town = CITY_TOWN, pop = as.numeric(CITY_TOWN_POPULATION))

unmatched <- setdiff(unique(town_deaths$town), town_coc$town)
message("Towns in DPH but not in Census: ", length(unmatched), " ", paste(unmatched, collapse = ", "))
stopifnot(length(unmatched) == 0)   # every DPH town must map to a CoC, or deaths are silently lost

town_out <- town_coc |> left_join(town_pop, by = "town") |> arrange(coc_number, town)
write_csv(town_out, here("data", "processed", "town_to_coc.csv"))

deaths_coc <- town_deaths |> inner_join(town_coc, by = "town") |>
  group_by(coc_number, year) |> summarise(deaths = sum(deaths), .groups = "drop") |>
  pivot_wider(names_from = year, values_from = deaths, names_prefix = "deaths_")
pop_coc <- town_out |> group_by(coc_number) |> summarise(population = sum(pop, na.rm = TRUE), n_towns = n())

# CHECK: CoC deaths must add up to the statewide totals (971 in 2025)
print(deaths_coc |> summarise(across(starts_with("deaths_"), sum)))

# ---- 4. SAMHSA facilities -> CoC ----
fac <- read_csv(here("data", "interim", "samhsa_ma_facilities.csv"), show_col_types = FALSE) |>
  mutate(def_narrow_a2 = is_moud & sliding_fee, fac_id = row_number())
no_xy <- is.na(fac$lat) | is.na(fac$lon)
fac_sf <- st_as_sf(fac[!no_xy, ], coords = c("lon", "lat"), crs = 4326) |> st_transform(26986)
print(st_bbox(fac_sf))   # CHECK: should sit inside the CoC bbox printed above
fj <- st_join(fac_sf, coc, join = st_within)
if (nrow(fj) > nrow(fac_sf)) warning("Some facilities fall in >1 CoC polygon (overlapping boundaries); first match kept")
fj <- fj |> distinct(fac_id, .keep_all = TRUE)   # one row per facility listing, by row ID
if (any(is.na(fj$coc_number))) {
  message(sum(is.na(fj$coc_number)), " facilities outside every CoC polygon (assigned to nearest, flagged)")
  idx <- which(is.na(fj$coc_number)); fj$coc_number[idx] <- coc$coc_number[st_nearest_feature(fj[idx, ], coc)]
}
fj_df <- fj |> st_drop_geometry() |> mutate(coc_method = "point")

# The SAMHSA API has no coordinates for some facilities: place them by city name instead.
village_to_town <- c("Feeding Hills" = "Agawam", "Jamaica Plain" = "Boston", "Roxbury" = "Boston",
                     "Dorchester Center" = "Boston", "Vineyard Haven" = "Tisbury")   # extend by hand for villages that show up below
fac_nocoord <- fac[no_xy, ] |>
  mutate(town_key = coalesce(unname(village_to_town[city]), city)) |>
  left_join(town_coc |> select(town, coc_number), by = c("town_key" = "town")) |>
  mutate(coc_method = "city name")
if (any(is.na(fac_nocoord$coc_number))) {
  message("Facilities with no coordinates AND no town match (assign by hand): ")
  print(fac_nocoord |> filter(is.na(coc_number)) |> select(name1, city), n = Inf)
}
fj_df <- bind_rows(fj_df, fac_nocoord |> filter(!is.na(coc_number)))

fac_coc <- fj_df |> group_by(coc_number) |>
  summarise(fac_broad = n(), fac_moud = sum(is_moud), fac_narrow_a2 = sum(def_narrow_a2),
            fac_narrow_a = sum(def_narrow), fac_otp = sum(is_otp), .groups = "drop")
print(fac_coc |> summarise(across(starts_with("fac_"), sum)))   # CHECK: 337, 275, 71, 244, 61

# ---- 5. One row per CoC ----
pit <- read_csv(here("data", "processed", "pit_2025_ma_coc.csv"), show_col_types = FALSE) |>
  select(coc_number, coc_name, pit_overall = overall_homeless, pit_sheltered = sheltered_homeless,
         pit_unsheltered = unsheltered_homeless, pit_hispanic = hispanic_total, pit_nh_black = nh_black, pit_nh_white = nh_white)
summary_coc <- pit |> left_join(pop_coc, by = "coc_number") |> left_join(deaths_coc, by = "coc_number") |>
  left_join(fac_coc, by = "coc_number") |>
  mutate(across(starts_with("fac_"), ~ replace_na(.x, 0)))
write_csv(summary_coc, here("data", "processed", "coc_summary_ma.csv"))
print(summary_coc |> select(coc_number, pit_overall, population, deaths_2025, fac_broad, fac_moud, fac_narrow_a2, fac_otp), width = Inf)
message("Spot-check: open data/processed/town_to_coc.csv and compare a few CoCs with their published member towns.")
