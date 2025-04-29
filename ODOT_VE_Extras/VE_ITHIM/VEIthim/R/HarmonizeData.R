# this module prepares VE outputs for ITHIM


#' Load VE households
#'
#' Helper function to load VE households table from output (csv) directory
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item given scenario name and year, identifies correct file to load
#'
#'  \item loads VE household table with only required columns
#'    }
#'
#' @param model VE model directory
#' @param year VE model year
#'
#' @return data.table containing VE households
#'
#' @export


loadVEHhs <- function(results_dir, model, year) {
  
  # identify correct hh table within model outputs directory
  hh_file <- paste0("Household_", model, "_", year, ".csv")
  file <- file.path(results_dir, hh_file)
  
  # load base model households table
  read_cols = c(
    "HhId", "Bzone",  "HhSize",
    "Age0to14", "Age15to19", "Age20to29", "Age30to54", "Age55to64", "Age65Plus",
    "Dvmt", "TransitPMT", "WalkPMT", "BikePMT"
  )
  Hhs <- fread(file, select=read_cols)
  
  # return Hhs table
  return(Hhs)
}


#' Estimate ventilation rates
#'
#' This function estiamtes ventilation rates for each VE person
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item NOTE: this function is largely unchanged from ITHIM-R source code
#'   
#'  \item load parameters that define ventilation rate calculations
#'
#'  \item estimates ventilation rate, drawing from distributions to account for 
#'  uncertainty
#'    }
#'
#' @param persons data.table containing persons synthesized from VE households
#' @param input_dir local file path to VE model input dir
#'
#' @return data.table containing ventilation rate estimates for VE persons
#'
#' @export


estimateVentilationRates <- function(persons, input_dir){
  
  # estimate body mass for inhalation rates
  # we will draw from distributions supplied in core ITHIM codebase
  # Body mass
  body_mass <- fread(file.path(
    input_dir, "BodyMass.csv"),
    select = c("age", "sex", "gm", "gsd", "lower", "upper"))
  
  # Energy Conversion Factor
  ecf <- fread(file.path(
    input_dir, "ECF.csv"),
    select = c("age", "sex", "lower", "upper"))
  
  # Resting Metabolic Rate
  rmr <- fread(file.path(
    input_dir,"RMR.csv"),
    select = c("age", "sex", "slope", "interc", "se"))
  
  # maximum oxygen uptake rate (NVO2max)
  nvo2max <- fread(file.path(
    input_dir, "NVO2max.csv"),
    select = c("age", "sex", "mean", "sd", "lower", "upper"))
  
  # Ventilation from o2 Uptake 
  vent_from_oxygen <- fread(file.path(
    input_dir, "VentilationFromOxygenUptake.csv"),
    select = c("age", "sex", "intercept_a", "slope_b", "sd_person_level", "sd_test_level"))  
  
  # Draw from a log-normal distribution the body mass [kg] of each person
  # in the synthetic population
  body_mass <- persons[body_mass, on = c('age', 'sex'),
                       nomatch = NULL][order(PId)] %>%
    rowwise() %>% # To apply an operation in each row
    mutate(
      # Draw sample from distribution
      sample = rlnorm(1, log(gm), log(gsd)),
      # Check maximum and minimum values
      body_mass = ifelse(sample < lower, lower,
                         ifelse(sample > upper, upper, sample))) %>% 
    dplyr::select(PId, age, sex, body_mass)
  
  # Draw from a uniform distribution the Energy Conversion Factor [lt/kcal]
  # of each person in the synthetic population
  body_mass <- body_mass %>%
    left_join(ecf, by = c("age", "sex")) %>%
    rowwise() %>% # To apply an operation in each row
    mutate(
      # Draw sample from distribution
      ecf = runif(1, min = lower, max = upper),
    ) %>%
    dplyr::select(PId, age, sex, body_mass, ecf)
  
  # For each person in the synthetic population, calculate the Resting
  # Metabolic Rate [kcal/min] from a given regression formula with a normally
  # distributed error
  body_mass <- body_mass %>%
    left_join(rmr, by = c("age", "sex")) %>%
    rowwise() %>% # To apply an operation in each row
    mutate(
      # Draw sample from distribution
      error = rnorm(1, 0, se),
      # Calculate RMR
      rmr = 0.166 * (interc + (slope * body_mass) + error)
    ) %>%
    dplyr::select(PId, age, sex, body_mass, ecf, rmr)
  
  # Draw from a normalized maximum oxygen uptake rate (NVO2max) [lt/(min*kg)]
  # of each person in the synthetic population
  body_mass <- body_mass %>%
    left_join(nvo2max, by = c("age", "sex")) %>%
    rowwise() %>% # To apply an operation in each row
    mutate(
      # Draw sample from distribution
      sample = rnorm(1, mean, sd),
      # Check maximum and minimum values
      sample_check = ifelse(sample < lower, lower,
                            ifelse(sample > upper, upper, sample)
      ),
      # Transform [ml/(min*kg)] to [lt/(min*kg)]
      nvo2max = sample_check / 1000
    ) %>%
    dplyr::select(PId, age, sex, body_mass, ecf, rmr, nvo2max)
  
  # Calculate the maximum oxygen uptake rate [lt/min] of each person in the
  # synthetic population
  body_mass$vo2max <- body_mass$nvo2max * body_mass$body_mass
  
  # Get the parameters for the empirical equation to calculate the
  # Ventilation Rate from Oxygen Uptake Rate in each person in the
  # synthetic population
  body_mass <- body_mass %>%
    left_join(vent_from_oxygen, by = c("age", "sex")) %>%
    rowwise() %>% # To apply an operation in each row
    mutate(
      # Draw sample from normal distribution taking into account the variance
      # between persons
      d_k = rnorm(1, 0, sd_person_level)
    ) %>%
    dplyr::select(
      PId, body_mass, ecf, rmr, vo2max, intercept_a, slope_b, sd_test_level, d_k
    )
  
  return(setDT(body_mass))
}


