
library(tidyverse)

df <- read_csv(here::here("/proc/addresses-with-gmaps-coordinates.csv"))

df %>% filter(collision_type == "Other") %>% View()


dfx <- dfx %>% glimpse
  mutate(report_date = lubridate::as_date(report_date, format = "%d-%b-%y", tz = "EST"))

dfx %>% write_csv(here("proc/addresses-with-gmaps-coordinates.csv"))  

(format = "%d-%b-%y")


df %>% 
  filter(crash_date != report_date) %>%
  View()


df %>% 
  filter(distance_btwn_coords_meters > 20) %>% 
  select(lat_raw, lon_raw, lat_api_best,  lon_api_best, street_or_highway, 
         address_sent_to_geocoder, nearest_intersection, distance_btwn_coords_meters) %>% 
  View("qa")
