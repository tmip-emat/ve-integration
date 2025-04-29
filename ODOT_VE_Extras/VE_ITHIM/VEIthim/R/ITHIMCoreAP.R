#' Calculate total AP exposure per person
#' 
#' Calculate total AP exposure per person based on population and personal travel
#' 
#' This function performs the following steps:
#' 
#' \itemize{
#' \item the ventilation rates per mode are defined - these parameters are fixed
#' 
#' \item the exposure factor rates by activity are defined - these parameters are fixed
#' 
#' \item calculate pm concentration not related to transport
#' 
#' \item calculate PM emission factors for each mode by dividing total emissions by distances travelled
#' 
#' \item calculate PM emissions for each mode in each scenario by multiplying the scenario distance
#'   by the emission factors
#' 
#' \item for modes without any assigned distance, use the PM emissions from the VEHICLE_INVENTORY instead
#' 
#' \item calculate the total PM concentrations for each scenario
#' 
#' \item add ventilation and exposure factors to the trip set by stage mode
#' 
#' \item add total scenario PM concentrations to the trip set
#' 
#' \item add the inhaled air and total PM (in micro grams) to the trip set
#' 
#' \item define the amount of time per day spent as leisure sedentary screen time, 
#'   non-discretionary time and other time - fixed
#' 
#' \item add total time spent travelling by each participant to the trip set
#'
#' \item calculate the sleep and the rest ventilation rates
#' 
#' \item for each participant in the synthetic population (with travel component), 
#'   calculate the total air inhaled, the total PM inhaled and 
#'   the total PM concentration inhaled for each scenario
#'
#' \item assign all participants in the synthetic population without travel component,
#'   the baseline or scenario PM concentrations
#'
#' \item join all people with and without travel in the synthetic population
#' }
#' 
#' 
#' @param dist total distance travelled by mode by the population for all scenarios
#' @param trip_scen_sets trips data frame of all trips from all scenarios
#' 
#' @return background PM concentration for baseline and all scenarios
#' @return total AP exposure per person in the synthetic population (for baseline and scenarios)
#' 
#' @export


developModeInventory <- function(settings){
  
  # Exposure factor rate by activity (the ratio between that mode’s PM2.5 and the background’s PM2.5)
  e_rate <- list(
    auto = settings[name=="e_rate_auto"]$value, 
    transit = settings[name=="e_rate_transit"]$value, 
    bike = settings[name=="e_rate_bike"]$value, 
    walk = settings[name=="e_rate_walk"]$value
  )
  
  # add mode speeds
  mode_speeds <- list(
    auto = settings[name=="speed_auto"]$value, 
    transit = settings[name=="speed_transit"]$value, 
    bike = settings[name=="speed_bike"]$value, 
    walk = settings[name=="speed_walk"]$value
  )
  
  # and pm emissions inventory values
  pm_inventory <- list(
    auto = settings[name=="pm_inventory_auto"]$value,
    transit = settings[name=="pm_inventory_transit"]$value,
    bike = settings[name=="pm_inventory_bike"]$value,
    walk = settings[name=="pm_inventory_walk"]$value
  )
  
  mode_inventory <- data.frame(
    e_rate = unlist(e_rate),
    speed = unlist(mode_speeds),
    PM_emission_inventory = unlist(pm_inventory),
    stringsAsFactors = F)
  
  return(mode_inventory)
}


