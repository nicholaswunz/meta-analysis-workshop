# =============================================================================
# simulate_data.R
# Simulates the teaching datasets used in the afternoon practicals of the
# "Meta-analysis in Comparative Physiology" workshop.
#
#   data/sim_correlation.csv  50 correlation effect sizes (metabolic rate vs performance)
#   data/sim_contrast.csv     50 treatment-control contrasts (experimental warming on physiology)
#   data/sim_spatial_arr.csv  40 population-level acclimation response ratios with coordinates
#   data/sim_tree.tre         15-species phylogeny (approximate divergence times, Mya)
#
# The data are simulated with KNOWN parameters so that students can check
# whether their models recover the truth. The "true" values are written to
# data/sim_truth.csv. Re-running this script with the same seed reproduces
# the files exactly.
# =============================================================================

library(tidyverse)
library(ape)

sim_seed <- as.integer(Sys.getenv("SIM_SEED", "22"))
set.seed(sim_seed)

# -----------------------------------------------------------------------------
# 1. Species pool and phylogeny
# -----------------------------------------------------------------------------
tree <- read.tree(here::here("data", "sim_tree.tre"))  # or read.tree("data/sim_tree.tre")
A    <- vcv(tree, corr = TRUE)                          # phylogenetic correlation matrix

species_tbl <- tribble(
  ~species,                 ~taxa,       ~mass_g,
  "Danio_rerio",            "Fish",         0.5,
  "Oncorhynchus_mykiss",    "Fish",       450,
  "Gasterosteus_aculeatus", "Fish",         1.5,
  "Xenopus_laevis",         "Amphibian",   60,
  "Rhinella_marina",        "Amphibian",  150,
  "Rana_temporaria",        "Amphibian",   25,
  "Lampropholis_delicata",  "Reptile",      0.6,
  "Anolis_sagrei",          "Reptile",      4,
  "Pogona_vitticeps",       "Reptile",    300,
  "Gallus_gallus",          "Bird",      1500,
  "Taeniopygia_guttata",    "Bird",        12,
  "Passer_domesticus",      "Bird",        28,
  "Peromyscus_maniculatus", "Mammal",      20,
  "Mus_musculus",           "Mammal",      22,
  "Rattus_norvegicus",      "Mammal",     300
)
stopifnot(setequal(species_tbl$species, tree$tip.label))

# draw phylogenetically structured species effects: u_phylo ~ MVN(0, sigma2 * A)
draw_phylo <- function(sigma2) {
  z <- MASS::mvrnorm(1, mu = rep(0, nrow(A)), Sigma = sigma2 * A)
  tibble(species = rownames(A), u_phylo = z)
}

mean_log_mass <- mean(log10(species_tbl$mass_g))

# helper: keep whole studies (in random order) until exactly n_rows rows
take_rows <- function(dat, n_rows = 50) {
  study_order <- sample(unique(dat$study))
  out <- dat %>%
    mutate(study = factor(study, levels = study_order)) %>%
    arrange(study, comparison, row_in_comp) %>%
    slice_head(n = n_rows)
  out %>% mutate(study = as.character(study))
}

# =============================================================================
# 2. CONTRAST DATA: effect of experimental warming on physiological rates
#    effect size of interest: lnRR = ln(treatment mean / control mean)
# =============================================================================
truth_contrast <- list(
  b0      =  0.15,   # overall lnRR for females of average body size in 2010
  b_male  =  0.12,   # males respond more strongly
  b_mass  = -0.08,   # per log10(g): larger species respond less
  b_year  = -0.008,  # time-lag (decline) effect per year
  s2_study   = 0.010,
  s2_phylo   = 0.015,
  s2_species = 0.004,
  s2_es      = 0.006,
  ln_cvr  =  0.15    # treatment CV is ~16% larger than control CV
)

u_phylo_c <- draw_phylo(truth_contrast$s2_phylo)
u_spp_c   <- tibble(species = species_tbl$species,
                    u_spp   = rnorm(nrow(species_tbl), 0, sqrt(truth_contrast$s2_species)))

