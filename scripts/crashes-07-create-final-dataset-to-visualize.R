
library(tidyverse)
library(lubridate)
# here

# read in data ------------------------------------------------------------

df_raw <- read_tsv(here::here("proc/processed-addresses-with-selected-fields-and-pvd-nhoods-wards-and-blocks.tsv"))

df_selected <- df_raw %>%
  select(crash_report_id, crash_date, crash_time, collision_type, address_sent_to_geocoder,
         hit_and_run, most_serious_injury, pvd_nhood, pvd_wards, geoid20,
         final_lat, final_lon) %>% 
  mutate(hit_and_run = case_when(hit_and_run == "Yes, Driver Left Scene" ~ "Yes",
                                 hit_and_run == "Yes, M/V and Driver Left Scene" ~ "Yes",
                                 hit_and_run == "No" ~ "No",
                                 hit_and_run == "Unknown" ~ "Unknown",
                                 is.na(hit_and_run) ~ "Unknown"),
         most_serious_injury = case_when(most_serious_injury %in% c("Complains Of Pain", "Non-Incapacitating") ~ "Non-Incapacitating",
                                         TRUE ~ most_serious_injury),
         year = year(crash_date),
         month = month(crash_date, label= T, abbr = F)) %>% 
  filter(!is.na(pvd_nhood),
         year >= 2010)

# write out data ----------------------------------------------------------

df_selected %>% 
  write_tsv(here::here("proc/final-pvd-crashes.tsv"))

