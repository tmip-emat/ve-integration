#' Compute health burden
#'
#' Compute health burden for population in scenarios given relative risks for diseases
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item get the demographic and disease burden (subset of Global Burden of Disease dataset) data
#'    into the correct formats and join the two datasets
#'
#'  \item split the above dataframe into two dataframes, one for deaths and one
#'    for years of life lost (YLLs)
#'
#'  \item add a demographic index (by age and sex category) to the dataframe containing the
#'    individual relative risk for different diseases
#'
#'  \item set the reference and the other scenarios
#'
#'  \item iterate over all disease outcomes:
#'    \itemize{
#'    \item define column names
#'
#'    \item loop either over 1 or 2 pathways depending on whether both PA and AP are affecting
#'      the disease and whether the AP and PA pathways are combined or not:
#'      \itemize{
#'      \item extract the relevant burden of disease for the specific scenario both for YLLs and deaths
#'
#'      \item find the sum of the relative risks (RR) for the specific disease for each age
#'        and sex category for the reference scenario
#'
#'      \item loop through the non-reference scenarios:
#'        \itemize{
#'        \item define column names
#'
#'        \item find the sum of the relative risks (RR) for the specific disease for each age
#'          and sex category for the non-reference scenario
#'
#'        \item calculate the PIF (potential impact fraction), i.e the proportional change
#'          in the sum of relative risks between the reference and the non-reference
#'          scenario for each age and sex category
#'
#'        \item calculate the health burden (deaths and ylls) for the non-reference scenario
#'          compared to the reference scenario by multiplying the current burden of disease
#'          by the PIF (combine_health_and_pif.R)
#'          }
#'
#'      \item if confidence intervals are required, loop through the upper and lower confidence
#'        interval limits and calculate the health burden for deaths and YLLs using
#'        the upper and lower confidence relative risks. If no upper and lower relative risk
#'        values exist, use the median value instead
#'        }
#'    }
#' }
#'
#'
#' @param ind_ap_pa dataframe of all individuals' relative risks for diseases
#' @param module_dir local file path to module directory
#' @param input_dir local file path to VE model input directory
#' @param conf_int=F logic: whether to include confidence interval from dose response relationships or not
#' @param combined_AP_PA=T logic: whether to combine the two exposure pathways (AP and PA) or to compute them independently
#'
#' @return list of dataframes: one for deaths per disease per demographic group and scenario, and likewise for YLLs
#'
#' @export


