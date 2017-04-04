library(DBI)
library(yaml)

generateLocationReport <- function(g_data_version) {
  #establish connection to database
  con <- establish_database_connection_OHDSI( g_config)


  # read a table into an R dataframe
  table_name<-"location"
  df_table <- retrieve_dataframe_OHDSI(con, g_config,table_name)

  ## writing to the issue log file
  logFileData<-data.frame(g_data_version=character(0), table=character(0),field=character(0), issue_code=character(0), issue_description=character(0)
                          , finding=character(0), prevalence=character(0))

  big_data_flag<-FALSE

  #writing to the final DQA Report
  fileConn<-file(paste(normalize_directory_path( g_config$reporting$site_directory),"./reports/",table_name,"_Report_Automatic.md",sep=""))
  fileContent <-get_report_header(table_name, g_config)

  #PRIMARY FIELD(s)
  field_name<-"location_id"
  current_total_count<-as.numeric(describeIdentifier(df_table,field_name))
  fileContent<-c(fileContent,paste("The total number of unique values for ",field_name,"is: ",current_total_count ,"\n"))
  prev_total_count<-get_previous_cycle_total_count( g_config$reporting$site, table_name)
  percentage_diff<-get_percentage_diff(prev_total_count, current_total_count)
  fileContent<-c(fileContent, get_percentage_diff_message(percentage_diff))
  ###########DQA CHECKPOINT############## difference from previous cycle
  logFileData<-custom_rbind(logFileData,apply_check_type_0("CA-005", percentage_diff, table_name, g_data_version));


  field_name<-"location_source_value"
  fileContent<-c(fileContent,paste("The total number of",field_name,"is: ", describeIdentifier(df_table, field_name),"\n"))
  ###########DQA CHECKPOINT##############  total id different from source value
  logFileData<-custom_rbind(logFileData,apply_check_type_2("AA-003","location_id", field_name,
                                                           (current_total_count- describeIdentifier(df_table, field_name)), table_name, g_data_version));
  missing_percent_message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  missing_percent<- extract_numeric_value(missing_percent_message)
  fileContent<-c(fileContent,missing_percent_message)
  ###########DQA CHECKPOINT##############
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent, table_name, g_data_version));

  test<-1


  field_name="state"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message)
  ###########DQA CHECKPOINT -- missing information##############
  missing_percent<-extract_numeric_value(message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent, table_name, g_data_version));
  describeOrdinalField(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name));
  ###########DQA CHECKPOINT##############
  order_bins <- c('AL', 'AK', 'AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA',
  'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR',
  'PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
  'AS','DC','FM','GU','MH','MP','PW','PR','VI','AE','AA','AP','ALABAMA', 'ALASKA','ARIZONA','ARKANSAS',
  'CALIFORNIA','COLORADO','CONNECTICUT','DELAWARE','FLORIDA','GEORGIA','HAWAII','IDAHO','ILLINOIS','INDIANA','IOWA','KANSAS','KENTUCKY','LOUISIANA',
  'MAINE','MARYLAND','MASSACHUSETTS','MICHIGAN','MINNESOTA','MISSISSIPPI','MISSOURI','MONTANA','NEBRASKA','NEVADA','NEW HAMPSHIRE','NEW JERSEY','NEW MEXICO','NEW YORK',
  'NORTH CAROLINA','NORTH DAKOTA','OHIO','OKLAHOMA','OREGON','PENNSYLVANIA','RHODE ISLAND','SOUTH CAROLINA','SOUTH DAKOTA','TENNESSEE',
  'TEXAS','UTAH','VERMONT','VIRGINIA','WASHINGTON','WEST VIRGINIA','WISCONSIN', 'WYOMING','Alabama',
  'Alaska','Arizona','Arkansas','California','Colorado','Connecticut','Delaware','Florida','Georgia','Hawaii','Idaho','Illinois',
  'Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland','Massachusetts','Michigan','Minnesota','Mississippi','Missouri',
  'Montana','Nebraska','Nevada','New Hampshire','New Jersey','New Mexico','New York','North Carolina','North Dakota',
  'Ohio','Oklahoma','Oregon','Pennsylvania','Rhode Island','South Carolina','South Dakota','Tennessee','Texas','Utah',
  'Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming','Commonwealth/Territory:','American Samoa','District of Columbia',
  'Federated States of Micronesia','Guam','Marshall Islands','Northern Mariana Islands','Palau','Puerto Rico','Virgin Islands','Armed Forces Africa',
  'Armed Forces Americas','Armed Forces Canada','Armed Forces of Europe','Armed Forces Middle East','Armed Forces Pacific', NA)
  unexpected_message<- reportUnexpected(df_table,table_name,field_name,order_bins,big_data_flag)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("AA-001", field_name, unexpected_message, table_name, g_data_version));
  fileContent<-c(fileContent,unexpected_message)


  field_name="zip"
  fileContent <-c(fileContent,paste("## Barplot for",field_name,"","\n"))
  message<-reportMissingCount(df_table,table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,message)
  ###########DQA CHECKPOINT -- missing information##############
  missing_percent<-extract_numeric_value(message)
  logFileData<-custom_rbind(logFileData,apply_check_type_1("BA-001", field_name, missing_percent, table_name, g_data_version));
  message<-describeOrdinalField_large(df_table, table_name,field_name,big_data_flag)
  fileContent<-c(fileContent,paste_image_name(table_name,field_name),message);


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