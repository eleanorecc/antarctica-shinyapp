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

get_seaice <- function(params, datasetID, user, pass, saveName){
  require(lubridate)
  require(reticulate)
  require(terra)

  virtualenv_create(envname = "CopernicusMarine")
  virtualenv_install("CopernicusMarine", packages = c("copernicusmarine"))
  use_virtualenv("CopernicusMarine", required = TRUE)

  cmt <- import("copernicusmarine")
  cmt$login(user, pass)

  nm <- "seaice_min_extents.nc"
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
  nctmp <- read_ncdata(saveDir, "siconc")

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
    nctmp <- read_ncdata(saveDir, "siconc")
    tmp <- extents_and_sums(nctmp, cutoff = useCutoff, spatialweights, metric = "minext")
    df <- rbind(df, cbind(year = yrs[i], tmp$df))
    extents[,,i] <- tmp$extent
    sums[,,i] <- tmp$sum
  }

  ## save data
  write.csv(df, file.path(saveDir, sprintf("coverage_%s_%s.csv", metric, saveName)))

  extents |>
    apply(MARGIN = c(1,3), FUN = function(x){rev(x)}) |>
    rast(ext(r), crs = crs(r)) |>
    writeRaster(file.path(saveDir, sprintf("%s_%s.csv", metric, saveName)))
  sums |>
    apply(MARGIN = c(1,3), FUN = function(x){rev(x)}) |>
    rast(ext(r), crs = crs(r)) |>
    writeRaster(file.path(saveDir, sprintf("sums_%s.csv", saveName)))

  return(list(
    extents = extents,
    sums = sums,
    df = df
  ))
}

## one dataset 1993-2020, another with 2021-2025 interm data
## 1993 to 2021-06-30 in cmems_mod_glo_phy_my_0.083deg_P1D-m
## 2021-07-01 to 2025 in cmems_mod_glo_phy_myint_0.083deg_P1D-m

## does year need to be split across date other than January 1st??
## what to do about 2021 split over two datasets around July 1st??

# c("1998-01-01", "2020-12-31") |>
#   dataparams(weddell_gyre_coords) |>
#   get_seaice(
#     "cmems_mod_glo_phy_my_0.083deg_P1D-m",
#     user, pass, "1998_2020_seaice"
#   )
# c("2022-01-01", "2024-12-31") |>
#   dataparams(weddell_gyre_coords) |>
#   get_seaice(
#     "cmems_mod_glo_phy_myint_0.083deg_P1D-m",
#     user, pass, "2020_2024_seaice"
#   )


