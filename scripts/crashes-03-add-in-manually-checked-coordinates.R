
# Description -------------------------------------------------------------

# This script reads in the output from script 1 and the QA google sheet completed after script 2.
# It joins the information from the google sheet with the main dataframe and corrects records as specified in the google sheet.
# https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing (QA google sheet)

# load packages -----------------------------------------------------------

library(tidyverse)
library(googlesheets4)
library(googledrive)

# read in data ------------------------------------------------------------

# connect to google drive & sheets

# make sure you're in the right project folder
# here::here()

# designate project-specific cache
options(gargle_oauth_cache = here::here(".google_tokens"))

# check the value of the option, if you like
# gargle::gargle_oauth_cache()

# trigger auth on purpose --> store a token in the specified cache
# drive_auth()

# see your token file in the cache, if you like
# list.files(".google_tokens/")

# step 2 (do this all following runs)
# authorize
drive_auth(email = "dwietsma@gmail.com")
gs4_auth(token = drive_token())

# read in our police coordinate data
filepaths <- list.files(here::here("proc"),
                        pattern = "^addresses-with-gmaps-coordinates.*\\.tsv",
                        full.names = T)

full_df <- map_dfr(.x = filepaths,
               .f = read_tsv,
               show_col_types = FALSE,
               col_types = cols(crash_date = col_character(),
                                report_date = col_character())) %>%
  mutate(crash_date = lubridate::parse_date_time(crash_date, orders = c("Ymd", "mdy", "dby")) %>% as.Date(),
         report_date = lubridate::parse_date_time(report_date, orders = c("Ymd", "mdy", "dby")) %>% as.Date())

# read in our googlesheet used for manually quality assurance
google_sheet <- read_sheet("1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw")

# cleanup google sheet data -----------------------------------------------

google_sheet_cleaned <- google_sheet %>%
  select(-c(date_row_was_created, `notes (optional)`)) %>% 
  mutate(best_coordinate_set = case_when(best_coordinate_set == "Cannot be determined" ~ "Unknown",
                                         T ~ best_coordinate_set),
         corrected_lat = as.numeric(str_extract(correct_coordinates, "^\\d+\\.\\d+")),
         corrected_lon = as.numeric(str_extract(correct_coordinates, "-\\d+\\.\\d+")))

manually_qaed_records <- google_sheet_cleaned$crash_report_id

# join googlesheet with police data ---------------------------------------

# add manually created 'best_coordinate_set' field from out QA googlesheet to the full dataframe 
joined <-  left_join(full_df, google_sheet_cleaned, by = "crash_report_id")

# add fields and clean-up -------------------------------------------------

# add more cleaned up fields
final_full <- joined %>% 
  mutate(manually_qaed_record = if_else(crash_report_id %in% manually_qaed_records, T, F),
         best_coordinate_set = if_else(is.na(best_coordinate_set), "Raw", best_coordinate_set),
        final_lat = case_when(best_coordinate_set == "Neither" ~ corrected_lat,
                              best_coordinate_set == "Geocoded" ~ lat_api_best,
                              best_coordinate_set == "Raw" ~ lat_raw,
                              best_coordinate_set == "Unknown" ~ NA_real_),
         final_lon = case_when(best_coordinate_set == "Neither" ~ corrected_lon,
                               best_coordinate_set == "Geocoded" ~ lon_api_best,
                               best_coordinate_set == "Raw" ~ lon_raw,
                               best_coordinate_set == "Unknown" ~ NA_real_),
         hit_and_run = case_when(hit_and_run == "Yes, Driver Left Scene" ~ "Yes",
                                 hit_and_run == "Yes, M/V and Driver Left Scene" ~ "Yes",
                                 hit_and_run == "No" ~ "No",
                                 hit_and_run == "Unknown" ~ "Unknown",
                                 is.na(hit_and_run) ~ "Unknown"),
         most_serious_injury = case_when(most_serious_injury == "Complains Of Pain" ~ "Pain Reported",
                                         T ~ most_serious_injury),
         year = year(as.Date(crash_date)),
         month = month(as.Date(crash_date), label= T, abbr = F)) %>%
  filter(year >= 2010)

# write out data ----------------------------------------------------------

# write out all of the messy fields
final_full %>% 
  write_tsv(here::here("proc/processed-addresses-with-all-fields.tsv"))

# remove some of the messy fields and write out a more streamlined data set
final_selected <- final_full %>% 
  select(-c(is_address_blank, lon_api_first_try, lat_api_first_try, type, 
            loctype, address_returned_by_geocoder, address_returned_by_autocomplete, 
            place_ids_autocompleted, lat_api_second_try, lon_api_second_try, 
            lat_api_best, lon_api_best, distance_btwn_coords_meters, corrected_lat, corrected_lon, correct_coordinates))

final_selected %>% 
  write_tsv(here::here("proc/processed-addresses-with-selected-fields.tsv"))

