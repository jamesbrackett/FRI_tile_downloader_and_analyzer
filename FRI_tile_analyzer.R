
# ------------------------------------------------------------------------------
# FRI_tile_analyzer.R
#
# Purpose:     Take a list of FRI tile links, download laz files one at a time, 
#              calculate chosen index one tile at a time, and save into their
#              respective folders.
#
# Author:      James Brackett
#
# Created:     2026-11-17
# Last Edited: 2026-11-18
# ------------------------------------------------------------------------------

# load libraries
library(sf)
library(lidR)
library(terra)

# load metric definitions from metrics.R
source("metrics.R")

# read geopackage file
tiles_gpkg <- st_read(
  "data/input/tile_indices_of_interest.gpkg", 
)

# convert tiles_gpkg to a table only
tiles_table <- st_drop_geometry(tiles_gpkg)

# create temporary and output directory
temp_dir <- "data/tile_temp_dir"
output_dir <- "data/tile_output_dir"

# choose which metrics to run and create one folder per metric
metric_names <- c("P95")
for (metric in metric_names){
  dir.create(file.path(output_dir, metric))
}


  





