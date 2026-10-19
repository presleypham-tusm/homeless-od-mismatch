# 03_figures.R
# Exploratory figures for the MA homelessness / opioid overdose / treatment project.
# Reads only files already in data/processed/. Writes PNGs to output/figures/.
# Run from the RStudio project (homeless-od-mismatch.Rproj) so here() resolves.

library(here)
library(readr)
library(dplyr)
library(tidyr)
library(forcats)
library(ggplot2)
library(scales)
library(ggrepel)   # install.packages("ggrepel") if needed, then renv::snapshot()

dir.create(here("output", "figures"), recursive = TRUE, showWarnings = FALSE)

# ---- 1. Load and check ------------------------------------------------------
coc <- read_csv(here("data", "processed", "coc_summary_ma.csv"), show_col_types = FALSE)
need <- c("coc_number", "pit_overall", "population", "deaths_2025", "fac_moud", "fac_narrow_a2")
stopifnot(all(need %in% names(coc)), nrow(coc) == 11)
stopifnot(sum(coc$pit_overall) == 28311, sum(coc$deaths_2025) == 971)  # tie-out totals

labels <- tribble(
  ~coc_number, ~coc_label,
  "MA-500", "Boston",
  "MA-502", "Lynn",
  "MA-503", "Cape & Islands",
  "MA-504", "Springfield/Hampden",
  "MA-505", "New Bedford/Bristol",
  "MA-506", "Worcester",
  "MA-507", "Berkshire/Franklin/Hampshire",
  "MA-509", "Cambridge",
  "MA-511", "Quincy/Brockton/Plymouth",
  "MA-515", "Fall River",
  "MA-516", "Balance of State"
)

d <- coc |>
  left_join(labels, by = "coc_number") |>
  mutate(
    homeless_per_10k   = pit_overall / population * 1e4,
    deaths_per_100k    = deaths_2025 / population * 1e5,
    moud_per_100k      = fac_moud / population * 1e5,
    sliding_per_100k   = fac_narrow_a2 / population * 1e5
  )
stopifnot(!anyNA(d$coc_label))

theme_set(theme_minimal(base_size = 12) +
            theme(plot.title.position = "plot",
                  panel.grid.minor = element_blank(),
                  strip.text = element_text(face = "bold")))

# ---- 2. Figure 1: four measures by CoC, same order in every panel ----------
order_levels <- d |> arrange(homeless_per_10k) |> pull(coc_label)

long <- d |>
  select(coc_label, homeless_per_10k, deaths_per_100k, moud_per_100k, sliding_per_100k) |>
  pivot_longer(-coc_label, names_to = "measure", values_to = "value") |>
  mutate(
    coc_label = factor(coc_label, levels = order_levels),
    measure = factor(measure,
      levels = c("homeless_per_10k", "deaths_per_100k", "moud_per_100k", "sliding_per_100k"),
      labels = c("Homeless Rate\n(per 10,000)", "Opioid Death Rate\n(per 100,000)",
                 "MOUD Facility Rate\n(per 100,000)", "Sliding-Fee MOUD\nFacility Rate\n(per 100,000)"))
  )

fig1 <- ggplot(long, aes(value, coc_label)) +
  geom_col(width = 0.7, fill = "grey35") +
  facet_wrap(~ measure, nrow = 1, scales = "free_x") +
  labs(title = "Rates by Continuum of Care, Massachusetts, 2025",
       subtitle = "CoCs ordered by homeless rate",
       caption = "Sources: HUD 2025 PIT; MA DPH BSAS (provisional); SAMHSA FindTreatment.gov.",
       x = "Rate", y = "Continuum of Care")
ggsave(here("output", "figures", "fig1_rates_by_coc.png"), fig1, width = 12, height = 5, dpi = 300, bg = "white")

# ---- 3. Figure 2: homelessness vs deaths ------------------------------------
rho <- cor(d$homeless_per_10k, d$deaths_per_100k, method = "spearman")

fig2 <- ggplot(d, aes(homeless_per_10k, deaths_per_100k)) +
  geom_point(aes(size = population), alpha = 0.6, colour = "grey25") +
  geom_text_repel(aes(label = coc_label), size = 3.4, min.segment.length = 0.2) +
  scale_size_area(max_size = 12, labels = label_comma(), name = "Population") +
  labs(title = "Opioid Death Rate vs. Homeless Rate",
       subtitle = sprintf("Continuums of Care, Massachusetts, 2025 (Spearman rho = %.2f)", rho),
       x = "Homeless Rate (per 10,000 residents)", y = "Opioid Death Rate (per 100,000 residents)")
ggsave(here("output", "figures", "fig2_homeless_vs_deaths.png"), fig2, width = 8, height = 6, dpi = 300, bg = "white")

# ---- 4. Figure 3: race shares (context, not a disparity estimate) -----------
pit <- read_csv(here("data", "processed", "pit_2025_ma_coc.csv"), show_col_types = FALSE)
pit_tot <- sum(pit$overall_homeless)
pit_race <- tibble(
  group = c("Black (non-Hispanic)", "Hispanic (any race)", "White (non-Hispanic)"),
  n = c(sum(pit$nh_black), sum(pit$hispanic_total), sum(pit$nh_white))
)
pit_race <- bind_rows(pit_race, tibble(group = "All other", n = pit_tot - sum(pit_race$n)))

# Statewide opioid-death counts by race, 2025, copied from the MA DPH dashboard
# "Opioid-Related Overdose Deaths Trend" visual. TODO: read these from the raw
# download in data/raw/ instead of typing them, so the figure is fully reproducible.
dph_total <- sum(coc$deaths_2025)
dph_race <- tibble(
  group = c("Black (non-Hispanic)", "Hispanic (any race)", "White (non-Hispanic)"),
  n = c(87, 166, 699)
)
dph_race <- bind_rows(dph_race, tibble(group = "All other", n = dph_total - sum(dph_race$n)))

race <- bind_rows(
  pit_race |> mutate(source = "Homeless count (HUD PIT)", share = n / sum(n)),
  dph_race |> mutate(source = "Opioid deaths (MA DPH)", share = n / sum(n))
) |> mutate(group = factor(group, levels = rev(c("Black (non-Hispanic)", "Hispanic (any race)",
                                                  "White (non-Hispanic)", "All other"))))

fig3 <- ggplot(race, aes(share, group, fill = source)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65) +
  geom_text(aes(label = percent(share, accuracy = 0.1)),
            position = position_dodge(width = 0.75), hjust = -0.1, size = 3.3) +
  scale_x_continuous(labels = percent, expand = expansion(mult = c(0, 0.12))) +
  scale_fill_manual(values = c("grey70", "grey25"), name = NULL) +
  labs(title = "Racial/Ethnic Composition: Homeless Count vs. Opioid Deaths",
       subtitle = "Massachusetts, 2025",
       x = "Share of Total", y = "Race/Ethnicity") +
  theme(legend.position = "top")
ggsave(here("output", "figures", "fig3_race_shares.png"), fig3, width = 8, height = 4.5, dpi = 300, bg = "white")

message("Wrote 3 figures to output/figures/")
