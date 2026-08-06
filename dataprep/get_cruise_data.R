## (1) Get Polarstern cruise path
## (2) Download and process PANGEA data


## Polarstern expedition coordinates

## can find the AWI API expedition number by navigating to cruise in ship tracking site
## and using develper tools, network, XHR file column
## https://onexpedition.awi.de/polarstern/

## PS152 (WOBEC): 2025-12-15 (Walvis Bay, Namibia) – 2026-02-02 (Punta Arenas, Chile) 
url_polarstern_wobec <- "https://follow-polarstern.awi.de/wp-json/data-api/v1/data?expedition=1637"

## PS129 (HAFOS): 2022-03-03 (Cape Town, South Africa) – 2022-04-27 (Punta Arenas, Chile)
url_polarstern_hafos <- "https://onexpedition.awi.de/wp-json/data-api/v1/data?expedition=192"

## Create request and perform
get_cruise_data <- function(url, save_filename) {
  data <- request(url) |> 
    req_timeout(30) |> 
    req_retry(max_tries = 3) |> 
    req_perform() |> 
    resp_body_json(simplifyVector = TRUE)

  coords <- data$sensor |> 
    distinct(date, longitude, latitude) |> 
    filter(!is.na(longitude), !is.na(latitude)) |> 
    arrange(date)

  write.csv(
    coords,
    file.path(dirData, save_filename), 
    row.names = FALSE
  )
}
get_cruise_data(url_polarstern_wobec, "coords_polarstern_wobec.csv")
get_cruise_data(url_polarstern_hafos, "coords_polarstern_hafos.csv")


## PANGEA datasets

## two relevant cruises for the app, PANGEA entries urls
## https://www.pangaea.de/expeditions/events/PS152
## https://www.pangaea.de/expeditions/events/PS129

## can look for other cruises with PANGEA records
## https://www.pangaea.de/expeditions/


## just use 'download as tab-delimited table' link on page
# get_table <- function(){}

## For one event's start/end coordinate, find the nearest recorded track
## point to each, slice the track between those two points (inclusive),
## and use the event's own exact coordinates as the line's endpoints.
## Stationary events (start == end) collapse to a degenerate two-point line.
track_linestring <- function(lon_start, lat_start, lon_end, lat_end, track) {
  
  if(lon_start == lon_end && lat_start == lat_end){
    coords <- st_point(c(lon_start, lat_start))
    return(coords)
  }

  dist_start <- (track$longitude - lon_start)^2 + (track$latitude - lat_start)^2
  dist_end   <- (track$longitude - lon_end)^2   + (track$latitude - lat_end)^2
  idx_start <- which.min(dist_start)
  idx_end   <- which.min(dist_end)
  idx_range <- sort(c(idx_start, idx_end))

  track_slice <- track[idx_range[1]:idx_range[2], c("longitude", "latitude")]

  coords <- rbind(
    c(lon_start, lat_start),
    as.matrix(track_slice),
    c(lon_end, lat_end)
  )
  linestr <- st_linestring(coords)
  return(linestr)
}

clean_table <- function(dir_rawdata) {

  # x <- "/Users/eleanorecampbell/Downloads/events_PS152.tab"
  # x <- "/Users/eleanorecampbell/Downloads/events_PS129.tab"

  rawdata <- list.files(dir_rawdata, pattern = "events_PS.*tab$", full.names = TRUE) |>
    lapply(function(x){
      read.delim(x, sep = "\t") |>
        select(
          method_device = Method.Device,
          lat_start = Latitude,
          lon_start = Longitude,
          elv_start = Elevation,
          elv_end = Elevation.end,
          lat_end = Latitude.end,
          lon_end = Longitude.end
        ) |>
        mutate(cruise = ifelse(str_detect(x, "PS152"), "wobec", "hafos")) |>
        mutate(
          lat_end = coalesce(lat_end, lat_start),
          lon_end = coalesce(lon_end, lon_start),
          elv_end = coalesce(elv_end, elv_start),
          ## in some cases for elevation only the end is recorded
          ## for lat/lon start is always recorded and sometimes end but not always
          elv_start = coalesce(elv_start, elv_end)
        )
        ## coalesce is clearer and avoids ifelse's type-coercion pitfalls
        # mutate(
        #   lat_end = ifelse(is.na(lat_end), lat_start, lat_end),
        #   lon_end = ifelse(is.na(lon_end), lon_start, lon_end),
        #   elv_end = ifelse(is.na(elv_end), elv_start, elv_end),
        # )
    }) |>
    bind_rows()

  tracks <- list(
    wobec = read.csv(file.path(dirData, "coords_polarstern_wobec.csv")),
    hafos = read.csv(file.path(dirData, "coords_polarstern_hafos.csv"))
  )

  geometry <- Map(
    function(lon_start, lat_start, lon_end, lat_end, cruise){
      track_linestring(lon_start, lat_start, lon_end, lat_end, tracks[[cruise]])
    },
    rawdata$lon_start, rawdata$lat_start, 
    rawdata$lon_end, rawdata$lat_end, 
    rawdata$cruise
  )
  geometry <- vapply(geometry, st_as_text, character(1))

  cruise_data <- rawdata |>
    select(cruise, method_device) |>
    cbind(geometry = geometry)

  write.csv(
    cruise_data, 
    file.path(dirData, "cruise_data.csv"), 
    row.names = FALSE
  )
}

