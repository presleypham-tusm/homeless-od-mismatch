# 01_download_samhsa.R
# Pull ALL Massachusetts substance-use (SA) facilities from the SAMHSA
# FindTreatment.gov API once, save the raw JSON, then flag facility definitions locally.
# Why pull once and filter locally: the API's sCodes filter means "ALL codes",
# so "MOUD OR Medicaid" cannot be asked in one query.
# Output: data/raw/ (untracked raw JSON + code list), data/interim/samhsa_ma_facilities.csv
# Run from the project root (open the .Rproj first). NOT yet tested on your machine.

library(here)
library(httr2)
library(jsonlite)
library(dplyr)
library(purrr)
library(tibble)

dir.create(here("data", "raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "interim"), recursive = TRUE, showWarnings = FALSE)
today <- format(Sys.Date(), "%Y%m%d")
ua <- "homeless-od-mismatch research project (public GitHub repo)"

fetch <- function(req, path) {
  resp <- req |> req_user_agent(ua) |> req_perform()
  writeLines(resp_body_string(resp), path, useBytes = TRUE)
  path
}

# Massachusetts = state ID 3 (Developer Guide, Appendix B). sAddr is "lat,lng" in the
# guide's own working example; the coordinate only seeds the sort order (miles).
api <- "https://findtreatment.gov/locator/exportsAsJson/v2"
raw_json <- here("data", "raw", paste0("samhsa_ma_sa_", today, ".json"))
fetch(request(api) |>
        req_url_query(sAddr = '"42.3601,-71.0589"', limitType = 0, limitValue = 3,
                      sType = "sa", pageSize = 2000, page = 1, sort = 0),
      raw_json)

codes_json <- here("data", "raw", paste0("samhsa_service_codes_", today, ".json"))
fetch(request("https://findtreatment.gov/locator/serviceCategories.json"), codes_json)

parsed <- fromJSON(raw_json, simplifyVector = FALSE)
stopifnot(length(parsed$rows) == parsed$recordCount, parsed$totalPages == 1)
message("Facilities returned: ", parsed$recordCount)   # was 337 on 2026-10-15

get_svc <- function(r, code) {
  hit <- keep(r$services, ~ identical(.x$f2, code))
  if (length(hit) == 0) "" else hit[[1]]$f3 %||% ""
}

fac <- map_dfr(parsed$rows, function(r) {
  tibble(
    name1 = r$name1 %||% NA_character_, name2 = r$name2 %||% NA_character_,
    street1 = r$street1 %||% NA_character_, city = r$city %||% NA_character_,
    state = r$state %||% NA_character_, zip = r$zip %||% NA_character_,
    lat = as.numeric(r$latitude %||% NA), lon = as.numeric(r$longitude %||% NA),
    OM = get_svc(r, "OM"), OT = get_svc(r, "OT"), LCA = get_svc(r, "LCA"),
    PAY = get_svc(r, "PAY"), PYAS = get_svc(r, "PYAS")
  )
})

# EXACT item matching on "; "-separated lists. Substring matching is wrong:
# "Medicaid" is inside "State-financed health insurance plan other than Medicaid".
has <- function(x, item) vapply(strsplit(x, ";", fixed = TRUE),
                                function(v) item %in% trimws(v), logical(1))

fac <- fac |>
  mutate(
    is_otp   = has(OT,  "Federally-certified Opioid Treatment Program"),
    is_sotp  = has(LCA, "SAMHSA certification for opioid treatment program (OTP)"),
    is_moud  = has(OM, "Methadone used in Treatment") | has(OM, "Buprenorphine used in Treatment") |
               has(OM, "Naltrexone used in Treatment") | is_otp | is_sotp |
               has(OT, "Prescribes buprenorphine") | has(OT, "Prescribes naltrexone") |
               has(OT, "Methadone maintenance") | has(OT, "Buprenorphine maintenance"),
    takes_medicaid = has(PAY, "Medicaid"),
    no_payment     = has(PAY, "No payment accepted"),
    sliding_fee    = has(PYAS, "Sliding fee scale (fee is based on income and other factors)"),
    def_broad  = TRUE,
    def_moud   = is_moud,
    def_narrow = is_moud & (takes_medicaid | no_payment | sliding_fee)
  )

# Expected on 2026-10-15 (check against the API filters): broad 337, MOUD 275,
# narrow A 244, OTP 61, SOTP 74, Medicaid 299, sliding fee 80, no payment 1.
fac |> summarise(across(c(def_broad, def_moud, def_narrow, is_otp, is_sotp,
                          takes_medicaid, no_payment, sliding_fee), sum)) |> print()

write.csv(fac, here("data", "interim", "samhsa_ma_facilities.csv"), row.names = FALSE)

# Manifest: what was downloaded, from where, when, and its checksum
man <- here("data", "raw", "MANIFEST.csv")
entry <- tibble(file = basename(c(raw_json, codes_json)),
                url = c(api, "https://findtreatment.gov/locator/serviceCategories.json"),
                accessed = as.character(Sys.Date()),
                md5 = unname(tools::md5sum(c(raw_json, codes_json))))
write.table(entry, man, sep = ",", row.names = FALSE,
            col.names = !file.exists(man), append = file.exists(man))
