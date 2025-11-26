## Download and process Copernicus Marine Service data


## set login for copernicus
## don't save in script!
cmt <- import("copernicusmarine")
cmt$login(user, pass)

## load make_timeseries function and create timeseries table
source(here("dataprep/make_timeseries.R"))

## polygons to calculate the timeseries over
polygons <- filter(asd, str_detect(GAR_Name, "48|58.6|58.7|58.4.4"))

  
## helper functions using arrays for aggregations
## annual summaries, timeperiod averages, extents, and save tiffs
annual_summaries <- function(ncFile, ncvarname, months) {

  ## get the data and time variable from the netcdf file
  nc_data <- nc_open(ncFile)
  x <- ncvar_get(nc_data, ncvarname)
  xtime <- ncvar_get(nc_data, "time")
  nc_close(nc_data)

  dim2 <- dim(x)[1:2]

  ## formatting of the time variable
  ## differs between datasets
  if(ncvarname == "CHL"){
    origin <- as.POSIXct("1970-01-01", tz = "UTC")
    datayears <- format(as.POSIXct(xtime, origin = origin, tz = "UTC"), "%Y")
  }
  if(ncvarname == "sos"){
    datayears <- c(xtime/24) |>
      as.Date(origin = "1950-01-01") |>
      format("%Y") |>
      as.numeric()
  }

  ## determine number of years in the dataset
  ## based on the netcdf time variable
  yrs <- unique(datayears)

  ## put in an array to summarize
  ## if needed, use months argument to filter
  y <- array(NA, dim = c(dim2, length(yrs)))
  for(i in 1:length(yrs)){
    k <- which(datayears == yrs[i])
    k <- k[months]
    y[,,i] <- rowMeans(x[,,k], na.rm = TRUE, dims = 2)
    y[is.nan(y)] <- NA
  }
  return(y)
}

timeperiod_averages <- function(y) {
  dim2 <- dim(y)[1:2]

  ## taking the time range where all variables had data
  ## and splitting into 3 equal intervals gives periods of 9 years
  prd_avgs <- array(NA, dim = c(dim2, 3))
  prd_var <- array(NA, dim = c(dim2, 3))
  for(i in 1:3){
    k <- (9*i-8):(9*i)
    prd_avgs[,,i] <- rowMeans(y[,,k], na.rm = TRUE, dims = 2)
    prd_var[,,i] <- apply(y[,,k], MARGIN = c(1, 2), FUN = var, na.rm = TRUE)
  }

  return(list(
    averages = prd_avgs,
    variability = prd_var
  ))
}

extents <- function(x, cutoff, spatialweights) {
  ## make a binary raster to apply this aggregation
  x[x < cutoff] <- NA
  x[x >= cutoff] <- 1

  ## multiply by spatial weights to account for the fact that
  ## lat/lon gridcells further from pole represent larger areas
  totalarea <- x |>
    sweep(MARGIN = c(1,2), FUN = "*", spatialweights) |>
    apply(MARGIN = 3, FUN = sum, na.rm = TRUE)

  ## choose which we want to use...
  ## could also calculate max extent
  # i = which.max(totalarea)
  i = which.min(totalarea)

  return(list(
    extent = x[,,i],
    sum = rowSums(x, na.rm = TRUE, dims = 2),
    df = data.frame(index = i, coveragearea = totalarea[i])
  ))
}

save_tiff <- function(saveArray, r, saveDir) {
  saveArray |>
    apply(MARGIN = c(1,3), FUN = function(x){rev(x)}) |>
    rast(ext(r), crs = crs(r)) |>
    project("EPSG:3031") |> 
    writeRaster(saveDir, overwrite = TRUE)
}


## functions to get the datasets

## the full data subset are downloaded
## then annual averages per raster pixel are calculated
## from the annual average rasters the following are calculated:
## (1) timeperiod averages for each raster pixel
## (2) averages per year within CCAMLR statistical areas

