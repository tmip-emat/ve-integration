#' Get relative risk for diseases given PM exposure
#'
#' Computes the relative risk (RR) for persons for each disease given PM exposure
#'
#' This function performs the following steps:
#' \itemize{
#' \item minimum ages for each age group corresponding to disease risks are assigned to the individuals in the
#'   synthetic population (with added PM exposure levels)
#'
#' \item loop through all diseases that are related to PM pollution:
#'   \itemize{
#'    \item depending on the disease (as some disease have different relative risks depending
#'      on the age of the individual) loop through disease specific age groups (or just
#'      one age group for most disease)
#'
#'    \item set the quantile of the value of the dose response curves to be extracted. If running in
#'      constant mode, the quantile is usually set to 0.5, i.e. to the median of the dose response curves.
#'      If running in sample mode, then the quantile can be set to be sampled from a distribution in the
#'      input parameters.
#'
#'    \item loop through the scenarios:
#'      \itemize{
#'      \item assign the relative risk for the given disease, age group, quantile and scenario to the
#'        relevant people in the synthetic population by calling the \code{\link{AP_dose_response()}} function
#'      }
#'    }
#' }
#'
#' @param pm_conc_pp individual PM exposures for each person in the synthetic population
#'
#' @return data frame of relative risks per person for each disease and each scenario
#'
#' @export