traits_c <- tribble(
  ~trait,                    ~mu_base, ~cv,
  "Resting metabolic rate",   0.80,    0.25,
  "Maximum metabolic rate",   3.50,    0.20,
  "Heart rate",              90.00,    0.15
)

n_pool <- 45
studies_c <- tibble(
  study      = sprintf("S%02d", seq_len(n_pool)),
  study_year = sample(1988:2025, n_pool, replace = TRUE),
  species    = sample(species_tbl$species, n_pool, replace = TRUE),
  trait      = sample(traits_c$trait, n_pool, replace = TRUE, prob = c(.5, .3, .2)),
  sex_design = sample(c("female", "male", "both"), n_pool, replace = TRUE, prob = c(.3, .3, .4)),
  n_trt      = sample(1:3, n_pool, replace = TRUE, prob = c(.45, .35, .20)),
  n_group    = pmin(pmax(round(exp(rnorm(n_pool, log(10), 0.75))), 4), 60),
  u_study    = rnorm(n_pool, 0, sqrt(truth_contrast$s2_study))
)

# expand: one comparison (shared control) per sex, 1-3 treatment groups per comparison
contrast_full <- studies_c %>%
  mutate(sex = map(sex_design, ~ if (.x == "both") c("female", "male") else .x)) %>%
  unnest(sex) %>%
  group_by(study) %>%
  mutate(comparison = paste0(study, "_", row_number())) %>%
  ungroup() %>%
  mutate(row_in_comp = map(n_trt, seq_len)) %>%
  unnest(row_in_comp) %>%
  left_join(species_tbl, by = "species") %>%
  left_join(traits_c, by = "trait") %>%
  left_join(u_phylo_c, by = "species") %>%
  left_join(u_spp_c, by = "species") %>%
  mutate(
    body_size = round(mass_g * exp(rnorm(n(), 0, 0.15)), 2),
    # true lnRR for each treatment group
    theta = truth_contrast$b0 +
            truth_contrast$b_male * (sex == "male") +
            truth_contrast$b_mass * (log10(mass_g) - mean_log_mass) +
            truth_contrast$b_year * (study_year - 2010) +
            u_study + u_phylo + u_spp +
            rnorm(n(), 0, sqrt(truth_contrast$s2_es)),
    mu_c  = mu_base * mass_g^-0.1,                 # allometric baseline
    mu_t  = mu_c * exp(theta),
    sd_c  = mu_c * cv,
    sd_t  = mu_t * cv * exp(truth_contrast$ln_cvr),
    treatment_n = pmax(n_group + sample(-2:2, n(), replace = TRUE), 3)
  ) %>%
  # animals in one comparison come from the same population: one body size per comparison
  group_by(comparison) %>%
  mutate(body_size = first(body_size)) %>%
  ungroup()

# control statistics are drawn ONCE per comparison (shared control)
controls <- contrast_full %>%
  distinct(comparison, mu_c, sd_c, n_group) %>%
  mutate(control_n    = n_group,
         control_mean = rnorm(n(), mu_c, sd_c / sqrt(control_n)),
         control_sd   = sd_c * sqrt(rchisq(n(), control_n - 1) / (control_n - 1))) %>%
  select(comparison, control_mean, control_sd, control_n)

contrast_full <- contrast_full %>%
  left_join(controls, by = "comparison") %>%
  mutate(treatment_mean = rnorm(n(), mu_t, sd_t / sqrt(treatment_n)),
         treatment_sd   = sd_t * sqrt(rchisq(n(), treatment_n - 1) / (treatment_n - 1)),
         lnrr_obs = log(treatment_mean / control_mean),
         se_obs   = sqrt(treatment_sd^2 / (treatment_n * treatment_mean^2) +
                         control_sd^2   / (control_n   * control_mean^2)))

