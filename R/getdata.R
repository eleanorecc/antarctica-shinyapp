source(here::here("global.R"))


## to control download and sync
getdata <- FALSE
syncdata <- FALSE
testrun <- TRUE

## polygons around south pole
polygon12 <- "POLYGON((0 -60, 30 -60, 60 -60, 90 -60, 120 -60, 150 -60, 180 -60, -150 -60, -120 -60, -90 -60, -60 -60, -30 -60, 0 -60))"
polygon12sf <- polygon12 |>
  st_as_sfc(crs = 4326) |>
  st_transform(3031)
polygon4 <- "POLYGON((-11 -62, 16 -74, -34 -82, -44 -68, -11 -62))"
polygon4sf <- polygon4 |>
  st_as_sfc(crs = 4326) |>
  st_transform(3031)



## test example --
## Polarview Sentinel-1 imagery

## dates for which to get data
## polarview ice concentration data is available daily
acquisitiondates <- as.Date(
  c("2023-09-01", "2023-10-01", "2023-11-01", "2023-12-01"),
  format="%Y-%m-%d"
)

## test out using blueant
if(getdata){
  example_data <- sources_seaice(
    "Polarview Sentinel-1 imagery",
    acquisition_date = acquisitiondates,
    polygon = polygon12sf,
    formats = "geotiff"
  )
  conf <- dirData |>
    bb_config() |>
    bb_add(example_data)

  if(syncdata){
    bb_sync(
      conf,
      verbose = TRUE,
      confirm_downloads_larger_than = 0.5,
      dry_run = testrun
    )
  }
}

## polarview bowerbird download isn't working
## use instead http directly https://seaice.uni-bremen.de/data-archive/
if(getdata){
  ## s6250 means southern hemisphere 6250 resolution
  base_url <- "https://data.seaice.uni-bremen.de/amsr2/asi_daygrid_swath/s6250"
  tiflinks <- lapply(acquisitiondates, function(dt){
    yr <- substr(dt, 1, 4)
    mn <- str_to_lower(month(dt, label = TRUE))
    url <- sprintf("%s/%s/%s/Antarctic", base_url, yr, mn)
    res <- GET(url)
    txt <- content(res, "text")
    ## current most recent version is v5.4
    tif <- str_extract_all(txt, '(?<=href=")[^"]+v5.4\\.tif(?=")')
    sprintf("%s/%s/%s/Antarctic/%s", base_url, yr, mn, unlist(tif))
  })
  dt <- acquisitiondates |>
    str_replace_all("-", "") |>
    paste(collapse = "|")
  tiflinks <- unlist(tiflinks) |>
    grep(pattern = dt, value = TRUE)

  for(x in tiflinks){
    file_name <- file.path(dirData, "www.polarview.aq", basename(x))
    ## only download if file does not yet exist
    if(!file.exists(file_name)){
      tryCatch({
        download.file(x, file_name, mode = "wb")
      }, error = function(e){
        cat("Error downloading:", file_name, "\n")
      })
    }
  }
  closeAllConnections()
}
