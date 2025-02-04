# Providence Crash Map Project

## Background

The Providence Street Coalition decided to create a crash map that displays the coordinates of cycling and pedestrian crashes in Providence, Rhode Island. The motivation of this project is to make these data transparent to the Providence community, and to potentially identify areas in the city that are particularly dangerous. The Coalition hopes that these data help inform community members, policy makers, planners, and safe street advocates about street safety conditions.

## Data Sourcing Overview

A Providence Streets Coalition member submitted a FOIA request to Rhode Island's department of transportation to source statewide crash data. The request was denied. Read about it in this [ProJo article](https://www.providencejournal.com/story/news/local/2023/06/26/rhode-island-crash-data-dangerous-roads-providence-streets-coalition/70337934007/). The group was able to source Providence crash data from the city's police department. These are the data used in this project.

## Data Processing and QA Overview

Notably, these data only represent crashes in the city when a police report is filed. The data set is longitudinal and includes crashes that occurred over more than a decade. When a police report is filed from a crash, the officer records some general information about the incident and it's location.

Although the raw data set included coordinates, the data team wanted to quality check these locations. The 1st script runs the street address and intersection information through a series of google apis to obtain secondary coordinate sets. We compare the original (raw) coordinates to the secondary coordinates (returned by google). If the coordinate sets are more than 100 meters apart, we write these records to a [shared googlesheet](https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing%20(QA%20googlesheet)). We manually inspect the records in the googlesheet with the help of a tableau visualization. In the googlesheet we specify which coordinate sets are best (occasionally it's neither and we write in alternative coordinates to use). These records get re-absorbed and eventually inform a series of tableau and arc map visualizations.

## How to Request Data

Submit a FOIA resquest to the city of Providence to obtain crash recorded for period you'd like add to the project.

## Project Setup

### Pull down repo from GitHub

``` bash
git clone https://github.com/dwietsma/pvd-crashes.git
```

### Setup Google API Key

This project [requires a google api key](https://developers.google.com/maps/documentation/geocoding/get-api-key). Follow these instructions to obtain a key. Once you've generated the key, create a directory called "config" within the "pvd-crashes" directory. Create a file within the "config" subdirectory called "google-api-key.R". Enter your key in this file using the following format:

``` r
google_key <- "enterkeyhere"
```

### R package setup with renv

Open the .Rproj file. Run the following to install all necessary packages:

``` r
if (!require("renv")) install.packages("renv") renv::restore()
```

### You also need the PROJ installed on your computer

On mac you can search to see if proj is installed with

``` bash
brew list proj | grep proj.db
```

If not installed, use homebrew to install with:

``` bash
brew install proj
```

Set the env variable in R to the directory where proj.db is located with:

``` r
Sys.setenv(PROJ_LIB="/path/to/proj")
```

## Update the Project

### Step 1: Manual Inspection & Prep

Once you receive the latest batch of data from the Providence police department, place the file in raw/pvd-raw-crash-data/. The file should be named something like: pvd-crashes-raw-2024-01-01-to-2024-12-31.csv. It may be necessary to do some light manual cleanup of the new file. For example, make sure the headers are the same as last year. If they are not, you can manually change the header in the raw file (maybe not a best practice but is expedient). Make sure the date format for the CrashDate and ReportDate fields are in YYYY-MM-DD format. If they are not, change the date format in excel with something like:

highlight the relevant row. Select the data type dropdown \> select yyyy-mm-dd \> ok. Save.

### Step 3: Run scripts 1 & 2

Open the .Rproj file. Run script 1, then run script 2, updating the input data paths as necessary.

### Step 4: QA Ambiguous Coordinates

Open [this googlesheet](https://docs.google.com/spreadsheets/d/1miGkil-zBHW3wahtWszv4dndI3F47fSX-oPnh5cE0Qw/edit?usp=sharing) (which should have new rows after running script 2)

Scroll down to the newly created rows (i.e. where the 'date_row_was_created' field equals the most recent run date)

Open tableau/pvd-crashes.twb. Refresh the lines-between-coordinates data extract. Go to tab 'qa-linestrings'

Enter the crash_report_id into the tableau Crash R search to visualize the relevant record. This will show you the discrepancy between the police coordinates and the coordinates returned by the google api based on the intersections and addresses. Go through each crash_report_id in the googlesheet and fill in column B to specify which coordinate looks best based based on whatever info is available (e.g. Raw = police provided coordinates, Geocoded = coordinates returned by Google api)

### Step 5: Run Remaining Scripts

### Step 6: Refresh and Re-post Tableau Charts

-   Open pvd-crash.twb

-   Select Data in the nav bar and select "Refresh all extracts"

efresh' all extracts update year in title if needed
