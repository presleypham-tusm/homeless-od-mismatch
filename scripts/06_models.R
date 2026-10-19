# 06_models.R
# Primary model and pre-specified sensitivity checks (docs/analysis_plan.md). Descriptive/associational only.
# Run ONLY after: plan committed (tag plan-v0.1 plus Deviations), BSAS reply on residence vs occurrence recorded.
# Input : data/processed/model_dataset.csv
# Output: output/tables/models_primary.csv, output/tables/models_sensitivity.csv
# Install once:  install.packages(c("glmmTMB", "sandwich", "lmtest")); then renv::snapshot()

library(here); library(dplyr); library(readr); library(tidyr); library(glmmTMB); library(sandwich); library(lmtest)
dir.create(here("output", "tables"), recursive = TRUE, showWarnings = FALSE)

dat <- read_csv(here("data", "processed", "model_dataset.csv"), show_col_types = FALSE)

# Standardize ONCE on the full 351 towns so every model reports rate ratios per 1 SD of the same variable.
zvars <- c("homeless_per_10k", "dist_moud_km", "dist_a2_km", "moud_per_100k", "a2_per_100k", "otp_per_100k",
           "pct_poverty", "pct_age_25_44", "pct_black_nh", "pct_hispanic", "rent_pct_income")
sds <- tibble(variable = zvars, mean = sapply(dat[zvars], mean, na.rm = TRUE), sd = sapply(dat[zvars], sd, na.rm = TRUE))
print(sds); write_csv(sds, here("output", "tables", "models_scaling_sd.csv"))
dat <- dat |> mutate(across(all_of(zvars), ~ as.numeric((.x - mean(.x, na.rm = TRUE)) / sd(.x, na.rm = TRUE)), .names = "z_{.col}"))

covs <- "z_pct_poverty + z_pct_age_25_44 + z_pct_black_nh + z_pct_hispanic"
f_primary <- as.formula(paste("deaths_2025 ~ z_homeless_per_10k + z_dist_moud_km +", covs, "+ offset(log(pop)) + (1 | coc_number)"))

fit_nb <- function(d, f) glmmTMB(f, data = d, family = nbinom2)
irr_nb <- function(m, label) {
  co <- summary(m)$coefficients$cond
  tibble(model = label, term = rownames(co), irr = exp(co[, 1]), lo = exp(co[, 1] - 1.96 * co[, 2]),
         hi = exp(co[, 1] + 1.96 * co[, 2]), p = co[, 4])
}

# ---- Primary ----
m1 <- fit_nb(dat, f_primary)
print(summary(m1))                                   # CHECK: convergence, CoC variance, dispersion (nbinom2 'theta' is sigma(m1))
cat("\nNB dispersion parameter (theta):", round(sigma(m1), 2), "\n")
primary <- irr_nb(m1, "Primary: NB mixed, 2025"); print(primary)
write_csv(primary, here("output", "tables", "models_primary.csv"))

# ---- Sensitivity checks (rate ratios per 1 SD; compare to the primary table) ----
res <- list()
res$boston <- irr_nb(fit_nb(filter(dat, town != "Boston"), f_primary), "1. Drop Boston")

res$loo <- bind_rows(lapply(sort(unique(dat$coc_number)), function(k)
  tryCatch(irr_nb(fit_nb(filter(dat, coc_number != k), f_primary), paste("2. Leave out", k)), error = function(e) NULL)))

pois <- glm(update(f_primary, . ~ . - (1 | coc_number)), data = dat, family = poisson)
ct <- coeftest(pois, vcov = vcovCL(pois, cluster = dat$coc_number))
res$pois <- tibble(model = "3. Poisson, CoC-clustered SE", term = rownames(ct), irr = exp(ct[, 1]),
                   lo = exp(ct[, 1] - 1.96 * ct[, 2]), hi = exp(ct[, 1] + 1.96 * ct[, 2]), p = ct[, 4])

res$a2 <- irr_nb(fit_nb(dat, update(f_primary, . ~ . - z_dist_moud_km + z_dist_a2_km)), "4a. Distance to sliding-fee MOUD (A2)")

res$pool <- irr_nb(fit_nb(dat, update(f_primary, deaths_2024_25 ~ .)), "5. 2024-25 pooled")

coh <- dat; ref <- filter(dat, coc_number == "MA-516")[1, ]   # MA-516 = Balance of State
i <- coh$town == "Cohasset"; stopifnot(sum(i) == 1)
coh$coc_number[i] <- "MA-516"; coh$z_homeless_per_10k[i] <- ref$z_homeless_per_10k
res$cohasset <- irr_nb(fit_nb(coh, f_primary), "6. Cohasset moved to Balance of State")

res$small <- irr_nb(fit_nb(filter(dat, !small_town), f_primary), "7. Drop towns under 1,000 residents")

res$rent <- irr_nb(fit_nb(filter(dat, !is.na(z_rent_pct_income)), update(f_primary, . ~ . + z_rent_pct_income)), "8. Add rent burden (complete case)")

for (v in c("z_moud_per_100k", "z_a2_per_100k", "z_otp_per_100k"))
  res[[v]] <- irr_nb(fit_nb(dat, update(f_primary, as.formula(paste(". ~ . - z_dist_moud_km +", v)))), paste("9. CoC-level exposure:", v))

# 10. CoC-level NB, 11 rows (no covariates: too few rows)
coc <- dat |> group_by(coc_number) |> summarise(deaths = sum(deaths_2025), pop = sum(pop), z_homeless_per_10k = first(z_homeless_per_10k), z_moud_per_100k = first(z_moud_per_100k))
m10 <- MASS::glm.nb(deaths ~ z_homeless_per_10k + z_moud_per_100k + offset(log(pop)), data = coc)
co <- summary(m10)$coefficients
res$coc <- tibble(model = "10. CoC-level NB (11 rows)", term = rownames(co), irr = exp(co[, 1]),
                  lo = exp(co[, 1] - 1.96 * co[, 2]), hi = exp(co[, 1] + 1.96 * co[, 2]), p = co[, 4])

sens <- bind_rows(res) |> mutate(across(c(irr, lo, hi), ~ round(.x, 2)), p = signif(p, 2))
write_csv(sens, here("output", "tables", "models_sensitivity.csv"))
print(sens |> filter(grepl("homeless|dist|moud|a2|otp", term)), n = Inf)
