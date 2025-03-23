annual_summaries <- function(ncFile, ncvarname, months){

  nc_data <- nc_open(ncFile)
  x <- ncvar_get(nc_data, ncvarname)
  xtime <- ncvar_get(nc_data, "time")
  nc_close(nc_data)

  dim2 <- dim(x)[1:2]

  ## handle different time definitions
  if(ncvarname == "CHL"){
    datayears <- xtime |>
      ## already using days
      as.Date(origin = "1900-01-01") |>
      format("%Y") |>
      as.numeric()
  }
  if(ncvarname == "sos"){
    ## convert from hours to days
    datayears <- c(xtime/24) |>
      as.Date(origin = "1950-01-01") |>
      format("%Y") |>
      as.numeric()
  }

  yrs <- unique(datayears)

  y <- array(NA, dim = c(dim2, length(yrs)))
  for(i in 1:length(yrs)){
    k <- which(datayears == yrs[i])
    k <- k[months]
    y[,,i] <- rowMeans(x[,,k], na.rm = TRUE, dims = 2)
    y[is.nan(y)] <- NA
  }
  return(y)
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

extents_and_sums <- function(x, cutoff, spatialweights, metric = c("minext", "maxext")){
  x[x < cutoff] <- NA
  x[x >= cutoff] <- 1

  totalarea <- x |>
    sweep(MARGIN = c(1,2), FUN = "*", spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)

  ## if x is 365 daily ice concentrations then i is doy
  ## if x is 9 annual ice extents then i is year number
  if(metric == "minext"){i = which.min(totalarea)}
  if(metric == "maxext"){i = which.max(totalarea)}

  return(list(
    extent = x[,,i],
    sum = rowSums(x, na.rm = TRUE, dims = 2),
    df = data.frame(index = i, coveragearea = totalarea[i])
  ))
}

read_ncdata <- function(ncFile, ncvarname){
  require(ncdf4)

  nc_data <- nc_open(ncFile)
  x <- ncvar_get(nc_data, ncvarname)
  nc_close(nc_data)

  return(x)
}

save_tiff <- function(saveArray, r, tifFile){
  saveArray |>
    apply(MARGIN = c(1,3), FUN = function(x){rev(x)}) |>
    rast(ext(r), crs = crs(r)) |>
    writeRaster(tifFile)
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

