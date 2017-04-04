library(DBI)
library(yaml)

generateDeathReport <- function(g_data_version) {
  #establish connection to database
  con <- establish_database_connection_OHDSI( g_config)

  # read a table into an R dataframe
  table_name<-"death"
  df_table<- retrieve_dataframe_OHDSI(con, g_config,table_name)
  big_data_flag<-FALSE

  #writing to the final DQA Report
  fileConn<-file(paste(normalize_directory_path( g_config$reporting$site_directory),"./reports/",table_name,"_Report_Automatic.md",sep=""))
  fileContent <-get_report_header(table_name, g_config)

  ## writing to the issue log file
  logFileData<-data.frame(g_data_version=character(0), table=character(0),field=character(0), issue_code=character(0), issue_description=character(0)
                          , finding=character(0), prevalence=character(0))


  #PRIMARY FIELD(s)
  field_name<-"death_cause_id"
  current_total_count<-as.numeric(describeIdentifier(df_table,field_name))
  fileContent<-c(fileContent,paste("The total number of unique values for ",field_name,"is: ",current_total_count ,"\n"))
  prev_total_count<-get_previous_cycle_total_count( g_config$reporting$site, table_name)
  percentage_diff<-get_percentage_diff(prev_total_count, current_total_count)
  fileContent<-c(fileContent, get_percentage_diff_message(percentage_diff))
  ###########DQA CHECKPOINT############## difference from previous cycle
  logFileData<-custom_rbind(logFileData,apply_check_type_0("CA-005", percentage_diff, table_name, g_data_version));

  field_name<-"person_id" #
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"\n"))
  message<-describeForeignKeyIdentifiers(df_table, "death_cause",field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name("death_cause",field_name),paste_image_name_sorted("death_cause",field_name),message);


  # ORDINAL Fields

  field_name="death_date"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-describeDateField(df_table, table_name,field_name,big_data_flag)
  if(grepl("future",message[3]))
  {
    logFileData<-custom_rbind(logFileData,apply_check_type_1("CA-001", field_name, "deaths cannot occur in the future", table_name, g_data_version));
  }

  fileContent<-c(fileContent,paste_image_name(table_name,field_name),message);

  if(extract_start_range(message)<2009)
  {
   # logFileData<-custom_rbind(logFileData,apply_check_type_1("G2-010", field_name, "deaths cannot occur before 2009", table_name, g_data_version));
    fileContent<-c(fileContent,"deaths cannot occur before 2009");
  }

  fileContent<-c(fileContent,paste_image_name(table_name,field_name),message);


  field_name<-"death_time"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-describeTimeField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message,paste_image_name(table_name,paste(field_name,"_time",sep="")));


  #death type concept id
  df_death_type <-retrieve_dataframe_clause(con, g_config, g_config$db$vocab_schema,"concept","concept_id,concept_name"
                                      ,"(concept_class_id ='Death Type')
                                      or (vocabulary_id = 'PCORNet' and (concept_class_id = 'Undefined' or concept_class_id = 'UnDefined'))")
  order_bins <-c(df_death_type$concept_id,0,NA)

  field_name="death_type_concept_id"

  unexpected_message<- reportUnexpected(df_table,table_name,field_name,order_bins,big_data_flag)
  no_matching_message<-reportNoMatchingCount(df_table,table_name,field_name,big_data_flag)
  ###########DQA CHECKPOINT##############
  logFileData<-custom_rbind(logFileData,apply_check_type_1("AA-002", field_name, unexpected_message, table_name, g_data_version));
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  describeOrdinalField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));
  fileContent<-c(fileContent,no_matching_message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-002", field_name,extract_numeric_value(no_matching_message), table_name, g_data_version));


  #cause of death source valueapply_check_type_1("BA-002"
  field_name="cause_source_value"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message)
  ###########DQA CHECKPOINT -- missing information##############
  missing_percent_source_value<-extract_numeric_value(message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent_source_value, table_name, g_data_version));
  describeOrdinalField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));

  field_name="cause_source_concept_id"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message)
  ###########DQA CHECKPOINT -- missing information##############
  missing_percent<-extract_numeric_value(message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent, table_name, g_data_version));
  no_matching_message<-reportNoMatchingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,no_matching_message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-002", field_name,extract_numeric_value(no_matching_message), table_name, g_data_version));
  describeOrdinalField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));


  #cause of death concept id
  field_name="cause_concept_id"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  no_matching_message<-reportNoMatchingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message)
  ###########DQA CHECKPOINT -- missing information##############
  missing_percent<-extract_numeric_value(message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent, table_name, g_data_version));
  fileContent<-c(fileContent,no_matching_message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-002", field_name,extract_numeric_value(no_matching_message), table_name, g_data_version));
  fileContent<-c(fileContent,paste("\n The standard/prescribed vocabulary is SNOMED CT\n"))
  used_vocabulary<-get_vocabulary_name_by_concept_ids(con, g_config, table_name, field_name, "CONDITION")
  fileContent<-c(fileContent,paste("\n The vocabulary used by the site is",used_vocabulary,"\n"))
  if(!is.na(used_vocabulary) && used_vocabulary!='SNOMED|'
     && used_vocabulary!='NA||')
  {
  ###########DQA CHECKPOINT -- vocabulary incorrect ##############
  logFileData<-custom_rbind(logFileData,apply_check_type_1("AA-005", field_name, "invalid vocabulary used, please use SNOMEDCT", table_name, g_data_version));
  }

  null_message<-reportNullFlavors(df_table,table_name,field_name,44814653,44814649,44814650,big_data_flag)
  ###########DQA CHECKPOINT############## source value Nulls and NI concepts should match
  logFileData<-custom_rbind(logFileData,apply_check_type_2("CA-014", field_name,"cause_source_value",
                                                           (missing_percent_source_value -
                                                            extract_ni_missing_percent( null_message)), table_name, g_data_version))

  describeOrdinalField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));


  #death impute concept id
  df_impute_type <-retrieve_dataframe_clause(con, g_config, g_config$db$vocab_schema,"concept","concept_id,concept_name"
                                            ,"(concept_class_id ='Death Imput Type')
                                            or (vocabulary_id = 'PCORNet' and (concept_class_id = 'Undefined' or concept_class_id = 'UnDefined'))
                                            and invalid_reason is null")
  order_bins <-c(df_impute_type$concept_id,0,NA)

  field_name="death_impute_concept_id"

  # flog.info( null_message)
  unexpected_message<- reportUnexpected(df_table,table_name,field_name,order_bins,big_data_flag)
  ###########DQA CHECKPOINT##############
  logFileData<-custom_rbind(logFileData,apply_check_type_1("AA-002", field_name, unexpected_message, table_name, g_data_version));
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  no_matching_message<-reportNoMatchingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,no_matching_message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-002", field_name,extract_numeric_value(no_matching_message), table_name, g_data_version));
  describeOrdinalField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));

  #write all contents to the report file and close it.
  writeLines(fileContent, fileConn)
  close(fileConn)


  colnames(logFileData)<-c("g_data_version", "table","field", "issue_code", "issue_description","finding", "prevalence")
  logFileData<-subset(logFileData,!is.na(issue_code))
  write.csv(logFileData, file = paste(normalize_directory_path( g_config$reporting$site_directory),"./issues/",table_name,"_issue.csv",sep="")
            ,row.names=FALSE)


  #close the connection
  close_database_connection_OHDSI(con, g_config)
}