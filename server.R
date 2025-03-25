server <- function(input, output, session) {

  ## map ----

  ## for polar crs need to custom define leaflet options
  ## https://thomasswilliams.github.io/development/r/2022/06/18/leaflet-and-r.html
  ## https://tile.gbif.org/ui/3031/EPSG3031-leaflet.js
  ## use 256 tile size resolutions (double) to accommodate generated tiles
  zooms <- 0:6
  resolutions <- 2*extent/256/2^zooms

  epsg_3031 <- leafletCRS(
    crsClass = "L.Proj.CRS",
    code = "EPSG:3031",
    proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs",
    resolutions = resolutions,
    origin = c(-extent, extent),
    bounds = list(c(-extent, -extent), c(extent, extent))
  )

  map_options <- leafletOptions(
    ## instead of -90,0 south pole,
    ## center the Weddell sea
    center = c(-75, -45),
    zoom = 3,
    minZoom = 3,
    maxZoom = 4,
    crs = epsg_3031,
    worldCopyJump = FALSE,
    preferCanvas = TRUE
  )
  gbif_tile_options <- tileOptions(
    ## shift zoom levels with offset
    ## to match 256px gdal tile grid
    tileSize = 512,
    zoomOffset = -1,
    noWrap = TRUE,
    continuousWorld = TRUE,
    updateWhenZooming = FALSE,
    updateWhenIdle = TRUE
  )
  tile_options <- tileOptions(
    tileSize = 256,
    noWrap = TRUE,
    opacity = 0.8,
    tms = TRUE,
    continuousWorld = TRUE
  )

  ## add tiles folders as resource paths
  ## https://stackoverflow.com/questions/59174298/using-addresourcepath-for-rendering-local-leaflet-tiles
  # resource_prefixes <- c("seaiceDays","seaiceMinExtent","chlorophyllA","chlorophyllA_Winter","chlorophyllA_Summer","surfaceSalinity") |>
  #   paste0(rep(c("_19982006","_20072015","_20162024","_2007diff","_2016diff"), 6)) |>
  #   sort()
  resource_prefixes <- "seaiceDays_2007diff"
  for(prefix in resource_prefixes){
    tilefolder <- file.path(dirData, str_replace_all(prefix, "_", "/"))
    addResourcePath(prefix, tilefolder)
  }

  # annualSalinity = list(
  #   rast_filepath = file.path(dirData, "surfaceSalinity", "timeperiod_all_months_salinity.tif"),
  #   tiles_1998 = file.path(dirData, "surfaceSalinity", "tiles_1998_2006"),
  #   tiles_2007 = file.path(dirData, "surfaceSalinity", "tiles_2007_2015"),
  #   tiles_2016 = file.path(dirData, "surfaceSalinity", "tiles_2016_2024")
  # )
  #
  # addResourcePath("dataset1", "path/to/dataset1/tiles")
  # addResourcePath("dataset2", "path/to/dataset2/tiles")
  # addResourcePath("dataset3", "path/to/dataset3/tiles")
  #
  # addResourcePath("dataset1", "path/to/dataset1/tiles")
  # addResourcePath("dataset2", "path/to/dataset2/tiles")
  # addResourcePath("dataset3", "path/to/dataset3/tiles")
  #


  ## two synced leaflet maps side-by-side
  output$map1 <- renderLeaflet({
    tilesLeft <- input$tilesLeft

    # input <- list()
    # input$taxonkey <- 212
    speciesOccurance <- paste(
      "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
      paste0("taxonKey=", input$taxonkey),
      paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
      "style=purpleYellow.point",
      sep = "&"
    )

    leaflet(options = map_options) |>
      addTiles(
        urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@2x.png?style=gbif-geyser-en",
        attribution = "OpenStreetMap | GBIF",
        layerId = "antartica_tiles",
        options = gbif_tile_options
      ) |>
      addTiles(
        urlTemplate = paste0("/", tilesLeft, "/{z}/{x}/{-y}.png"),
        group = "seaiceDays",
        options = tileOptions(
          tileSize = 256,
          noWrap = TRUE,
          opacity = 0.8,
          tms = TRUE,
          continuousWorld = TRUE
        )
      ) |>
      addTiles(
        urlTemplate = speciesOccurance,
        options = gbif_tile_options
      ) |>
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
      addLayersControl(
        overlayGroups = c("Statistical Areas", "Study Area", "Points of Interest"),
        position = "bottomleft"
      ) |>
      addPolygons(
        data = asd,
        group = "Statistical Areas",
        fillOpacity = 0, weight = 1
      ) |>
      addPolygons(
        data = wobec,
        group = "Study Area",
        popup = "Study Area",
        color = "red", fillOpacity = 0, weight = 2
      ) |>
      addCircles(
        data = maud_rise_center,
        group = "Points of Interest",
        popup = "Maud Rise",
        fill = FALSE, weight = 12
      ) |>
      addCircles(
        data = kap_norvegia,
        group = "Points of Interest",
        popup = "Kap Norvegia",
        fill = FALSE, weight = 12
      ) |>
      syncWith("maps")
  })

  output$map2 <- renderLeaflet({
    tilesRight <- input$tilesRight

    speciesOccurance <- paste(
      "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?srs=EPSG%3A3031",
      paste0("taxonKey=", input$taxonkey),
      paste0("basisOfRecord=", c("HUMAN_OBSERVATION", "MACHINE_OBSERVATION"), collapse = "&"),
      "style=purpleYellow.point",
      sep = "&"
    )

    leaflet(options = map_options) |>
      addTiles(
        urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@2x.png?style=gbif-geyser-en",
        attribution = "OpenStreetMap | GBIF",
        layerId = "antartica_tiles",
        options = gbif_tile_options
      ) |>
      addTiles(
        urlTemplate = paste0("/", tilesRight, "/{z}/{x}/{-y}.png"),
        group = "seaiceDays",
        options = tileOptions(
          tileSize = 256,
          noWrap = TRUE,
          opacity = 0.8,
          tms = TRUE,
          continuousWorld = TRUE
        )
      ) |>
      addTiles(
        urlTemplate = speciesOccurance,
        options = gbif_tile_options
      ) |>
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
      addLayersControl(
        overlayGroups = c("Statistical Areas", "Study Area", "Points of Interest"),
        position = "bottomleft"
      ) |>
      addPolygons(
        data = asd,
        group = "Statistical Areas",
        fillOpacity = 0, weight = 1
      ) |>
      addPolygons(
        data = wobec,
        group = "Study Area",
        popup = "Study Area",
        color = "red", fillOpacity = 0, weight = 2
      ) |>
      addCircles(
        data = maud_rise_center,
        group = "Points of Interest",
        popup = "Maud Rise",
        fill = FALSE, weight = 12
      ) |>
      addCircles(
        data = kap_norvegia,
        group = "Points of Interest",
        popup = "Kap Norvegia",
        fill = FALSE, weight = 12
      ) |>
      syncWith("maps")
  })

  ## comparison either in map of difference between two layers,
  ## or a scatter plot of the two layers' values
  # output$scatterplot <- renderPlotly({
  #
  # })
  #
  # output$mapdifference <- renderLeaflet({
  #
  # })
  #
  # output$comparison <- renderUI({
  #   condition <- input$select1 == input$select2
  #   if(condition){
  #     plotlyOutput("scatterplot")
  #   } else {
  #     leafletOutput("mapdifference")
  #   }
  # })


  ## time series plots ----

  ## start with an empty data frame
  # plotdata <- reactiveVal(list(
  #   values = data.frame(),
  #   plotymin = 0,
  #   ylab = ""
  # ))
  # ## wrangle data for plotting based on layer selected and line drawn
  # observeEvent(list(input$map_groups, input$map_draw_new_feature), {
  #   feature <- input$map_draw_new_feature
  #   plotlayer <- intersect(input$map_groups, names(data))
  #   if(!is.null(feature) & length(plotlayer) > 0){
  #     newdata <- wrangle_data(
  #       coords = feature$geometry$coordinates,
  #       layer =  data[[first(plotlayer)]]
  #     )
  #     plotdata(newdata)
  #   }
  # })
  # ## render plot
  # output$elevation_plot <- renderHighchart({
  #   if(input$plottype == "Time Series"){
  #     time_series_plot(plotdata())
  #   } else if(input$plottype == "Cross Section"){
  #     cross_section_plot(plotdata())
  #   }
  # })
  #
  # ## define CRS for  using Copernicus Marine Service tiles with EPSG 32761
  # leafletCRS(
  #   crsClass = "L.Proj.CRS",
  #   code = "EPSG:32761",
  #   proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
  # )
  #




}
