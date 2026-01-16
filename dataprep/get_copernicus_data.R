## Download and process Copernicus Marine Service data

## first will need copernicusmarine
# reticulate::py_install("copernicusmarine")

## set login for copernicus
## don't save in script!
cmt <- import("copernicusmarine")
cmt$login(copernicus_login_user, copernicus_login_pass)

## load make_timeseries function and create timeseries table
source(here("dataprep/make_timeseries.R"))

## polygons to calculate the timeseries over
polygons <- filter(asd, str_detect(GAR_Name, "48|58.6|58.7|58.4.4"))

  
## helper functions using arrays for aggregations
## annual summaries, timeperiod averages, extents, and save tiffs
annual_summaries <- function(ncFile, ncvarname, months, summarystat) {

  ## would need to have checked the ncvarname, and 
  ## downloaded one netcdf file to check about the time dimension...

  ## get the data and time variable from the netcdf file
  nc_data <- nc_open(ncFile)
  x <- ncvar_get(nc_data, ncvarname)
  xtime <- ncvar_get(nc_data, "time")
  nc_close(nc_data)

  dim2 <- dim(x)[1:2]

  ## formatting of the time variable
  ## differs between datasets
  if(ncvarname %in% c("CHL")){
    origin <- as.POSIXct("1970-01-01", tz = "UTC")
    datayears <- format(as.POSIXct(xtime, origin = origin, tz = "UTC"), "%Y")
  }
  ## why is this not consistent across copernicus datasets??
  ## note- sea ice ncdf created by get_seaice_data function below
  if(ncvarname %in% c("sos", "icedays")){
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

    if(summarystat == "mean"){
      y[,,i] <- rowMeans(x[,,k], na.rm = TRUE, dims = 2)
    }
    if(summarystat == "sum"){
      y[,,i] <- rowSums(x[,,k], na.rm = TRUE, dims = 2)
    }

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

get_monthly_data <- function(saveDir, vars, downloads, polygons) {
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
  
  ## open one a raster to easily access info on crs and extent
  ## doesn't matter which one because they have same dims
  r <- rast(file.path(saveDir, d$nm))
  v <- unlist(vars)

  results <- lapply(
    ## for each variable we want whole year averages,
    ## as well as summer (january-march) and winter (july-september) averages
    list(annual = 1:12, winter = 7:9, summer = 1:3),
    function(m){
      yravgs <- lapply(
        list.files(saveDir, pattern = ".nc$", full.names = TRUE),
        function(nc){annual_summaries(nc, v, m, "mean")}
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

## seaice data is extracted one month at a time because it is daily, thus much larger
## we use daily dataset to calculate the total monthly ice-days, later aggregate to annual
get_seaice_data <- function(saveDir, vars, downloads, cutoff, polygons) {
  if(!file.exists(saveDir)){
    dir.create(saveDir, recursive = TRUE, showWarnings = FALSE)

    for(i in 1:length(downloads)) {
      d <- downloads[[i]]

      ## set up looping over months
      month_starts <- seq(
        as.Date(d$params$start_datetime), 
        as.Date(d$params$end_datetime), 
        by = "month"
      )
      month_ends <- ceiling_date(month_starts, "month") - days(1)

      ## get the month's data and save it to a temporary nc file, 
      ## apply 15% cutoff to make it binary - ice / not ice covered
      ## sum icedays per month and save that to new ncdf file with proper time dimension
    
      savefile <- file.path(saveDir, str_replace(d$nm, "cover_fraction", "days"))

      for(m in 1:length(month_starts)){
        cmt$subset(
          dataset_id = d$params$datasetID, variables = vars,
          start_datetime = paste0(month_starts[m], "T00:00:00"), 
          end_datetime = paste0(month_ends[m], "T00:00:00"),
          minimum_longitude = d$params$min_longitude, minimum_latitude = d$params$min_latitude,
          maximum_longitude = d$params$max_longitude, maximum_latitude = d$params$max_latitude,
          minimum_depth = d$params$min_depth, maximum_depth = d$params$max_depth,
          output_filename = d$nm, output_directory = saveDir, 
          overwrite = TRUE
        )
        nc_data <- nc_open(file.path(saveDir, d$nm))
        x <- ncvar_get(nc_data, unlist(vars))

        if(m == 1){
          ## initialize ncdf to store monthly results
          ## the dimensions here are called latitude and longitude
          lon <- ncvar_get(nc_data, "longitude")
          lat <- ncvar_get(nc_data, "latitude")
          dim_lon <- ncdim_def("longitude", "degrees_east", lon)
          dim_lat <- ncdim_def("latitude", "degrees_north", lat)

          monthtimes <- as.numeric(difftime(month_starts, as.Date("1950-01-01"), units = "hours"))
          dim_time <- ncdim_def("time", "hours since 1950-01-01 00:00:00", monthtimes, unlim = TRUE)

          var_icedays <- ncvar_def(
            name = "icedays",
            units = "days",
            dim = list(dim_lon, dim_lat, dim_time),
            missval = -9999,
            longname = "Days per month with sea ice (concentration >= 15%)"
          )
          nc_out <- nc_create(savefile, vars = list(var_icedays))
          nc_close(nc_out)
        }
        nc_close(nc_data)

        ## calculate icedays
        x[x < cutoff] <- NA
        x[x >= cutoff] <- 1

        nc_out <- nc_open(savefile, write = TRUE)
        ncvar_put(
          nc_out, 
          "icedays", 
          rowSums(x, na.rm = TRUE, dims = 2),
          start = c(1, 1, m),
          count = c(-1, -1, 1)
        )
        nc_close(nc_out)
      }
    }
  }

  ## now calculate annual summaries 
  ## based on the monthly icedays ncdf file created

  ## open one a raster to easily access info on crs and extent
  ## doesn't matter which one because they have same dims
  r <- rast(file.path(saveDir, d$nm))

  ## annual sum for total seaice days
  ## summary stat for seaice days is sum not average like for other vars
  yrsums <- lapply(
    list.files(saveDir, pattern = "days.*nc$", full.names = TRUE),
    function(nc){annual_summaries(nc, "icedays", months = 1:12, summarystat = "sum")}
  )
  ## average by timeperiod
  ## after first merging arrays where multiple nc files
  dim2 <- dim(yrsums[[1]])[1:2]
  nyears <- sum(sapply(yrsums, function(x) dim(x)[3]))
  yrsums <- array(do.call(c, yrsums), dim = c(dim2, nyears))
  prd <- timeperiod_averages(yrsums)

  save_tiff(prd$averages, r, file.path(saveDir, "timeperiod_icedays_all_months.tif"))
  save_tiff(prd$variability, r, file.path(saveDir, "timeperiod_icedays_all_months_var.tif"))

  ## spatial weights used to average across raster pixels with differing areas
  spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
    cellSize(unit = "km") |> 
    ## looks upside-down now, but will align correctly
    ## once t() and as.array() are applied in make_timeseries function 
    flip(direction = "vertical")
  
  make_timeseries(
    yrsums, polygons, spatialweights,
    file.path(saveDir, "timeperiod_all_months_icedays.csv")
  )

  return(TRUE)
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

get_seaice_data(
  file.path(dirData, "seaiceDays"),
  vars = list("siconc"),
  downloads = list(
    list(params = params_ice_my, nm = "seaice_cover_fraction_my.nc"),
    list(params = params_ice_myint, nm = "seaice_cover_fraction_myint.nc")
  )
)

## merge timeseries tables
## to create tsData.csv
merge_timeseries()