# publication bias: comparisons with no significant positive effect are
# published with probability 0.35 (selection acts on the whole comparison)
published_c <- contrast_full %>%
  group_by(comparison) %>%
  mutate(sig = any(lnrr_obs / se_obs > 1.645)) %>%
  ungroup() %>%
  group_by(comparison) %>%
  filter(first(sig) | runif(1) < 0.25) %>%
  ungroup()

sim_contrast <- take_rows(published_c, 50) %>%
  mutate(study_ID = as.integer(factor(study, levels = unique(study))),
         comparison_ID = as.integer(factor(comparison, levels = unique(comparison)))) %>%
  transmute(study_ID, study_year, taxa, species, trait, sex, body_size, comparison_ID,
            control_mean   = round(control_mean, 3),
            control_sd     = round(control_sd, 3),
            control_n,
            treatment_mean = round(treatment_mean, 3),
            treatment_sd   = round(treatment_sd, 3),
            treatment_n)

# =============================================================================
# 3. CORRELATION DATA: individual-level correlation between metabolic rate
#    and whole-organism performance. Effect size: Zr
# =============================================================================
truth_corr <- list(
  b0     =  0.25,  # overall Zr (r ~ 0.24) for females of average size in 2010
  b_male =  0.08,
  b_mass =  0.05,
  b_year = -0.008,
  s2_study   = 0.010,
  s2_phylo   = 0.010,
  s2_species = 0.003,
  s2_es      = 0.008
)

u_phylo_r <- draw_phylo(truth_corr$s2_phylo)
u_spp_r   <- tibble(species = species_tbl$species,
                    u_spp   = rnorm(nrow(species_tbl), 0, sqrt(truth_corr$s2_species)))

n_pool_r <- 40
studies_r <- tibble(
  study      = sprintf("R%02d", seq_len(n_pool_r)),
  study_year = sample(1990:2025, n_pool_r, replace = TRUE),
  species    = sample(species_tbl$species, n_pool_r, replace = TRUE),
  sex_design = sample(c("female", "male", "both"), n_pool_r, replace = TRUE, prob = c(.3, .3, .4)),
  n_traits   = sample(1:3, n_pool_r, replace = TRUE, prob = c(.4, .4, .2)),
  n_sample   = pmin(pmax(round(exp(rnorm(n_pool_r, log(25), 0.6))), 8), 200),
  u_study    = rnorm(n_pool_r, 0, sqrt(truth_corr$s2_study))
)

perf_traits <- c("Sprint speed", "Endurance", "Exploration", "Activity")

corr_full <- studies_r %>%
  mutate(sex = map(sex_design, ~ if (.x == "both") c("female", "male") else .x)) %>%
  unnest(sex) %>%
  group_by(study) %>%
  mutate(comparison = paste0(study, "_", row_number())) %>%  # same individuals = same comparison
  ungroup() %>%
  mutate(trait = map(n_traits, ~ sample(perf_traits, .x))) %>%
  unnest(trait) %>%
  group_by(comparison) %>% mutate(row_in_comp = row_number()) %>% ungroup() %>%
  left_join(species_tbl, by = "species") %>%
  left_join(u_phylo_r, by = "species") %>%
  left_join(u_spp_r, by = "species") %>%
  mutate(
    body_size   = round(mass_g * exp(rnorm(n(), 0, 0.15)), 2),
    sample_size = pmax(n_sample + sample(-3:3, n(), replace = TRUE), 6)
  ) %>%
  # correlations in one comparison are measured on the same animals:
  # one body size and one sample size per comparison
  group_by(comparison) %>%
  mutate(body_size = first(body_size), sample_size = first(sample_size)) %>%
  ungroup() %>%
  mutate(
    theta = truth_corr$b0 +
            truth_corr$b_male * (sex == "male") +
            truth_corr$b_mass * (log10(mass_g) - mean_log_mass) +
            truth_corr$b_year * (study_year - 2010) +
            u_study + u_phylo + u_spp +
            rnorm(n(), 0, sqrt(truth_corr$s2_es)),
    zr_obs = rnorm(n(), theta, sqrt(1 / (sample_size - 3))),
    r      = round(tanh(zr_obs), 3)
  )

