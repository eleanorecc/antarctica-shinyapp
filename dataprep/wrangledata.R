annual_summaries <- function(ncFile, ncvarname, months){

  nc_data <- nc_open(ncFile)
  x <- ncvar_get(nc_data, ncvarname)
  xtime <- ncvar_get(nc_data, "time")
  nc_close(nc_data)

  dim2 <- dim(x)[1:2]

  ## handle different time definitions
  ## handle different time definitions
  # if(ncvarname == "CHL"){
  #   datayears <- xtime |>
  #     ## already using days
  #     as.Date(origin = "1900-01-01") |>
  #     format("%Y") |>
  #     as.numeric()
  # }
  if(ncvarname == "CHL"){
    origin <- as.POSIXct("1970-01-01", tz = "UTC")
    datayears <- format(as.POSIXct(xtime, origin = origin, tz = "UTC"), "%Y")
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

gdal2tiles <- function(r, dirData, saveFile){
  require(terra)
  writeRaster(
    r, file.path(dirData, "delete.tif"),
    datatype = "INT1U",
    overwrite = TRUE
  )
  system(paste(
    "gdal_translate -of vrt -expand rgba",
    file.path(dirData, "delete.tif"),
    file.path(dirData, "delete.vrt")
  ))
  system(paste(
    "gdal2tiles.py -p raster -z 2-4 -x -tmscompatible",
    file.path(dirData, "delete.vrt"),
    saveFile
  ))
}

maketiles <- function(r_start, saveDir){
  require(terra)

  ## addRasterImage does not handle sterographic projections
  ## need to make into tiles, so can use addTiles to put on leaflet map

  r_start <- project(r_start, "EPSG:3031")

  ## need to match shiny leaflet map extent
  dims <- rep(256*2^5,2)
  template <- rast(ext(c(-extent,extent,-extent,extent)), nrow=dims[1], ncol=dims[2], crs=crs(r_start))
  # r_resample <- resample(r_start, template)
  r_resample <- r_start

  ## in case of two seasons/annual chlorophyll a
  ## want to have same scale across all
  if(nlyr(r_resample) == 9){
    r_diffs <- c(
      r_resample[[2]] - r_resample[[1]],
      r_resample[[3]] - r_resample[[1]],
      r_resample[[5]] - r_resample[[4]],
      r_resample[[6]] - r_resample[[4]],
      r_resample[[8]] - r_resample[[7]],
      r_resample[[9]] - r_resample[[7]]
    )
    warning("make sure rasters are properly ordered annual, summer, winter")
  }
  ## differences from baseline
  r_diffs_int <- as.int(stretch(r_diffs, minq = 0.02, maxq = 0.98, minv = 0, maxv = 255), datatype = "INT1U")
  cols1 <- data.frame(
    value = 0:255,
    col = hcl.colors(256, "plasma")
  )
  breaks <- quantile(
    values(r_diffs),
    probs = seq(0,1,length.out=256),
    na.rm = TRUE
  )
  data.frame(breaks) |>
    cbind(cols2) |>
    write.csv(
      file.path(saveDir[1], "diffspalette.csv"),
      row.names = FALSE
    )

  ## re-scale for INT1U and define color table
  ## use stretch instead of simple rescaling..
  r_int <- as.int(stretch(r_resample, minq = 0.02, maxq = 0.98, minv = 0, maxv = 255), datatype = "INT1U")
  cols2 <- data.frame(
    value = 0:255,
    col = hcl.colors(256, "viridis")
  )
  breaks <- quantile(
    values(r_resample),
    probs = seq(0,1,length.out=256),
    na.rm = TRUE
  )
  data.frame(breaks) |>
    cbind(cols1) |>
    write.csv(
      file.path(saveDir[1], "palette.csv"),
      row.names = FALSE
    )

  ## loop over time periods and difference, making tiles
  tilefolder1 <- rep(c("19982006","20072015","20162024"),3)
  tilefolder2 <- rep(c("2007diff","2016diff"),3)
  for(s in 1:length(saveDir)){
    idx1 <- list(1:3,4:6,7:9)[[s]]
    idx2 <- list(1:2,3:4,5:6)[[s]]
    for(i in idx1){
      r <- r_int[[i]]
      coltab(r) <- cols1
      gdal2tiles(r, dirData, file.path(saveDir[s], tilefolder1[[i]]))
    }
    for(i in idx2){
      r <- r_diffs_int[[i]]
      coltab(r) <- cols2
      gdal2tiles(r, dirData, file.path(saveDir[s], tilefolder2[[i]]))
    }
  }
}
