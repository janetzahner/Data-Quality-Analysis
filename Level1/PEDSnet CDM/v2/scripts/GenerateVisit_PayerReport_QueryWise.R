library(DBI)
library(yaml)

generateVisitPayerReport <- function(g_data_version) {
  flog.info(Sys.time())

  big_data_flag<-TRUE # for query wise analysis

  #establish connection to database
  con <- establish_database_connection_OHDSI( g_config)

  # read a table into an R dataframe
  table_name<-"visit_payer"
  #df_table <- retrieve_dataframe_OHDSI(con, g_config,table_name)

  #writing to the final DQA Report
  fileConn<-file(paste(normalize_directory_path( g_config$reporting$site_directory),"./reports/",table_name,"_Report_Automatic.md",sep=""))
  fileContent <-get_report_header(table_name, g_config)

  ## writing to the issue log file
  logFileData<-data.frame(g_data_version=character(0), table=character(0),field=character(0), issue_code=character(0), issue_description=character(0)
                          , finding=character(0), prevalence=character(0))



  #PRIMARY FIELD
  field_name<-"visit_payer_id"
  df_total_procedure_count<-retrieve_dataframe_count(con, g_config,table_name,field_name)
  current_total_count<-as.numeric(df_total_procedure_count[1][1])
  fileContent<-c(fileContent,paste("The total number of",field_name,"is:", formatC(current_total_count, format="d", big.mark=','),"\n"))
  prev_total_count<-get_previous_cycle_total_count( g_config$reporting$site, table_name)
  percentage_diff<-get_percentage_diff(prev_total_count, current_total_count)
  fileContent<-c(fileContent, get_percentage_diff_message(percentage_diff))
  ###########DQA CHECKPOINT############## difference from previous cycle
  logFileData<-custom_rbind(logFileData,apply_check_type_0("CA-005", percentage_diff, table_name, g_data_version));

  df_total_visit_count<-retrieve_dataframe_count(con, g_config,table_name,"distinct visit_occurrence_id")
  fileContent<-c(fileContent,paste("The visit_payer to visit ratio is ",round(df_total_procedure_count[1][1]/df_total_visit_count[1][1],2),"\n"))

  field_name<-"visit_occurrence_id"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"\n"))

    df_table<-retrieve_dataframe_group(con, g_config,table_name,field_name)
    message<-describeForeignKeyIdentifiers(df_table, table_name,field_name,big_data_flag)
    fileContent<-c(fileContent,paste_image_name(table_name,field_name),paste_image_name_sorted(table_name,field_name),message);
  


  field_name = "plan_type"
  df_table<-retrieve_dataframe_group(con, g_config,table_name,field_name)
  order_bins <-c("HMO","PPO","POS","Fee for service","Other/Unknown",NA)
  label_bins<-c("HMO","PPO","POS","Fee for service","Other/Unknown","NULL")
  color_bins <-c("HMO"="lightcoral","PPO"="steelblue1","POS"="red","Fee for service"="grey64","Other/Unknown"="grey64")
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message)
  ###########DQA CHECKPOINT -- missing information##############
  missing_percent<-extract_numeric_value(message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent, table_name, g_data_version));
  unexpected_message<- reportUnexpected(df_table,table_name,field_name,order_bins,big_data_flag)
  ############# DQA WARNING ######################
  logFileData<-custom_rbind(logFileData,apply_check_type_1("AA-001", field_name, unexpected_message, table_name, g_data_version));
  # flog.info(unexpected_message)
  fileContent<-c(fileContent,unexpected_message)
  describeNominalField(df_table,table_name,field_name, label_bins, order_bins,color_bins, big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));

  field_name = "plan_class"
  df_table<-retrieve_dataframe_group(con, g_config,table_name,field_name)
  order_bins <-c("Private/Commercial","Medicaid/sCHIP","Medicare","Other public","Self-pay","Other/Unknown",NA)
  label_bins<-c("Private/Commercial","Medicaid/sCHIP","Medicare","Other public","Self-pay","Other/Unknown","NULL")
  color_bins <-c("Private/Commercial"="lightcoral","Medicaid/sCHIP"="steelblue1","Medicare"="red","Other public"="grey64","Self-pay"="grey64","Other/Unknown"="grey64")
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  unexpected_message<- reportUnexpected(df_table,table_name,field_name,order_bins,big_data_flag)
  ############# DQA WARNING ######################
  logFileData<-custom_rbind(logFileData,apply_check_type_1("AA-001", field_name, unexpected_message, table_name, g_data_version));
  # flog.info(unexpected_message)
  fileContent<-c(fileContent,unexpected_message)
  describeNominalField(df_table,table_name,field_name, label_bins, order_bins,color_bins, big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));

   flog.info(Sys.time())

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