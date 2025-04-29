#### This script validates VE model results using Latch 2017 DVMT data
  ### Files required: Latch 2017 data with est_vmiles field, crosswalk of 2010 Census tracts to Bzones,
  ### and previous model results ready to crosswalk for comparison

### The latch field to use is 'est_vmiles' which represents vmt per household

library(tidyverse)
library(rstudioapi)
library(openxlsx)
library(scales)
library(ggplot2)
library(tidycensus)
library(data.table)
library(sf)

setwd(dirname(getActiveDocumentContext()$path))

## Load files
tracts20 <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Bzone to Tracts 2020')
tracts <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Bzone for Latch')
census_to_bzone <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Census to Bzone')
census_to_azone <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'Census to Azone')
hh_df <- read.csv('../results/output/Household_outputs.csv')
bzone_df <- read.csv('../results/output/Bzone_outputs.csv')
veh_df <- read.csv('../results/output/vehicle_outputs.csv')
latch <- read.csv('../defs/latch_2017-b(2).csv') %>%
  select(geocode, est_vmiles)
ve <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'VE')

##### Validation sources:
# Latch 2017: https://www.bts.gov/latch/latch-data
# FHWA licensed drivers by state 2019: https://www.fhwa.dot.gov/policyinformation/statistics/2019/dl1c.cfm
# DMV licensed drivers by county: https://www.oregon.gov/odot/DMV/docs/2019_age_summary.pdf
# Vehicles by MPO data: https://orscenplg.github.io/VEWiki/chapter3.html?q=valid#model-calibration-and-validation
    ## The SKATS MPO total household vehicles = 203004
# SKATS MPO LRTP 2020 population figures (Appendix A): https://www.mwvcog.org/media/3286
# Income data: ACS 2020
# Activity density D1D variable compared to Smart Location Database: https://www.epa.gov/smartgrowth/smart-location-mapping#SLD

### Load validation measures
temp <- hh_df %>%
  filter(Year==2020) %>%
  group_by(Bzone) %>%
  summarize(Dvmt_ve=sum(Dvmt, na.rm = T),
            population_ve=sum(HhSize, na.rm = T),
            Income_ve=sum(Income, na.rm = T),
            Vehicles_ve=sum(Vehicles, na.rm = T),
            Drivers_ve=sum(Drivers, na.rm = T)) %>%
  ungroup() %>%
  mutate(Income_pc_ve=round(Income_ve/population_ve))

spatial <- bzone_df %>%
  filter(Year==2020) %>%
  select(Bzone, NumHh, D1D) %>%
  left_join(temp) %>%
  mutate(Dvmt_ve=ifelse(is.na(Dvmt_ve), 0, Dvmt_ve)) %>%
  mutate(Dvmt_per_hh_ve=round(Dvmt_ve/NumHh, 1),
         Dvmt_per_hh_ve=ifelse(is.nan(Dvmt_per_hh_ve), 0, Dvmt_per_hh_ve))

one <- get_acs(geography = 'tract',
               variables = 'B11001_001',
               state = 'Oregon',
               Year=2017) %>%
  mutate(variable=ifelse(variable=='B11001_001', 'NumHh_census', variable),
         GEOID=as.numeric(GEOID)) %>%
  select(GEOID, variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate)

##### VMT
vmt_tract <- tracts %>%
  left_join(spatial) %>%
  mutate(NumHh_ve=NumHh*pct_bzone,
         Dvmt_ve=Dvmt_ve*pct_bzone) %>%
  group_by(GEOID) %>%
  summarize(NumHh_ve=sum(NumHh_ve, na.rm = T),
            Dvmt_ve=sum(Dvmt_ve, na.rm = T)) %>%
  left_join(one)
    #### verify DVMT and NumHh - differences are very small
    print(sum(vmt_tract$Dvmt_ve)-sum(spatial$Dvmt_ve))
    print(sum(vmt_tract$NumHh_ve)-sum(spatial$NumHh_ve))
  
vmt_tract <- vmt_tract %>%
  left_join(latch, by=c('GEOID'='geocode')) %>%
  mutate(Dvmt_per_hh_ve=Dvmt_ve/NumHh_ve,
         Dvmt_per_hh_ve=ifelse(is.infinite(Dvmt_per_hh_ve), 0, Dvmt_per_hh_ve),
         Dvmt_pct_diff=(est_vmiles-Dvmt_per_hh_ve)/Dvmt_per_hh_ve,
         Dvmt_pct_diff=ifelse(is.nan(Dvmt_pct_diff) | is.na(Dvmt_pct_diff) | is.infinite(Dvmt_pct_diff), 0, Dvmt_pct_diff)) %>%
  rename(Dvmt_per_hh_latch = est_vmiles)