get_monthly_data <- function(saveDir, vars, downloads) {
  if(!file.exists(saveDir)){
    dir.create(saveDir, recursive = TRUE, showWarnings = FALSE)

    ## this is using the copernicusmarine package via r reticulate
    ## downloaded data saved at saveDir
    for(i in 1:length(downloads)) {
      d <- downloads[[i]]
      cmt$subset(
        dataset_id = d$params$datasetID, variables = vars,
        start_datetime = d$params$start_datetime, end_datetime = d$params$end_datetime,
        minimum_longitude = d$params$min_longitude, minimum_latitude = d$params$min_latitude,
        maximum_longitude = d$params$max_longitude, maximum_latitude = d$params$max_latitude,
        minimum_depth = d$params$min_depth, maximum_depth = d$params$max_depth,
        output_filename = d$nm, output_directory = saveDir
      )
    }
  }
  
  ## open as a raster to easily access info on crs and extent
  r <- rast(file.path(saveDir, d$nm))
  v <- unlist(vars)

  results <- lapply(
    ## for each variable we want whole year averages,
    ## as well as summer (january-march) and winter (july-september) averages
    list(annual = 1:12, winter = 7:9, summer = 1:3),
    function(m){
      yravgs <- lapply(
        list.files(saveDir, pattern = ".nc$", full.names = TRUE),
        function(nc){annual_summaries(nc, v, m)}
      )
      
      ## average by timeperiod
      ## after first merging arrays where multiple nc files
      dim2 <- dim(yravgs[[1]])[1:2]
      nyears <- sum(sapply(yravgs, function(x) dim(x)[3]))
      yravgs <- array(do.call(c, yravgs), dim = c(dim2, nyears))
      prd <- timeperiod_averages(yravgs)

      w <- case_when(
        max(m) == 3 ~ "summer_months",
        max(m) == 9 ~ "winter_months",
        max(m) == 12 ~ "all_months"
      )
      save_tiff(prd$averages, r, file.path(saveDir, sprintf("timeperiod_%s_%s.tif", w, str_to_lower(v))))
      save_tiff(prd$variability, r, file.path(saveDir, sprintf("timeperiod_%s_%s_var.tif", w, str_to_lower(v))))
      
      
      ## spatial weights used to average across raster pixels with differing areas
      spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
        cellSize(unit = "km") |> 
        ## looks upside-down now, but will align correctly 
        ## once t() and as.array() are applied in make_timeseries function
        flip(direction = "vertical")

      make_timeseries(
        yravgs, polygons, spatialweights, 
        file.path(saveDir, sprintf("timeperiod_%s_%s.csv", w, str_to_lower(v)))
      )
      return(TRUE)
  })
  return(TRUE)
}

