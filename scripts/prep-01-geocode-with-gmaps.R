
# Description:
# This script uses 3  different google apis to retrieve coordinates for the raw intersections and addresses given by
# the city of Providence. The first geocoding pass worked well on some addresses but not well on others. We then use google's
# autocomplete api to guess more locations. We retrieve coordinates from guesses via google's place details api. 
# My understanding is that gmaps returns coordinates in the WGS84 EPSG 4326 CRS

# Helpful links:
# https://developers.google.com/maps/documentation/geocoding/best-practices
# https://developers.google.com/maps/documentation/geocoding/overview
# https://rpubs.com/michaeldgarber/geocode

# BE SURE TO DELETE SAMPLE LINE ONCE WE RECEIVE THE CORRECT DATA FROM CITY - LINE 30 

# load packages -----------------------------------------------------------

library(tidyverse)
library(janitor)
library(here)
library(glue)
library(ggmap)
library(googleway)

# read in data ------------------------------------------------------------

raw <- read_csv(here("raw/pvd-accidents-raw.csv"),
                col_types = cols(
                  .default = col_character(),
                  CrashDate = col_date(format = "%d-%b-%y"),
                  CrashReportId = col_double(),
                  CrashTime = col_time(),
                  NumberofVehicles = col_double(),
                  PersonCount = col_double(),
                  InjuryCount = col_double(),
                  Latitude = col_character(),
                  Longitude = col_character()
                )) 

# register google api keys ------------------------------------------------

source(here("config/google-api-key.R"))

# for ggmap
register_google(key = google_key)

# for googleway
googleway::set_key(key = google_key)

# initial cleanup ---------------------------------------------------------

# reformat the addresses to work best with google's geocoder

accidents <- raw %>% 
  janitor::clean_names() %>% 
  select(-c(report_number, officer, badge)) %>% 
  mutate(has_st_number = str_detect(street_or_highway, "^[[:digit:]]"), #does the location column start with a digit?
         is_intersection_null = if_else(is.na(nearest_intersection), T, F),
         address = case_when(has_st_number == T ~ glue("{str_to_title(street_or_highway)}, Providence, RI, USA"),
                             is_intersection_null == T ~ glue("{str_to_title(street_or_highway)}, Providence, RI, USA"),
                             T ~ glue("{str_to_title(street_or_highway)} and {str_to_title(nearest_intersection)}, Providence, RI, USA")),
         address = str_replace(address, " St ", " Street "),
         address = str_replace(address, " St,", " Street,"),
         address = str_replace(address, " & ", " and "),
         address = if_else(is.na(address), "", address),
         is_address_blank = if_else(address == "", T, F),
         row_number = row_number(),
         scooter = case_when(scooter == "1" ~ T, T ~ F),
         wheel_chair = case_when(wheel_chair == "1" ~ T, T ~ F)) %>% 
  rename(lat_raw = latitude,
         lon_raw = longitude,
         manner_of_impact = mannerof_impact,
         number_of_vehicles = numberof_vehicles)

# first round of geocoding ------------------------------------------------

accidents_with_coordinates <- accidents %>% 
  mutate_geocode(address, output = "more")

addresses_with_warnings <- warnings()

# use autocomplete to improve accuracy of certain rows --------------------

uncertain_coords <- accidents_with_coordinates %>% 
  filter(!(type %in% c("intersection", "premise", "street_address", "subpremise")))

# define autocomplete api function
google_autocomplete <- function(address_xyz) {
  googleway::google_place_autocomplete(place_input = address_xyz,
                                       location = c(41.823989, -71.412834))
}

autocomplete_results <- uncertain_coords %>%
  pull(address...28) %>% 
  map(., google_autocomplete) 

# extract info from autocomplete results ----------------------------------

# extract addresses from autocomplete results
autocomplete_addresses <- map(autocomplete_results, ~pluck(.x, "predictions", "description")) 

