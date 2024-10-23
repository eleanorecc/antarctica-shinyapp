source(here::here("global.R"))


## to control download and sync
getdata <- FALSE
syncdata <- FALSE
testrun <- TRUE


## datasets to download ----
if(getdata){

  ## blueant datasets
  # cersat_ice_conc <- sources_seaice(
  #   "CERSAT SSM/I sea ice concentration",
  # )
  # usnic_ice_edge <- sources_seaice(
  #   "National Ice Center Antarctic daily sea ice charts",
  # )
  # aqua_modis_chla <- sources_ocean_colour(
  #   "Oceandata MODIS Aqua Level-3 mapped monthly 9km chl-a",
  # )
  # aqua_modis_sst <- sources_sst(
  #   "Oceandata MODIS Aqua Level-3 mapped monthly 9km SST",
  # )
  # ncep_reanalysis2 <- sources_reanalysis(
  #   "NCEP-DOE Reanalysis 2",
  # )
  # cryosat2_dem <- sources_topography(
  #   "CryoSat-2 digital elevation model",
  # )
  # bathymetry <- sources_topography(
  #   "Smith and Sandwell bathymetry",
  # )


  ## download directly from sources...

  ## NCEP-DOE Reanalysis 2
  ## would use RNCEP R package but issue with tcltk on server, and with gcc and gfortran for tgp pkg locally...
  url_ncep <- "https://psl.noaa.gov/thredds/fileServer/Datasets/ncep.reanalysis2/Monthlies/gaussian_grid/"
  lyrs <- c(
    "tmax.2m.mon.mean.nc",
    "tmp.0-10cm.mon.mean.nc",
    "tmp.10-200cm.mon.mean.nc",
    "wspd.10m.mon.mean.nc",
    "icec.sfc.mon.mean.nc"
  )
  ## monthly max temp,
  ## monthly 0-10cm BGL temp,
  ## monthly 10-200cm BGL temp,
  ## monthly mean wind speed,
  ## monthly surface ice concentration
  for(x in lyrs){
    nm <- x |>
      str_replace_all("\\.", "_") |>
      str_replace("_nc", ".nc")
    download.file(
      url = paste0(url_ncep, x),
      destfile = file.path(dirData, "Reanalysis-NCEP-DOE", nm),
      mode = "wb"
    )
  }

  ## CryoSat-2 digital elevation model
  ## already has EPSG3031 crs
  download.file(
    url = "http://www.cpom.ucl.ac.uk/csopr/icesheets3/data/Antarctica_Cryosat2_1km_DEMv1.0.tif",
    destfile = file.path(dirData, "DEM", "Antarctica_Cryosat2_1km_DEMv1.0.tif"),
    mode = "wb"
  )

  ## Smith and Sandwell bathymetry
  download.file(
    url = "https://topex.ucsd.edu/pub/global_topo_1min/topo_25.1.nc",
    destfile = file.path(dirData, "DEM", "topo_25.1.nc"),
    mode = "wb"
  )


  ## additional datasets from copernicus marine portal

  ## rates of change in surface ocean pH at 0.25 degree resolution
  ## https://data.marine.copernicus.eu/product/GLOBAL_OMI_HEALTH_carbon_ph_trend/description


  ## monthly mean biogeochemical parameters at 0.25 degree resolution
  ## https://data.marine.copernicus.eu/product/GLOBAL_ANALYSISFORECAST_BGC_001_028/description

  ## chla, nitrate, phosphate, siilicate, dissolved oxygen, dissolved iron,
  ## primary production, phytoplankton, pH, surface partial pressure of carbon dioxyde
  ## 50 vertical levels are ranging from 0 to 5700 meters


  ## monthly ocean surface carbon
  ## https://data.marine.copernicus.eu/product/MULTIOBS_GLO_BIO_CARBON_SURFACE_REP_015_008/description

  ## surface ocean pCO2, air-sea fluxes, pH, total alkalinity,
  ## dissoved inorganic carbon, saturation state wrt calcite and aragonite


  ## COGS
  # cog.url <- "ftp://palantir.boku.ac.at/Public/ClimateData/v4_cogeo/AllDataRasters/"
  # con <- curl(cog.url, "r", handle = new_handle(dirlistonly = TRUE))
  # read.table(con)
  # close(con)

}



