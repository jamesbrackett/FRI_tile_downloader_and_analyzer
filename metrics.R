#-------------------------------------------------------------------------------
# metrics.R
#
# Purpose:     Includes a list of pixel level formulas of forest attributes
#              to be called by FRI_tile_analyzer.R
#
# Author:      James Brackett
#
# Created:     2026-11-18
# Last Edited: 2026-11-18
#-------------------------------------------------------------------------------

metric_formulas <- list(
  P95 = ~list(P95 = quantile(Z, 0.95))
)