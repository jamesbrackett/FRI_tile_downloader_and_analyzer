
# ------------------------------------------------------------------------------
# FRI_tile_analyzer.R
#
# Purpose:     Take a list of FRI tile links, download laz files in parallel, 
#              calculate chosen index one tile at a time, and save into their
#              respective folders.
#
# Author:      James Brackett
#
# Created:     2026-11-17
# Last Edited: 2026-11-21
# ------------------------------------------------------------------------------

# load libraries
library(sf)
library(lidR)
library(terra)
library(future)
library(future.apply)
library(progressr)

# load metric definitions from metrics.R
source("metrics.R")

# read geopackage file and convert to a table only
tiles_gpkg <- st_read("data/input/tile_indices_of_interest.gpkg" )
tiles_table <- st_drop_geometry(tiles_gpkg)

# create temporary and output directory
temp_dir <- "data/tile_temp_dir"
output_dir <- "data/tile_output_dir"
failed_dir <- "data/tile_error_reports"

# choose which metrics to run and create one folder per metric
chosen_metrics <- c("P95")
for (metric in chosen_metrics){
  dir.create(file.path(output_dir, metric), showWarnings = FALSE)
}

# set resolution of output tiles
resolution = 20

# tile processor function
process_tile <- function(i) {
  
  # set timout time to longer for larger tiles
  options(timeout = 3600)
  
  # store urls for laz and dtm files as well as name of tile
  url_laz <- tiles_table$Download_L[i]
  url_dtm <- tiles_table$Download_D[i]
  tilename <- tiles_table$Tilename[i]
  
  # create file paths for temp laz and dtm files
  temp_laz <- file.path(temp_dir, basename(url_laz))
  temp_dtm <- file.path(temp_dir, basename(url_dtm))
  
  # create file paths for each metric folder
  output_paths <- c()
  for (metric in chosen_metrics){
    output_paths[metric] <- file.path(output_dir, 
                                      metric, 
                                      paste0(tilename, "_", metric, ".tif"))
  }
  
  # check if the tile exists already for each metric
  missing_metrics <- chosen_metrics[!file.exists(output_paths)]
  if (length(missing_metrics) == 0) {
    return(NULL)
  }
  
  # tryCatch for downloading tiles and calculating metrics
  tryCatch({
    
    # download temporary laz and dtm tiles
    download.file(url_laz, temp_laz, mode = "wb", quiet = TRUE)
    download.file(url_dtm, temp_dtm, mode = "wb", quiet = TRUE)
    
    # select xyzc from temp_laz
    las <- readLAS(temp_laz, select = "xyzc")
    if (is.empty(las)) stop("empty LAS")
    
    # filter las point cloud
    las <- filter_poi(las,
                      Classification != 7,
                      Classification != 12,
                      Classification != 18)
    las <- filter_duplicates(las)
    
    # load dtm and normalize las height using dtm
    dtm <- rast(temp_dtm)
    las <- normalize_height(las, dtm)
    
    # compute pixel metrics, trim to extent of tile, and save tile
    for (metric in missing_metrics){
      metric_raster <- pixel_metrics(las, metric_formulas[[metric]], res = resolution)
      metric_raster <- crop(metric_raster, ext(las))
      metric_raster <- ifel(is.na(metric_raster), 0, metric_raster)
      writeRaster(metric_raster, output_paths[metric], overwrite = TRUE)
    }
    
    # remove the temporary laz and dtm
    file.remove(temp_laz)
    file.remove(temp_dtm)
    NULL
    
  }, error = function(e) {
    # remove files that may have failed part way through download
    if (file.exists(temp_laz)) try(file.remove(temp_laz), silent = TRUE)
    if (file.exists(temp_dtm)) try(file.remove(temp_dtm), silent = TRUE)
    # create one row table outlining failure
    data.frame(tile = tilename, error = conditionMessage(e))
  })
}

# use simple text bar to display progress
handlers("txtprogressbar")
# set how many workers to use
plan(multisession, workers = 2)

# determine the number of tiles needed to be processed
indices <- seq_len(nrow(tiles_table))

# process tiles
with_progress({
  p <- progressor(steps = length(indices))
  results <- future_lapply(
    indices,
    function(i) {
      p()
      process_tile(i)
    }
  )
})

# shut down parallel workers
plan(sequential)

# create table of failed rows
failed <- do.call(rbind, results)

# save failed tiles to csv if any failed
if (is.null(failed)) {
  message("No tiles failed.")
} else {
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H%M%S")
  write.csv(failed, file.path(failed_dir, paste0("failed_tiles_", timestamp, ".csv")), row.names = FALSE)
  message(nrow(failed), " tiles failed. See failed_tiles.csv")
}






