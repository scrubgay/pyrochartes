# hms_fi.r
# generate a geopackage or shapefile from a directory of downloaded text files
# get the files from https://www.ospo.noaa.gov/Products/land/hms.html#data

# libraries ----
library(tidyverse)
library(sf)

# function ----
read_hms <- function(file) {
  data <- read_csv(file, show_col_types = FALSE)
  # if (!setequal(colnames(datum), c("Lon", "Lat", "YearDay", "Time", "Satellite", "Method", "Ecosystem", "FRP"))) {
  #   return()
  # }
  data <- data %>%
    st_as_sf(coords = c("Lon", "Lat")) %>%
    `st_crs<-`(4326)
  
  data <- data %>%
    mutate(
      Year = as.character(YearDay) %>% str_sub(1, 4),
      Wday = as.character(YearDay) %>% str_sub(5, 7) %>% as.integer(),
      Date = make_date(year = Year),
      Date = `yday<-`(Date, Wday)
    )

  yday(data$Date) <- data$wday
  
  data <- data %>%
    mutate(Month = month(Date) %>% month.name[.])

  return(data)
}

files <- list.files("./data/", full.names = TRUE, pattern = "*.txt$")

# filter <- read_sf("./data/cb_2018/cb_2018_us_state_20m.shp") %>%
#   filter(NAME == "Florida") %>%
#   st_transform(st_crs(3086))
# 
# flma <- read_sf("./data/flma_202310/flma.shp") %>%
#   st_transform(st_crs(3086))
# flma <- flma %>%
#   select(Name = MANAME,
#          Name_Short = MANAME_AB,
#          Part_of = MAJORMA,
#          Owner = OWNER,
#          Coowners = COOWNERS,
#          Managers = MANAGING_A,
#          Area = TOTACRES) %>%
#   mutate(across(where(is.character), ~ ifelse(.x == "ZZ", NA, .x)))
# 
# write_sf(filter, "./data/geographies.gpkg", layer = "florida")
# write_sf(flma, "./data/geographies.gpkg", layer = "flma_202310")

florida <- read_sf("./data/geographies.gpkg", layer = "florida")
flma <- read_sf("./data/geographies.gpkg", layer = "flma_202310")

dir.create("./data/completed")

walk(files, \(file) {
  data <- read_hms(file)
  data <- data %>%
    st_transform(st_crs(3086)) %>%
    st_filter(florida) %>%
    st_join(flma %>% select(FLMA = Name)) %>%
    st_transform(st_crs(4326))
  
  write_sf(data, "./exports/hms.gpkg", layer = "fl_hms", append = TRUE)
  
  file_new = str_replace(file, "data/", "data/completed/")
  file.rename(file, file_new)
  
}, .progress = TRUE)

today = as.character(`year<-`(today(), 2023))
query = str_glue("select Date, FLMA, geom from \"fl_hms\" where Date >= {today}")
data <- read_sf("./exports/hms.gpkg", query = query) %>%
  mutate(
    Growing = month(Date) %in% c(4:8),
    FRP = ifelse(FRP == -999, NA, round(FRP, 0)),
    FLMA = !is.na(FLMA),
    ThisSeason = year(Date) == year(today())
    )

write_sf(data, "data.geojson")