## seaice data is extracted one year at a time because it is daily rather than monthly
## thus much larger, and it needs special processing to get sea ice minextent and total ice-days
get_seaice <- function(saveDir, vars, downloads){
  
  ## setup year ranges that we will loop over
  yrs <- substr(c(params$start_datetime, params$end_datetime), 1, 4)
  yrs <- yrs[1]:yrs[2]
  ystart <- as.Date(paste0(yrs, "-01-01"))
  df <- data.frame(year = numeric(), index = numeric(), coveragearea = numeric())

  ## download first year to initialize arrays and calculate spatial weights
  ## daily data is ~365 timesteps per year, too large to download all at once
  datasetID <- "cmems_mod_glo_phy_my_0.083deg_P1D-m"
  cmt$subset(
    dataset_id = datasetID, variables = vars,
    start_datetime = paste0(ystart[1], "T00:00:00"),
    end_datetime = paste0(ystart[1] + years(1) - days(1), "T00:00:00"),
    minimum_longitude = params$min_longitude, minimum_latitude = params$min_latitude,
    maximum_longitude = params$max_longitude, maximum_latitude = params$max_latitude,
    minimum_depth = params$min_depth, maximum_depth = params$max_depth,
    output_filename = nm, output_directory = saveDir, overwrite = TRUE
  )

  nc_data <- nc_open(file.path(saveDir, nm))
  nctmp <- ncvar_get(nc_data, "siconc")
  nc_close(nc_data)

  dim2 <- dim(nctmp)[1:2]
  extents <- array(NA, dim = c(dim2, length(yrs)))
  sums <- array(NA, dim = c(dim2, length(yrs)))

  r <- rast(file.path(saveDir, nm))
  spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
    cellSize(unit = "km") |>
    flip(direction = "vertical") |>
    t() |>
    as.array()

  ## calculate ice extent (minimum across year) and ice days (sum across year)
  ## using 15% concentration as threshold for "ice covered"
  useCutoff <- 0.15
  tmp <- extents(nctmp, cutoff = useCutoff, spatialweights)
  df <- rbind(df, cbind(year = yrs[1], tmp$df))
  extents[,,1] <- tmp$extent
  sums[,,1] <- tmp$sum

  ## loop through remaining years, downloading and processing one at a time
  for(i in 2:length(ystart)){
    cmt$subset(
      dataset_id = datasetID, variables = list("siconc"),
      start_datetime = paste0(ystart[i], "T00:00:00"),
      end_datetime = paste0(ystart[i] + years(1) - days(1), "T00:00:00"),
      minimum_longitude = params$min_longitude, minimum_latitude = params$min_latitude,
      maximum_longitude = params$max_longitude, maximum_latitude = params$max_latitude,
      minimum_depth = params$min_depth, maximum_depth = params$max_depth,
      output_filename = nm, output_directory = saveDir, overwrite = TRUE
    )

    nc_data <- nc_open(file.path(saveDir, nm))
    nctmp <- ncvar_get(nc_data, "siconc")
    nc_close(nc_data)

    ## handle dataset transition in 2021 from 'my' to 'myint'
    ## need to download both parts and merge for complete year
    if(ystart[i] == "2021-01-01"){
      datasetID <- "cmems_mod_glo_phy_myint_0.083deg_P1D-m"
      cmt$subset(
        dataset_id = datasetID, variables = list("siconc"),
        start_datetime = paste0(ystart[i], "T00:00:00"),
        end_datetime = paste0(ystart[i] + years(1) - days(1), "T00:00:00"),
        minimum_longitude = params$min_longitude, minimum_latitude = params$min_latitude,
        maximum_longitude = params$max_longitude, maximum_latitude = params$max_latitude,
        minimum_depth = params$min_depth, maximum_depth = params$max_depth,
        output_filename = "part2_seaice.nc", output_directory = saveDir, overwrite = TRUE
      )

      nc_data <- nc_open(file.path(saveDir, "part2_seaice.nc"))
      nctmp2 <- ncvar_get(nc_data, "siconc")
      nc_close(nc_data)

      nctmp <- array(c(nctmp, nctmp2), dim = c(dim2, 365))
    }

    tmp <- extents_and_sums(nctmp, cutoff = useCutoff, spatialweights, metric = "minext")
    df <- rbind(df, cbind(year = yrs[i], tmp$df))
    extents[,,i] <- tmp$extent
    sums[,,i] <- tmp$sum
  }

  ## save annual results as CSV, RDS, and TIFF
  write.csv(df, file.path(saveDir, "seaice_coverage_minext.csv"), row.names = FALSE)
  saveRDS(extents, file.path(saveDir, "seaice_minext.rds"))
  saveRDS(sums, file.path(saveDir, "seaice_icedays.rds"))

  save_tiff(extents, r, file.path(saveDir, "seaice_minext.tif"))
  save_tiff(sums, r, file.path(saveDir, "seaice_icedays.tif"))

  ## calculate 9-year timeperiod minimum extents
  prd_ext <- array(NA, dim = c(dim2, 3))
  for(i in 1:3){
    k <- (9*i-8):(9*i)
    tmp <- extents(extents[,,k], cutoff = 1, spatialweights)
    prd_ext[,,i] <- tmp$extent
  }
  save_tiff(prd_ext, r, file.path(saveDir, "timeperiod_seaice_minext.tif"))

  ## calculate timeperiod ice day averages and variability
  prd_icedays <- timeperiod_averages(sums)
  seaiceDaysDir <- file.path(dirname(saveDir), "seaiceDays")
  dir.create(seaiceDaysDir, recursive = TRUE, showWarnings = FALSE)
  save_tiff(prd_icedays$averages, r, file.path(seaiceDaysDir, "timeperiod_seaice_icedays.tif"))
  save_tiff(prd_icedays$variability, r, file.path(seaiceDaysDir, "timeperiod_seaice_icedays_var.tif"))
  make_timeseries(sums, spatialweights, file.path(seaiceDaysDir, "seaice_icedays.csv"))

  return(list(extents = extents, sums = sums, df = df))
}


