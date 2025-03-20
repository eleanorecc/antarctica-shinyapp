## function to get averages
annual_summaries <- function(x, include_years, months, metric = c("mean", "sum")){
  dim2 <- dim(x)[1:2]

  y <- array(NA, dim = c(dim2, length(include_years)))
  if(metric == "mean"){
    for(i in seq_along(include_years)){
      k <- which(yrs == include_years[i])
      k <- k[months]
      y[,,i] <- rowMeans(x[,,k], na.rm = TRUE, dims = 2)
      y[is.nan(y)] <- NA
    }
  }
  if(metric == "sum"){
    for(i in seq_along(include_years)){
      k <- which(yrs == include_years[i])
      k <- k[months]
      y[,,i] <- rowSums(x[,,k], na.rm = TRUE, dims = 2)
      y[is.nan(y)] <- NA
    }
  }
  return(y)
}

seaice_extents <- function(x, cutoff, spatialweights, metric = c("minext", "maxext")){
  x[x < cutoff] <- NA
  x[x >= cutoff] <- 1

  totalarea <- x |>
    sweep(MARGIN = c(1,2), FUN = "*", spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)

  ## if x is 365 daily ice concentrations then i is doy
  ## if x is 9 annual ice extents then i is year number
  if(metric == "minext"){ i = which.min(totalarea) }
  if(metric == "maxext"){ i = which.max(totalarea) }

  return(list(
    extent = x[,,i],
    df = data.frame(index = i, coveragearea = totalarea)
  ))
}

timeperiod_averages <- function(y, spatialweights){
  dim2 <- dim(y)[1:2]

  ## get time period (per-pixel) averages
  ## and interannual variability
  prd_avgs <- array(NA, dim = c(dim2, 3))
  prd_var <- array(NA, dim = c(dim2, 3))
  for(i in 1:3){
    k <- (9*i-8):(9*i)
    prd_avgs[,,i] <- rowMeans(y[,,k], na.rm = TRUE, dims = 2)
    prd_var[,,i] <- apply(y[,,k], MARGIN = c(1, 2), FUN = var, na.rm = TRUE)
  }

  ## timeseries table
  ## taking spatially-weighted means
  ## and sd of pixel values from the annual values
  yrwgtsum <- y |>
    sweep(MARGIN = c(1,2), FUN = "*", spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)
  nonNAarea <- y |>
    sweep(MARGIN = c(1,2), FUN = function(a, b){ ifelse(is.na(a), NA, b) }, spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)
  ## does sd also need to be spatially weighted??
  yrsd <- apply(y, MARGIN = 3, FUN = sd, na.rm = TRUE)
  yrmean <- apply(y, MARGIN = 3, FUN = mean, na.rm = TRUE)

  tstab <- data.frame(yrmean, yrsd, nonNAarea, yrwgtsum) |>
    mutate(yrwgtmean = yrwgtsum/nonNAarea)

  return(list(
    averages = prd_avgs,
    variability = prd_var,
    table = tstab
  ))
}


## function to get annual minimum extent
seaice_extents <- function(x, include_years, spatialweights){
  dim2 <- dim(x)[1:2]

  ## first get per-pixel annual means, averaging monthly values
  message("note: this is assuming there is one raster layer per day each year")

  y <- array(NA, dim = c(dim2, length(include_years)))
  if(metric == "mean"){
    for(i in seq_along(include_years)){
      k <- which(yrs == include_years[i])
      k <- k[months]
      y[,,i] <- rowMeans(x[,,k], na.rm = TRUE, dims = 2)
      y[is.nan(y)] <- NA
    }
  }
  if(metric == "sum"){
    for(i in seq_along(include_years)){
      k <- which(yrs == include_years[i])
      k <- k[months]
      y[,,i] <- rowSums(x[,,k], na.rm = TRUE, dims = 2)
      y[is.nan(y)] <- NA
    }
  }

  ## then get time period (per-pixel) averages
  ## and interannual variability
  prd_avgs <- array(NA, dim = c(dim2, 3))
  prd_var <- array(NA, dim = c(dim2, 3))
  for(i in 1:3){
    k <- (9*i-8):(9*i)
    prd_avgs[,,i] <- rowMeans(y[,,k], na.rm = TRUE, dims = 2)
    prd_var[,,i] <- apply(y[,,k], MARGIN = c(1, 2), FUN = var, na.rm = TRUE)
  }

  ## also return a timeseries table
  ## taking spatially-weighted averages and sd of pixel values from annual averages
  yrwgtsum <- y |>
    sweep(MARGIN = c(1,2), FUN = "*", spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)
  nonNAarea <- y |>
    sweep(MARGIN = c(1,2), FUN = function(a, b){ ifelse(is.na(a), NA, b) }, spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)
  ## does sd also need to be spatially weighted??
  yrmean <- apply(y, MARGIN = 3, FUN = mean, na.rm = TRUE)

  tstab <- data.frame(year = include_years, yrmean, yrsd, nonNAarea, yrwgtsum) |>
    mutate(yrwgtmean = yrwgtsum/nonNAarea)

  return(list(
    extents = prd_extents,
    averages = prd_avgs,
    table = tstab
  ))
}

variable_summaries <- function(dataDir, ncvarname){
  require(ncdf4)
  require(lubridate)
  require(terra)

  nc_file <- list.files(dataDir, pattern = "\\.nc$", full.names = TRUE)
  nc_data <- nc_open(nc_file)

  ## interpreting time dimension
  ## time is in days since 1900-01-01
  ## data sometimes start from 1993 but most start from mid 1997
  time <- ncvar_get(nc_data, "time")
  dates <- as.Date(time, origin = "1900-01-01")
  yrs <- as.numeric(format(dates, "%Y"))
  include_years <- 1998:2024

  ## do spatial weighting when take averages??
  ## at the poles lat long grid vary significantly in size
  r <- rast(nc_file)
  spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
    cellSize(unit="km") |>
    t() |>
    as.array()
  rm(r)


  ## read in the data itself
  ## ncvarname = "CHL"
  x <- ncvar_get(nc_data, ncvarname)

  if(ncvarname == "SEAICE(??)"){
    icedays <- timeperiod_averages(x, 1998:2024, 1:12, metric = "sum", spatialweights)

    iceextent <- timeperiod_extents(x, 1998:2024, spatialweights)

  } else {
    annual <- timeperiod_averages(x, include_years, 1:12, metric = "mean", spatialweights)
    summer <- timeperiod_averages(x, include_years, 7:9, metric = "mean", spatialweights)
    winter <- timeperiod_averages(x, include_years, 1:3, metric = "mean", spatialweights)

    aa <- list(annual$averages, summer$averages, winter$averages)
    vv <- list(annual$variability, summer$variability, winter$variability)
    tt <- bind_rows(annual$table, summer$table, winter$table)
  }

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

