server <- function(input, output, session) {

  ## map ----

  ## for polar crs need to custom define leaflet options
  ## https://thomasswilliams.github.io/development/r/2022/06/18/leaflet-and-r.html
  ## https://tile.gbif.org/ui/3031/EPSG3031-leaflet.js
  zooms <- 0:5
  resolutions <- extent / gbif_tile_size / 2^(zooms-1)

  epsg_3031 <- leafletCRS(
    crsClass = "L.Proj.CRS",
    code = "EPSG:3031",
    proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs",
    resolutions = resolutions,
    origin = c(-extent, extent),
    bounds = list(c(-extent, -extent), c(extent, extent))
  )
  map_options <- leafletOptions(
    ## instead of -90,0 south pole,
    ## center the Weddell sea
    center = c(-75, -45),
    zoom = 3,
    minZoom = 2,
    maxZoom = 5,
    crs = epsg_3031,
    worldCopyJump = FALSE,
    preferCanvas = TRUE
  )
  gbif_tile_options <- tileOptions(
    tileSize = gbif_tile_size,
    noWrap = TRUE,
    continuousWorld = TRUE,
    updateWhenZooming = FALSE,
    updateWhenIdle = TRUE
  )

  ## add tiles folders as resource paths
  ## https://stackoverflow.com/questions/59174298/using-addresourcepath-for-rendering-local-leaflet-tiles
  addResourcePath("mytiles", data$`Polarview Ice Concentration`$tiles_filepath)

  ## render the leaflet map
  output$map <- renderLeaflet({
    # input <- list()
    # input$taxonkey <- 212
    speciesOccurance <- paste(
      "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
      paste0("taxonKey=", input$taxonkey),
      paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
      "style=purpleYellow.point",
      sep = "&"
    )

    ## adjust the shiny map to display the tiles with screen slider between two sides so can compare two variables/stats/decades
    ## make two time series plots static at bottom based on selected variable/stat
    ## https://github.com/digidem/leaflet-side-by-side

    leaflet(options = map_options) |>
      addTiles(
        urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@1x.png?style=gbif-light",
        attribution = "OpenStreetMap | GBIF",
        layerId = "antartica_tiles",
        options = gbif_tile_options
      ) |>

      # addCmsWMTSTiles(
      #   product = "SST_GLO_SST_L4_NRT_OBSERVATIONS_010_001",
      #   layer = "analysed_sst",
      #   variable = "Sea surface temperature (SST)",
      #   tilematrixset = "EPSG:3031",
      #   options = WMSTileOptions(
      #     format = "image/png",
      #     transparent = TRUE
      #   )
      # ) |>
      # attribution = cms_cite_product("GLOBAL_ANALYSISFORECAST_PHY_001_024")

      ## TODO sort issue with misalignment of tiles...
      # addTiles(
      #   urlTemplate = "mytiles/{z}/{x}/{y}.png",
      #   group = "Polarview Ice Concentration",
      #   options = tileOptions(
      #     tileSize = gbif_tile_size,
      #     noWrap = TRUE,
      #     opacity = 0.2,
      #     continuousWorld = TRUE
      #   )
      # ) |>
      addTiles(
        urlTemplate = speciesOccurance,
        options = gbif_tile_options
      ) |>
      # addDrawToolbar(
      #   targetGroup = "draw",
      #   singleFeature = TRUE,
      #   polygonOptions = FALSE,
      #   markerOptions = FALSE,
      #   rectangleOptions = FALSE,
      #   circleOptions = FALSE,
      #   circleMarkerOptions = FALSE,
      #   editOptions = editToolbarOptions(
      #     edit = FALSE,
      #     remove = TRUE,
      #     selectedPathOptions = selectedPathOptions()
      #   )
      # ) |>
      # addMeasurePathToolbar(
      #   options = measurePathOptions(
      #     showOnHover = FALSE,
      #     minPixelDistance = 30,
      #     showDistances = TRUE,
      #     showArea = FALSE
      #   )
      # ) |>
      addLayersControl(overlayGroups = c(names(data))) |>
      hideGroup(names(data))
  })

  ## update when user uploads shapefile
  observe({
    uploaded_data <- shpdata()
    if(!is.null(uploaded_data)){
      leafletProxy("map") |>
        clearGroup("uploaded_data") %>%
        addPolygons(
          data = uploaded_data,
          group = "uploaded_data"
        )
    }
  })

  ## time series or cross section ----

  ## start with an empty data frame
  plotdata <- reactiveVal(list(
    values = data.frame(),
    plotymin = 0,
    ylab = ""
  ))
  ## wrangle data for plotting based on layer selected and line drawn
  observeEvent(list(input$map_groups, input$map_draw_new_feature), {
    feature <- input$map_draw_new_feature
    plotlayer <- intersect(input$map_groups, names(data))
    if(!is.null(feature) & length(plotlayer) > 0){
      newdata <- wrangle_data(
        coords = feature$geometry$coordinates,
        layer =  data[[first(plotlayer)]]
      )
      plotdata(newdata)
    }
  })
  ## render plot
  output$elevation_plot <- renderHighchart({
    if(input$plottype == "Time Series"){
      time_series_plot(plotdata())
    } else if(input$plottype == "Cross Section"){
      cross_section_plot(plotdata())
    }
  })

  ## define CRS for  using Copernicus Marine Service tiles with EPSG 32761
  leafletCRS(
    crsClass = "L.Proj.CRS",
    code = "EPSG:32761",
    proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
  )





}
