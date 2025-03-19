multiyear_summaries <- function(dataDir, ncvarname){
  require(ncdf4)
  require(lubridate)
  require(terra)
  require(dplyr)

  nc_file <- list.files(dataDir, pattern = "\\.nc$", full.names = TRUE)
  nc_data <- nc_open(nc_file)

  lon <- ncvar_get(nc_data, "longitude")
  lat <- ncvar_get(nc_data, "latitude")
  time <- ncvar_get(nc_data, "time")

  # ncvarname <- "CHL"
  x <- ncvar_get(nc_data, ncvarname)

  ## get 3 time periods
  ## time is in days since 1900-01-01
  dates <- as.Date(time, origin = "1900-01-01")
  yrs <- as.numeric(format(dates, "%Y"))

  ## are these the time periods we should use?
  ## data sometimes start from 1993 but most start from mid 1997
  T1998_2006 <- which(yrs >= 1998 & yrs <= 2006)
  T2007_2015 <- which(yrs >= 2007 & yrs <= 2015)
  T2016_2024 <- which(yrs >= 2016 & yrs <= 2024)


  ## get per-pixel annual averages of:
  ## all/summer/winter months
  include_years <- 1998:2024
  annual_averages <- array(NA, dim = c(length(lon), length(lat), length(include_years)))
  summer_averages <- array(NA, dim = c(length(lon), length(lat), length(include_years)))
  winter_averages <- array(NA, dim = c(length(lon), length(lat), length(include_years)))

  avgsfun <- function(i, months){
    j <- which(yrs == include_years[i])
    yavg <- rowMeans(x[,,j], na.rm = TRUE, dims = 2)
    annual_averages[,,i] <- yavg
    df <- expand.grid(lon = lon, lat = lat) |>
      mutate(x = as.vector(yavg), xsd = as.vector(ysd)) |>
      mutate(x = ifelse(is.nan(x), NA, x))
  }

  annual_list <- lapply(seq_along(include_years), function(i){
    j <- which(yrs == include_years[i])

    yavg <- rowMeans(x[,,j], na.rm = TRUE, dims = 2)
    ysd <- apply(x[,,j], MARGIN = c(1, 2), FUN = sd, na.rm = TRUE)

    annual_averages[,,i] <- yavg
    annual_stdev[,,i] <- ysd

    expand.grid(lon = lon, lat = lat) |>
      mutate(x = as.vector(yavg), xsd = as.vector(ysd)) |>
      mutate(x = ifelse(is.nan(x), NA, x))
  })
  summer_list <- lapply(seq_along(include_years), function(i){
    j <- which(yrs == include_years[i])

    ## summer months
    j <- j[format(dates[j], "%m") %in% c("06", "07", "08")]

    yavg <- rowMeans(x[,,j], na.rm = TRUE, dims = 2)
    ysd <- apply(x[,,j], MARGIN = c(1, 2), FUN = sd, na.rm = TRUE)

    summer_averages[,,i] <- yavg
    summer_stdev[,,i] <- ysd

    expand.grid(lon = lon, lat = lat) |>
      mutate(x = as.vector(yavg), xsd = as.vector(ysd)) |>
      mutate(x = ifelse(is.nan(x), NA, x))
  })




  names(annual_averages_list) <- as.character(include_years)

  aadf <- annual_list |>
    bind_rows(.id = "year") |>
    group_by(year) |>
    mutate(area_annual_mean = mean(x, na.rm = TRUE)) |>
    ungroup() |>
    mutate(timeperiod = case_when(
      year %in% 1998:2006 ~ "1998-2006",
      year %in% 2007:2015 ~ "2007-2015",
      year %in% 2016:2024 ~ "2016-2024"
    )) |>
    group_by(timeperiod) |>
    mutate(
      timeperiod_areamean = mean(area_annual_mean, na.rm = TRUE),

    ) |>

  return(list(
    table = aadf,
    array = annual_averages
  ))
}

maketiles <- function(tiffs_folder, ){

  rast1 <- tiffs_folder |>
    list.files("v5.4.tif", full.names = TRUE) |>
    rast()

  cols <- coltab(rast1)
  rast1 <- project(rast1, "EPSG:3031")

  ## need to match shiny leaflet map extent
  dims <- floor(2*extent/res(rast1))
  template <- rast(ext(c(-extent,extent,-extent,extent)), nrow=dims[1], ncol=dims[2], crs=crs(rast1))

  rast2 <- resample(rast1, template)
  rast2 <- as.int(rast2, datatype="INT1U")
  coltab(rast2) <- cols


  ## addRasterImage does not handle sterographic projections
  ## need to make into tiles, so can use addTiles to put on leaflet map

  ## for now just save top layer to test tile in shiny map
  ## TODO figure out how best to make all layers available... lots of tiles...
  i <- nlyr(rast2)
  writeRaster(
    rast2[[i]],
    file.path(dirData, "delete.tif"),
    datatype="INT1U",
    overwrite = TRUE
  )
  ## for some reason for me the tiler r package gives warning: no module named 'osgeo'
  ## so will call gdal2tiles.py directly https://gdal.org/en/latest/programs/gdal2tiles.html
  system(paste(
    "gdal_translate -of vrt -expand rgba",
    file.path(dirData, "delete.tif"),
    file.path(tiffs_folder, "tiles.vrt")
  ))
  system(paste(
    "gdal2tiles.py -p raster -z 2-5 -s EPSG:3031 -x",
    file.path(tiffs_folder, "tiles.vrt"),
    file.path(tiffs_folder, "tiles")
  ))
}

