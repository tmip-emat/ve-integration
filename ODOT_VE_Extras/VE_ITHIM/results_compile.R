#### Use this script to compile VisionEval export() results into one spreadsheet ####
#---------------------------------------------------------------------------------#
library(tidyverse)
library(rstudioapi)
library(openxlsx)

setwd(dirname(getActiveDocumentContext()$path))

# Household

## Get file names - remove ithim from this list
file <- list.files('../results/output')
list <- list.files(paste0('../results/output/', file), pattern = 'Household', full.names = T)
list <- list[!grepl('ithim', list)]
# bzones <- read.csv('../defs/bzone_summary_Portland.csv') %>%
#   filter(MetroB==1)

hh_df <- data.frame()

## Load CSVs, optionally filter bzones to what are in Target Rule area by uncommenting line 23
for (i in list){
  data <- read.csv(i)
  data <- data %>% 
    mutate(HH=1)%>%
    # filter(Bzone %in% bzones$Bzone) %>%
    select(Year, Marea, Azone, Bzone, where(is.numeric))
  exclude <- c('Year', 'Marea', 'Azone', 'Bzone')
  cols <- names(data)
  cols <- setdiff(cols, exclude)
  mean_vars <- cols[grepl('Ave|Avg', cols)]
  sum_vars <- setdiff(cols, mean_vars)
  data <- data %>% 
    group_by(Year, Marea, Azone, Bzone) %>%
    summarize(across(all_of(sum_vars), ~sum(., na.rm = T)),
              across(all_of(mean_vars), ~mean(., na.rm = T)))
  
  hh_df <- rbind(hh_df, data)
}

hh_df <- hh_df %>%
  mutate(dvmt_pc=round(Dvmt/HhSize, 1),
         trips_per_cap=round(VehicleTrips/HhSize, 1),
         income_pc=Income/HhSize,
         transit_trips_pc=round(TransitTrips/HhSize, 1)) %>%
  group_by(Year) %>%
  mutate(income_bin=4,
         income_bin=ifelse(income_pc <= quantile(income_pc, 0.75), 3, income_bin),
         income_bin=ifelse(income_pc <= quantile(income_pc, 0.5), 2, income_bin),
         income_bin=ifelse(income_pc <= quantile(income_pc, 0.25), 1, income_bin),
         income_quartile=ifelse(income_bin==1, quantile(income_pc, 0.25), NA),
         income_quartile=ifelse(income_bin==2, quantile(income_pc, 0.5), income_quartile),
         income_quartile=ifelse(income_bin==3, quantile(income_pc, 0.75), income_quartile),
         income_quartile=ifelse(income_bin==4, quantile(income_pc, 1), income_quartile),
         transit_trips_pc=TransitTrips/HhSize,
         vehicles_per_hh=Vehicles/HH) %>%
  ungroup() %>%
  mutate(azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
         azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
         azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))

temp <- hh_df %>%
  group_by(Year, income_bin) %>%
  summarize(dvmt_pc=mean(dvmt_pc, na.rm = T),
            transit_trips_pc=mean(transit_trips_pc, na.rm = T),
            vehicles_per_hh=mean(vehicles_per_hh, na.rm = T)) %>%
  ungroup() %>%
  mutate(income_bin=as.character(income_bin),
         Year=as.character(Year))

# Bzone - using same function but loading global csv files

## Get file names - remove ithim files
list <- list.files(paste0('../results/output/', file), pattern = 'Bzone', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)
list <- list[!grepl('ithim', list)]

bzone_df <- data.frame()

## Load CSVs, optionally filter bzones to what is in Target Rule area by uncommenting line ###
for (i in list){
  data <- read.csv(i)
  # data <- data %>% filter(Bzone %in% bzones$Bzone)
  bzone_df <- rbind(bzone_df, data)
}