vmt_azone <- tracts %>%
  left_join(latch, by=c('GEOID'='geocode')) %>%
  filter(pct_bzone > .05) %>%
  left_join(vmt_tract %>% select(GEOID, NumHh_census)) %>%
  mutate(NumHh_census=NumHh_census*pct_bzone) %>%
  left_join(ve %>% select(Bzone, Azone)) %>%
  group_by(Azone) %>%
  mutate(weight=NumHh_census/sum(NumHh_census, na.rm = T)) %>%
  ungroup() %>%
  mutate(weighted=weight*est_vmiles) %>%
  group_by(Azone) %>%
  summarize(est_vmiles=sum(weighted, na.rm = T),
            NumHh_census=sum(NumHh_census, na.rm = T)) %>%
  ungroup() %>%
  left_join(hh_df %>% filter(Year==2020) %>%
              group_by(Azone) %>%
              summarize(HH_ve=sum(HH, na.rm = T),
                        Dvmt_ve=sum(Dvmt, na.rm = T)) %>%
              mutate(Dvmt_per_hh_ve = Dvmt_ve/HH_ve)) %>%
  mutate(Dvmt_pct_diff = (Dvmt_per_hh_ve-est_vmiles)/est_vmiles) %>%
  rename(Dvmt_per_hh_latch = est_vmiles)

vmt_total <- tracts %>%
  left_join(latch, by=c('GEOID'='geocode')) %>%
  left_join(vmt_tract %>% select(GEOID, NumHh_census)) %>%
  mutate(NumHh_census=NumHh_census*pct_bzone) %>%
  left_join(ve %>% select(Bzone, Azone)) %>%
  mutate(weight=NumHh_census/sum(NumHh_census, na.rm = T)) %>%
  ungroup() %>%
  mutate(weighted=weight*est_vmiles) %>%
  summarize(est_vmiles=sum(weighted, na.rm = T),
            NumHh_census=sum(NumHh_census, na.rm = T)) %>%
  ungroup() %>%
  cbind(hh_df %>% filter(Year==2020) %>%
              summarize(HH_ve=sum(HH, na.rm = T),
                        Dvmt_ve=sum(Dvmt, na.rm = T)) %>%
              mutate(Dvmt_per_hh_ve = Dvmt_ve/HH_ve)) %>%
  mutate(Dvmt_pct_diff = (Dvmt_per_hh_ve-est_vmiles)/est_vmiles) %>%
  rename(Dvmt_per_hh_latch = est_vmiles)

####### Income 

## Get ACS vars - using income per capita
#### Using 2020
vars <- data.table(load_variables(2020, 'acs5', cache = T)) %>%
  filter(name=='B19301_001')

one <- get_acs(geography = 'block group',
               variables = vars$name,
               state = 'Oregon',
               Year=2020)

income_azone <- one %>% 
  mutate(variable=ifelse(variable=='B19301_001', 'perCapIncHh', variable)) %>%
  select(GEOID, variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate) %>%
  select(GEOID, perCapIncHh) %>%
  mutate(GEOID=as.numeric(GEOID)) %>%
  left_join(census_to_azone) %>%
  filter(!is.na(Azone)) %>%
  mutate(Year=2020) %>%
  mutate(perCapIncHh=ifelse(is.nan(perCapIncHh), NA, perCapIncHh)) %>%
  filter(pct_azone > 5) %>%
  group_by(Azone, Year) %>%
  summarize(Income_pc_census=mean(perCapIncHh, na.rm = T)) %>%
  ungroup() %>%
  left_join(hh_df %>% filter(Year==2020) %>%
              group_by(Azone) %>%
              summarize(Income_ve = sum(Income*1.32, na.rm = T),
                        Population_ve = sum(HhSize, na.rm = T)) %>%
              ungroup() %>%
              mutate(Income_pc_ve = Income_ve/Population_ve)) %>%
  mutate(Income_pc_pct_diff = (Income_pc_ve-Income_pc_census)/Income_pc_census)

income_total <- one %>% 
  mutate(variable=ifelse(variable=='B19301_001', 'perCapIncHh', variable)) %>%
  select(GEOID, variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate) %>%
  select(GEOID, perCapIncHh) %>%
  mutate(GEOID=as.numeric(GEOID)) %>%
  left_join(census_to_azone) %>%
  filter(!is.na(Azone)) %>%
  mutate(Year=2020) %>%
  mutate(perCapIncHh=ifelse(is.nan(perCapIncHh), NA, perCapIncHh)) %>%
  filter(pct_azone > 5) %>%
  summarize(Income_pc_census=mean(perCapIncHh, na.rm = T)) %>%
  ungroup() %>%
  cbind(hh_df %>% filter(Year==2020) %>%
              summarize(Income_ve = sum(Income*1.32, na.rm = T),
                        Population_ve = sum(HhSize, na.rm = T)) %>%
              ungroup() %>%
              mutate(Income_pc_ve = Income_ve/Population_ve)) %>%
  mutate(Income_pc_pct_diff = (Income_pc_ve-Income_pc_census)/Income_pc_census)