scenario_pm_calculations <- function(trips, Persons, input_dir, settings){
  
  # concentration contributed by non-transport share
  # remains constant across the scenarios
  background_pm <- Persons$scenarioPersons[scenario=="baseline", PM25]
  non_transport_pm <- background_pm*(1 - settings[name=="pm_trans_share"]$value)
  mode_inventory <- developModeInventory(settings)
  
  # we assume travel predicted by VE represents all travel in the region
  # ie, we do not need to add travel not covered in synthetic trip set
  # total distance traveled by each mode
  dist_cols <- c("auto_dist", "transit_dist", "walk_dist", "bike_dist")
  distances_by_mode <- Persons$scenarioPersons[, lapply(.SD, sum, na.rm=TRUE),
                                       by=.(scenario),
                                       .SDcols=dist_cols]
  scenarios <- distances_by_mode$scenario  # stash scenario names
  counterfactual_scenarios <- scenarios[2:length(scenarios)]  # scrub "baseline"
  distances_by_mode <- transpose(
    distances_by_mode[, ..dist_cols],
    keep.names = "mode")
  distances_by_mode$mode <- gsub("_dist", "", distances_by_mode$mode)  # clean up mode names
  
  # transpose creates temporary names we want to replace
  temp_names <- names(distances_by_mode)
  temp_names <- temp_names[2:length(temp_names)]  # scrub "mode"
  setnames(distances_by_mode, temp_names, scenarios)

  # convert to data.frame for indexing
  distances_by_mode <- as.data.frame(distances_by_mode)
  rownames(distances_by_mode) <- distances_by_mode$mode
  distances_by_mode$mode <- NULL
  
  # and now we can append to mode_inventory
  mode_inventory$total_dist <- distances_by_mode$baseline

  # get emission factor by dividing inventory by baseline distance
  # We don't need to scale to a whole year, as we are just scaling the background concentration
  # this is just emission inventory divided by total travel
  baseline_emfacs <- mode_inventory$PM_emission_inventory / distances_by_mode$baseline
  trans_emissions <- distances_by_mode[scenarios] * t(repmat(baseline_emfacs, length(scenarios), 1))
  
  # TODO: figure out something more elegant
  # transit emissions shouldn't scale directly with transit trips (i.e., based on service, not person-trips)
  # so replace all scenario value with baseline value
  for(counterfactual in counterfactual_scenarios){
    trans_emissions["transit" , counterfactual] <- trans_emissions["transit" , "baseline"]
  }
  
  # scenario travel pm2.5 calculated as relative to the baseline
  baseline_pm <- sum(trans_emissions["baseline"], na.rm = T)
  
  # in this sum, the non-transport pm is constant
  # the transport emissions scale the transport contribution (pm_trans_share) to the base level (PM_CONC_BASE)
  for(counterfactual in counterfactual_scenarios){
    Persons$scenarioPersons[scenario==counterfactual, "PM25"] <- 
      non_transport_pm + settings[name=="pm_trans_share"]$value * background_pm * sum(trans_emissions[[counterfactual]], na.rm = T)/baseline_pm
  }
  
  # Join trip_set and exponent factors df
  # first, convert mode_inventory to DT now that we no longer need index
  mode_inventory$mode <- rownames(mode_inventory)
  setDT(mode_inventory)
  join_cols <- c("mode", "e_rate")
  trips <- trips[mode_inventory[, ..join_cols], on = .(mode)]
  
  #----
  # Dan: These new lines of code are for the ventilation rate
  # Dan: MET values for each mode/activity. These values come from the Compendium
  mets <- fread(file.path(input_dir, "ithim", "mets.csv"),
                select = c("mode", "met"))
  
  # Dan: Adding MET values [dimensionless] for each mode
  trips <- trips[mets, on = .(mode), nomatch = NULL]
  trips <- trips[Persons$ventRates, on = .(PId), nomatch = NULL]
  
  # Dan: Calculate new variables for each stage
  #   - vo2 = oxygen uptake [lt/min]
  #   - pct_vo2max = upper limit of VO2max in percentage [%]
  #   - upper_vo2max = permitted upper limit of VO2 [lt/min]
  #   - adj_vo2 = adjusted oxygen uptake [lt/min]
  #   - e_ijk = error to account variance between activities
  #   - log_vent_rate = log of ventilation rate (empirical equation)
  #   - vent_rate = ventilation rate by removing the log in the empirical equation [lt/min]
  #   - v_rate = ventilation rate in different units of measurement [m3/h]
  
  # TODO: trips needs body_mass, ecf, rmr, vo2max, intercept_a, slope_b, sd_test_level, d_k
  vo2 <- trips$ecf *  trips$met * trips$rmr
  pct_vo2max = ifelse(trips$minutes < 5, 100,
                      ifelse(trips$minutes > 540, 33,
                             121.2 - (14 * log(trips$minutes))))
  upper_vo2max = trips$vo2max * (pct_vo2max / 100)
  adj_vo2 = ifelse(vo2 > upper_vo2max, upper_vo2max, vo2)
  e_ijk = rnorm(nrow(trips), 0, trips$sd_test_level)
  log_vent_rate = trips$intercept_a + (trips$slope_b * log(adj_vo2/trips$body_mass)) + trips$d_k + e_ijk
  vent_rate = exp(log_vent_rate) * trips$body_mass
  
  # append ventilation rate to trips
  # this all we need to carry forward
  trips$v_rate = vent_rate * 60 / 1000
  
  # join PM to trips
  cols = c("PId", "scenario", "PM25")
  trips <- trips[Persons$scenarioPersons[, ..cols],
                 on = .(PId, scenario),
                 nomatch = NULL]
  
  # cubic meters of air inhaled are the product oftri the ventilation rate and the 
  # time (hours/60) spent travelling by that mode
  trips$travel_air_inhaled <- trips$minutes / 60 * trips$v_rate
  
  # PM inhaled (micro grams) = duration * ventilation rate * exposure rates * concentration
  trips$travel_pm_inhaled <- trips$minutes / 60 * trips$v_rate * trips$e_rate * trips$PM25
  
  # roll-up to person-level
  sum_cols <- c("minutes", "travel_air_inhaled", "travel_pm_inhaled")
  activities <- trips[, lapply(.SD, sum, na.rm=TRUE),
                      by=.(PId, scenario),
                      .SDcols=sum_cols ]
  
  # and join person-level attributes stored in trips table
  first_cols <- c(
    "leisurePA", "PM25", "vo2max", "ecf", "rmr",
    "intercept_a", "slope_b", "body_mass", "sd_test_level", "d_k"
    )
  person_attrs <- trips[, lapply(.SD, first),
                        by=.(PId, scenario),
                        .SDcols=first_cols]
  activities <- activities[person_attrs, on = .(PId, scenario)]
  
  #----
  # Dan: We are saying that time spent for any person is:
  # Sleep: 8.3 hours
  # Leisure sedentary screen time: 3.15 hours
  # Light activities: 10.75 hours
  # For a total of 22.2 hours
  # Since it is possible that the unknown time is less than 22.2, I am going
  # to use proportions for now to get values for these activities.
  # There are a couple of rules to consider:
  # - When sleep time is less than 6 hours, we have to assign it to 6 and split
  # proportionally the remaining time in leisure and light activities
  # - When the known time is greater than 18 hours, we assign it to 18 and sleep
  # to 6 hours. Leisure and light activities will be zero in this case
  
  sleep_hours <- settings[name=="sleep_hours"]$value
  leisure_hours <- settings[name=="leisure_hours"]$value
  light_hours <- settings[name=="light_hours"]$value

  # Transforming leisurePA to a daily value
  daily_leisurePA = (activities$leisurePA / 60) / 7
  
  # Calculate time spent in moderate and vigorous activities from leisurePA
  moderate_pa_contribution <- settings[name=="moderate_pa_contribution"]$value
  time_moderate = (daily_leisurePA * moderate_pa_contribution) / (mets[mode=="moderate"][, met] - 1)  # to marginal METs
  time_vigorous = (daily_leisurePA * (1 - moderate_pa_contribution)) / (mets[mode=="vigorous"][, met] - 1)
  
  # Calculate known time
  known_time = activities$minutes / 60 + time_moderate + time_vigorous
  known_time = ifelse(known_time > 18, 18, known_time) # Just to avoid outliers
  
  # Calculate unknown time
  unknown_time = 24 - known_time
  
  # Calculate ventilation rate for each activity (duration calculated from unknown time)
  ## Sleep
  sleep_duration = (unknown_time * (sleep_hours/(sleep_hours + leisure_hours + light_hours))) * 60 # In minutes
  
  ### Conditional to check if sleep duration is less than 6 hours
  sleep_less_6h = ifelse(sleep_duration < (6 * 60), 1, 0)
  ### Assign 6 hours when sleep time is less than 6
  sleep_duration = ifelse(sleep_less_6h == 1, (6 * 60), sleep_duration)
  vo2_sleep = activities$ecf * mets[mode=="sleep"][, met] * activities$rmr
  pct_vo2max_sleep = ifelse(sleep_duration < 5, 100,
                            ifelse(sleep_duration > 540, 33,
                                   121.2 - (14 * log(sleep_duration))))
  
  upper_vo2max_sleep = activities$vo2max * (pct_vo2max_sleep / 100)
  adj_vo2_sleep = ifelse(vo2_sleep > upper_vo2max_sleep, 
                         upper_vo2max_sleep, vo2_sleep)
  
  ### Draw sample from normal distribution taking into account the variance 
  ### between activities
  e_ijk_sleep = rnorm(nrow(activities), 0, activities$sd_test_level)   
  log_vent_rate_sleep = activities$intercept_a + (
    activities$slope_b * log(adj_vo2_sleep/activities$body_mass)
    ) + activities$d_k + e_ijk_sleep
  vent_rate_sleep = exp(log_vent_rate_sleep) * activities$body_mass
  v_rate_sleep = vent_rate_sleep * 60 / 1000
  
  ### Calculate air and pm inhaled
  sleep_air_inhaled = sleep_duration / 60 * v_rate_sleep
  sleep_pm_inhaled = sleep_duration / 60 * v_rate_sleep * activities$PM25
  
  #### Leisure has a correction if sleep time is less than 6 hours
  leisure_duration = ifelse(sleep_less_6h == 1,
                            (unknown_time - 6) * (leisure_hours/(leisure_hours + light_hours)) * 60,# In minutes
                            unknown_time * (leisure_hours/(sleep_hours + leisure_hours + light_hours))) * 60 # In minutes
  leisure_duration = ifelse(leisure_duration < 0, 0, leisure_duration) # This happened in 35 rows out of the 132k
  vo2_leisure = activities$ecf * mets[mode=="leisure"][, met] * activities$rmr
  pct_vo2max_leisure = ifelse(leisure_duration < 5, 100,
                              ifelse(leisure_duration > 540, 33,
                                     121.2 - (14 * log(leisure_duration))))
  upper_vo2max_leisure = activities$vo2max * (pct_vo2max_leisure / 100)
  adj_vo2_leisure = ifelse(vo2_leisure > upper_vo2max_leisure, 
                           upper_vo2max_leisure, vo2_leisure)
  
  ## Draw sample from normal distribution taking into account the variance 
  ## between activities
  e_ijk_leisure = rnorm(nrow(activities), 0, activities$sd_test_level)
  log_vent_rate_leisure = activities$intercept_a + (
    activities$slope_b * log(adj_vo2_leisure/activities$body_mass)
    ) + activities$d_k + e_ijk_leisure
  vent_rate_leisure = exp(log_vent_rate_leisure) * activities$body_mass
  v_rate_leisure = vent_rate_leisure * 60 / 1000
  
  # Calculate air and pm inhaled
  leisure_air_inhaled = leisure_duration / 60 * v_rate_leisure
  leisure_pm_inhaled = leisure_duration / 60 * v_rate_leisure * activities$PM25
  
  ## Light activities
  #### Light activities has a correction if sleep time is less than 6 hours
  light_duration = ifelse(sleep_less_6h == 1,
                          (unknown_time - 6) * (light_hours/(leisure_hours + light_hours)) * 60,# In minutes
                          unknown_time * (light_hours/(sleep_hours + leisure_hours + light_hours))) * 60 # In minutes
  light_duration = ifelse(light_duration < 0, 0, light_duration) # This happened in 35 rows out of the 132k
  vo2_light = activities$ecf * mets[mode=="light_activities"][, met] * activities$rmr
  pct_vo2max_light = ifelse(light_duration < 5, 100,
                            ifelse(light_duration > 540, 33,
                                   121.2 - (14 * log(light_duration))))
  upper_vo2max_light = activities$vo2max * (pct_vo2max_light / 100)
  adj_vo2_light = ifelse(vo2_light > upper_vo2max_light, 
                         upper_vo2max_light, vo2_light)
  
  ## Draw sample from normal distribution taking into account the variance 
  ## between activities
  e_ijk_light = rnorm(nrow(activities), 0, activities$sd_test_level)
  log_vent_rate_light = activities$intercept_a + (
    activities$slope_b * log(adj_vo2_light/activities$body_mass)
    ) + activities$d_k + e_ijk_light
  vent_rate_light = exp(log_vent_rate_light) * activities$body_mass
  v_rate_light = vent_rate_light * 60 / 1000
  
  # Calculate air and pm inhaled
  light_air_inhaled = light_duration / 60 * v_rate_light
  light_pm_inhaled = light_duration / 60 * v_rate_light * activities$PM25
  
  # Total air and pm inhaled
  total_air_inhaled = activities$travel_air_inhaled + sleep_air_inhaled + leisure_air_inhaled + light_air_inhaled
  total_pm_inhaled = activities$travel_pm_inhaled + sleep_pm_inhaled + leisure_pm_inhaled + light_pm_inhaled
  
  # Calculate pm / air ratio
  activities$conc_pm_inhaled = total_pm_inhaled / total_air_inhaled
  
  # append to persons
  join_cols <- c("PId", "scenario", "conc_pm_inhaled")
  Persons$scenarioPersons <- Persons$scenarioPersons[activities[, ..join_cols],
                                     on = .(PId, scenario)]
  
  # Calculate total air and pm inhaled in each person
  # Change to wide format
  pm_exp <- Persons$scenarioPersons %>% 
    dplyr::select(PId, scenario, conc_pm_inhaled) %>% 
    pivot_wider(names_from = 'scenario', values_from = 'conc_pm_inhaled')
  
  # pm_conc prefix for each scenario
  pm_colnames <- paste('pm_conc', scenarios, sep = '_')
  setDT(pm_exp)
  setnames(pm_exp, scenarios, pm_colnames)
  
  # Join person info to pm_exp
  join_cols <- c("PId", "age", "sex")
  pm_exp <- pm_exp[Persons$scenarioPersons[scenario=="baseline", ..join_cols],
                   on = .(PId)]
  
  # enforce sorting and return pm_exp
  # per person PM2.5 exposure (unit: ug/m3)
  return(pm_exp[order(PId)])
}

