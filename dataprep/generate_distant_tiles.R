## Pre-generate all distAnt tiles locally before deploying to shinyapps.io


## template matching leaflet map extent
template <- rast(
  ext(c(-extent, extent, -extent, extent)), 
  nrow = 8192, ncol = 8192, 
  crs = crs("EPSG:3031")
)

## results to log the download
results <- data.frame(
  name = distant_data$name,
  success = NA, 
  timestamp = NA
)

## load the make_tile function
source(here("dataprep/make_tiles.R"))


## process all datasets
for(i in 1:nrow(distant_data)) {
  nm <- distant_data$name[i]

  info <- filter(distant_data, name == nm)
  tiledir <- file.path(dirData, "distAnt", info$dir)

  ## don't recreate if the tiles already exist
  if(!file.exists(file.path(tiledir, "palette.csv"))) {
    dir.create(tiledir, recursive = TRUE, showWarnings = FALSE)
    
    r <- curl_fetch_memory(info$url)
    if(r$status_code != 200) {
      return(FALSE)
    }
    vsi_url <- paste0("/vsicurl/", info$url)
    rresamp <- rast(vsi_url, lyrs = info$lyrnum) |> 
      project("EPSG:4326") |>
      crop(ext(c(-180, 180, -90, -45))) |>
      project("EPSG:3031") |>
      resample(template)

    rc <- info$reclass

    success <- make_tiles(
      resampled_raster = rresamp, 
      tile_directory = tiledir,
      reclass = rc
    )
    results$success[i] <- success
    results$timestamp[i] <- as.character(Sys.time())

    write.csv(results, file.path(dirData, "distAnt_tiles_log.csv"), row.names = FALSE)
    if(i %% 10 == 0) {
      message(sprintf("%d/%d layers completed", i, nrow(distant_data)))
    }
  }
}