#' Synthesize persons from VE households
#'
#' Function to synthesize VE persons using data in the VE households table and 
#' assign required person attributes
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item aligns travel mode names in Hh table with downstream expectations
#'  
#'  \item estimates travel duration by mode from Hh miles traveled estimates
#'
#'  \item decomposes Hhs into persons based on Hh age distribution
#'  
#'  \item assign age (continuous) and sex to each person 
#'  
#'  \item call estimateVentilationRates func to estimate ventilation rates
#'  
#'  \item distribute Hh travel to synthetic persons 
#'    }
#'
#' @param Hhs data.table containing VE households
#' @param input_dir local file path to VE model input dir
#' @param settings data.table storing ithim settings/configuration
#'
#' @return list containing two data.tables: one containing VE persons, 
#' one containing ventilation rate estiamtes for those persons
#'
#' @export


hhsToPersons <- function(Hhs, input_dir, settings){

  # first, rename mode cols
  mode_cols = c("auto_dist", "transit_dist", "walk_dist", "bike_dist")
  setnames(Hhs,
           c("Dvmt", "TransitPMT", "WalkPMT", "BikePMT"),
           mode_cols)
  
  # and convert distances to duration
  Hhs$auto_minutes <- Hhs$auto_dist / settings[name=="speed_auto"]$value * 60
  Hhs$transit_minutes <- Hhs$transit_dist / settings[name=="speed_transit"]$value * 60
  Hhs$walk_minutes <- Hhs$walk_dist / settings[name=="speed_walk"]$value * 60
  Hhs$bike_minutes <- Hhs$bike_dist / settings[name=="speed_bike"]$value * 60
  
  # melt Hh table so that each age bin is a row
  # replace 0 with NA on the fly to so we can use na.rm in melt()
  persons <- melt(
    replace(Hhs, Hhs==0, NA),  # so we can use na.rm = TRUE
    id.vars=c("HhId", "Bzone"),
    measure = patterns("Age"),
    variable.name = "ageBin",
    value.name = "nPersons",
    na.rm = TRUE)
  
  # we need to join a few items back to persons from hh table
  join_cols <- c(
    "HhId", "HhSize",
    "auto_dist", "transit_dist", "walk_dist", "bike_dist",
    "auto_minutes", "transit_minutes", "walk_minutes", "bike_minutes"
    )
  persons <- persons[Hhs[, ..join_cols], on = .(HhId)]
  
  # now, each person becomes a row
  persons <- data.table(
    as.data.frame(lapply(persons, rep, persons$nPersons)))
  persons[,nPersons:=NULL]  # in-place
  
  # randomly assign each person an age in the relevant bin
  # first need to parse min, max age within each age bin
  persons$ageBin <- substring(persons$ageBin, 4)
  persons[, c("minAge", "maxAge") := tstrsplit(ageBin, "to", fixed=TRUE)]
  persons[minAge == "65Plus", minAge := "65"]  # in-place
  persons[is.na(maxAge), maxAge := "85"]  # in-place
  
  # TODO: this is a little slow
  persons$age <- mapply(
    function(x, y) sample(seq(x, y), 1), 
    persons$minAge, persons$maxAge)
  
  # next, assign gender to each person based on global gender ratio
  # for now, we're not going to worry about gender distribution within Hhs
  # in the future, we should do this more carefully
  values <- c('male', 'female')
  genderRatio <- settings[name=="gender_ratio"]$value
  weights <- c(genderRatio, 1 - genderRatio)
  persons$sex <- sample(
    values,
    size=nrow(persons),
    replace = TRUE,
    prob = weights)
  
  # assign person uid so that we can keep track of persons across scenarios
  persons$PId <- 1:nrow(persons)
  
  # estimate ventilation rates and join to persons
  ventInputDir <- file.path(input_dir, "ithim")
  ventilationRates <- estimateVentilationRates(persons, ventInputDir)
  
  # finally, decompose Hh travel totals to individuals
  # for now, just distribute equally across Hh members
  # in the future, we should do this more carefully
  travel_cols = c(
    "auto_dist", "transit_dist", "walk_dist", "bike_dist",
    "auto_minutes", "transit_minutes", "walk_minutes", "bike_minutes"
    )
  for (col in travel_cols) {
    replacement_values <- persons[, ..col] / persons$HhSize
    persons[, (col) := replacement_values]
  }
  
  # clean up schema and return list of persons, ventilation rates
  scrub <- c("ageBin", "minAge", "maxAge")
  persons[ ,(scrub) := NULL]  # in-place
  return(list(persons = persons, ventRates = ventilationRates))
}


