ui <- page_sidebar(
  ## input elements in sidebar
  sidebar = sidebar(
    width = 280,
    ## select which variables to map
    selectInput(
      inputId = "tilesLeft",
      label = "Left Map",
      choices = allrasters,
      selected = "seaiceDays_2007diff"
    ),
    selectInput(
      inputId = "tilesRight",
      label = "Right Map",
      choices = allrasters,
      selected = "seaiceDays_2007diff"
    ),
    br(),
    textInput(
      inputId = "taxonkey",
      label = "GBIF Taxon Key",
      value = ""
    ),
    p(
      "Enter numeric GBIF taxon key (https://www.gbif.org/species) to add
      human and machine observation records from GBIF.",
      style = "font-size: 12px; color: #606891"
    )
  ),

  ## main content area
  ## maps
  fluidRow(
    column(4, leafletOutput(outputId = "map1", height = "58vh")),
    column(4, leafletOutput(outputId = "map2", height = "58vh"))
    # column(4, uiOutput(outputId = "comparison"))
  )
  ## time series
  # fluidRow(
  #   column(12, plotlyOutput("timeseries"))
  # )
)
