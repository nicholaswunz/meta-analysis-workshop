# Shared plotting theme and colours for the workshop -------------------------
# Sourced at the top of every page so that all figures look the same.

# 1. A clean ggplot theme --------------------------------------------------
ggplot2::theme_set(
  ggplot2::theme_classic(base_size = 13) +
    ggplot2::theme(
      plot.title       = ggplot2::element_text(face = "bold", size = 13),
      plot.subtitle    = ggplot2::element_text(colour = "grey35", size = 11),
      strip.background = ggplot2::element_rect(fill = "#EEECEA", colour = NA),
      strip.text       = ggplot2::element_text(face = "bold"),
      legend.position  = "bottom"
    )
)

# 2. Workshop colours (based on the website's red, #e12744) ---------------
pal <- c(red     = "#e12744",   # main colour
         dark    = "#1A2533",   # navy, for contrast
         orange  = "#E54D23",
         pink    = "#F4A3AC",
         darkred = "#8C1C2E",
         grey    = "#7F7F7F",
         light   = "#fecdd0")   # very light pink, for shading

# Colours for the five taxonomic groups
taxa_cols <- c(Fish      = "#1A2533",
               Amphibian = "#8C1C2E",
               Reptile   = "#E54D23",
               Bird      = "#e12744",
               Mammal    = "#F4A3AC")

# Use the workshop colours whenever a plot has a discrete colour or fill scale
# (this also applies to orchaRd plots made with cb = FALSE)
options(
  ggplot2.discrete.colour = unname(pal),
  ggplot2.discrete.fill   = unname(pal)
)

# Default fill for bars and histograms when no colour is given
ggplot2::update_geom_defaults("bar", list(fill = "#e12744"))
ggplot2::update_geom_defaults("col", list(fill = "#e12744"))

options(digits = 3, pillar.sigfig = 3)

# 3. Small helpers ------------------------------------------------------------

# Format an estimate and its 95% CI, e.g. "0.25 [95% CI: 0.10, 0.40]"
fmt_ci <- function(est, lb, ub, digits = 2) {
  sprintf(paste0("%.", digits, "f [95%% CI: %.", digits, "f, %.", digits, "f]"),
          est, lb, ub)
}

# Format p-values the way journals like them, e.g. "< 0.001" or "= 0.023"
fmt_p <- function(p) {
  ifelse(p < 0.001, "< 0.001", sprintf("= %.3f", p))
}
