ui <- page_sidebar(
  tags$head(
    tags$style(HTML("
      #map {
        height: 65vh !important;
      }
    "))
  ),
  ## input elements in sidebar
  sidebar = sidebar(
    p(
      "Click the 'draw polyline' button in the top left of the map toolbar
      to draw a line on the map and view time series for those points,
      or cross-section of the data shown on the map.
      Select which type of map to view in the dropdown below",
      style = "font-size: 12px; color: #606891"
    ),
    selectInput(
      inputId = "plottype",
      label = "Plot Type",
      choices = c("Time Series", "Cross Section"),
      selected = "Time Series"
    ),
    p(
      "Enter numeric GBIF taxon key (see: https://www.gbif.org/species) to add
      human and machine observation records from GBIF.",
      style = "font-size: 12px; color: #606891"
    ),
    textInput(
      inputId = "taxonkey",
      label = "GBIF Taxon Key",
      value = ""
    ),
    p(
      "Upload a zipped shapefile (.zip) to view as an overlay on the map.
      If not already using coordinate ref. system EPSG:3031, the data will be transformed.",
      style = "font-size: 12px; color: #606891"
    ),
    fileInput(
      "shapefile",
      "Upload Shapefile",
      accept = c(".zip")
    )
  ),

  ## output from server function
  leafletOutput(outputId = "map"),

  ## timeseries or cross section plot
  highchartOutput("elevation_plot")
)