###### Vehicles - source = Wiki VE-State validation by MPO (https://orscenplg.github.io/VEWiki/chapter3.html?q=table%209#light-duty-vehicles)

vehicles_total <- spatial %>%
  summarize(Vehicles_ve=sum(Vehicles_ve, na.rm = T)) %>%
  mutate(Vehicles_mpo=203004,
         Vehicles_diff=percent((Vehicles_mpo-Vehicles_ve)/Vehicles_ve, accuracy = 0.1))


###### Drivers
# Apply proportions taken from DMV statistics - will update with actual DMV statistics when available - https://www.oregon.gov/odot/DMV/docs/2019_age_summary.pdf
vars <- data.table(load_variables(2020, 'acs5', cache = T)) %>%
  filter(name=='B01001_001')

one <- get_acs(geography = 'tract',
               variables = vars$name,
               state = 'Oregon',
               Year=2020)

prop <- one %>% filter(grepl('Lane', NAME)) %>%
  mutate(county='Lane') %>%
  mutate(variable=ifelse(variable=='B01001_001', 'population', variable)) %>%
  filter(variable=='population') %>%
  group_by(county) %>%
  summarize(population=sum(estimate, na.rm = T)) %>%
  ungroup() %>%
  mutate(drivers=290310) %>%
  mutate(prop=drivers/population) %>%
  select(county, prop)

two <- one %>%
  mutate(GEOID=as.numeric(GEOID)) %>%
  mutate(variable=ifelse(variable=='B01001_001', 'population', variable)) %>%
  filter(variable=='population') %>%
  pivot_wider(names_from = variable, values_from = estimate) %>%
  mutate(population=ifelse(is.na(population), 0, population),
         county='Lane') %>%
  group_by(GEOID, county) %>%
  summarize(population=sum(population, na.rm = T)) %>%
  ungroup() %>%
  left_join(prop) %>% 
  mutate(drivers_census_est=prop*population) %>%
  select(GEOID, drivers_census_est)

drivers_tract <- tracts20 %>%
  left_join(spatial) %>%
  mutate(Drivers_ve=Drivers_ve*pct_bzone) %>%
  group_by(GEOID) %>%
  summarize(Drivers_ve=sum(Drivers_ve, na.rm = T)) %>%
  ungroup() %>%
  left_join(two) %>%
  mutate(pct_diff=(drivers_census_est-Drivers_ve)/Drivers_ve)
    ### check totals
    print(sum(drivers_tract$Drivers_ve, na.rm = T)-sum(spatial$Drivers_ve, na.rm = T))

drivers_azone <- tracts20 %>%
  left_join(two) %>%
  mutate(drivers_census_est=drivers_census_est*pct_bzone) %>%
  group_by(Bzone) %>%
  summarize(drivers_census_est=sum(drivers_census_est, na.rm = T)) %>%
  ungroup() %>%
  left_join(spatial) %>%
  left_join(ve) %>%
  group_by(Azone) %>%
  summarize(drivers_census_est=sum(drivers_census_est, na.rm = T),
            drivers_ve=sum(Drivers_ve, na.rm = T)) %>%
  ungroup() %>%
  mutate(pct_dif=(drivers_census_est-drivers_ve)/drivers_ve)

drivers_total <- drivers_tract %>%
  mutate(model='SKATS') %>%
  group_by(model) %>%
  summarize(drivers_census_est=sum(drivers_census_est, na.rm = T),
            Drivers_ve=sum(Drivers_ve, na.rm = T)) %>%
  ungroup() %>%
  mutate(pct_diff=(drivers_census_est-Drivers_ve)/Drivers_ve,
         min_tract=min(drivers_tract$pct_diff),
         first_quartile_tract=quantile(drivers_tract$pct_diff, 0.25),
         median_tract=median(drivers_tract$pct_diff),
         third_quartile_tract=quantile(drivers_tract$pct_diff, 0.75),
         max_tract=max(drivers_tract$pct_diff))

#### Activity density
temp <- read.xlsx('../defs/D1D.xlsx', sheet = 'Sheet1') %>%
  rename(D1D_sld=3)

d1d_bg <- temp %>%
  left_join(spatial) %>%
  rename(D1D_ve=D1D,
         GEOID=2) %>%
  mutate(D1D_ve=D1D_ve/608*pct_bzone,
         D1D_sld=D1D_sld*pct_bzone) %>%
  group_by(GEOID) %>%
  summarize(D1D_ve=sum(D1D_ve),
            D1D_sld=sum(D1D_sld)) %>%
  mutate(D1D_diff=(D1D_sld-D1D_ve)/D1D_ve) %>%
  select(GEOID, D1D_ve, D1D_sld, D1D_diff)