# If autocomplete returned multiple addresses, set to NA, 
# If autocomplete didn't return a result with ' & ', set to NA
# If autcomplete returned NULL, set to NA
cleaned_autocomplete_addresses <- map_chr(autocomplete_addresses, ~if_else(length(.x) > 1, NA_character_,
                                                                           .x[[1]])) %>% 
  if_else(str_detect(., " & ", negate = T), NA_character_, .) %>% 
  na_if("NULL") 

# extract place ids from autocomplete results
autocomplete_place_ids <- map(autocomplete_results, ~pluck(.x, "predictions", "place_id")) 

cleaned_autocomplete_place_ids <- map_chr(autocomplete_place_ids, ~if_else(length(.x) > 1, NA_character_, .x[[1]]))

# get the coordinates of the locations found by autocomplete --------------

# add the autocomplete vectors into our uncertain_coords dataframe 
uncertain_coords_with_auto_cols <- uncertain_coords %>% 
  mutate(address_autocompleted = cleaned_autocomplete_addresses,
         place_ids_autocompleted = if_else(is.na(cleaned_autocomplete_addresses), 
                                           NA_character_, cleaned_autocomplete_place_ids),
         index = as.character(row_number()))

# define place api function
geocode_with_place_ids <- function(place_id) {
googleway::google_place_details(place_id) %>%
  pluck("result", "geometry", "location") %>% 
  as.data.frame()
}

# retrieve coordinates via google's place details api
second_round_coords <- uncertain_coords_with_auto_cols %>% 
  pull(place_ids_autocompleted) %>% 
  map_dfr(., geocode_with_place_ids, .id = "index")

# add the new coordinates back into full dataframe
combined <- uncertain_coords_with_auto_cols %>% 
  select(row_number, address_autocompleted, place_ids_autocompleted, index) %>% 
  left_join(., second_round_coords, by = c("index")) %>% 
  rename(lat_api_second_try = lat,
         lon_api_second_try = lng) %>% 
  left_join(accidents_with_coordinates, ., by = "row_number") %>% 
  arrange(row_number) %>% 
  select(row_number, crash_date, everything())

# final cleanup -----------------------------------------------------------

# rename, drop, and add columns
clean_combined <- combined %>% 
  rename(lon_api_first_try = lon,
         lat_api_first_try = lat,
         address_sent_to_geocoder = "address...28",
         address_returned_by_geocoder = "address...35",
         address_returned_by_autocomplete = address_autocompleted) %>%
  select(-c(south, north, east, west, index)) %>% 
  mutate(lat_api_best = case_when(!is.na(place_ids_autocompleted) ~ lat_api_second_try,
                                  T ~ lat_api_first_try),
         lon_api_best = case_when(!is.na(place_ids_autocompleted) ~ lon_api_second_try,
                              T ~ lon_api_first_try),
         api_coord_conf = case_when(has_st_number == T ~ "High",
                                    has_st_number == F & is_intersection_null == T ~ "Inaccurate",
                                    type %in% c("intersection", "premise", "street_address", "subpremise") ~ "Med High",                                    !is.na(place_ids_autocompleted) ~ "Med",
                                    T ~ "Med")) 

final <- clean_combined %>% 
  rowwise() %>% #compute distance between raw coords and best api coords
  mutate(distance_btwn_coords_meters = geosphere::distHaversine(c(as.numeric(lon_raw), as.numeric(lat_raw)), 
                                                                c(lon_api_best, lat_api_best)))

# write out data ----------------------------------------------------------

final %>% 
  write_csv("proc/addresses-with-gmaps-coordinates.csv")

# plot --------------------------------------------------------------------

# final %>% 
#   slice(78) %>% 
#   st_as_sf(coords = c("lon_best", "lat_best"), crs = 4326) %>% 
#   leaflet() %>% 
#   addProviderTiles(providers$CartoDB.Positron) %>%
#   setView(lng = -71.402550, lat = 41.826771, zoom = 14) %>%
#   addCircles(stroke = T,
#              color = "black",
#              weight = 10)


    
