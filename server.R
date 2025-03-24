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
    proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs",
    resolutions = resolutions,
    origin = c(-extent, extent),
    bounds = list(c(-extent, -extent), c(extent, extent))
  )
  ## polar crs used for Copernicus marine tiles...
  # epsg_32761 <- leafletCRS(
  #   crsClass = "L.Proj.CRS",
  #   code = "EPSG:32761",
  #   proj4def = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs",
  #   ...
  # )

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
  # addResourcePath("mytiles", data$`Polarview Ice Concentration`$tiles_filepath)


  ## two synced leaflet maps side-by-side
  output$map1 <- renderLeaflet({
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
        urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@1x.png?style=gbif-light",
        attribution = "OpenStreetMap | GBIF",
        layerId = "antartica_tiles",
        options = gbif_tile_options
      ) |>

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
      addPolygons(data = wobec, color = "red", fillOpacity = 0, weight = 1) |>
      addPolygons(data = weddell_gyre, color = "yellow", fillOpacity = 0, weight = 1) |>
      syncWith("maps")
      # addLayersControl(overlayGroups = c(names(allrasters))) |>
      # hideGroup(names(allrasters))
  })

  output$map2 <- renderLeaflet({
    leaflet(options = map_options) |>
      addTiles(
        urlTemplate = "https://tile.gbif.org/3031/omt/{z}/{x}/{y}@1x.png?style=gbif-light",
        attribution = "OpenStreetMap | GBIF",
        layerId = "antartica_tiles",
        options = gbif_tile_options
      ) |>
      addPolygons(data = wobec, color = "red", fillOpacity = 0, weight = 1) |>
      addPolygons(data = weddell_gyre, color = "yellow", fillOpacity = 0, weight = 1) |>
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