#### MPG and MPKWH
mpg <- veh_df %>%
  group_by(Year) %>%
  summarize(MPG=mean(MPG, na.rm = T),
            MPGe=mean(MPGe, na.rm = T),
            MPKWH=mean(MPKWH, na.rm = T))

#### alt modes
alt_modes <-rbind(
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2005),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2010),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2020),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2035),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2045)
) %>%
  left_join(hh_df %>% select(Bzone, Azone, Year, VehicleTrips, WalkTrips, BikeTrips, TransitTrips, HhSize, CommuteDistanceAdj) %>%
              mutate(WalkTrips=ifelse(is.infinite(WalkTrips), 0, WalkTrips),
                     BikeTrips=ifelse(is.infinite(BikeTrips), 0, BikeTrips)), by=c('Bzone', 'Year')) %>%
  group_by(Azone, Year) %>%
  summarize(Population=round(sum(HhSize, na.rm = T)),
            VehicleTrips=round(sum(VehicleTrips, na.rm = T)),
            WalkTrips=round(sum(WalkTrips, na.rm = T)),
            BikeTrips=round(sum(BikeTrips, na.rm = T)),
            TransitTrips=round(sum(TransitTrips, na.rm = T)),
            CommuteDistanceAdj=round(sum(CommuteDistanceAdj, na.rm = T))) %>%
  ungroup() %>%
  mutate(VehicleTrips_pc=round(VehicleTrips/Population, 1),
         WalkTrips_pc=round(WalkTrips/Population, 1),
         BikeTrips_pc=round(BikeTrips/Population, 2),
         TransitTrips_pc=round(TransitTrips/Population, 1),
         CommuteDist_pc=round(CommuteDistanceAdj/Population, 1),
         CommuteDist_per_vehicle_trip=round(CommuteDistanceAdj/VehicleTrips, 1)) %>%
  filter(!is.na(Azone))

#### CO2e
co2e_bzone <- rbind(
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2005),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2010),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2020),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2035),
  data.frame(Bzone=unique(bzone_df$Bzone), Year=2045)
) %>%
  left_join(hh_df %>% select(Bzone, Year, DailyCO2e, Dvmt, HhSize), by=c('Bzone', 'Year')) %>%
  mutate(co2e_pc=DailyCO2e/HhSize,
         co2e_per_dvmt=DailyCO2e/Dvmt) %>%
  rename(Population=HhSize)

co2e_azone <- rbind(
  data.frame(Azone=unique(bzone_df$Azone), Year=2005),
  data.frame(Azone=unique(bzone_df$Azone), Year=2010),
  data.frame(Azone=unique(bzone_df$Azone), Year=2020),
  data.frame(Azone=unique(bzone_df$Azone), Year=2035),
  data.frame(Azone=unique(bzone_df$Azone), Year=2045)
) %>%
  left_join(hh_df %>% select(Azone, Year, DailyCO2e, Dvmt, HhSize), by=c('Azone', 'Year')) %>%
  group_by(Azone, Year) %>%
  summarize(DailyCO2e=sum(DailyCO2e, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T),
            HhSize=sum(HhSize, na.rm = T)) %>%
  ungroup() %>%
  mutate(co2e_pc=DailyCO2e/HhSize,
         co2e_per_dvmt=DailyCO2e/Dvmt) %>%
  rename(Population=HhSize)

co2e_total <- co2e_bzone %>%
  group_by(Year) %>%
  summarize(Population=round(sum(Population, na.rm = T)),
            DailyCO2e=sum(DailyCO2e, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T)) %>%
  ungroup() %>%
  mutate(co2e_pc=DailyCO2e/Population,
         co2e_per_dvmt=DailyCO2e/Dvmt)

#### Compile results
list <- list('VMT Tract'=vmt_tract, 'VMT Azone'=vmt_azone, 'VMT total'=vmt_total,
             'Income Tract'=income_tract, 'Income Azone'=income_azone, 'Income total'=income_total,
             'Drivers Tract'=drivers_tract, 'Drivers Azone'=drivers_azone, 'Drivers total'=drivers_total,
             'CO2e Bzone'=co2e_bzone, 'CO2e Azone'=co2e_azone, 'CO2e total'=co2e_total,
             'D1D Block Group'=d1d_bg, 'Vehicles total'=vehicles_total, 'MPG'=mpg,
             'Transit modes&dist'=alt_modes
             )
write.xlsx(list, file='../results/output/validation results.xlsx')
