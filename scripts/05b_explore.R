# 05b_explore.R
# Exploratory checks on data/processed/model_dataset.csv BEFORE any model is fit.
# Questions: (1) what do the counts look like, (2) are the predictors too correlated to use together,
# (3) is the variance of deaths much larger than the mean (overdispersion)?
# Outputs: output/figures/explore_*.png, output/tables/explore_*.csv

library(here); library(dplyr); library(readr); library(ggplot2); library(tidyr); library(scales)
dir.create(here("output", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("output", "tables"),  recursive = TRUE, showWarnings = FALSE)

dat <- read_csv(here("data", "processed", "model_dataset.csv"), show_col_types = FALSE) |>
  mutate(rate_100k = 1e5 * deaths_2025 / pop)

# ---- 1. Counts ----
p1 <- ggplot(dat, aes(deaths_2025)) + geom_histogram(binwidth = 1, boundary = -0.5) +
  coord_cartesian(xlim = c(-0.5, 20)) +
  labs(title = "Frequency vs. Town Opioid Deaths, 2025", x = "Opioid-related deaths (axis cut at 20)", y = "Number of towns") +
  theme_minimal()
ggsave(here("output", "figures", "explore_1_deaths_hist.png"), p1, width = 6, height = 4, dpi = 300)

zero_by_coc <- dat |> group_by(coc_number) |>
  summarise(towns = n(), zero_death_towns = sum(deaths_2025 == 0), pct_zero = round(100 * mean(deaths_2025 == 0)), .groups = "drop")
print(zero_by_coc)
write_csv(zero_by_coc, here("output", "tables", "explore_zero_by_coc.csv"))

# ---- 2. Overdispersion: variance vs mean (Poisson would give variance = mean) ----
m <- mean(dat$deaths_2025); v <- var(dat$deaths_2025)
cat(sprintf("\nMean deaths per town: %.2f   Variance: %.2f   Variance/mean: %.1f\n", m, v, v / m))
# Same, excluding Boston (its 128 deaths drives the variance)
nb <- dat |> filter(town != "Boston")
cat(sprintf("Without Boston: mean %.2f, variance %.2f, ratio %.1f\n", mean(nb$deaths_2025), var(nb$deaths_2025), var(nb$deaths_2025) / mean(nb$deaths_2025)))

# ---- 3. Town death rate vs CoC homelessness ----
p2 <- ggplot(dat, aes(homeless_per_10k, rate_100k, size = pop)) + geom_point(alpha = 0.4) +
  scale_size_continuous(range = c(0.5, 6), labels = comma) +
  labs(title = "Town Death Rate vs. CoC Homelessness Rate, 2025", x = "CoC homeless per 10,000 (2025 PIT)",
       y = "Town opioid deaths per 100,000", size = "Town population") + theme_minimal()
ggsave(here("output", "figures", "explore_2_rate_vs_homeless.png"), p2, width = 6.5, height = 4.5, dpi = 300)

p3 <- ggplot(dat, aes(dist_moud_km, rate_100k, size = pop)) + geom_point(alpha = 0.4) +
  scale_size_continuous(range = c(0.5, 6), labels = comma) +
  labs(title = "Town Death Rate vs. Distance to Nearest MOUD Facility", x = "Distance to nearest MOUD facility (km)",
       y = "Town opioid deaths per 100,000", size = "Town population") + theme_minimal()
ggsave(here("output", "figures", "explore_3_rate_vs_distance.png"), p3, width = 6.5, height = 4.5, dpi = 300)

# ---- 4. Collinearity among candidate predictors ----
preds <- c("homeless_per_10k", "moud_per_100k", "dist_moud_km", "pct_poverty", "pct_age_25_44", "pct_black_nh", "pct_hispanic")
cors <- round(cor(dat[preds], method = "spearman", use = "complete.obs"), 2)
print(cors)
write.csv(cors, here("output", "tables", "explore_predictor_correlations.csv"))
# CHECK: any |rho| above about 0.7 means two predictors carry nearly the same information.
hi <- which(abs(cors) > 0.7 & upper.tri(cors), arr.ind = TRUE)
if (nrow(hi)) print(data.frame(a = rownames(cors)[hi[, 1]], b = colnames(cors)[hi[, 2]], rho = cors[hi])) else cat("\nNo pair above 0.7.\n")

# CoC-level predictors take only 11 distinct values: show them next to the number of towns.
print(dat |> distinct(coc_number, homeless_per_10k, moud_per_100k) |> arrange(coc_number))
