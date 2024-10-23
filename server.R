server <- function(input, output, session) {

  ## handling user-uploaded data ----
  shpdata <- reactive({
    ## req ensures this code only runs when a file is uploaded
    req(input$shapefile)

    ## unzip the uploaded shapefile
    dirtmp <- tempdir()
    unzip(input$shapefile$datapath, exdir = dirtmp)
    tmpfile <- list.files(dirtmp, pattern = "\\.shp$", full.names = TRUE)
    if(length(tmpfile) == 1){
      shpfile <- st_read(tmpfile)
      if(st_crs(shpfile) != st_crs("EPSG:3031")){
        shpfile <- st_transform(shpfile, "EPSG:3031")
      }
    }
    if(length(tmpfile) != 1){
      ## TODO check the shp has at least 30% overlap with map latitudes?
      shpfile <- NULL
    }
    return(shpfile)
  })

  ## increase upload limit to 30MB (from default of 5) in options
  options(shiny.maxRequestSize = 30*1024^2)

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
      leafletProxy("map_cms") |>
        clearGroup("uploaded_data") %>%
        addPolygons(
          data = uploaded_data,
          group = "uploaded_data"
        )
    }
  })


  ## GBIF map ----
  ## GBIF tiles are in EPSG:3031 projection

  zooms <- 0:10
  tile_size <- 512
  map_options <- leafletOptions(
    ## instead of -90,0 south pole,
    ## center the Weddell sea
    center = c(-75, -45),
    zoom = 3,
    minZoom = 2,
    maxZoom = 5
  )
  tile_options <- tileOptions(
    minZoom = 2,
    maxZoom = 5,
    tileSize = tile_size,
    noWrap = FALSE,
    detectRetina = TRUE
  )

  ## for polar crs need to custom define leaflet options
  ## https://thomasswilliams.github.io/development/r/2022/06/18/leaflet-and-r.html
  ## https://tile.gbif.org/ui/3031/EPSG3031-leaflet.js

  gbif_extent <- 12367396.2185
  gbif_resolutions <- 2*gbif_extent / tile_size / 2^zooms
  gbif_map_options <- map_options
  gbif_map_options$crs <- leafletCRS(
    crsClass = "L.Proj.CRS",
    code = "EPSG:3031",
    proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs",
    resolutions = gbif_resolutions,
    origin = c(-gbif_extent, gbif_extent),
    bounds = list(c(-gbif_extent, -gbif_extent), c(gbif_extent, gbif_extent))
  )

  ## render the leaflet map
  output$map <- renderLeaflet({
    speciesOccurance <- paste(
      "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
      paste0("taxonKey=", input$taxonkey),
      paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
      "style=purpleYellow.point",
      sep = "&"
    )
    leaflet(options = gbif_map_options) |>
      addTiles(
        urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@1x.png?style=gbif-light",
        attribution = "OpenStreetMap | GBIF",
        layerId = "antartica_tiles",
        options = tile_options
      ) |>
      addTiles(
        urlTemplate = speciesOccurance,
        options = tile_options
      )
  })


  ## CMS map ----
  ## Copernicus tiles are in EPSG:32761 projection
  ## other data layers from other sources, will reproject to match...

  ## earth circumference at equator 40,075,017 meters
  ## 0.00028 is the standard meters-per-pixel for a 96 DPI screen
  ## meters per pixel = distance at equator / tile size in pixels (resolution at zoom 0)
  ## scale denominator = meters per pixel / standard meters-per-pixel for a 96 DPI screen
  ## scale denominator x standard meters-per-pixel for a 96 DPI screen = distance at equator / tile size in pixels

  cms_extent <- 20037508.3428
  cms_resolutions <- 2*cms_extent / tile_size / 2^zooms
  cms_map_options <- map_options
  cms_map_options$crs <- leafletCRS(
    crsClass = "L.Proj.CRS",
    code = "EPSG:32761",
    proj4def = "+proj=stere +lat_0=-90 +lon_0=0 +k=0.994 +x_0=2000000 +y_0=2000000 +datum=WGS84 +units=m +no_defs +type=crs",
    resolutions = cms_resolutions,
    origin = c(-cms_extent, cms_extent),
    bounds = list(c(-cms_extent, -cms_extent), c(cms_extent, cms_extent))
  )


  ## render the leaflet map
  output$map2 <- renderLeaflet({

    cms_style <- "default"
    # dataset <- paste(
    #   "SEAICE_ANT_PHY_L3_MY_011_018",
    #   "cmems_obs-si_ant_physic_my_drift-amsr_P2D_202311",
    #   "eastward_sea_ice_velocity",
    #   sep = "/"
    # )
    leaflet(options = cms_map_options) |>
      addTiles(
        urlTemplate = paste0(
          "http://wmts.marine.copernicus.eu/teroWmts/?",
          "service=WMTS&version=1.0.0&request=GetTile&tilematrixset=EPSG:32761@2x&tilematrix={z}&tilerow={y}&tilecol={x}",
          # paste0("&time=", "2021-06-01T00:00:00Z"),
          paste0("&style=", cms_style),
          paste0("&layer=", input$dataset)
        ),
        options = tile_options
      ) |>
      addPolygons(data = coast) |>
      addDrawToolbar(
        targetGroup = "draw",
        singleFeature = TRUE,
        polygonOptions = FALSE,
        markerOptions = FALSE,
        rectangleOptions = FALSE,
        circleOptions = FALSE,
        circleMarkerOptions = FALSE,
        editOptions = editToolbarOptions(
          edit = FALSE,
          remove = TRUE,
          selectedPathOptions = selectedPathOptions()
        )
      ) |>
      addMeasurePathToolbar(
        options = measurePathOptions(
          showOnHover = FALSE,
          minPixelDistance = 30,
          showDistances = TRUE,
          showArea = FALSE
        )
      )
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
      newdata <- wrangle_localdata(
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
}
