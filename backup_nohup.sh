#!/bin/bash
#-----------------------------------------------#Synopsis
# name: backup_nohup.sh                         #Synopsis
#-----------------------------------------------#Synopsis
# desc: worker program to take export. Called   #Synopsis
#       from backup.sh                          #Synopsis
# usage: None. Called from backup.sh, an        #Synopsis
#       interactive script.                     #Synopsis
#-----------------------------------------------#
# Change Control                                #
#-----------------------------------------------#
# Date       Author    Desc.                    #
# 2017.12.08 Askew     Make production ready.   
# 2017.12.12 Askew     Add schema option        
# 2017.12.12 Askew     Add option to split dump 
# 2017.12.13 Askew     Unify backup.sh with     
#                      CI export solution.      
# 2017.12.14 Askew     Prod. readiness          
# 2017.12.14 Askew     Allow exp overwrite.     
# 2017.12.20 Askew     Add common_properties    
# 2017.12.22 Askew     Add common properties    
# 2018.01.11 Askew     Catch missing pos. parms.
#################################################
# Source a bunch of environment specific settings.
 [[ -z ${SCRIPT_DIR} ]] && SCRIPT_DIR="./"
 case "${ORACLE_SID}" in
    [a-z,A-Z]*)  [[ -s ${SCRIPT_DIR}/common_properties.${ORACLE_SID} ]]  && . ${SCRIPT_DIR}/common_properties."${ORACLE_SID}"
        ;;
    *) ;;
 esac

 for i in common.sh common_validation.sh 
   do                                            
        if [[ -x ${SCRIPT_DIR}/${i} ]];then       
          {                                      
               . ${SCRIPT_DIR}/${i} "N"           
          }                                      
        else                                     
          {                                      
               tput setaf 4                      
               echo "##########################################" 
               echo "# ${mySCRIPT}                             " 
               echo "# Error: unable to execute: ${i}          " 
               echo "# Process aborting with no action taken.  " 
               echo "# Returning with return code of:          " 
               builtin echo -1                   
               exit -1                           
          }                                      
        fi                                       
   done                                          

mySCRIPT=backup_nohup.sh			  
operation="BACKUP"
tableInfoFileExt="tabs"
hostInfoFileExt="hostInfo"
in_SCHEMAS=""                                    
num_test='^[0-9]+$'                              
my_trailing_parameters=""                        
#############################################################
# Script for backing up database using Oracle DataPump (expdb)
#############################################################

