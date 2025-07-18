# Note to Reviewer
# To rerun the code below, please refer ADRG appendix.
# After required package are installed.
# The path variable needs to be defined by using example code below

## --------------------------------------------------------------------------------------------------------------------
# Working directory requires write permission
if (file.access(".", 2) != 0) {
  warning(
    "The working directory '", normalizePath("."), "' is not writable.\n",
    "Please change it to a location with write permission."
  )
}


## ----setup, message=FALSE--------------------------------------------------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)

# CRAN package, please using install.packages() to install
library(haven)
library(dplyr)
library(ggplot2)
library(cowplot)
library(ggsurvfit)
library(pilot5utils)

## -----------------------------------------------------------------------------
adsl <- readRDS(file.path(path$adam, "adsl.rds"))
adtte <- readRDS(file.path(path$adam, "adtte.rds"))

## -----------------------------------------------------------------------------
anl <- adsl %>%
  filter(
    SAFFL == "Y",
    STUDYID == "CDISCPILOT01"
  ) %>%
  select(STUDYID, USUBJID, TRT01A) %>%
  inner_join(
    filter(
      adtte, PARAMCD == "TTDE", STUDYID == "CDISCPILOT01"
    ) %>% select(STUDYID, USUBJID, AVAL, CNSR, PARAM, PARAMCD),
    by = c("STUDYID", "USUBJID")
  ) %>%
  mutate(
    TRT01A = factor(TRT01A, levels = c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose"))
  )


## -----------------------------------------------------------------------------
# estimate survival
surv_mod <- ggsurvfit::survfit2(Surv(AVAL, 1 - CNSR) ~ TRT01A, data = anl)

# save plot
ggplot2::theme_set(theme_bw())

km <- (surv_mod %>%
  ggsurvfit(linewidth = 1) +
  add_censor_mark() +
  add_confidence_interval() +
  add_risktable(risktable_stats = c("n.risk")) +
  scale_ggsurvfit(
    x_scales = list(
      name = "Time to First Dermatologic Event (Days)",
      breaks = seq(0, 200, by = 20),
      limits = c(0, 200)
    ),
    y_scales = list(
      name = "Probability of event",
      expand = c(0.025, 0),
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.10),
      label = scales::label_number(accuracy = 0.01)
    )
  ) +
  ggsurvfit::add_legend_title(title = "TRT01A") +
  ggplot2::theme(legend.position = "right") +
  ggplot2::geom_hline(yintercept = 0.5, linetype = "dashed")) %>%
  ggsurvfit_build()


title <- cowplot::ggdraw() +
  cowplot::draw_label(
    "KM plot for Time to First Dermatologic Event: Safety population\n",
    fontfamily = "sans",
    fontface = "bold",
    size = 10
  )

caption <- cowplot::ggdraw() +
  cowplot::draw_label(
    paste0("\nProgram: tlf-kmplot.r [", Sys.time(), "]"),
    fontfamily = "sans",
    size = 10
  )

file <- cowplot::plot_grid(
  title, km, caption,
  ncol = 1,
  rel_heights = c(0.1, 0.75, 0.1)
)

ggsave(file, filename = file.path(path$output, "pdf/tlf-kmplot-pilot5.pdf"))

while (!is.null(dev.list())) dev.off()
