## Pre-generate all distAnt model output tiles
## Run this script locally before deploying to shinyapps.io
## This avoids memory issues from streaming COGs during user sessions

library(terra)
library(dplyr)
library(curl)
library(here)

distcsv <- read.csv(here("www", "distAnt.csv"))
output_base <- here("www", "distAnt")

## Template matching leaflet map tiles/extent in EPSG:3031
x <- 12367396.2185
template <- rast(ext(c(-x, x, -x, x)), nrow = 8192, ncol = 8192, crs = crs("EPSG:3031"))

generate_tiles <- function(layer_name, distcsv, output_base, template) {
  info <- filter(distcsv, name == layer_name)
  tileDir <- file.path(output_base, info$dir)

  ## Skip if tiles already exist
  if(file.exists(file.path(tileDir, "palette.csv"))) {
    return(TRUE)
  }

  dir.create(tileDir, recursive = TRUE, showWarnings = FALSE)

  ## Check URL accessibility
  r <- curl_fetch_memory(info$url)
  if(r$status_code != 200) {
    return(FALSE)
  }

  tryCatch({
    ## Stream COG via GDAL VSI, reproject to EPSG:3031, resample to template
    vsi_url <- paste0("/vsicurl/", info$url)
    rresamp <- project(rast(vsi_url, lyrs = info$lyrnum), "EPSG:4326") |>
      crop(ext(c(-180, 180, -90, -50))) |>
      project("EPSG:3031") |>
      resample(template)

    ## Calculate 257 quantile breaks for color mapping
    qt <- global(rresamp, quantile, probs = seq(0, 1, length.out = 257), na.rm = TRUE)
    breaks <- unlist(qt)

    ## Classify into 256 bins and apply viridis color table
    rcm <- matrix(c(breaks[1:256], breaks[2:257], 0:255), ncol = 3)
    rint <- classify(rresamp, rcm, include.lowest = TRUE, right = FALSE)
    cols <- data.frame(value = 0:255, col = hcl.colors(256, "viridis"))
    coltab(rint) <- cols

    ## Save indexed raster
    writeRaster(
      rint, file.path(tileDir, "rint.tif"),
      datatype = "INT1U",
      overwrite = TRUE
    )

    ## Save palette for legend rendering
    pal <- data.frame(
      breaks_lower = breaks[1:256],
      breaks_upper = breaks[2:257],
      value = 0:255,
      col = cols$col
    )
    write.csv(pal, file.path(tileDir, "palette.csv"), row.names = FALSE)

    ## Create VRT with RGBA expansion
    system(paste(
      "gdal_translate -of vrt -expand rgba",
      file.path(tileDir, "rint.tif"),
      file.path(tileDir, "rint.vrt")
    ))

    ## Generate TMS tiles (zoom levels 2-4)
    system(paste(
      "gdal2tiles.py -z 2-4 -w none --processes=4",
      file.path(tileDir, "rint.vrt"),
      tileDir
    ))

    ## Clean up intermediate files
    file.remove(file.path(tileDir, "rint.tif"))
    file.remove(file.path(tileDir, "rint.vrt"))

    return(TRUE)

  }, error = function(e) {
    return(FALSE)
  })
}

## Generate tiles for all layers
message("Starting tile generation for ", nrow(distcsv), " distAnt layers...")

results <- data.frame(
  name = distcsv$name,
  success = NA,
  timestamp = NA
)

for(i in 1:nrow(distcsv)) {
  layer_name <- distcsv$name[i]
  success <- generate_tiles(layer_name, distcsv, output_base, template)
  results$success[i] <- success
  results$timestamp[i] <- as.character(Sys.time())

  ## Save progress log
  write.csv(results, file.path(output_base, "generation_log.csv"), row.names = FALSE)

  if(i %% 10 == 0) {
    message(sprintf("Progress: %d/%d layers completed", i, nrow(distcsv)))
  }
}
