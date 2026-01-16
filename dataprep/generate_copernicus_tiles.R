## Pre-generate tiles from Copernicus raster data before deploying to shinyapps.io


## template matching leaflet map extent
template <- rast(
  ext(c(-extent, extent, -extent, extent)), 
  nrow = 8192, ncol = 8192, 
  crs = crs("EPSG:3031")
)

## results to log the tile creation
results <- data.frame(
  timestamp = NA,
  name = c(
    list.files(here(dirData, "seaiceDays"), pattern = "icedays.tif$", full.names = TRUE),
    list.files(here(dirData, "surfaceSalinity"), pattern = "sos.tif$", full.names = TRUE),
    list.files(here(dirData, "chlorophyllA"), pattern = "chl.tif$", full.names = TRUE)
  )
)

## load the make_tile function
source(here("dataprep/make_tiles.R"))


## process all the datasets
for(i in 1:nrow(results)){

  ## make the directories for the tiles
  ## these names are the ones the shiny server/ui expect currently
  tif <- results[i,"name"]
  tiledirs <- tif |> 
    str_replace("timeperiod_", "") |> 
    str_remove("_months_[a-z]+.tif") |> 
    file.path(c("19982006","20072015","20162024","20072015diff","20162024diff"))
  
  lapply(tiledirs, function(x){
    dir.create(x, recursive = TRUE, showWarnings = FALSE)
  })
  
  ## read the tiff file and resample
  ## reprojection happens with save tiff in get data script
  r <- rast(tif) 
  rresamp <- resample(r, template)
  chkvar <- all(global(rresamp, var, na.rm = TRUE) > 0)
  ## check that variance is non-zero i.e. that the data isnt all the same value
  
  if(chkvar) {
    ## need to loop over the layers and tile each, 
    ## including the difference-rasters,
    ## saving each in its respective tiledir
    n <- nlyr(rresamp)
    idx <- rep(seq(1, n, by = 3), each = 2)
    diffs <- rresamp[[idx + rep(c(1, 2), times = n / 3)]] - rresamp[[idx]]
    
    ## make sure order matches tiledirs 
    ## so that they get saved in the right place!
    
    ## (1) tiles for each timeperiod
    lapply(1:nlyr(rresamp), function(x) {
      ## make_tiles function will tile the first raster in the stack
      ## but we pass the whole stack so the palette quantiles are calculated using all the values
       success <- make_tiles(
        resampled_raster = rresamp, idx = x,
        tile_directory = tiledirs[x]
      )
    })
    ## (2) tiles for differences between time periods
    lapply(1:nlyr(diffs), function(x) {
      success <- make_tiles(
        resampled_raster = diffs, idx = x,
        tile_directory = tiledirs[x+nlyr(rresamp)], 
        usepal = "plasma"
      )
    })
    
    results$timestamp[i] <- as.character(Sys.time())
    write.csv(results, file.path(dirData, "copernicus_tiles_log.csv"), row.names = FALSE)
  }
}