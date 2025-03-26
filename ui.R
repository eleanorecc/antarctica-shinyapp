ui <- page_sidebar(
  ## input elements in sidebar
  sidebar = sidebar(
    width = 295,
    ## select which variables to map
    selectInput(
      inputId = "tilesLeft",
      label = "Left Map",
      choices = allrasters
    ),
    selectInput(
      inputId = "tilesRight",
      label = "Right Map",
      choices = allrasters
    ),
    br(),
    HTML(paste0(
      "<p style='font-size:12px; color:#606891; margin-bottom:-20px;'>",
      "Search GBIF using scientific name",
      "</p>"
    )),
    textInput(
      inputId = "taxonkey",
      label = NULL,
      value = ""
    ),
    br(),
    HTML(paste0(
      "<p style='font-size:18px; margin-bottom:-20px;'>Chlorophyll A Data:</p>",
      "<p style='font-size:12px; color:#606891'>",
      "Chlorophyll A averages calculated from Copernicus Marine Dataset:<br>",
      "<a href = 'https://data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104/services'>",
      "cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M",
      "</a></p>"
    )),
    HTML(paste0(
      "<p style='font-size:18px; margin-bottom:-20px'>Sea Ice Data:</p>",
      "<p style='font-size:12px; color:#606891'>",
      "Sea Ice averages and minimums calculated (taking >%15 covered area as 'ice covered') from Copernicus Marine Dataset:<br>",
      "<a href = 'https://data.marine.copernicus.eu/product/GLOBAL_MULTIYEAR_PHY_001_030/services'>",
      "cmems_mod_glo_phy_my_0.083deg_P1D-m",
      "</a></p>"
    )),
    HTML(paste0(
      "<p style='font-size:18px; margin-bottom:-20px;'>Salinity Data:</p>",
      "<p style='font-size:12px; color:#606891'>",
      "Salinity averages calculated from Copernicus Marine Dataset:<br>",
      "<a href = 'https://data.marine.copernicus.eu/product/MULTIOBS_GLO_PHY_S_SURFACE_MYNRT_015_013/services'>",
      "cmems_obs-mob_glo_phy-sss_my_multi_P1M",
      "</a></p>"
    ))
  ),

  ## main content area
  ## maps
  fluidRow(
    column(6, leafletOutput(outputId = "map1", height = "58vh")),
    column(6, leafletOutput(outputId = "map2", height = "58vh"))
  ),
  ## time series
  fluidRow(
    column(12, plotOutput("timeseries", height = "36vh"))
  )
)