dmp_file="$2"
LOG="$1"
###-----------------------------------------------
### Validate options sent from backup.sh          
### If options not sent, then unset/initialize them 
###-----------------------------------------------
 if [ $# -gt  2 ]; then                           
   {                                              
       [[ ( -z $3 ) || ( "${3}" == "*" )  ]] && unset in_SCHEMAS || export in_SCHEMAS=$3  
       [[ -z $4 ]] && export in_dmp_no=8  || export in_dmp_no=$4 
       [[ ( -z $5 ) || ( "${5}" == "N")  ]] && unset in_tar || export in_tar=$5 
       [[ ( -z $6 ) || ( "${6}" == "*" ) ]] && unset in_copy || export in_copy=$6 
       [[ ( -z $7 ) || ( "${7}" == "" ) ]] &&  unset my_trailing_parameters || export my_trailing_parameters="$7"  
   }                                              
 fi                                               
 [[ ( "${in_tar}" ) || ( "${in_copy}" )  ]] && export in_dmp_no=1             
 echo "Backup process received schema overrides of: ${in_SCHEMAS}" >> ${LOG} 

echo "Backup process $$ started at `date` in Directory ${DB_DUMP_DIR}" >> ${IN_PROGRESS} 
#-------------------------------------------------
function saveCurrentDBTableInfo() {
#-------------------------------------------------
  sysUser=$1
  sysPass=$2
  resultFile="$3"

  sqlFile=`find $SCRIPT_DIR -name 'SelectSchemaCount.sql'|egrep -vi "archive|pristine"|head -1`
  resultTmpFile="/tmp/$(basename "$resultFile").tmp"

  log "Counting tables for %DEVINT% with userid $SYSTEM_USER ... into $resultFile using temp file $resultTmpFile"

 echo "${in_SCHEMAS}"|sed  's/ //g' > /tmp/in_schema.deleteme
 in_SCHEMAS=`cat /tmp/in_schema.deleteme`  
 [[ -e /tmp/in_schema.deleteme ]] && rm -f /tmp/in_schema.deleteme
 # xxx
 if [[ ( -z "$sqlFile" ) || ( -z "${sysUser}" ) || ( -z "${sysPass}" ) || ( -z "${resultTmpFile}"  ) ]];then 
   {                                              
     echo "\$sqlFile=$sqlFile"                    
     echo "\${sysUser}=${sysUser}"                
     echo "\${sysPass}=${sysPass}"                
     echo "\${resultTmpFile}=${resultTmpFile}"    
     in_object="backup_nohup.sh"                  
     in_rc=25                                     
     in_msg="Call to $SCRIPT_DIR/exportDataFromSQLOnSchema.sh did not contain the needed number of parameters". 
     common_sdt_report ${in_object} ${in_rc} "${in_msg}" 
   }                                              
 fi                                               
 $SCRIPT_DIR/exportDataFromSQLOnSchema.sh "$sqlFile" $sysUser $sysPass "$resultTmpFile" 0 >/dev/null 

  if [[ ( -z ${in_SCHEMAS} ) || ( "${in_SCHEMAS}" == "" ) ]]; then 
     {                                            
          cat "$resultTmpFile" | grep '[[:blank:]]' > "$resultFile" 
     }                                            
  else                                            
     {                                            
          echo "${in_SCHEMAS}"|sed 's/\,/| /g'
          cat "$resultTmpFile" | grep '[[:blank:]]'|egrep -i "`echo "${in_SCHEMAS}"|sed 's/\,/|/g'`" |sort -u > "$resultFile" 
     }                                            
  fi                                              
 rm -f "$resultTmpFile"

  # TODO Return this so that the caller doesn't need to know what variable you used for the schemas
  schemas=""
  addComma=0
 if [[ ( -z ${in_SCHEMAS} ) || ( "${in_SCHEMAS}" == "" ) ]]; then 
   {                                              
  	for schema in $(cat "$resultFile" | cut -f 1 -d , ) 
  	do                                        
  	   if [ $addComma -eq 1 ]; then           
              schemas="$schemas,$schema"          
           else                                   
               schemas=$schema                    
               addComma=1                         
           fi                                     
        done                                      
   }                                              
 else                                             
   {                                              
       schemas=${in_SCHEMAS}                      
   }                                              
 fi                                               
  if [[ ( -z ${schemas} ) && ( -z ${in_SCHEMAS} ) ]]; then
   {
       mySQL=`find ${SCRIPT_DIR}  -name 'SelectSchemaCount.sql' -print|head -1`
       in_rc=11
       in_object="backup_nohup.sh"
       in_msg="exportDataFromSQLOnSchema.sh returned NO SCHEMAS Aborting Process. Try looking at ${mySQL}"
       common_sdt_report ${in_object} ${in_rc} "${in_msg}"

   }
  fi
       
}

#-------------------------------------------------
function saveCurrentHostInfo() {
#-------------------------------------------------
    hostInfoFile=$1
	
	echo "$(hostname),${dmp_file},`date`,`whoami`" > $hostInfoFile
}

#############################################################
# Backup starts here - MAIN LOGIC STARTS HERE     
#############################################################
 echo "schemas=$schemas" 
  cd ${DB_DUMP_DIR}

  start=`date +%s`

  tableInfoFile="${dmp_file}.${tableInfoFileExt}" 
  saveCurrentDBTableInfo $SYSTEM_USER $SYSTEM_PASS "${tableInfoFile}" 

  hostInfoFile="${dmp_file}.$hostInfoFileExt"
  saveCurrentHostInfo $hostInfoFile

  log "Exporting schemas ($schemas) to ${DB_DUMP_DIR} ... "
 if [[ -f ${SCRIPT_DIR}/backup_validate_schema.sh ]]; then
   {
      dmp_file=`. ${SCRIPT_DIR}/backup_validate_schema.sh -d "${ORACLE_SID}" -u "${SYSTEM_USER}" -p "${SYSTEM_PASS}"  -f "${dmp_file}" -s "$schemas"`
   }
 fi
  log "dumpfile=$dmp_file.dmp"
  log "logfile=expdp_${dmp_file}.log"
 if [[ ( ! -z  "${in_tar}" ) || ( ! -z "${in_copy}" ) ]];then  
   {                                                           
      expdp $SYSTEM_USER/$SYSTEM_PASS@$ORACLE_SID schemas=$schemas directory=$DB_PUMP_NAME parallel=${in_dmp_no}  dumpfile=$dmp_file.dmp logfile=\"expdp_${dmp_file}.log\" "${my_trailing_parameters}" 
   }                                                           
 else                                                          
   {                                                           
     expdp $SYSTEM_USER/$SYSTEM_PASS@$ORACLE_SID schemas=$schemas directory=$DB_PUMP_NAME parallel=${in_dmp_no}  dumpfile=\"$dmp_file%U.dmp\" logfile=\"expdp_${dmp_file}.log\" "${my_trailing_parameters}" 
   }                                                           
 fi                                                            
 myRC=$?                                          
   log "Export complete."
   [ ${in_copy} ] && cp -p "${DB_DUMP_DIR}"/"${dmp_file}"*.dmp "${in_copy}"  >> "${LOG}" 

  if [ -z "${in_tar}" ];  then                    
   {                                              
	   log "Packaging..."
	   {
	     cd "${DB_DUMP_DIR}"
	     tar -cvf "${dmp_file}.tar" "${dmp_file}"*.dmp "${tableInfoFile}"  "$hostInfoFile" "${dmp_file}"*.rpt >> "$LOG" 
	     cd -
	   }
	   log "Compressing..."
	   logq "Before: `ls -l "${DB_DUMP_DIR}/$dmp_file.tar"`"
	   gzip -9 -f "${DB_DUMP_DIR}/$dmp_file.tar" >> "$LOG" 
	   logq "After : `ls -l "${DB_DUMP_DIR}/$dmp_file.tar.gz"`"

	   log "Setting permissions..."
	   chmod 777 "${DB_DUMP_DIR}/${dmp_file}.tar.gz" >> "$LOG"
   }                                              
 fi                                               

 if [ -r "${DB_DUMP_DIR}/${dmp_file}.tar.gz" ]; then
   {                                              
      log "Cleaning up temporary files..."
      if [ -z "${in_tar}" ];  then                
          {                                       
               rm -f  ${DB_DUMP_DIR}/"${dmp_file}"*.dmp "${DB_DUMP_DIR}/expdp_${dmp_file}.log"  >> "$LOG" 
          }                                       
      fi                                          
   rm -f "${DB_DUMP_DIR}/${tableInfoFile}" "${DB_DUMP_DIR}/$hostInfoFile" >> "$LOG" 
   }                                              
 else                                             
   {                                            
       rm -f "${DB_DUMP_DIR}/${tableInfoFile}" "${DB_DUMP_DIR}/$hostInfoFile" 
   }                                          
 fi

   finish=`date +%s`

   seconds=`expr $finish - $start`

if [ ! -z $OWNER ] && [ ! -z $EMAIL ]; then 
   {                                                      
	 if [ -z "${in_tar}" ];  then                     
	   {                                              
	       mail -s "{DB} Backup: `whoami` complete on ${TNS}@`hostname`." -c $OWNER $EMAIL <<EOF
Your DB backup to archive ${dmp_file} containing schemas: 
               `cat  "${DB_DUMP_DIR}/${dmp_file}"*.rpt|while read line;do  printf "\n%30s" "${line}";done`
from ${TNS} instance on `hostname` is complete at `date`.  $seconds seconds elapsed  ( $(( ${seconds} / 60 )) minutes.)

Full path to archive package is `hostname`:${DB_DUMP_DIR}/${dmp_file}.tar.gz
EOF
	       log "${GREEN}Database backup to ${dmp_file}.tar.gz is now complete${RESET}" 
	   }                                              
	 else                                             
	   {                                              
	       mail -s "{DB} Backup: `whoami` complete on ${TNS}@`hostname`." -c $OWNER $EMAIL <<EOF
Your DB backup to archive ${dmp_file} containing schemas: 
               `cat  "${DB_DUMP_DIR}/${dmp_file}"*.rpt|while read line;do  printf "\n%30s" "${line}";done`
from ${TNS} instance on `hostname` is complete at `date`.  $seconds seconds elapsed  ( $(( ${seconds} / 60 )) minutes.)

Full path to archive package is `hostname`:"${DB_DUMP_DIR}"/"${dmp_file}"
EOF
	       log "${GREEN}Database backup to ${dmp_file} is now complete${RESET}" 
	   }                                              
	 fi                                               
   }                                                      
fi
 rm -f "${DB_DUMP_DIR}/${dmp_file}"*.rpt
printf "\t%-20s%s\n" "Schemas:" "${schemas}."
printf "\t%-20s%s\n" "Elapsed time:" "${seconds} seconds ( $(( ${seconds} / 60 )) minutes.)"
printf "\t%-20s%s\n" "Basic log in:" "$LOG"
printf "\t%-20s%s\n\n" "Extended log in:" "${DB_DUMP_DIR}/expdp_${dmp_file}.log"


#Remove pid file

 [[ -e ${IN_PROGRESS} ]] && rm ${IN_PROGRESS}

unset LOG
 if [ $((myRC)) -ne 0 ]; then
   {
     mySQL=`find ${SCRIPT_DIR}  -name 'SelectSchemaCount.sql' -print|head -1`
     in_rc=13
     in_object="backup_nohup.sh"
     in_msg="Export did not complete successfully. RC=${myRC} is considered failure. In the log, look for ORA- for reason. Try looking at ${mySQL}. Aborting all processes after attempting backup."
     common_sdt_report ${in_object} $((in_rc)) "${in_msg}"
   }
 fi

