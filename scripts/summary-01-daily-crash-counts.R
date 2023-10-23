

# load packages -----------------------------------------------------------

library(tidyverse)
library(lubridate)
library(here)

# read in data ------------------------------------------------------------

df_raw <- read_tsv(here("proc/processed-addresses-with-selected-fields.tsv"))

# summarize data ----------------------------------------------------------

df_summarised <- df_raw %>% 
  group_by(crash_date) %>% 
  summarise(crash_count = n_distinct(crash_report_id))

start_date <- as_date("2012-01-01")
end_date <- as_date("2022-12-31")

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
