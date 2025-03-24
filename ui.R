ui <- page_sidebar(
  ## input elements in sidebar
  sidebar = sidebar(
    ## select which variables to map
    selectInput(
      inputId = "map1var",
      label = "Map (Left)",
      choices = c(
        "1", "2"
      ),
      selected = "Time Series"
    ),
    selectInput(
      inputId = "map2var",
      label = "Map (Right)",
      choices = c(
        "1", "2"
      ),
      selected = "Time Series"
    ),
    ## third chart to compare
    ## either scatter plot or difference map
    selectInput(
      inputId = "plot3type",
      label = "Comparison",
      choices = c(
        "Scatter Plot",
        "Difference Map"
      ),
      selected = "Scatter Plot"
    ),
    p(
      "Enter numeric GBIF taxon key (https://www.gbif.org/species) to add
      human and machine observation records from GBIF.",
      style = "font-size: 12px; color: #606891"
    ),
    textInput(
      inputId = "taxonkey",
      label = "GBIF Taxon Key",
      value = ""
    )
  ),

  ## main content area
  ## maps
  fluidRow(
    column(4, leafletOutput(outputId = "map1", height = "60vh")),
    column(4, leafletOutput(outputId = "map2", height = "60vh"))
    # column(4, leafletOutput(outputId = "comparison"))
  )
  ## time series
  # fluidRow(
  #   column(12, plotlyOutput("timeseries"))
  # )
)