#' Append zone attributes
#'
#' Joins zone attributes to VE persons
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item loads bzone background PM, PA estimates for study region
#'
#'  \item joins attributes to persons based on home bzone
#'    }
#'
#' @param persons data.table containing VE persons
#' @param year VE model year
#' @param input_dir local file path to VE model input dir
#'
#' @return data.table containing VE persons with zonal exposures appended
#'
#' @export


appendZoneAttributes <- function(persons, year, input_dir){
  
  # loads bzone PM, PA estimates
  zonePM <- fread(file.path(input_dir, "bzone_pm.csv"))
  setnames(zonePM, c("Geo"), c("Bzone"))
  zonePA <- fread(file.path(input_dir, "bzone_pa.csv"))
  setnames(zonePA, c("Geo"), c("Bzone"))
  
  # join background PM2.5 to persons table
  # from Bzones
  join_cols <- c("Bzone", "PM25")
  persons <- persons[zonePM[zonePM$Year == year][, ..join_cols],
                     on = .(Bzone),
                     nomatch = NULL]
  
  # join background PA to persons table
  # from Bzones
  join_cols <- c("Bzone", "pa0", "pa1", "pa2", "pa3")
  persons <- persons[zonePA[zonePA$Year == year][, ..join_cols],
                     on = .(Bzone),
                     nomatch = NULL]
  
  # background PA is a distribution, so assign a value to each person
  prob_samp <- function(x) sample.int(n=4, size=1, prob=x) # from jay.sf
  persons[, pa_group := apply(.SD, 1, prob_samp), 
          .SDcols=c("pa0", "pa1", "pa2", "pa3")]
  
  # now that we have a bin for each person, assign min/max PA values
  persons$minPA <- 0
  persons$maxPA <- 39
  persons[pa_group == 2, c("minPA", "maxPA") := list(40, 74)]  # in-place
  persons[pa_group == 3, c("minPA", "maxPA") := list(75, 149)]
  persons[pa_group == 4, c("minPA", "maxPA") := list(150, 225)]

  # TODO: this is a little slow
  persons$leisurePA <- mapply(
    function(x, y) sample(seq(x, y), 1), 
    persons$minPA, persons$maxPA)
  
  # clean up schema and return persons df
  scrub <- c("pa0", "pa1", "pa2", "pa3", "pa_group", "minPA", "maxPA")
  persons[ ,(scrub) := NULL]  # in-place
  return(persons)
}
  