AP_dose_response <- function(cause, rr_values, dose, quantile = 0.5, confidence_intervals = FALSE) {
  # Check there are NAs in dose or the classes is not numeric
  if (sum(is.na(dose)) > 0 || class(dose) != "numeric") {
    stop("Please provide dose in numeric")
  }
  # check that the correct disease name is used
  if (!cause %in% c(
    "all_cause_ap", "cvd_ihd", "neo_lung", "resp_copd",
    "cvd_stroke", "t2_dm", "lri", "respiratory", "cvd",
    "cvd_ihd_25", "cvd_ihd_30", "cvd_ihd_35", "cvd_ihd_40",
    "cvd_ihd_45", "cvd_ihd_50", "cvd_ihd_55", "cvd_ihd_60",
    "cvd_ihd_65", "cvd_ihd_70", "cvd_ihd_75", "cvd_ihd_80",
    "cvd_ihd_85", "cvd_ihd_90", "cvd_ihd_95",
    "cvd_stroke_25", "cvd_stroke_30", "cvd_stroke_35",
    "cvd_stroke_40", "cvd_stroke_45", "cvd_stroke_50",
    "cvd_stroke_55", "cvd_stroke_60", "cvd_stroke_65",
    "cvd_stroke_70", "cvd_stroke_75", "cvd_stroke_80",
    "cvd_stroke_85", "cvd_stroke_90", "cvd_stroke_95"
  )) {
    stop("Unsupported cause/disease. Please select from \n
         cvd_ihd \n
         neo_lung \n
         resp_copd \n
         cvd_stroke \n
         t2_dm \n
         lri \n
         respiratory \n
         cvd")
  } # End if unsupported causes
  
  # read in dose response functions for disease cause
  # contains relative risk with upper and lower limits for a variety of doses
  lookup_df <- rr_values
  
  # interpolate the values in the lookup table to get RR values for all PM exposure doses
  # in the synthetic population
  rr <- approx(
    x = lookup_df$dose, y = lookup_df$RR,
    xout = dose, yleft = 1, yright = min(lookup_df$RR)
  )$y
  
  # if a confidence interval is to be returned or if the quantile is not 0.5,
  # i.e. the median define an upper or lower band
  # interpolate the upper and lower band values in the lookup table to get upper and lower band
  # RR values for all PM exposure doses in the synthetic population
  if (confidence_intervals || quantile != 0.5) {
    lb <-
      approx(
        x = lookup_df$dose,
        y = lookup_df$lb,
        xout = dose,
        yleft = 1,
        yright = min(lookup_df$lb)
      )$y
    ub <-
      approx(
        x = lookup_df$dose,
        y = lookup_df$ub,
        xout = dose,
        yleft = 1,
        yright = min(lookup_df$ub)
      )$y
  }
  
  # if the quantile is not 0.5, i.e. the median, then find the RR value by finding the
  # right quantile of a normal function with mean = the median RR value and standard deviation
  # defined by the upper and lower RR confidence interval values
  if (quantile != 0.5) {
    rr <- qnorm(quantile, mean = rr, sd = (ub - lb) / 1.96)
    rr[rr < 0] <- 0
  }
  
  # if confidence values are required return the RR and the lower and upper bounds
  # otherwise just return the RR
  if (confidence_intervals) {
    return(data.frame(rr = rr, lb = lb, ub = ub))
  } else {
    return(data.frame(rr = rr))
  }
  
  browser()
  return(rr)
}


gen_ap_rr <- function(pm_conc_pp, scenarios, input_dir) {
  pm_rr_pp <- pm_conc_pp
  
  # load air pollution relative risk values
  # these are stored in global env in ITHIM, which is not ideal....
  diseases <- fread(file.path(input_dir, "disease_outcomes_lookup.csv"))
  diseases <- diseases[air_pollution==1]  # isolate AP pathway
  
  ## assigning air pollution age bands to the individual level data
  min_ages <- c(seq(24, 94, by = 5), 200)
  pm_rr_pp$age <- as.numeric(pm_rr_pp$age)
  pm_rr_pp$age_bin <- 0
  
  for (i in 1:length(min_ages)) { # loop through the minimum ages
    
    # assign 'age categories' by assigning the minimum age of that category
    pm_rr_pp$age_bin[pm_rr_pp$age > min_ages[i]] <- min_ages[i] + 1
  }
  
  # find column locations of columns containing the scenario specific pm exposure levels
  pm_indices <- sapply(
    scenarios,
    function(x) {
      which(colnames(pm_rr_pp) == paste0("pm_conc_", x))
    }
  )
  
  ### iterate over all disease outcomes that are related to PM pollution levels
  for (j in c(1:nrow(diseases))[diseases$air_pollution == 1]) {
    
    # initialise columns to store results
    for (x in 1:length(scenarios)) { # create columns for future results
      pm_rr_pp[[paste0("RR_ap_", scenarios[x])]] <- 1
    }
    
    cause <- as.character(diseases$ap_acronym[j])
    
    # apply age groups depending on the disease
    if (cause %in% c("cvd_ihd", "cvd_stroke")) {
      ages <- seq(25, 95, 5)
    } else {
      ages <- 99
    }
    
    for (age in ages) { # loop through ages groups
      
      # Look for index of people in the age category
      if (age == 99) {
        i <- 1:nrow(pm_rr_pp)
      } else {
        i <- which(pm_rr_pp$age_bin == age)
      }
      cause_age <- ifelse(length(ages) != 1,
                          paste(cause, age, sep = "_"),
                          cause
      )
      
      
      # get name of disease
      ap_n <- as.character(diseases$acronym[j]) # same as cause
      
      # Set quantile to the default value
      quant <- 0.5
      
      # Check if quantile for the the specific disease has been declared.
      # If yes, then use it instead
      if (exists(paste0("AP_DOSE_RESPONSE_QUANTILE_", cause))) {
        quant <- get(paste0("AP_DOSE_RESPONSE_QUANTILE_", cause))
      }
      
      # calculate AP and apply to all in age group
      for (x in 1:length(scenarios)) { # loop through scenarios
        
        # load relative risk values
        cause_rr <- fread(file.path(input_dir, "drap", "extdata", paste0(cause_age, ".csv")))
        
        # call AP_dose_response.R function to calculate the relative risk for that disease, age, dose and quantile
        # only apply to people in synthetic population with assigned index i (based on age)
        return_vector <- AP_dose_response(
          cause = cause_age,
          rr_values = cause_rr,
          dose = pm_rr_pp[[pm_indices[x]]][i], quantile = quant
        )
        pm_rr_pp[[paste0("RR_ap_", scenarios[x])]][i] <- return_vector$rr
      }
    } # End loop ages
    
    ## change the names of the columns as per the disease
    for (n in 1:length(scenarios)) {
      col <- which(names(pm_rr_pp) == paste0("RR_ap_", scenarios[n]))
      names(pm_rr_pp)[col] <- paste0("RR_ap_", scenarios[n], "_", diseases$acronym[j])
    }
  } # end disease loop
  
  # clean up columns and return ap relative risks
  scrub <- colnames(pm_rr_pp)[pm_indices]
  pm_rr_pp[ ,(scrub) := NULL]  # in-place
  return(pm_rr_pp)
}

