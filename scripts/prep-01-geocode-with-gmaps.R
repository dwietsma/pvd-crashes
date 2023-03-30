
# https://developers.google.com/maps/documentation/geocoding/overview
# my understanding is that gmaps returns coordinates in the WGS84 EPSG 4326 CRS

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
                  CrashDate = col_date(format = "%m/%d/%y"),
                  CrashReportId = col_double(),
                  CrashTime = col_time(format = ""),
                  NumberofVehicles = col_double(),
                  PersonCount = col_double(),
                  InjuryCount = col_double()
                )) %>% 
  sample_n(2000) # DELETE THIS LINE LATER

# register google api keys ------------------------------------------------

source(here("config/google-api-key.R"))

# for ggmap
register_google(key = google_key)

# for googleway
googleway::set_key(key = google_key)

# clean up ----------------------------------------------------------------

accidents <- raw %>% 
  janitor::clean_names() %>% 
  select(-c(report_number, officer, badge)) %>% 
  mutate(has_st_number = str_detect(street_or_highway, "^[[:digit:]]"), #does the location column start with a digit?
         address_original = if_else(has_st_number, glue("{str_to_title(street_or_highway)} Providence, RI"),
                           glue("{str_to_title(street_or_highway)} and {str_to_title(nearest_intersection)} Providence, RI")),
         row_number = row_number()) 

# autocomplete addresses --------------------------------------------------

# ggmap's mutate_geocode() function does not perform well on the address_original column.
# To improve the accuracy of our geocoding, we're first using google's 'place autocomplete api' to
# guess and reformat the address. We'll then pass those results into geocode().

# https://developers.google.com/maps/documentation/geocoding/best-practices

autocomplete_addresses <- function(address_xyz) {
  googleway::google_place_autocomplete(place_input = address_xyz,
                                       location = c(41.823989, -71.412834)) %>% 
    pluck(1, 1, 1) # index into returned list to pluck the first autocompletion for each address
}

autocompletion_vector <- accidents %>% 
  mutate(address_autocompleted = map(address_original, autocomplete_addresses)) %>% 
  pull(address_autocompleted) %>% 
  na_if("NULL") %>% # if no auto-completions are returned, change NULL to NA so we can create a simple character vector
  unlist()

# add the autocompletion vector into our accidents data frame as a new column
accidents_with_autocompletions <- accidents %>% 
  mutate(address_autocompleted = autocompletion_vector,
         autocompletion_found = case_when(is.na(address_autocompleted) ~ F,
                                          T ~ T))

# geocode -----------------------------------------------------------------

# 'EXIT' INTERSECTIONS ARE AMBIGUOUS - WILL NEED ATTENTION LATER

# some final address prep and geocoding
accidents_with_coords <- accidents_with_autocompletions %>%
  mutate(address_to_geocode = if_else(autocompletion_found == TRUE, address_autocompleted, as.character(address_original)),
         address_to_geocode = str_replace(address_to_geocode, " St ", " Street "),
         address_to_geocode = str_replace(address_to_geocode, " St,", " Street,"),
         address_to_geocode = str_replace(address_to_geocode, " & ", " and ")) %>% 
  mutate_geocode(address_to_geocode,
                 output = "more") 

warnings_from_geocoding <- warnings()

# write out data ----------------------------------------------------------

final <- accidents_with_coords %>% 
  rename(address_returned_by_geocoder = address) %>%
  write_csv("proc/addresses-with-gmaps-coordinates.csv")



    
