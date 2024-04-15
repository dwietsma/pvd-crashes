

# load packages -----------------------------------------------------------

library(tidyverse)
library(lubridate)
library(here)

# read in data ------------------------------------------------------------

df_raw <- read_tsv(here("proc/final-pvd-crashes.tsv"),
                   col_types = cols(
                     crash_report_id = col_double(),
                     crash_date = col_date(format = ""),
                     crash_time = col_time(format = ""),
                     collision_type = col_character(),
                     address_sent_to_geocoder = col_character(),
                     hit_and_run = col_character(),
                     most_serious_injury = col_character(),
                     pvd_nhood = col_character(),
                     pvd_wards = col_double(),
                     geoid20 = col_double(),
                     year = col_double(),
                     month = col_character(),
                     final_lon = col_double(),
                     final_lat = col_double()
                   ))

# summarize data ----------------------------------------------------------

df_summarised <- df_raw %>% 
  group_by(crash_date) %>% 
  summarise(crash_count = n_distinct(crash_report_id))

# find the last day in the last month that a crash occurs
end_date <- rollforward(as_date(range(df_raw$crash_date)[2], roll_to_first = F))

# find the date of january 1 10 years before the end date
# (we only want to visualize 10 years for the lite bright tableau chart)
start_date <- as_date(paste(year(end_date - years(10)), "01", "01", sep = "-"))

date_seq <- seq(start_date, end_date, by = "day")

time_df <- data.frame(date = date_seq,
                      year = year(date_seq),
                      month = month(date_seq, label = T, abbr = F),
                      day_number = yday(date_seq))

final <- df_summarised %>% 
  filter(crash_date > start_date) %>% 
  left_join(time_df, ., by = c("date" = "crash_date")) %>% 
  replace_na(., list(crash_count = 0))

# final %>%  
#   mutate(day_with_crash = if_else(crash_count >= 1, T, F)) %>%  
#   group_by(year) %>% 
#   summarise(num_of_days = n(), 
#             day_with_crash = sum(day_with_crash)) %>% 
#   summarise(mean(day_with_crash))

# write out data ----------------------------------------------------------

final %>% 
  write_csv(here::here("proc/daily-crash-counts.csv"))
