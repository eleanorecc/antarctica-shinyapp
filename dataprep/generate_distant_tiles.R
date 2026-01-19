## Pre-generate all distAnt tiles locally before deploying to shinyapps.io


## template matching leaflet map extent
template <- rast(
  ext(c(-extent, extent, -extent, extent)), 
  nrow = 8192, ncol = 8192, 
  crs = crs("EPSG:3031")
)

## table to log the download
results <- data.frame(
  name = distant_data$name,
  success = NA, 
  timestamp = NA
)

## load the make_tile function
source(here("dataprep/make_tiles.R"))


## make tmp directory for processing and point terra there with 2GB limit
## SSD mac main storage will be slower than RAM but there's more space
tmp_path <- normalizePath("~/tmp")
if(!file.exists(tmp_path)){
  dir.create(tmp_path)
}
tmp_distant <- tempfile(tmpdir = tmp_path)
dir.create(tmp_distant, showWarnings = FALSE)
terraOptions(tempdir = tmp_distant, memmax = 2)


## process all datasets
for(i in 155:nrow(distant_data)) {
  nm <- distant_data$name[i]

  info <- filter(distant_data, name == nm)
  tiledir <- file.path(dirData, "distAnt", info$dir)

  ## don't recreate if the tiles already exist
  if(!file.exists(file.path(tiledir, "palette.csv"))) {
    dir.create(tiledir, recursive = TRUE, showWarnings = FALSE)
    
    ## only request header to check status
    r <- request(info$url) |> 
      req_method("HEAD") |> 
      req_perform()
    if(r$status_code != 200) {
      return(FALSE)
    }
    vsi_url <- paste0("/vsicurl/", info$url)
    rr <- rast(vsi_url, lyrs = info$lyrnum)

    ## extent matching original raster to crop before projecting just once
    # bb <- project(ext(c(-180, 180, -90, -45)), "EPSG:4326", crs(rr))
    bb <- project(ext(c(-70, 60, -80, -45)), "EPSG:4326", crs(rr))
    
    rresamp <- rr |> 
      crop(bb) |> 
      project("EPSG:3031")
    
    ## when going from higher to lower resolution, use average
    ## when going to higher resolution, use bilinear
    usemethod <- ifelse(all(res(rresamp) < res(template)), "average", "bilinear")
    rresamp <- resample(rresamp, template, usemethod)

    rc <- info$reclass

    Sys.sleep(3)
    success <- make_tiles(
      resampled_raster = rresamp, 
      tile_directory = tiledir,
      reclass = rc
    )
    ## delete terra temporary files 
    ## so it doesn't fill up storage...
    tmpFiles(remove = TRUE)
    
    results$success[i] <- success
    results$timestamp[i] <- as.character(Sys.time())

    write.csv(results, file.path(dirData, "distAnt_tiles_log.csv"), row.names = FALSE)
    message(sprintf("%d/%d completed - %s", i, nrow(distant_data), nm))
  }
}

## remove temporary directory manually
## not deleted when quitting positron as R session keeps running
unlink(tmp_distant, recursive = TRUE)