health_burden <- function(ind_ap_pa, input_dir, scenarios, conf_int = F, combined_AP_PA = T) {
  
  # load all relative risk values
  # these are stored in global env in ITHIM, which is not ideal....
  diseases <- fread(file.path(input_dir, "disease_outcomes_lookup.csv"))
  
  # load gbd data for region
  gbd_data <- fread(file.path(input_dir, "gbd.csv"))
  
  # convert gbd data to rates
  gbd_data$deathrate <- gbd_data$deaths / gbd_data$ref_pop
  gbd_data$yllrate <- gbd_data$ylls / gbd_data$ref_pop
  
  # initiate dfs to store yll, deaths
  ind_ap_pa <- ind_ap_pa[order(PId)]
  cols <- c("PId")
  ylls <- deaths <- ind_ap_pa[, ..cols]
  
  ### iterate over all disease outcomes
  for (j in 1:nrow(diseases)) {
      
    # Disease acronym and full name
    ac <- as.character(diseases$acronym[j])
    gbd_dn <- as.character(diseases$GBD_name[j])
    
    # calculate health outcome, or independent pathways?
    pathways_to_calculate <- ifelse(combined_AP_PA, 1,
                                    diseases$physical_activity[j] + diseases$air_pollution[j]
    )
    
    # loop through relevant pathways depending on whether disease affects AP or PA and
    # whether AP and PA are combined or not
    for (path in 1:pathways_to_calculate) { # pathways_to_calculate is either 1 or 2
      # set up column names
      if (combined_AP_PA) { # if combined, find whether only pa or ap or both
        middle_bit <-
          paste0(
            ifelse(diseases$physical_activity[j] == 1, "pa_", ""),
            ifelse(diseases$air_pollution[j] == 1, "ap_", "")
          )
      } else {
        # if independent, choose which one
        middle_bit <- c("pa_", "ap_")[which(c(diseases$physical_activity[j], diseases$air_pollution[j]) == 1)[path]]
      }
      
      # set column names
      base_var <- paste0("RR_", middle_bit, scenarios[1], "_", ac)
      scen_var <- paste0("RR_", middle_bit, scenarios[2], "_", ac)
      
      # subset gbd data for deaths and ylls by the given disease
      gbd_disease <- gbd_data[cause == ac]
      
      # isolate rr for pathway
      person_cols <- c("PId", "age_bin", "sex", base_var, scen_var)
      disease_risk <- ind_ap_pa[, ..person_cols]
      
      # join the population, gbd data
      join_cols <- c("age_bin", "sex", "deathrate", "yllrate")
      disease_risk <- disease_risk[gbd_disease[, ..join_cols],
                                   on = .(age_bin, sex),
                                   nomatch = NULL]
      disease_risk <- disease_risk[order(PId)]
        
      # set up naming conventions
      scen <- scenarios[2]
      yll_name <- paste0(scen, "_ylls_", middle_bit, ac)
      deaths_name <- paste0(scen, "_deaths_", middle_bit, ac)
      
      # calculate PIF (i.e. change in RR compared to reference scenario) for this scenario and convert to vector
      pif_scen <- (disease_risk[, ..base_var] - disease_risk[, ..scen_var]) / disease_risk[, ..base_var]
      disease_risk$pif <- (
        (disease_risk[, ..base_var] - disease_risk[, ..scen_var]) / disease_risk[, ..base_var])
        
      # Calculate the difference in ylls between the non-reference and the reference scenario
      # by multiplying the current burden of disease for particular disease by the PIF value,
      # i.e the expected change between the reference scenario and the given scenario
      # for each age and sex category
      disease_ylls <- disease_risk$yllrate * disease_risk$pif
      ylls[[yll_name]] <- disease_ylls
        
      # Calculate the difference in deaths between the non-reference and the reference scenario
      # by multiplying current burden of disease for particular disease by the PIF value,
      # i.e the expected change between the reference scenario and the given scenario
      # for each age and sex category
      disease_deaths <- disease_risk$deathrate * disease_risk$pif
      deaths[[deaths_name]] <- disease_deaths
      
    } # end of pathways loop
  } # end of disease loop
  
  # return list of (deaths, ylls)
  return(list(deaths = deaths, ylls = ylls))
}



#' Join disease health burden and injury data
#'
#' Join the two data frames for health burden: that from disease, and that from road-traffic injury
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item extract the yll and deaths data from the AP and PA pathways
#'  \item extract the yll and deaths data from the injury data
#'  \item create one dataframe for yll and one for deaths containing all the AP, PA and injury data
#' }
#'
#' @param ind_ap_pa list (deaths, YLLs) of data frames of all demographic groups' burdens of diseases
#' @param inj list (deaths, YLLs) of data frames of all demographic groups' burdens for road-traffic injury
#'
#' @return list of dataframes: one for deaths per cause per demographic group, and likewise for YLLs
#'
#' @export


injury_death_to_yll <- function(persons, injuries, input_dir, ref_scenarios) {
  
  # load gbd data for region
  gbd_data <- fread(file.path(input_dir, "gbd.csv"))
  gbd_data <- gbd_data[cause=="road_injuries"]
  gbd_data$yll_ratio <- gbd_data$ylls / gbd_data$deaths
  
  # append sex, age to injuries
  join_cols <- c("PId", "sex", "age")
  injuries <- injuries[persons[scenario=="baseline"][, ..join_cols],
                       on = .(PId)]
  
  # add person age bin so we can join gbd data
  injuries$age_bin <- (injuries$age %/% 5) * 5
  injuries[age_bin==0, age_bin := 1]  # to match lowest age bin in gbd data
  join_cols <- c("age_bin", "sex", "yll_ratio")
  injuries <- injuries[gbd_data[, ..join_cols],
                       on = .(age_bin, sex),
                       nomatch = NULL]
  
  # now, we can use yll_ratio to estimate road injury ylls for each scenario
  for (scenario in ref_scenarios){
    
    # parse colnames for scenario
    deaths_colname <- paste(scenario, 'traffic_deaths', sep = '_')
    ylls_colname <- paste(scenario, 'traffic_ylls', sep = '_')
    
    # estimate ylls and append
    ylls <- injuries[, ..deaths_colname] * injuries$yll_ratio
    injuries[, ylls_colname] <- ylls
  }
  
  # finally, calc difference between baseline, counterfactual
  deaths_colname <- paste(ref_scenarios[2], 'traffic_deaths', sep = '_')
  delta_deaths <- 
    injuries$baseline_traffic_deaths - injuries[, ..deaths_colname]
  ylls_colname <- paste(ref_scenarios[2], 'traffic_ylls', sep = '_')
  delta_ylls <- 
    injuries$baseline_traffic_ylls - injuries[, ..ylls_colname]
  
  # replace scenario cols with deltas
  injuries[, (deaths_colname) := delta_deaths]
  injuries[, (ylls_colname) := delta_ylls]
  
  # clean up schema and return injury burden
  # to match other health burden objects return list of (deaths, ylls)
  scrub <- c("sex", "age", "age_bin", "yll_ratio",
             "baseline_traffic_deaths", "baseline_traffic_ylls")
  injuries[ ,(scrub) := NULL][order(PId)]  # in-place
  traffic_deaths <- injuries[, grep("PId|traffic_deaths", names(injuries)),
                             with = FALSE]
  injuries <- injuries[, grep("PId|traffic_ylls", names(injuries)),
                       with = FALSE]  # recycle object name
  return(list(deaths= traffic_deaths, ylls = injuries))
}