getdata <- function(datasets = datlst, getdates){
  require(stringr)
  require(lubridate)
  require(httr2)

  getdates <- as.Date(getdates, format="%Y-%m-%d")
  start_datetime <- paste0(getdates[1], "T00:00:00")
  end_datetime <- paste0(getdates[length(getdates)], "T00:00:00")
  min_longitude <- min(weddell_gyre_coords$lon)
  min_latitude <- min(weddell_gyre_coords$lat)
  max_longitude <- max(weddell_gyre_coords$lon)
  max_latitude <- max(weddell_gyre_coords$lat)
  min_depth <- -1
  max_depth <- 10

  copernicus_datasets <- c(
    "seaice_daily_conc", "seaice_monthly_conc",
    "chla_monthly_modis", "biogeochem", "pH_roc", "surface_carbon"
  )
  if(any(dataset %in% copernicus_datasets)){
    if(is.null(user) | is.null(pass)){
      stop("Downloading requires a Copernicus Marine username and password")
    }
    ## https://help.marine.copernicus.eu/en/articles/863825
    ## how-to-download-data-via-the-copernicus-marine-toolbox-in-r
    require(reticulate)
    cmt <- import("copernicusmarine")
    cmt$login(user, pass)
  }

  if("dem" %in% datasets){
    ## CryoSat-2 digital elevation model
    download.file(
      url = "http://www.cpom.ucl.ac.uk/csopr/icesheets3/data/Antarctica_Cryosat2_1km_DEMv1.0.tif",
      destfile = file.path(dirData, "CPOM", "Antarctica_Cryosat2_1km_DEMv1.0.tif"),
      mode = "wb"
    )
  }
  if("bathymetry" %in% datasets){
    ## Smith and Sandwell bathymetry
    download.file(
      url = "https://topex.ucsd.edu/pub/global_topo_1min/topo_25.1.nc",
      destfile = file.path(dirData, "DEM", "topo_25.1.nc"),
      mode = "wb"
    )
  }
  if("seaice_daily_conc" %in% datasets){
    ## CERSAT SSM/I sea ice concentration
    # cersat_url <- "ftp://ftp.ifremer.fr/ifremer/cersat/products/gridded/psi-concentration/data/antarctic/daily/netcdf/"
    # cersat_ice_conc <- ""

    ## polarview bowerbird download isn't working
    ## use instead http directly https://seaice.uni-bremen.de/data-archive/
    ## s6250 means southern hemisphere 6250 resolution
    base_url <- "https://data.seaice.uni-bremen.de/amsr2/asi_daygrid_swath/s6250"
    tiflinks <- lapply(getdates, function(dt){
      yr <- substr(dt, 1, 4)
      mn <- str_to_lower(month(dt, label = TRUE))
      url <- sprintf("%s/%s/%s/Antarctic", base_url, yr, mn)
      txt <- request(url) |>
        req_perform() |>
        resp_body_string()
      ## current most recent version is v5.4
      tif <- str_extract_all(txt, '(?<=href=")[^"]+v5.4\\.tif(?=")')
      sprintf("%s/%s/%s/Antarctic/%s", base_url, yr, mn, unlist(tif))
    })
    dt <- dt |>
      str_replace_all("-", "") |>
      paste(collapse = "|")
    tiflinks <- unlist(tiflinks) |>
      grep(pattern = dt, value = TRUE)

    for(x in tiflinks){
      file_name <- file.path(dirData, "seaiceDailyConcentration", basename(x))
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
  if("seaice_monthly_conc" %in% datasets){
    ## not working...

    ## NCEP-DOE Reanalysis 2
    url_ncep <- "https://psl.noaa.gov/thredds/catalog/Datasets/ncep.reanalysis2/Monthlies/gaussian_grid"
    x <- "icec.sfc.mon.mean.nc"
    nm <- x |>
      str_replace_all("\\.", "_") |>
      str_replace("_nc", ".nc")
    ## monthly max temp,
    ## monthly mean wind speed,
    ## monthly surface ice concentration
    download.file(
      url = paste(url_ncep, x, sep = "/"),
      destfile = file.path(dirData, "reanalysis2NCEP", nm),
      mode = "wb"
    )
  }
  if("chla_monthly_modis" %in% datasets){
    if(is.null(user) | is.null(pass)){
      stop("Downloading requires a Earthdata username and password")
    }
    ## Oceandata MODIS Aqua Level-3 mapped monthly 9km chl-a
    ## this dataset comes from nasa oceancolor site
    require(reticulate)
    earthaccess <- import("earthaccess")
    auth <- earthaccess$login(strategy="interactive", persist=FALSE)
    ## will need an earthdata account
    ## may need to pip install earthaccess

    results <- earthaccess$search_data(
      short_name="MODISA_L3m_CHL",
      cloud_hosted=TRUE,
      temporal=c(starttime, endtime)
    )
    saveDir <- file.path(dirData, "chlorophyllMODIS")
    for(granule in results){
      earthaccess$download(
        granule,
        local_path=saveDir,
        access="direct"
      )
    }
  }
  if("chla_3d_monthly_copernicus" %in% datasets){
    nm <- ""
    saveDir <- file.path(dirData, "")



    ## MULTIOBS_GLO_BIO_BGC_3D_REP_015_010
  }
  if("biogeochem" %in% datasets){
    nm <- ""
    saveDir <- file.path(dirData, "")

    ## monthly mean biogeochemical parameters at 0.25 degree resolution
    ## https://data.marine.copernicus.eu/product/GLOBAL_ANALYSISFORECAST_BGC_001_028/description
    ## chla, nitrate, phosphate, siilicate, dissolved oxygen, dissolved iron,
    ## primary production, phytoplankton, pH, surface partial pressure of carbon dioxyde
    ## 50 vertical levels are ranging from 0 to 5700 meters
    cmt$subset(
      dataset_id = "",
      variables = list(),
      start_datetime = start_datetime,
      end_datetime = end_datetime,
      minimum_longitude = min_longitude,
      minimum_latitude = min_latitude,
      maximum_longitude = max_longitude,
      maximum_latitude = max_latitude,
      minimum_depth = min_depth,
      maximum_depth = max_depth,
      output_filename = "",
      output_directory = saveDir,
      force_download = TRUE
    )
  }
  if("oceancolor" %in% datasets){

    library(tidyr)
    library(stringr)
    library(CopernicusMarine)
    prd <- cms_products_list() |>
      rowwise() |>
      filter(tempExtentBegin <= "1998-01-01") |>
      mutate(tempExtentEnd = ifelse(str_length(tempExtentEnd) == 0, NA, tempExtentEnd)) |>
      filter(is.na(tempExtentEnd) | tempExtentEnd >= "2022-12-31") |>
      filter(unlist(areas)[[1]] == "Global Ocean", str_detect(product_id, "GLO")) |>
      select(product_id, title, tempExtentBegin, tempResolutions, mainVariables, tempExtentEnd) |>
      unnest(cols = c(mainVariables)) |>
      filter(mainVariables %in% c("Sea ice", "Plankton", "Optics", "Salinity"))
    # dat_oceancolor <- c(
    #   "OCEANCOLOUR_GLO_BGC_L4_MY_009_108",
    #   "OCEANCOLOUR_GLO_BGC_L4_NRT_009_102",
    #   "OCEANCOLOUR_GLO_BGC_L4_MY_009_104"
    # )
    # filter(prd, product_id %in% dat_oceancolor)

    nm <- "cmems_chl_4km_monthly.nc"
    saveDir <- file.path(dirData, "chlorophyllACopernicus")

    ## OCEANCOLOUR_GLO_BGC_L4_MY_009_104
    ##

    cmt$subset(
      dataset_id = "cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M",
      variables = list("CHL"),
      start_datetime = start_datetime,
      end_datetime = end_datetime,
      minimum_longitude = min_longitude,
      minimum_latitude = min_latitude,
      maximum_longitude = max_longitude,
      maximum_latitude = max_latitude,
      output_filename = nm,
      output_directory = saveDir
    )
  }
  if("pH_roc" %in% datasets){
    nm <- ""
    saveDir <- file.path(dirData, "")

    ## rates of change in surface ocean pH at 0.25 degree resolution
    ## https://data.marine.copernicus.eu/product/GLOBAL_OMI_HEALTH_carbon_ph_trend/description
    cmt$subset(
      dataset_id = "",
      variables = list(),
      start_datetime = start_datetime,
      end_datetime = end_datetime,
      minimum_longitude = min_longitude,
      minimum_latitude = min_latitude,
      maximum_longitude = max_longitude,
      maximum_latitude = max_latitude,
      minimum_depth = min_depth,
      maximum_depth = max_depth,
      output_filename = nm,
      output_directory = saveDir,
      force_download = TRUE
    )
  }
  if("surface_carbon" %in% datasets){
    nm <- ""
    saveDir <- file.path(dirData, "")

    ## monthly ocean surface carbon
    ## https://data.marine.copernicus.eu/product/MULTIOBS_GLO_BIO_CARBON_SURFACE_REP_015_008/description
    ## surface ocean pCO2, air-sea fluxes, pH, total alkalinity,
    ## dissolved inorganic carbon, saturation state wrt calcite and aragonite
    cmt$subset(
      dataset_id = "",
      variables = list(),
      start_datetime = start_datetime,
      end_datetime = end_datetime,
      minimum_longitude = min_longitude,
      minimum_latitude = min_latitude,
      maximum_longitude = max_longitude,
      maximum_latitude = max_latitude,
      minimum_depth = min_depth,
      maximum_depth = max_depth,
      output_filename = nm,
      output_directory = saveDir,
      force_download = TRUE
    )
  }
}
