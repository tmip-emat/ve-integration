# this module contains helper funcs for settings/configuration management


#' Load settings
#'
#' Helper function to load ithim settings
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item loads settings
#'    }
#'
#' @param module_dir local ithim module directory
#'
#' @return data.table containing ithim settings
#'
#' @export


# loads csv file containing ithim parameters
loadSettings <- function(input_dir){
  
  # read settings
  settings_cols = c("name", "value")  # dont need 'description' col
  settings <- fread(file.path(input_dir, "settings.csv"), select=settings_cols)
  
  # and config settings
  config <- fread(file.path(input_dir, "config.csv"), select=settings_cols)
  
  # move a couple items up a level
  base_model <- config[name=="base_model"]$value
  reference_model <- config[name=="reference_model"]$value
  base_year <- as.numeric(config[name=="base_year"]$value)
  type <- config[name=='type']$value
  
  # now scrub from config
  scrub <- c("base_model", "reference_model", "base_year")
  config <- config[!name %in% scrub]

  # let's not deal with .cnf files for now
  # just parse scenarios from results
  model_name <- config[name=="model_name"]$value
  # scenarios <- list.dirs(
  #   file.path("models", model_name, "scenarios"),
  #   recursive = F,
  #   full.names = F)
  scenarios <- list.dirs(
    file.path("..", model_name, "scenarios"),
    recursive = F,
    full.names = F)
  
  if(type=='single') {
    base_model <- model_name
    reference_model <- model_name
    scenarios <- model_name
  }
  
  # results_dir <- list.dirs(
  #   file.path("models", model_name, "results", "output"),
  #   recursive = F)
  results_dir <- list.dirs(
    file.path("..", model_name, "results", "output"),
    recursive = F)
  
  # finally, identify future years from results files
  # this assumes that each future year has a reference model
  future_years <- basename(
    Sys.glob(
      file.path(results_dir, paste0("Household_", reference_model, "*"))
    )
  )
  
  # parse year(s)
  future_years <- as.numeric(gsub("\\D", "", future_years))
  future_years2 <- as.character(future_years)
  
  if(nchar(future_years2[1] > 4)) {
    
    future_years2 <- as.numeric(substr(future_years2, nchar(future_years2)-3, nchar(future_years2)))
    future_years <- as.numeric(future_years2)
    future_years <- future_years[future_years > base_year]
    
  }
  
  return(list(settings=settings,
              config=config,
              base_model=base_model,
              base_year=base_year,
              reference_model=reference_model,
              future_years=future_years,
              scenarios=scenarios,
              results_dir=results_dir))
}
  

#' Parse year
#'
#' Helper function to extract list of years from VE output csv directory and 
#' scrub years before the reference year (ie, backcasting years)
#'
#' This function performs the following steps:
#'
#' \itemize{
#'  \item identifies all household files in a VE output csv directory
#'  
#'  \item parses year from each file in the list
#'  
#'  \item removes years that are before the reference year
#'    }
#'
#' @param base_model local VE model directory
#' @param ref_year reference base) year for ithim model
#'
#' @return list of years for which a VE model exists (excluding those before 
#' the reference year)
#'
#' @export


parseYears <- function(base_model, ref_year){
  
  # parse years from output dir
  files <- Sys.glob(file.path('../', base_model, "results", "output", "*", "Household_*"))
  getYear <- function(item){
    as.integer(tail(strsplit(basename(file_path_sans_ext(item)), "_")[[1]], 1))
  }
  years <- lapply(files, getYear)
  
  # if there is a backcast year (ie, a year before the reference year) scrub it
  years <- years[years >= ref_year]
  return(years)
}