join_hb_and_injury <- function(hb_ap_pa, inj) {
  
  # combine deaths, ylls on the fly
  deaths <- hb_ap_pa$deaths[inj$deaths, on = .(PId)]
  ylls <- hb_ap_pa$ylls[inj$ylls, on = .(PId)]
  
  # return total health burden
  list(deaths = deaths, ylls = ylls)
}


aggregateHealthBurden <- function(healthBurden, persons, scenario, output_dir) {
  
  # join person attributes to health burden estimates
  joincols <- c("HhId", "Bzone", "PId", "age", "sex")
  healthBurden$deaths <- healthBurden$deaths[persons[, ..joincols],
                                             on = .(PId)]
  
  # roll-up to hhs, bzones
  outcomes <- names(
    healthBurden$deaths)[grepl(scenario, names(healthBurden$deaths))]
  hhAgg_deaths <- healthBurden$deaths[, lapply(.SD, sum),
                                      by=.(HhId),
                                      .SDcols=outcomes]
  zoneAgg_deaths <- healthBurden$deaths[, lapply(.SD, sum),
                                        by=.(Bzone),
                                        .SDcols=outcomes]
  
  # join person attributes to health burden estimates
  joincols <- c("HhId", "Bzone", "PId", "age", "sex")
  healthBurden$ylls <- healthBurden$ylls[persons[, ..joincols],
                                             on = .(PId)]
  
  # roll-up to hhs, bzones
  outcomes <- names(
    healthBurden$ylls)[grepl(scenario, names(healthBurden$ylls))]
  hhAgg_ylls <- healthBurden$ylls[, lapply(.SD, sum),
                                  by=.(HhId),
                                  .SDcols=outcomes]
  zoneAgg_ylls <- healthBurden$ylls[, lapply(.SD, sum),
                                    by=.(Bzone),
                                    .SDcols=outcomes]

  # now, clean up schema and write each output
  # hh deaths
  names(hhAgg_deaths) <- sub(paste0(scenario, "_"), '', names(hhAgg_deaths))
  write.csv(hhAgg_deaths, file.path(
    output_dir, paste0("ithim_Household_", scenario,"-mortality_", year, ".csv")))
  
  # hh ylls
  names(hhAgg_ylls) <- sub(paste0(scenario, "_"), '', names(hhAgg_ylls))
  write.csv(hhAgg_ylls, file.path(
    output_dir, paste0("ithim_Household_", scenario,"-ylls_", year, ".csv")))
  
  # zonal deaths
  names(zoneAgg_deaths) <- sub(paste0(scenario, "_"), '', names(zoneAgg_deaths))
  write.csv(zoneAgg_deaths, file.path(
    output_dir, paste0("ithim_Bzone_", scenario,"-mortality_", year, ".csv")))
  
  # zonal ylls
  names(zoneAgg_ylls) <- sub(paste0(scenario, "_"), '', names(zoneAgg_ylls))
  write.csv(zoneAgg_ylls, file.path(
    output_dir, paste0("ithim_Bzone_", scenario,"-ylls_", year, ".csv")))
}