published_r <- corr_full %>%
  group_by(comparison) %>%
  filter(any(zr_obs * sqrt(sample_size - 3) > 1.645) | runif(1) < 0.35) %>%
  ungroup()

sim_correlation <- take_rows(published_r, 50) %>%
  mutate(study_ID = as.integer(factor(study, levels = unique(study))),
         comparison_ID = as.integer(factor(comparison, levels = unique(comparison)))) %>%
  transmute(study_ID, study_year, taxa, species, trait, sex, body_size, comparison_ID,
            r, sample_size)

# =============================================================================
# 4. SPATIAL DATA: acclimation response ratio (ARR) of heat tolerance in
#    populations of a widespread Australian skink (advanced topic: phylogenetic and spatial meta-analysis)
# =============================================================================
haversine_km <- function(lon, lat) {
  rad <- pi / 180
  outer(seq_along(lon), seq_along(lon), function(i, j) {
    dlat <- (lat[j] - lat[i]) * rad; dlon <- (lon[j] - lon[i]) * rad
    a <- sin(dlat / 2)^2 + cos(lat[i] * rad) * cos(lat[j] * rad) * sin(dlon / 2)^2
    2 * 6371 * asin(pmin(1, sqrt(a)))
  })
}

n_sites <- 40
sites <- tibble(site_ID   = sprintf("P%02d", seq_len(n_sites)),
                longitude = round(runif(n_sites, 142, 153.5), 3),
                latitude  = round(runif(n_sites, -38, -16), 3))
D_sites <- haversine_km(sites$longitude, sites$latitude)
range_km <- 300
spatial_field <- MASS::mvrnorm(1, rep(0, n_sites), 0.0064 * exp(-D_sites / range_km))

sim_spatial <- sites %>%
  mutate(study_ID = sample(sprintf("St%02d", 1:18), n_sites, replace = TRUE),
         n_low = sample(8:30, n_sites, replace = TRUE),
         n_high = n_low + sample(-2:2, n_sites, replace = TRUE),
         # ARR (deg C change in CTmax per deg C acclimation): stronger plasticity towards the tropics
         true_arr = 0.20 + 0.006 * (latitude + 27) + spatial_field + rnorm(n_sites, 0, 0.03),
         sd_ctmax = runif(n_sites, 0.6, 1.2),
         var_arr  = (sd_ctmax^2 / n_high + sd_ctmax^2 / n_low) / 10^2,  # acclimation temps 10 deg apart
         ARR      = round(rnorm(n_sites, true_arr, sqrt(var_arr)), 4),
         V_ARR    = sprintf("%.6f", var_arr)) %>%
  arrange(study_ID, site_ID) %>%
  select(study_ID, site_ID, longitude, latitude, n_low, n_high, ARR, V_ARR)

# =============================================================================
# 5. Write files
# =============================================================================
write_csv(sim_contrast,    here::here("data", "sim_contrast.csv"))
write_csv(sim_correlation, here::here("data", "sim_correlation.csv"))
write_csv(sim_spatial,     here::here("data", "sim_spatial_arr.csv"))

truth <- bind_rows(
  enframe(unlist(truth_contrast), "parameter", "value") %>% mutate(dataset = "contrast (lnRR)"),
  enframe(unlist(truth_corr),     "parameter", "value") %>% mutate(dataset = "correlation (Zr)"),
  tibble(dataset = "spatial (ARR)", parameter = c("b0_at_27S", "b_lat", "spatial_var", "range_km"),
         value = c(0.20, 0.006, 0.0064, range_km))
) %>% relocate(dataset)
write_csv(truth, here::here("data", "sim_truth.csv"))

message("Contrast rows: ", nrow(sim_contrast), "; correlation rows: ", nrow(sim_correlation))