# Azone - using same function but loading global csv files
list <- list.files(paste0('../results/output/', file), pattern = 'Azone', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

azone_df <- data.frame()

## Load CSVs
for (i in list){
  data <- read.csv(i)
  azone_df <- rbind(azone_df, data)
}

# Marea - using same function but loading global csv files (only accounts for numeric outputs, not characters)
list <- list.files(paste0('../results/output/', file), pattern = 'Marea', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

marea_df <- data.frame()

## Load CSVs
for (i in list){
  data <- read.csv(i)
  if(!exists('Marea', data)) {
    data <- mutate(data, Marea = 'NA')
  }
  data <- data %>%
    select(Scenario, Global, Marea, Year, where(is.numeric))
  exclude <- c('Scenario', 'Global', 'Marea', 'Year')
  cols <- setdiff(names(data), exclude)
  data <- data %>%
    pivot_longer(cols = cols, names_to = 'Output', values_to = 'Value') %>%
    select(Scenario, Global, Marea, Year, Output, Value) %>%
    distinct(Year, Output, .keep_all = T)
  marea_df <- rbind(marea_df, data)
}

# Region - using same function but loading global csv files
list <- list.fileslist <- list.files(paste0('../results/output/', file), pattern = 'Region', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

region_df <- data.frame()

## Load CSVs
for (i in list){
  data <- read.csv(i)
  region_df <- rbind(region_df, data)
}

# Vehicles
list <- list.files
list <- list.files(paste0('../results/output/', file), pattern = 'Vehicle', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

vehicle_df <- data.frame()

## Load CSVs, optionally filter bzones to what is in Target Rule area by uncommenting line ###
for (i in list){
  data <- read.csv(i)
  data <- data %>%
    # filter(!grepl('CarSvc', VehicleAccess)) %>%
    mutate(ICEV=ifelse(Powertrain=='ICEV',1,0),
           PHEV=ifelse(Powertrain=='PHEV',1,0),
           BEV=ifelse(Powertrain=='BEV',1,0),
           HEV=ifelse(Powertrain=='HEV',1,0),
           NA_powertrain=ifelse(is.na(Powertrain),1,0),
           Auto=ifelse(Type=='Auto',1,0),
           LtTrk=ifelse(Type=='LtTrk',1,0),
           Auto_HH=ifelse(Type=='Auto' & !grepl('CarSvc', VehicleAccess), 1, 0),
           LtTrk_HH=ifelse(Type=='LtTrk' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_ICEV=ifelse(Powertrain=='ICEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_PHEV=ifelse(Powertrain=='PHEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_BEV=ifelse(Powertrain=='BEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           HH_HEV=ifelse(Powertrain=='HEV' & !grepl('CarSvc', VehicleAccess), 1, 0),
           access_LowCarSvc=ifelse(VehicleAccess=='LowCarSvc',1,0),
           access_HighCarSvc=ifelse(VehicleAccess=='HighCarSvc',1,0),
           access_Own=ifelse(VehicleAccess=='Own',1,0)) %>%
    select(Marea, Azone, Bzone, Year, where(is.numeric))
  cols <- names(data)
  exclude <- c('Year', 'Marea', 'Azone', 'Bzone', 'VehId', 'Global', 'HhId', 'Type', 'Powertrain', 'VehicleAccess')
  cols <- setdiff(cols, exclude)
  sum_vars <- cols[grepl('ICEV|PHEV|BEV|HEV|NA_powertrain|Auto|LtTrk|access', cols)]
  mean_vars <- setdiff(cols, sum_vars)
  data <- data %>% group_by(Marea, Azone, Bzone, Year) %>%
    summarize(across(all_of(sum_vars), ~sum(., na.rm = T)),
              across(all_of(mean_vars), ~mean(., na.rm = T))) %>%
    ungroup() %>%
    mutate(azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
           azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
           azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))
  vehicle_df <- rbind(vehicle_df, data)
}


### Worker results
list <- list.files
list <- list.files(paste0('../results/output/', file), pattern = 'Worker', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

wrk_df <- data.frame()

for(i in list) {
  data <- read.csv(i)
  data <- data %>%
    mutate(WorkFromHome=ifelse(WorkFromHome=='Yes', 1, 0),
           TeleWork=ifelse(TeleWork!='Yes', 1, 0),
           TeleWorkDays=ifelse(is.na(TeleWorkDays), 0, TeleWorkDays),
           TeleworkDays_0=ifelse(TeleWorkDays==0, 1, 0),
           TeleworkDays_1=ifelse(TeleWorkDays==1, 1, 0),
           TeleworkDays_2=ifelse(TeleWorkDays==2, 1, 0),
           TeleworkDays_3=ifelse(TeleWorkDays==3, 1, 0),
           TeleworkDays_4=ifelse(TeleWorkDays==4, 1, 0),
           TeleworkDays_5=ifelse(TeleWorkDays==5, 1, 0),
           PartTimeTelework=ifelse(TeleworkDays_1==1 | TeleworkDays_2==1 | TeleworkDays_3==1 | TeleworkDays_4==1, 1, 0),
           FullTimeTelework=ifelse(TeleWorkDays==5, 1, 0),
           NoTelework=ifelse(TeleWorkDays==0, 1, 0),
           Occupation_1=ifelse(Occupation==1, 1, 0),
           Occupation_2=ifelse(Occupation==1, 1, 0),
           Occupation_3=ifelse(Occupation==1, 1, 0))
  cols <- names(data)
  exclude <- c('Year', 'Bzone', 'Azone', 'Marea', 'HhId', 'WkrId', 'Scenario', 'Global', 'Occupation', 'TeleWorkDays', 'WorkFromHome')
  cols <- setdiff(cols, exclude)
  sum_vars <- cols[grepl('PaysForParking|IsCashOut|IsECO|TeleWork|TeleworkDays_0|TeleworkDays_1|TeleworkDays_2|TeleworkDays_3|TeleworkDays_4|TeleworkDays_5|PartTimeTelework|FullTimeTelework|NoTelework|Occupation_1|Occupation_2|Occupation_3', cols)]
  mean_vars <- setdiff(cols, sum_vars)
  data <- data %>% group_by(Bzone, Azone, Marea, Year) %>%
    summarize(across(all_of(sum_vars), ~sum(., na.rm = T)),
              across(all_of(mean_vars), ~mean(., na.rm = T))) %>%
    ungroup() %>%
    mutate(azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
           azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
           azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary))
  wrk_df <- rbind(wrk_df, data)
}

temp2 <- marea_df %>%
  filter(Output=='VanDvmt' | Output=='VanCO2e' | Output=='ComSvcNonUrbanCO2e' |
           Output=='ComSvcUrbanCO2e' | Output=='ComSvcRuralDvmt' | Output=='ComSvcTownDvmt' |
           Output=='ComSvcUrbanDvmt') %>%
  select(Year, Output, Value) %>%
  pivot_wider(names_from = Output, values_from = Value)

temp <- hh_df %>%
  group_by(Year) %>%
  summarize(DailyCO2e=sum(DailyCO2e, na.rm = T),
            Dvmt=sum(Dvmt, na.rm = T),
            HhSize=sum(HhSize, na.rm = T),
            VehicleTrips=sum(VehicleTrips, na.rm = T),
            Vehicles=sum(Vehicles, na.rm = T),
            trips_per_cap=mean(trips_per_cap, na.rm = T),
            Population=sum(HhSize, na.rm = T),
            HH=sum(HH, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T)) %>%
  ungroup() %>%
  left_join(temp2) %>%
  mutate(Dvmt=Dvmt+VanDvmt+ComSvcRuralDvmt+ComSvcTownDvmt+ComSvcUrbanDvmt,
         DailyCO2e=DailyCO2e+VanCO2e+ComSvcNonUrbanCO2e+ComSvcUrbanCO2e,
         Dvmt_pc=round(Dvmt/HhSize, 1)) %>%
  mutate(co2_per_dvmt=round((DailyCO2e)/Dvmt, 2),
         co2_pc=round(DailyCO2e/HhSize, 2),
         mixed_use_pct=IsUrbanMixNbrhd/HH) %>%
  select(Year, DailyCO2e, co2_pc, co2_per_dvmt, Dvmt, Dvmt_pc, VehicleTrips, Vehicles, trips_per_cap, Population, mixed_use_pct)

temp2 <- hh_df %>%
  mutate(azone_secondary=ifelse(grepl('Salem', Azone), 'Salem UGB', 'Other'),
         azone_secondary=ifelse(grepl('Keizer', Azone), 'Keizer UGB', azone_secondary),
         azone_secondary=ifelse(grepl('Marion_Inside', Azone), 'Marion UGB', azone_secondary)) %>%
  group_by(azone_secondary, Year) %>%
  summarize(HH=sum(HH, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T)) %>%
  ungroup() %>%
  mutate(mixed_use_pct=IsUrbanMixNbrhd/HH) %>%
  arrange(azone_secondary, Year)

#ITHIM if applicable

## Get ithim files - ithim produces files at household and Bzone levels if ithim output files exist
list <- list.files(paste0('../results/output/', file), pattern = 'Bzone', full.names = T)
list <- grep('^((?!Global).)*$', list, value = TRUE, perl = TRUE)

if(any(grepl('ithim', list))) {
  
  list <- list[grep('ithim', list)]
  
  ithim_df <- data.frame()
  
  for(i in list) {
    
    data <- read.csv(i) %>% select(-1) %>%
      mutate(Year=max(hh_df$Year)) %>%
      select(Bzone, Year, everything())
    
    if(dim(ithim_df)[1]==0) {
      ithim_df <- data
    } else {
      ithim_df <- left_join(ithim_df, data)
    }
    
  }
  
  ## Summarize ithim outputs for the scenario
  ithim_sum <- ithim_df %>% select(-Bzone, -Year) %>%
    summarize_all(sum)
  
  write.csv(ithim_df, '../results/output/ithim_Bzone_results.csv', row.names = F)
  write.csv(ithim_sum, '../results/output/ithim_summary.csv', row.names = F)
  
}


# Write all results to CSV files
write.csv(hh_df, '../results/output/Household_outputs.csv', row.names = F)
write.csv(bzone_df, '../results/output/Bzone_outputs.csv', row.names = F)
write.csv(azone_df, '../results/output/Azone_outputs.csv', row.names = F)
write.csv(marea_df, '../results/output/Marea_outputs.csv', row.names = F)
write.csv(region_df, '../results/output/region_outputs.csv', row.names = F)
write.csv(vehicle_df, '../results/output/vehicle_outputs.csv', row.names = F)
write.csv(wrk_df, '../results/output/worker_outputs.csv', row.names = F)
write.csv(temp, '../results/output/target rule.csv', row.names = F)
write.csv(temp2, '../results/output/mixed use Azone.csv', row.names = F)

#----------------------------------------------------------------------------#
### Export key metrics for comparison with TAZ data
bzone_vars <- bzone_df %>% select(Year, Bzone, Pop, GQ, SFDU, MFDU, GQDU, TotEmp, RetEmp, SvcEmp)
write.csv(bzone_vars, '../results/output/for_taz_comparison.csv', row.names = F)

#-----------------------------------------------------------------------------#
# Develop the summary table metrics

## Read in the VE sheet from the crosswalk table
ve <- read.xlsx('../defs/LCOG_crosswalk.xlsx', sheet = 'VE')

## Choose summarization level - note if you need to make custom assumptions here on what Geographies you are summarizing
#### This needs to match a column name in the results
#### Select either 'Azone', 'Marea', or a custom geography to summarize by - this table should only be used for geographies larger than bzones
###### Custom geographies will require additions to the base loops 
level = 'Azone'
negate = if(level=='Azone'){'Marea'} else if(level=='Marea'){'Azone'}

## Choose years to summarize - these years must be in the model and can only select 2 for comparison
years = c(2020, 2045)

## Are we using bus factors for revenue miles? Enter 'Yes' or 'No'. Entering 'Yes' will convert all revenue miles to bus equivalent
bus_factors = 'Yes'

## Inputs - enter which inputs need to be presented as sum or averages
### Ex. Population sums vs TDM proportions
### Marea or region inputs should be processed separately in the marea inputs list
inputs_sum <- c('azone_hh_pop_by_age', 'bzone_employment', 'bzone_dwelling_units')
inputs_avg <- c('azone_per_cap_inc', 'azone_payd_insurance_prop', 'bzone_parking', 'azone_fuel_power_cost', 'azone_hh_veh_own_taxes',
                'azone_veh_use_taxes', 'bzone_travel_demand_mgt', 'azone_prop_sov_dvmt_diverted', 'azone_charging_availability',
                'azone_hhsize_targets')
inputs_marea <- c('marea_lane_miles', 'marea_transit_service', 'marea_operations_deployment',
                  'marea_transit_fuel', 'marea_transit_biofuel_mix', 'marea_transit_powertrain_prop')

### Sum calculations
sum_df <- data.frame()

for(i in years) {
  if(level=='Azone'){
    data <- ve %>% mutate(Year=i) %>%
      distinct(Marea, Azone, Year)
    sum_df <- rbind(sum_df, data)
  } else if(level=='Marea'){
    data <- ve %>% mutate(Year=i) %>%
      distinct(Marea, Year)
    sum_df <- rbind(sum_df, data)
  }
}

for(i in inputs_sum){
  data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
    filter(Year %in% years)
  
  cols <- setdiff(names(data), c('Geo', 'Azone', 'Marea', 'Year'))
  
  if(level=='Azone'){
    if(substr(i, 1, 5)=='azone'){
      if(i=='azone_hh_pop_by_age'){
        data <- data %>% group_by(Geo, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(Population=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
          rename(Azone=Geo) %>%
          select(Azone, Year, Population)
      } else {
        data <- data %>% group_by(Geo, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          rename(Azone=Geo)
      }
    } else if(substr(i, 1, 5)=='bzone') {
      if(i=='bzone_dwelling_units'){
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Azone, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(HHs=SFDU+MFDU,
                 Pct_SFDU=SFDU/HHs,
                 Pct_MFDU=MFDU/HHs) %>%
          select(Azone, Year, HHs, contains('Pct'))
      } else {
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Azone, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup()
      }
    } 
    
    sum_df <- sum_df %>% left_join(data, by=c('Azone', 'Year'))
    
  } else if(level=='Marea'){
    if(substr(i, 1, 5)=='azone'){
      if(i=='azone_hh_pop_by_age'){
        data <- data %>% left_join(ve %>% select(Marea, Azone), by=c('Geo'='Azone')) %>%
          group_by(Marea, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(Population=Age0to14+Age15to19+Age20to29+Age30to54+Age55to64+Age65Plus) %>%
          select(Marea, Year, Population)
      } else {
        data <- data %>% group_by(Geo, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          rename(Marea=Geo)
      }
    } else if(substr(i, 1, 5)=='bzone') {
      if(i=='bzone_dwelling_units'){
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Marea, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup() %>%
          mutate(HHs=SFDU+MFDU,
                 Pct_SFDU=SFDU/HHs,
                 Pct_MFDU=MFDU/HHs) %>%
          select(Marea, Year, HHs, contains('Pct'))
      } else {
        data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
          group_by(Marea, Year) %>%
          summarize(across(all_of(cols), ~sum(., na.rm = T))) %>%
          ungroup()
      }
    } 
    
    sum_df <- sum_df %>% left_join(data, by=c('Marea', 'Year'))
    
  }
}

### Average calculations
for(i in inputs_avg){
  data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
    filter(Year %in% years)
  
  cols <- setdiff(names(data), c('Geo', 'Azone', 'Marea', 'Year'))
  
  if(level=='Azone'){
    if(substr(i, 1, 5)=='azone'){
      data <- data %>% group_by(Geo, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup() %>%
        rename(Azone=Geo)
    } else if(substr(i, 1, 5)=='bzone') {
      data <- data %>% left_join(ve, by=c('Geo' = 'Bzone')) %>%
        group_by(Azone, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup()
    } 
    
    sum_df <- sum_df %>% left_join(data, by=c('Azone', 'Year'))
    
    #### Add in a piece for parking here - need to get the average across only Bzones that charge parking
    if(i=='bzone_parking' & level=='Azone') {
      data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
        filter(Year %in% years) %>% filter(PkgCost.2010 > 0) %>%
        left_join(ve, by=c('Geo' = 'Bzone')) %>%
        group_by(Azone, Year) %>%
        summarize(PkgCost.2010=mean(PkgCost.2010, na.rm = T)) %>%
        ungroup() %>%
        rename(PkgCost.2010_filtered=PkgCost.2010)
      sum_df <- sum_df %>% left_join(data, by=c('Azone', 'Year'))
    }
    
  } else if(level=='Marea'){
    if(substr(i, 1, 5)=='azone'){
      data <- data %>% left_join(ve %>% distinct(Marea, Azone), by=c('Geo'='Azone')) %>%
        group_by(Marea, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup()
    } else if(substr(i, 1, 5)=='bzone'){
      data <- data %>% left_join(ve %>% select('Marea', 'Bzone'), by=c('Geo'='Bzone')) %>%
        group_by(Marea, Year) %>%
        summarize(across(all_of(cols), ~mean(., na.rm = T))) %>%
        ungroup()
    }
    
    sum_df <- sum_df %>% left_join(data, by=c('Marea', 'Year'))
    
    #### Add in a piece for parking here - need to get the average across only Bzones that charge parking
    if(i=='bzone_parking' & level=='Marea') {
      data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
        filter(Year %in% years) %>% filter(PkgCost.2010 > 0) %>%
        left_join(ve, by=c('Geo' = 'Bzone')) %>%
        group_by(Marea, Year) %>%
        summarize(PkgCost.2010=mean(PkgCost.2010, na.rm = T)) %>%
        ungroup() %>%
        rename(PkgCost.2010_filtered=PkgCost.2010)
      sum_df <- sum_df %>% left_join(data, by=c('Marea', 'Year'))
    }
  }
}

### Marea - we will want to save this as an Excel file on a separate sheet and combine later when formatting
marea_df <- data.frame()

for(i in years) {
  data <- ve %>% distinct(Marea) %>% mutate(Year=i)
  marea_df <- rbind(marea_df, data)
}

for(i in inputs_marea) {
  data <- read.csv(paste0('../inputs/', i, '.csv')) %>%
    filter(Year %in% years)
  
  if(i=='marea_transit_service' & bus_factors=='Yes') {
    data <- data %>% 
      mutate(BusRevMi=MBRevMi+(RBRevMi*1.91),
             TotalRevMi=BusRevMi+(DRRevMi*.18)+(VPRevMi*.88)+(MGRevMi*1.09)+(SRRevMi*1.92)+(HRRevMi*3.43)+(CRRevMi*2.5)) %>%
      select(Geo, Year, BusRevMi, TotalRevMi)
    
    marea_df <- marea_df %>% left_join(data, by=c('Marea'='Geo', 'Year'))
    
  } else if(i=='marea_transit_service' & bus_factors=='No') {
    data <- data %>% 
      mutate(BusRevMi=MBRevMi+RBRevMi,
             TotalRevMi=BusRevMi+DRRevMi+VPRevMi+MGRevMi+SRRevMi+HRRevMi+CRRevMi) %>%
      select(Geo, Year, BusRevMi, TotalRevMi)
    
    marea_df <- marea_df %>% left_join(data, by=c('Marea'='Geo', 'Year'))
    
  } else if(i!='marea_transit_service') {
    marea_df <- marea_df %>% left_join(data, by=c('Marea'='Geo', 'Year'))
  }
}

### Can query outputs from the compiled dataframes established earlier in the script
output <- hh_df %>% filter(Year %in% years) %>%
  group_by(!!sym(level), Year) %>%
  summarize(AveVehCostPM=mean(AveVehCostPM, na.rm = T),
            HH=sum(HH, na.rm = T),
            IsUrbanMixNbrhd=sum(IsUrbanMixNbrhd, na.rm = T)) %>% #### average vehicle cost per mile by geography
  ungroup() %>% 
  mutate(MixedUse_pct=IsUrbanMixNbrhd/HH) %>%
  select(-HH, -IsUrbanMixNbrhd) %>%
  left_join(     ##### percent of households with high car service
    temp <- bzone_df %>% filter(Year %in% years) %>% 
      group_by(!!sym(level), Year, CarSvcLevel) %>%
      summarize(HH=sum(SFDU+MFDU, na.rm = T)) %>%
      ungroup() %>%
      pivot_wider(names_from = CarSvcLevel, values_from = HH) %>%
      mutate(pct_HHs_HighCarSvc=High/(Low+High),
             pct_HHs_HighCarSvc=ifelse(is.na(pct_HHs_HighCarSvc), 0, pct_HHs_HighCarSvc)) %>%
      select(!!sym(level), Year, pct_HHs_HighCarSvc)
  ) %>%
  left_join(    ##### Percent Non-ICE vehicles and Effective HH MPG
    temp <- vehicle_df %>%
      filter(Year %in% years) %>%
      group_by(!!sym(level), Year) %>%
      summarize(HH_ICEV=sum(HH_ICEV, na.rm = T),
                HH_PHEV=sum(HH_PHEV, na.rm = T),
                HH_BEV=sum(HH_BEV, na.rm = T),
                HH_HEV=sum(HH_HEV, na.rm = T),
                MPG=mean(MPG, na.rm = T),
                MPGe=mean(MPGe, na.rm = T)) %>%
      ungroup() %>%
      mutate(Effective_HH_MPG=(MPG+MPGe)/2,
             non_ICEV_prop=(HH_PHEV+HH_BEV+HH_HEV)/(HH_PHEV+HH_BEV+HH_HEV+HH_ICEV)) %>%
      select(!!sym(level), Year, Effective_HH_MPG, non_ICEV_prop)
  ) %>%
  left_join(    #### Proportion of workers who are no, part, or full time teleworking
    temp <- wrk_df %>% filter(Year %in% years) %>%
      group_by(!!sym(level), Year) %>%
      summarize(PartTimeTelework=sum(PartTimeTelework, na.rm = T),
                FullTimeTelework=sum(FullTimeTelework, na.rm = T),
                NoTelework=sum(NoTelework, na.rm = T)) %>%
      ungroup() %>%
      mutate(PartTimeTelework_pct=PartTimeTelework/(PartTimeTelework+FullTimeTelework+NoTelework),
             FullTimeTelework_pct=FullTimeTelework/(PartTimeTelework+FullTimeTelework+NoTelework),
             NoTelework_pct=NoTelework/(PartTimeTelework+FullTimeTelework+NoTelework)) %>%
      select(!!sym(level), Year, PartTimeTelework_pct, FullTimeTelework_pct, NoTelework_pct)
  )

## Now perform custom calculations on the summary dataframe
custom_df_sum <- sum_df %>%
  left_join(output) %>%
  select(-all_of(negate)) %>% ### May need to comment out this line in the case of using level = 'Marea'
  pivot_longer(cols = -c(!!sym(level), Year), names_to = 'Measure', values_to = 'Value') %>%
  pivot_wider(names_from = Year, values_from = Value) %>%
  mutate(pct_change = ((!!sym(as.character(years[2])) - !!sym(as.character(years[1]))) / !!sym(as.character(years[1]))),
         pct_change=ifelse(is.infinite(pct_change), 1, pct_change),
         pct_change=ifelse(is.nan(pct_change), 0, pct_change)) %>%
  pivot_longer(cols=-c(!!sym(level), Measure), names_to = 'Year', values_to = 'Value') %>%
  mutate(name=paste0(!!sym(level), '_', Year)) %>%
  select(name, Measure, Value) %>%
  pivot_wider(names_from = name, values_from = Value) %>%
  select(Measure, ends_with(as.character(years[1])), ends_with(as.character(years[2])), ends_with('pct_change'))

custom_df_marea <- marea_df %>%
  pivot_longer(cols = -c(Marea, Year), names_to = 'Measure', values_to = 'Value') %>%
  pivot_wider(names_from = Year, values_from = Value) %>%
  mutate(pct_change = ((!!sym(as.character(years[2])) - !!sym(as.character(years[1]))) / !!sym(as.character(years[1]))),
         pct_change=ifelse(is.infinite(pct_change), 1, pct_change),
         pct_change=ifelse(is.nan(pct_change), 0, pct_change)) %>%
  pivot_longer(cols=-c(Marea, Measure), names_to = 'Year', values_to = 'Value') %>%
  mutate(name=paste0(Marea, '_', Year)) %>%
  select(name, Measure, Value) %>%
  pivot_wider(names_from = name, values_from = Value) %>%
  select(Measure, ends_with(as.character(years[1])), ends_with(as.character(years[2])), ends_with('pct_change'))

## Write the Excel file
list <- list('Summary - selected Geo' = custom_df_sum, 'Summary - Marea metrics' = custom_df_marea)
write.xlsx(list, file = '../results/output/summary_table_processed.xlsx')
