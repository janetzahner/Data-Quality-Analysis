library(DBI)
library(yaml)
library(dplyr)
library(RPostgreSQL)

generateLevel2Measurement <- function () {
  #detach("package:plyr", unload=TRUE) # otherwise dplyr's group by , summarize etc do not work

  table_name<-"measurement"
  big_data_flag<-TRUE

  # load the configuration file
  config = yaml.load_file(g_config_path)

  #establish connection to database
  #con <- establish_database_connection_OHDSI(config)

  #con <- establish_database_connection(config)

  #writing to the final DQA Report
  fileConn<-file(paste(normalize_directory_path(config$reporting$site_directory),"./reports/Level2_Measurement_Automatic.md",sep=""))
  fileContent <-get_report_header("Level 2",config)

  
  # Connection basics ---------------------------------------------------------
  # To connect to a database first create a src:
  my_db <- src_postgres(dbname=config$db$dbname,
                        host=config$db$dbhost,
                        user =config$db$dbuser,
                        password =config$db$dbpass,
                        options=paste("-c search_path=",config$db$schema,sep=""))

  # Then reference a tbl within that src
  patient_tbl<-tbl(my_db, "person")
  measurement_tbl <- tbl(my_db, "measurement")
  death_tbl <- tbl(my_db, "death")

  concept_tbl <- tbl(my_db, dplyr::sql(paste('SELECT * FROM ',config$db$vocab_schema,'.concept',sep='')))

  patient_dob_tbl <- tbl(my_db, dplyr::sql
                         ('SELECT person_id, to_date(year_of_birth||\'-\'||month_of_birth||\'-\'||day_of_birth,\'YYYY-MM-DD\') as dob FROM person'))


  ### checking consistency between date and date/time fields. 
  ## AA009 check type 
  
  #temp1<- mutate(
  #  select(measurement_tbl, measurement_date, measurement_time)
  #  , measurement_time_new=date(measurement_time),  ### also extract the right format. 
  #  measurement_date_new=date(measurement_date)
  #)
  #temp2<-select(temp1, measurement_date_new,measurement_time_new)
  #temp3<-temp2  %>% head %>% mutate(mismatch = .[[1]]!=.[[2]]) 
  #temp4<-temp3 %>% filter(mismatch==TRUE)
  
  mismatch_meas_date_tbl <- tbl(my_db, dplyr::sql(paste('SELECT * FROM ',config$db$schema,'.',table_name,
                                                        " WHERE cast(measurement_time as date) <> measurement_date",sep=''))
  )
  
  df_incon<-as.data.frame(mismatch_meas_date_tbl)
  if(nrow(df_incon)>0)
  {
    
    message<-paste(nrow(df_incon)," measurements with inconsistency between date and date/time fields")
    fileContent<-c(fileContent,"\n",message)
    ### open the person log file for appending purposes.
    log_file_name<-paste(normalize_directory_path(config$reporting$site_directory),"./issues/measurement_issue.csv",sep="")
    log_entry_content<-(read.csv(log_file_name))
    log_entry_content<-custom_rbind(log_entry_content,
                                    apply_check_type_2('AA-009',"measurement_time", "measurement_date",nrow(df_incon), 
                                                       table_name, g_data_version)
    )
    write.csv(log_entry_content, file = log_file_name
              ,row.names=FALSE)
  }
  
  
  mismatch_meas_order_date_tbl <- tbl(my_db, dplyr::sql(paste('SELECT * FROM ',config$db$schema,'.',table_name,
                                                        " WHERE cast(measurement_order_time as date) <> measurement_order_date",sep=''))
  )
  
  df_incon<-as.data.frame(mismatch_meas_order_date_tbl)
  if(nrow(df_incon)>0)
  {
    
    message<-paste(nrow(df_incon)," measurements with inconsistency between date and date/time fields")
    fileContent<-c(fileContent,"\n",message)
    ### open the person log file for appending purposes.
    log_file_name<-paste(normalize_directory_path(config$reporting$site_directory),"./issues/measurement_issue.csv",sep="")
    log_entry_content<-(read.csv(log_file_name))
    log_entry_content<-custom_rbind(log_entry_content,
                                    apply_check_type_2('AA-009',"measurement_order_time", "measurement_order_date",nrow(df_incon), 
                                                       table_name, g_data_version)
    )
    write.csv(log_entry_content, file = log_file_name
              ,row.names=FALSE)
  }
  
  
  mismatch_meas_result_date_tbl <- tbl(my_db, dplyr::sql(paste('SELECT * FROM ',config$db$schema,'.',table_name,
                                                              " WHERE cast(measurement_result_time as date) <> measurement_result_date",sep=''))
  )
  
  df_incon<-as.data.frame(mismatch_meas_result_date_tbl)
  if(nrow(df_incon)>0)
  {
    
    message<-paste(nrow(df_incon)," measurements with inconsistency between date and date/time fields")
    fileContent<-c(fileContent,"\n",message)
    ### open the person log file for appending purposes.
    log_file_name<-paste(normalize_directory_path(config$reporting$site_directory),"./issues/measurement_issue.csv",sep="")
    log_entry_content<-(read.csv(log_file_name))
    log_entry_content<-custom_rbind(log_entry_content,
                                    apply_check_type_2('AA-009',"measurement_result_time", "measurement_result_date",nrow(df_incon), 
                                                       table_name, g_data_version)
    )
    write.csv(log_entry_content, file = log_file_name
              ,row.names=FALSE)
  }
 
  lab_tbl<-select(filter(measurement_tbl, measurement_type_concept_id==44818702),measurement_id, measurement_concept_id)
  vital_tbl<-select(filter(measurement_tbl, measurement_type_concept_id==2000000033
                           |measurement_type_concept_id==2000000032),measurement_id, measurement_concept_id)
  
  
  
  ### Print top 100 no matching concept source values in measurement table 
  measurement_no_match<- select( filter(measurement_tbl, measurement_concept_id==0)
                                                             , measurement_source_value)
  
  #head(measurement_no_match)
  no_match_measurement_counts <-
    filter(
      arrange(
        summarize(
          group_by(measurement_no_match, measurement_source_value)
          , count=n())
        , desc(count))
      , row_number()>=1 & row_number()<=100) ## printing top 100
  
  
  
  df_no_match_measurement_counts<-as.data.frame(
    no_match_measurement_counts
  )

  
  #print(df_no_match_measurement_counts)
  if(nrow(df_no_match_measurement_counts)>0)
  {
  ## writing to the issue log file
  data_file<-data.frame(measurement_source_value=character(0), counts=character(0))
  
  data_file<-rbind(df_no_match_measurement_counts)
  colnames(data_file)<-c("measurement_source_value","occurrence_counts")
  write.csv(data_file, file = paste(normalize_directory_path( g_config$reporting$site_directory),
                                    "./data/no_match_measurements.csv",sep="")
            ,row.names=FALSE)
  }
  
  ##### Printing top 100 vital measurements ##### 
  #print("here")
  
  vital_tbl_enhanced<- distinct(select(inner_join(concept_tbl,vital_tbl, by = c("concept_id"="measurement_concept_id"))
                                           ,measurement_id, measurement_concept_id, concept_name))
  #head(vital_tbl_enhanced)
  
  vital_counts <-
    filter(
      arrange(
        summarize(
          group_by(vital_tbl_enhanced, measurement_concept_id)
          , occurrence_counts=n())
        , desc(occurrence_counts))
      , row_number()>=1 & row_number()<=100) ## printing top 100
  
  #head(vital_counts)
  
  df_vital_counts_all<-as.data.frame(
    arrange(distinct(
      select(inner_join(vital_counts, vital_tbl_enhanced, 
                        by = c("measurement_concept_id"="measurement_concept_id"))
             ,measurement_concept_id, concept_name, occurrence_counts)
    ), desc(occurrence_counts)
    ))
  
  #print(df_vital_counts_all)
  #print(df_lab_counts)
  
  ## writing to the issue log file
  data_file<-data.frame(concept_id=character(0), concept_name=character(0), occurrence_counts=character(0))
  
  data_file<-rbind(df_vital_counts_all)
  colnames(data_file)<-c("concept_id", "concept_name","occurrence_counts")
  write.csv(data_file, file = paste(normalize_directory_path( g_config$reporting$site_directory),
                                    "./data/vital_measurements.csv",sep="")
            ,row.names=FALSE)
  

  ##### Printing top 100 lab measurements ##### 
  #print("here")
  
  lab_tbl_enhanced<- distinct(select(inner_join(concept_tbl,lab_tbl, by = c("concept_id"="measurement_concept_id"))
                                       ,measurement_id, measurement_concept_id, concept_name))
  #print(head(lab_tbl_enhanced))
  
  lab_counts <-
    filter(
      arrange(
        summarize(
          group_by(lab_tbl_enhanced, measurement_concept_id)
          , occurrence_counts=n())
        , desc(occurrence_counts))
      , row_number()>=1 & row_number()<=100) ## printing top 100
  
  #print(head(lab_counts))
  
  df_lab_counts_all<-as.data.frame(
    arrange(distinct(
      select(inner_join(lab_counts, lab_tbl_enhanced, 
                        by = c("measurement_concept_id"="measurement_concept_id"))
             ,measurement_concept_id, concept_name, occurrence_counts)
    ), desc(occurrence_counts)
    ))
  
 # print(df_vital_counts_all)
  #print(df_lab_counts)
  
  ## writing to the issue log file
  data_file<-data.frame(concept_id=character(0), concept_name=character(0), occurrence_counts=character(0))
  
  data_file<-rbind(df_lab_counts_all)
  colnames(data_file)<-c("concept_id", "concept_name","occurrence_counts")
  write.csv(data_file, file = paste(normalize_directory_path( g_config$reporting$site_directory),
                                    "./data/lab_measurements.csv",sep="")
            ,row.names=FALSE)
  
  
  fileContent<-c(fileContent,"##Implausible Events")
  table_name<-"measurement"
  df_meas_before_dob<-as.data.frame(
    select(
      filter(inner_join(measurement_tbl,patient_dob_tbl, by =c("person_id"="person_id")),measurement_date<dob)
      ,person_id, dob, measurement_date
    ))
  if(nrow(df_meas_before_dob)>0)
  {
    df_meas_prenatal<-subset(df_meas_before_dob,elapsed_months(dob,measurement_date)<=9)
    message<-paste(nrow(df_meas_before_dob)
                 ,"measurements before birth ( including",nrow(df_meas_prenatal),"prenatal measurements)")
    fileContent<-c(fileContent,"\n",message)
    ### open the person log file for appending purposes.
    log_file_name<-paste(normalize_directory_path(config$reporting$site_directory),"./issues/measurement_issue.csv",sep="")
    log_entry_content<-(read.csv(log_file_name))
    log_entry_content<-custom_rbind(log_entry_content,
                                    apply_check_type_2_diff_tables('CA-003',"Person","time_of_birth","measurement", "measurement_date", message)
    )
    write.csv(log_entry_content, file = log_file_name
              ,row.names=FALSE)
  }


  table_name<-"measurement"
  df_meas_after_death<-as.data.frame(
    select(
      filter(inner_join(measurement_tbl,death_tbl, by =c("person_id"="person_id")),measurement_date>death_date)
      ,person_id
    ))

  if(nrow(df_meas_after_death)>0)
  {
    message<-paste(nrow(df_meas_after_death),"measurements after death")
    fileContent<-c(fileContent,"\n",message)
    ### open the person log file for appending purposes.
    log_file_name<-paste(normalize_directory_path(config$reporting$site_directory),"./issues/measurement_issue.csv",sep="")
    log_entry_content<-(read.csv(log_file_name))
    log_entry_content<-custom_rbind(log_entry_content,
                                    apply_check_type_2_diff_tables('CA-004',"Death","death_date","measurement", "measurement_date", message)
    )
    write.csv(log_entry_content, file = log_file_name
              ,row.names=FALSE)
  }


  #write all contents to the report file and close it.
  writeLines(fileContent, fileConn)
  close(fileConn)

  #close the connection
  #close_database_connection_OHDSI(con,config)
}