## parameters to give copernicusmarine 
## define a subset of data to extract from their database
dataparams <- function(getdates, latitudes, longitudes, depths = c(0,0)) {
  getdates <- as.Date(getdates, format="%Y-%m-%d")
  return(list(
    start_datetime = paste0(getdates[1], "T00:00:00"),
    end_datetime = paste0(getdates[length(getdates)], "T00:00:00"),
    min_longitude = min(longitudes),
    min_latitude = min(latitudes),
    max_longitude = max(longitudes),
    max_latitude = max(latitudes),
    min_depth = min(depths),
    max_depth = max(depths)
  ))
}

## download and process data
## salinity is split in two datasets
params_sos_my <- dataparams(
  ## date range for 'my' dataset
  c("1998-01-01", "2022-12-31"), 
  c(latmin, latmax), 
  c(lonmin, lonmax),
)
params_sos_nrt <- dataparams(
  ## date range for 'nrt' dataset
  c("2023-01-01", "2024-12-31"), 
  c(latmin, latmax),
  c(lonmin, lonmax)
)
params_sos_my$datasetID <- "cmems_obs-mob_glo_phy-sss_my_multi_P1M"
params_sos_nrt$datasetID <- "cmems_obs-mob_glo_phy-sss_nrt_multi_P1M"

get_monthly_data(
  file.path(dirData, "surfaceSalinity"),
  vars = list("sos"),
  downloads = list(
    list(params = params_sos_my, nm = "salinity_my.nc"),
    list(params = params_sos_nrt, nm = "salinity_nrt.nc")
  )
)

## date range is based on where all 3 variables have data
## use lat/lon from global.R weddell gyre definition
params_chla <- dataparams(
  c("1998-01-01", "2024-12-31"), 
  c(latmin, latmax),
  c(lonmin, lonmax),
  c(0.5, 10)
)
params_chla$datasetID <- "c3s_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M"

get_monthly_data(
  file.path(dirData, "chlorophyllA"),
  vars = list("CHL"),
  downloads = list(list(params = params_chla, nm = "chlorophyll.nc"))
)


## seaice is also split into 2 datasets
params_ice_my <- dataparams(
  ## daterange for 'my' dataset
  c("1998-01-01", "2021-12-31"), 
  c(latmin, latmax),
  c(lonmin, lonmax),
  c(0.5, 10)
)
params_ice_myint <- dataparams(
  ## daterange for 'myint' dataset
  c("2022-01-01", "2024-12-31"), 
  c(latmin, latmax),
  c(lonmin, lonmax),
  c(0.5, 10)
)
params_ice_my$datasetID <- "cmems_mod_glo_phy_my_0.083deg_P1D-m"
params_ice_myint$datasetID <- "cmems_mod_glo_phy_myint_0.083deg_P1D-m"

get_seaice(
  file.path(dirData, "seaiceDays"),
  vars = list("siconc"),
  downloads = list(
    list(params = params_ice_my, nm = "seaice_cover_fraction_my.nc"),
    list(params = params_ice_myint, nm = "seaice_cover_fraction_myint.nc")
  )
)