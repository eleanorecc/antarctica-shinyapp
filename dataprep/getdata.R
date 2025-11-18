dataparams <- function(getdates, bboxcoords){
  getdates <- as.Date(getdates, format="%Y-%m-%d")

  return(list(
    start_datetime = paste0(getdates[1], "T00:00:00"),
    end_datetime = paste0(getdates[length(getdates)], "T00:00:00"),
    min_longitude = min(bboxcoords$lon),
    min_latitude = min(bboxcoords$lat),
    max_longitude = max(bboxcoords$lon),
    max_latitude = max(bboxcoords$lat),
    min_depth = 0.5,
    max_depth = 10
  ))
}

## copernicus marine data
## for sea ice concentration, chlorophyll a, and salinity

## https://help.marine.copernicus.eu/en/articles/863825
## how-to-download-data-via-the-copernicus-marine-toolbox-in-r

get_seaice <- function(params, user, pass){
  require(lubridate)
  require(reticulate)
  require(ncdf4)
  require(terra)

  cmt <- import("copernicusmarine")
  cmt$login(user, pass)

  nm <- "seaice_cover_fraction.nc"
  saveDir <- file.path(dirData, "seaiceExtent")

  yrs <- substr(c(params$start_datetime, params$end_datetime), 1, 4)
  yrs <- yrs[1]:yrs[2]
  ystart <- as.Date(paste0(yrs, "-01-01"))

  ## initialize dataframe
  df <- data.frame(
    year = numeric(),
    index = numeric(),
    coveragearea = numeric()
  )
  ## one dataset 1993-2020, another with 2021-2025 interm data
  ## 1993 to 2021-06-30 in cmems_mod_glo_phy_my_0.083deg_P1D-m
  ## 2021-07-01 to 2025 in cmems_mod_glo_phy_myint_0.083deg_P1D-m

  ## start with firstdataset, switch when reach split points
  datasetID <- "cmems_mod_glo_phy_my_0.083deg_P1D-m"
  cmt$subset(
    dataset_id = datasetID,
    variables = list("siconc"),
    start_datetime = paste0(ystart[1], "T00:00:00"),
    end_datetime = paste0(ystart[1] + years(1) - days(1), "T00:00:00"),
    minimum_longitude = params$min_longitude,
    minimum_latitude = params$min_latitude,
    maximum_longitude = params$max_longitude,
    maximum_latitude = params$max_latitude,
    minimum_depth = params$min_depth,
    maximum_depth = params$max_depth,
    output_filename = nm,
    output_directory = saveDir,
    overwrite = TRUE
  )
  nc_data <- nc_open(file.path(saveDir, nm))
  nctmp <- ncvar_get(nc_data, "siconc")
  nc_close(nc_data)

  ## initialize arrays
  dim2 <- dim(nctmp)[1:2]
  extents <- array(NA, dim = c(dim2, length(yrs)))
  sums <- array(NA, dim = c(dim2, length(yrs)))

  r <- rast(file.path(saveDir, nm))
  spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
    cellSize(unit = "km") |>
    flip(direction = "vertical") |>
    t() |>
    as.array()

  ## will use 15 percent as the cutoff meaning the pixel is ice covered
  ## https://blogs.egu.eu/divisions/cr/2020/04/10/did-you-know-the-difference-between-sea-ice-area-and-sea-ice-extent/
  useCutoff <- 0.15
  tmp <- extents_and_sums(nctmp, cutoff = useCutoff, spatialweights, metric = "minext")
  df <- rbind(df, cbind(year = yrs[1], tmp$df))
  extents[,,1] <- tmp$extent
  sums[,,1] <- tmp$sum

  ## annual min extents and sums
  for(i in 2:length(ystart)){
    cmt$subset(
      dataset_id = datasetID,
      variables = list("siconc"),
      start_datetime = paste0(ystart[i], "T00:00:00"),
      end_datetime = paste0(ystart[i] + years(1) - days(1), "T00:00:00"),
      minimum_longitude = params$min_longitude,
      minimum_latitude = params$min_latitude,
      maximum_longitude = params$max_longitude,
      maximum_latitude = params$max_latitude,
      minimum_depth = params$min_depth,
      maximum_depth = params$max_depth,
      output_filename = nm,
      output_directory = saveDir,
      overwrite = TRUE
    )
    nc_data <- nc_open(file.path(saveDir, nm))
    nctmp <- ncvar_get(nc_data, "siconc")
    nc_close(nc_data)


    if(ystart[i] == "2021-01-01"){
      datasetID <- "cmems_mod_glo_phy_myint_0.083deg_P1D-m"
      ## download other part of 2021 year
      cmt$subset(
        dataset_id = datasetID,
        variables = list("siconc"),
        start_datetime = paste0(ystart[i], "T00:00:00"),
        end_datetime = paste0(ystart[i] + years(1) - days(1), "T00:00:00"),
        minimum_longitude = params$min_longitude,
        minimum_latitude = params$min_latitude,
        maximum_longitude = params$max_longitude,
        maximum_latitude = params$max_latitude,
        minimum_depth = params$min_depth,
        maximum_depth = params$max_depth,
        output_filename = "part2_seaice.nc",
        output_directory = saveDir,
        overwrite = TRUE
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

  ## save data
  write.csv(df, file.path(saveDir, "seaice_coverage_minext.csv"))
  saveRDS(extents, file.path(saveDir, "seaice_minext.rds"))
  saveRDS(sums, file.path(saveDir, "seaice_icedays.rds"))

  save_tiff(extents, r, file.path(saveDir, "seaice_minext.tif"))
  save_tiff(sums, r, file.path(saveDir, "seaice_icedays.tif"))


  ## summarize by 3 time periods
  prd_ext <- array(NA, dim = c(dim2, 3))
  for(i in 1:3){
    k <- (9*i-8):(9*i)
    tmp <- extents_and_sums(extents[,,k], cutoff = 1, spatialweights, metric = "minext")
    prd_ext[,,i] <- tmp$extent
  }
  save_tiff(prd_ext, r, file.path(saveDir, "timeperiod_seaice_minext.tif"))

  prd_icedays <- timeperiod_averages(sums, spatialweights)
  save_tiff(prd_icedays$averages, r, file.path(dirname(saveDir), "seaiceDays", "timeperiod_seaice_icedays.tif"))
  save_tiff(prd_icedays$variability, r, file.path(dirname(saveDir), "seaiceDays", "timeperiod_seaice_icedays_var.tif"))
  write.csv(prd_icedays$table, file.path(dirname(saveDir), "seaiceDays", "seaice_icedays.csv"))

  return(list(
    extents = extents,
    sums = sums,
    df = df
  ))
}

get_chla <- function(params, user, pass){
  require(lubridate)
  require(reticulate)
  library(ncdf4)
  require(terra)

  cmt <- import("copernicusmarine")
  cmt$login(user, pass)

  nm <- "chlorophyll.nc"
  saveDir <- file.path(dirData, "chlorophyllA")

  # datasetID <- "cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M"
  datasetID <- "c3s_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M"
  cmt$subset(
    dataset_id = datasetID,
    variables = list("CHL"),
    start_datetime = params$start_datetime,
    end_datetime = params$end_datetime,
    minimum_longitude = params$min_longitude,
    minimum_latitude = params$min_latitude,
    maximum_longitude = params$max_longitude,
    maximum_latitude = params$max_latitude,
    minimum_depth = params$min_depth,
    maximum_depth = params$max_depth,
    output_filename = nm,
    output_directory = saveDir
  )

  r <- rast(file.path(saveDir, nm))
  spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
    cellSize(unit = "km") |>
    flip(direction = "vertical") |>
    t() |>
    as.array()

  results <- lapply(list(annual = 1:12, winter = 7:9, summer = 1:3), function(m){
    annual <- annual_summaries(file.path(saveDir, nm), ncvarname = "CHL",  months = m)
    prd <- timeperiod_averages(annual, spatialweights)

    w <- ifelse(
      max(m) == 12,
      "all_months",
      ifelse(
        max(m) == 9,
        "winter_months",
        "summer_months"
      )
    )
    save_tiff(prd$averages, r, file.path(saveDir, sprintf("timeperiod_%s_chla.tif", w)))
    save_tiff(prd$variability, r, file.path(saveDir, sprintf("timeperiod_%s_chla_var.tif", w)))
    write.csv(prd$table, file.path(saveDir,  sprintf("timeperiod_%s_chla.csv", w)))
    return(prd)
  })
  return(results)
}

get_salinity <- function(params, user, pass){
  require(lubridate)
  require(reticulate)
  library(ncdf4)
  require(terra)

  cmt <- import("copernicusmarine")
  cmt$login(user, pass)

  nm <- "salinity_my.nc"
  nm2 <- "salinity_nrt.nc"
  saveDir <- file.path(dirData, "surfaceSalinity")

  ## multi-year dataset 1993 to 2023, then need near-real-time one
  datasetID <- "cmems_obs-mob_glo_phy-sss_my_multi_P1M"
  cmt$subset(
    dataset_id = datasetID,
    variables = list("sos"),
    start_datetime = params$start_datetime,
    end_datetime = "2022-12-31T00:00:00",
    minimum_longitude = params$min_longitude,
    minimum_latitude = params$min_latitude,
    maximum_longitude = params$max_longitude,
    maximum_latitude = params$max_latitude,
    minimum_depth = 0,
    maximum_depth = 0,
    output_filename = nm,
    output_directory = saveDir
  )

  ## for 2024 need the near real time dataset
  ## also for 2023 as that years MY data ends in november
  datasetID <- "cmems_obs-mob_glo_phy-sss_nrt_multi_P1M"
  cmt$subset(
    dataset_id = datasetID,
    variables = list("sos"),
    start_datetime = "2023-01-01T00:00:00",
    end_datetime = params$end_datetime,
    minimum_longitude = params$min_longitude,
    minimum_latitude = params$min_latitude,
    maximum_longitude = params$max_longitude,
    maximum_latitude = params$max_latitude,
    minimum_depth = 0,
    maximum_depth = 0,
    output_filename = nm2,
    output_directory = saveDir
  )

  r <- rast(file.path(saveDir, nm))
  spatialweights <- rast(ext(r), resolution = res(r), crs = crs(r)) |>
    cellSize(unit = "km") |>
    flip(direction = "vertical") |>
    t() |>
    as.array()

  dim2 <- dim(spatialweights)[1:2]

  results <- lapply(list(annual = 1:12, winter = 7:9, summer = 1:3), function(m){
    annual <- annual_summaries(file.path(saveDir, nm), ncvarname = "sos", months = m)
    annual2 <- annual_summaries(file.path(saveDir, nm2), ncvarname = "sos", months = m)
    prd <- array(c(annual, annual2), dim = c(dim2, 27)) |>
      timeperiod_averages(spatialweights)

    w <- ifelse(
      max(m) == 12,
      "all_months",
      ifelse(
        max(m) == 9,
        "winter_months",
        "summer_months"
      )
    )
    save_tiff(prd$averages, r, file.path(saveDir, sprintf("timeperiod_%s_salinity.tif", w)))
    save_tiff(prd$variability, r, file.path(saveDir, sprintf("timeperiod_%s_salinity_var.tif", w)))
    write.csv(prd$table, file.path(saveDir,  sprintf("timeperiod_%s_salinity.csv", w)))
    return(prd)
  })

  return(results)
}


## use functions to get all the data...
# params <- dataparams(c("1998-01-01","2024-12-31"), weddell_gyre_corners)
# result_seaice <- get_seaice(params, user, pass)
# result_chla get_chla(params, user, pass)
# result_salinity <- get_salinity(params, user, pass)
