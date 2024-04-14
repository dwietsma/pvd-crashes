
# https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing (QA googlesheet)

# load packages -----------------------------------------------------------

library(tidyverse)
library(sf)
# install.packages('sf', repos = c('https://r-spatial.r-universe.dev'))
library(googlesheets4)
library(googledrive)

# read in data ------------------------------------------------------------

# this should be the latest batch of data that you want to QA
df <- read.csv("proc/addresses-with-gmaps-coordinates-2023-04-01-to-2023-12-31.tsv", sep = "\t")

# process data ------------------------------------------------------------

df_selected <- df %>% 
  select(row_number, crash_report_id, street_or_highway, nearest_intersection, traffic_control, type, type_of_roadway,
         address_sent_to_geocoder, lat_raw, lon_raw, lat_api_best, lon_api_best, distance_btwn_coords_meters)

df_complete_cases <- df_selected %>% 
  drop_na(row_number, lon_api_best, lat_api_best, lon_raw, lat_raw)
  
sf_raw_coords <-  df_complete_cases %>% 
  select(row_number, lon_raw, lat_raw) %>% 
  st_as_sf(coords = c("lon_raw", "lat_raw"), crs = 4326)

sf_api_coords <- df_complete_cases %>% 
  select(row_number, lon_api_best, lat_api_best) %>% 
  st_as_sf(coords = c("lon_api_best", "lat_api_best"), crs = 4326)

# connect our coordinates with lines to visualize
sf_with_line_geo <- st_sfc(mapply(function(a,b){st_cast(st_union(a,b),"LINESTRING")}, sf_raw_coords$geometry, sf_api_coords$geometry, SIMPLIFY=FALSE)) %>% 
  bind_cols(df_complete_cases, .) %>% 
  rename("geometry" = starts_with("...")) %>% 
  st_as_sf(crs = 4326) 
  
# determine which coords are best -----------------------------------------

# for each record, we need to determine whether the raw or geocoded coordinates are correct (or maybe neither)
# if the distance between the two sets of coordinates is 100 or greater, they should be manually inspected (via tableau)
# and the best coordinate set should be selected and recored (via the google sheet)

sf_final <- sf_with_line_geo %>%
  mutate(best_coords = case_when(street_or_highway == nearest_intersection ~ "Raw",
                                 T ~ "Not yet determined")) %>% 
  filter(distance_btwn_coords_meters > 100) 

# write records to qa to google sheet -------------------------------------

# connect to google drive & sheets
drive_auth(email = "dwietsma@gmail.com")
gs4_auth(token = drive_token())

# read in the existing records that have already been qa'ed
sheet_ss <- "1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw"
gsheet_existing_records <- read_sheet(sheet_ss)

# append only records whose crash ids have not already been qa'ed
append_these_rows_to_google <- sf_final %>% 
  st_drop_geometry() %>% 
  select(crash_report_id,
         best_coordinate_set = best_coords) %>% 
  mutate(date_row_was_created = Sys.Date()) %>% 
  anti_join(., gsheet_existing_records, by = "crash_report_id")

# append rows
sheet_append(sheet_ss, append_these_rows_to_google, sheet = 1)


# write out data to be visualized to help qa ------------------------------

# this dataset will be visualized to in tableau to pick with coordinates look right
sf_final %>% 
  st_write(here::here("proc/qa-the-latest-batch-of-data/lines-between-coordinates.shp"),
           append = FALSE)


