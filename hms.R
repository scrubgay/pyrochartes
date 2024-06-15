# hms functions
# generate a geopackage or shapefile from a directory of downloaded text files
# get the files from https://www.ospo.noaa.gov/Products/land/hms.html#data

# libraries ----
library(dplyr)
library(sf)

read_hms <- function(file) {
  data <- read.csv(file)
  
  data <- data |>
    mutate(
      Year = as.character(YearDay) |> substring(1, 4) |> as.integer(),
      Wday = as.character(YearDay) |> substring(5, 7) |> as.integer(),
      Date = lubridate::make_date(year = Year),
      Date = lubridate::`yday<-`(Date, Wday),
      across(c(Satellite, Method), stringr::str_squish)
    ) |> 
    select(Lon, Lat, Date, Satellite, Method, FRP) |> 
    st_as_sf(coords = c("Lon", "Lat")) |> 
    `st_crs<-`(4326)
  
  return(data)
}

download_hms <- function(hms_db, from_date = NULL, to_date = NULL) {
  form_date <- lubridate::stamp_date("01/29/1997")
  
  if (is.null(from_date)) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), hms_db)
    hms <- tbl(conn, "pts")
    
    from_date <- hms |> 
      summarize(max = max(Date)) |> 
      collect() |> 
      pull(max) |> 
      lubridate::ymd()
    
    lubridate::day(from_date) <- lubridate::day(from_date) + 1
    
    from_date <- form_date(from_date)
  }
  
  if (is.null(to_date)) {
    to_date <- form_date(lubridate::today())
  }

  # scraper
  command <- stringr::str_glue("python scrape_hms.py --start {from_date} --end {to_date}")
  system(command)
}

update_hms <- function(hms_db) {
  files <- list.files("~/Projects/github/pyrochartes/data/", full.names = TRUE, pattern = "*.txt$")
  florida <- read_sf("~/Projects/github/pyrochartes/data/geographies.gpkg", layer = "florida") |> 
    st_transform(st_crs(4326))
  flma <- read_sf("~/Projects/github/pyrochartes/data/geographies.gpkg", layer = "flma_202310") |> 
    st_transform(st_crs(4326)) |> 
    st_make_valid()
  
  dir.create("~/Projects/github/pyrochartes/data/completed")
  
  purrr::walk(files, \(file) {
    data <- read_hms(file)
    message(file)
    data <- data |> 
      mutate(FRP = ifelse(FRP == -999, NA, FRP)) |> 
      st_filter(florida) |> 
      st_join(flma |> select(FLMA = Name))
    
    if (nrow(data) > 0) {
      # write raw points
      write_sf(data, hms_db, layer = "pts", append = TRUE)
      
      # dbscan shit
      data$cluster <- (\(x) {
        x <- x |> 
          st_transform(3086) |> 
          st_coordinates() |>
          dbscan::dbscan(eps = 804, minPts = 3)
        
        return(x$cluster)})(data)
      
      clus <- data |> 
        group_by(cluster, Date) |> 
        summarize(
          FLMA = any(!is.na(FLMA)),
          FRP = mean(FRP, na.rm = TRUE),
          shape = st_union(geometry) |> st_convex_hull(),
          .groups = "drop"
        ) |> 
        filter(cluster != 0) 
      
      clus <- bind_rows(
        clus,
        data |>
          filter(cluster == 0) |>
          rename(shape = geometry) |> 
          select(cluster, Date, shape)
      )
      
      write_sf(clus, hms_db, layer = "polys", append = TRUE)
    }
    
    file_new = stringr::str_replace(file, "data/", "data/completed/")
    file.rename(file, file_new)
  }, .progress = TRUE)
}


path <- "~/Projects/github/pyrochartes/exports/fl_hms.gpkg"

download_hms(path)

update_hms(path)