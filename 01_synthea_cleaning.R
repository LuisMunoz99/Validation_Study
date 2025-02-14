###################################################################################
## This script takes the US-representative Synthea cohort .csvs produced by 
## 00a_run_synthea.R and 00b_agedist_synthea.R, cleans them, and merges them into 
## a single file.
## 
## Limited cleaning includes dropping unnecessary columns, some recoding, including
## datetime data. It also filters for ONLY procedures and observations of interest
## for this analysis in order to keep the resultant data files a manageable size 
## for all research team members. 
##
###################################################################################


# Set up 
library(dplyr)
library(data.table)
library(tidyr)
library(table1)
library(flextable)
library(lubridate)


mydir <- "C:/Users/Steph/Dropbox/projects/Synthea_privacy_justice" 

datetime <- "2022_02_09_12_14_16" 

# Data -----------------------------------------------------------------------------

patients_orig <- fread(paste0(mydir, "/data/synthea_dist_", datetime, "/patients.csv"))
conditions_orig <- fread(paste0(mydir, "/data/synthea_dist_", datetime, "/conditions.csv"))
procedures_orig <- fread(paste0(mydir, "/data/synthea_dist_", datetime, "/procedures.csv"))
observations_orig <- fread(paste0(mydir, "/data/synthea_dist_", datetime, "/observations.csv"))
patients <- patients_orig
conditions <- conditions_orig
procedures <- procedures_orig
observations <- observations_orig



# Data prep --------------------------------------------------------------------------. 

# Calculate patient age (as of November 12th 2021, when this dataset was created)
patients$BIRTHDATE <- ymd(patients$BIRTHDATE)
patients$age <- floor(as.numeric((ymd("2021-11-12") - patients$BIRTHDATE)/365.25))
patients$DEATHDATE <- ymd(patients$DEATHDATE)


# patients.csv - Eliminating extra variables, renaming columns and filtering  
patients <- patients %>% 
  subset(select = c("PATIENT","RACE", "ETHNICITY", "GENDER", "age", "BIRTHDATE", "DEATHDATE")) %>% 
  rename(patient = PATIENT,sex = GENDER,race = RACE, ethnicity = ETHNICITY, birthdate = BIRTHDATE,
         deathdate = DEATHDATE)


# conditions.csv - eliminating columns, keeping selected conditions of interest, reshaping 
conditions <- conditions %>%
  subset(select = c("PATIENT","START","DESCRIPTION")) %>% 
  rename(start_condition = 
           START,condition = DESCRIPTION,patient = PATIENT) 

    # reshape wide to get each row to be a unique patient (rather than encounter)
    keep_conditions <- c("Myocardial Infarction", "Cardiac Arrest", "Diabetes", 
                         "Chronic obstructive bronchitis (disorder)", "Pulmonary emphysema (disorder)")
    conditions <- conditions %>%
      filter(condition %in% keep_conditions) %>%
      mutate(condition = recode(condition, "Myocardial Infarction" = "MI", "Cardiac Arrest" = "cardiac_arrest", 
                                "Diabetes" = "diabetes", 
                                "Chronic obstructive bronchitis (disorder)" = "COPD_bronch", 
                                "Pulmonary emphysema (disorder)" = "COPD_emph")) %>%
      pivot_wider(id_cols = patient, names_from = condition, values_from = start_condition) # In this dataset, patients only ever have 1 MI
    
    ## combine MI and cardiac arrest 
    # conditions$MI <- pmax(conditions$MI, conditions$cardiac_arrest, na.rm = TRUE)
    # conditions$cardiac_arrest <- NULL

    
# procedures.csv - eliminating columns, keeping/recoding selected procedures of interest, organizing procedure datetime data
procedures <- procedures %>%
  subset(select = c("PATIENT","DESCRIPTION", "START")) %>%
  rename(proc = DESCRIPTION,
         patient = PATIENT, 
         date = START) 
procedures <- procedures[procedures$procedure == "Percutaneous coronary intervention" |
                    procedures$procedure == "Coronary artery bypass grafting" |
                    procedures$procedure == "Pulmonary rehabilitation (regime/therapy)",]
procedures$procedure <- recode(procedures$procedure, "Percutaneous coronary intervention" = "PCI", 
                               "Coronary artery bypass grafting" = "CABG",
                               "Pulmonary rehabilitation (regime/therapy)" = "pulm_rehab")


# observations.csv - eliminating columns, keeping/recoding selected observations of interest, keeping datetime data
observations <- observations %>%
  subset(select = c("PATIENT","DESCRIPTION", "DATE")) %>%
  rename(proc = DESCRIPTION,
         patient = PATIENT, 
         date = DATE) 
observations <- observations[observations$proc == "Hemoglobin A1c/Hemoglobin.total in Blood" | 
                        observations$proc == "Total Cholesterol",]
observations$proc <- recode(observations$proc, "Hemoglobin A1c/Hemoglobin.total in Blood" = "HbA1c", 
                            "Total Cholesterol" = "Total_chol")
                               


# merge ----------------------------------------------------------------------------- 


# Merge all
df <- conditions %>% full_join(patients, by="patient") # full join so we keep all patients at this step, even those who did not have MI
obs_cond <- rbind(procedures, observations)
df <- left_join(x = df, y = obs_cond, by = "patient", na_matches = "never")





# Write merged data ----------------------------------------------------------------

fwrite(df, paste0(mydir, "/data/Synthea_merged_", datetime, ".csv"))



