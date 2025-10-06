#!/bin/bash
#-----------------------------------------------#Synopsis
# name: backup.sh                               #Synopsis 
#-----------------------------------------------#Synopsis
# desc: Master script to perform database backup#Synopsis
# usage: Interactive or can run in batch with   #Synopsis
#        options and/or arguments.              #Synopsis
#  ---> The Oracle SID or ORACLE_SID drives     #Synopsis
#       which common properties file to source. #Synopsis
#       The common properties holds all the     #Synopsis
#       database specific information to take   #Synopsis
#       a backup.                               #Synopsis
#-----------------------------------------------#Synopsis
#   ===> Options <===                           #Synopsis
#-----------------------------------------------#Synopsis
# -b              ORACLE_SID or database name   #Synopsis
#      --->       Must be last option specified #Synopsis
#                 when using options on the     #Synopsis
#                 command line.                 #Synopsis
# -F|--file       Override the export dmp name. #Synopsis
# -T|--no-tar     Don't create tar and zip files#Synopsis
#                 Simply write export.          #Synopsis
#      --->       Override -D and defaults to 1.#Synopsis
#                 Exports only 1 dmp file.      #Synopsis
#                 The export is NOT parallel.   #Synopsis
# -s|--schemas    List of comma delim. schemas  #Synopsis
#                 to export. Overrides any      #Synopsis
#                 hardcoding.                   #Synopsis
# -d              Run with defaults. The script #Synopsis
#                 will create a default export  #Synopsis
#                 file name.                    #Synopsis
# -D|--dumps      Number of output dump file to #Synopsis
#                 split the export dump into by #Synopsis
#                 parallel processes.           #Synopsis
#                 -->default is 8               #Synopsis
# -C|--copy       Copies export to remote loc.  #Synopsis
#                 Where remote loc is the       #Synopsis
#                 absolute path of directory.   #Synopsis
#      --->       Override -D and defaults to 1.#Synopsis
#                 Exports only 1 dmp file.      #Synopsis
#                 The export is NOT parallel.   #Synopsis
# -O|--over       Allow overlay of existing     #Synopsis
#                 export or tar.gz              #Synopsis
# -h|--help       (display usage)               #Synopsis
#                                               #Synopsis
#-----------------------------------------------#Synopsis
#   ===> Arguments <===                         #Synopsis
#-----------------------------------------------#Synopsis
# file-name       Uses file-name as part of the #Synopsis
#                 export file name, with the    #Synopsis
#                 timestamp automatically added.#Synopsis
#-----------------------------------------------#Synopsis
#   ===> Examples <===                          #Synopsis
#-----------------------------------------------#Synopsis
# ./backup.sh   (no arguments, INTERACTIVE)     #Synopsis
# or                                            #Synopsis
# ./backup.sh file-name                         #Synopsis
# or                                            #Synopsis
# ./backup.sh -d                                #Synopsis
# or                                            #Synopsis
# ./backup.sh -D 16                             #Synopsis
# or                                            #Synopsis
# ./backup.sh -s SALESWMS,SALESMDA              #Synopsis
# or                                            #Synopsis
# ./backup.sh -F complete-name-of-dump          #Synopsis
# or                                            #Synopsis
# ./backup.sh -F complete-name-of-dump -s SALESWMS,SALESMDA #Synopsis
# or                                            #Synopsis
# ./backup.sh -F complete-name-of-dump -O       #Synopsis
# or                                            #Synopsis
# ./backup.sh -C /apps/scpp/DBs                 #Synopsis
# or                                            #Synopsis
# ./backup.sh -T                                #Synopsis
# or                                            #Synopsis
# ./backup.sh -h                                #Synopsis
#-----------------------------------------------#
# Change Control                                #
#-----------------------------------------------#
# Date       Author    Desc.                    #
# 2017.12.08 Askew     Make production ready.   
# 2017.12.09 Askew     Add options for override 
# 2017.12.12 Askew     Add schema option        
# 2017.12.12 Askew     Bug fix for -F           
# 2017.12.12 Askew     Add interactive help -h  
# 2017.12.12 Askew     Add option to split dump 
# 2017.12.13 Askew     Unify backup.sh with     
#                      CI export solution.      
# 2017.12.14 Askew     Update usage/make prod.  
#                      ready.                   
# 2017.12.14 Askew     Change spacecheck to look
#                      for 12 GB free space.    
# 2017.12.14 Askew     Add expdp opt. overwrite 
# 2017.12.14 Askew     Set up /apps/scpp for    
#                      db backups.              
# 2017.12.18 Askew     Bug Fix                  
# 2017.12.20 Askew     Cont. production readiness
# 2017.12.20 Askew     Add common_properties.orcl
# 2017.12.22 Askew     Production readiness     
# 2017.12.22 Askew     Add common properties    
# 2017.12.26 Askew     SDT automate. data pump. 
# 2017.12.31 Askew     Add export function      
# 2018.01.01 Askew     Add OPT_FLG comm. prop.  
# 2018.01.03 Askew     Replace commmon_xxx.sh   
#                      with common_validation.sh
# 2018.01.05 Askew     Salesforce case 4646285;
#                      Ride in bug fix for SID
# 2018.01.07 Askew     Add catch for non-exist SCRIPT_DIR
# 2018.01.09 Askew     Add OPT_FLG_USE_CLASSIC logic.
################################################# 
#-------------------------------------------------
 function 000-common-validate () {                
#-------------------------------------------------
 num_arg=2                                        
 in_object="000-common-validate"                  
 in_rc=8                                          
 in_msg=" Num. arguments was: $#, expecting: ${num_arg}" 
 [ $# -ne $((num_arg)) ] &&  common_sdt_report ${in_object} ${in_rc} ${in_msg} 
 
 in_option=$1                                     
 in_argument=$2                                   
 }                                                
#-------------------------------------------------
 function 000-usage() {                           
#-------------------------------------------------
 clear                                            
 export mySCRIPT="backup.sh"
 echo "################################################" 
 echo "# Program: backup.sh                          " 
 echo "################################################" 
 echo "# Usage:                                        " 
 echo "#  ---> The Oracle SID or ORACLE_SID drives     "
 echo "#       which common properties file to source. "
 echo "#       The common properties holds all the     "
 echo "#       database specific information to take   "
 echo "#       a backup.                               "
 echo "#-----------------------------------------------" 
 echo "#   ===> Options <===                           " 
 echo "#-----------------------------------------------" 
 echo "# -b              ORACLE_SID or database name   " 
 echo "#      --->       Must be last option specified " 
 echo "#                 when using options on the     "
 echo "#                 command line.                 " 
 echo "#                 Not mandatory option, but if  "
 echo "#                 you want to be sure...        "
 echo "# -F|--file       Override the export dmp name. " 
 echo "# -T|--no-tar     Don't create tar and zip files" 
 echo "#                 Simply write export.          " 
 echo "#      --->       Override -D and defaults to 1." 
 echo "#                 Exports only 1 dmp file.      " 
 echo "#                 The export is NOT parallel.   " 
 echo "# -s|--schemas    List of comma delim. schemas  " 
 echo "#                 to export. Overrides any      " 
 echo "#                 hardcoding.                   " 
 echo "# -d              Run with defaults. The script " 
 echo "#                 will create a default export  " 
 echo "#                 file name.                    " 
 echo "# -D|--dumps      Number of output dump file to " 
 echo "#                 split the export dump into by " 
 echo "#                 parallel processes.           " 
 echo "#                 -->default is 8               " 
 echo "# -C|--copy       Copies export to remote loc.  " 
 echo "#                 Where remote loc is the       " 
 echo "#                 absolute path of directory.   " 
 echo "#      --->       Override -D and defaults to 1." 
 echo "#                 Exports only 1 dmp file.      " 
 echo "#                 The export is NOT parallel.   " 
 echo "# -O|--over       Allow overlay of existing     " 
 echo "#                 export or tar.gz              " 
 echo "# -h|--help       (display usage)               " 
 echo "#                                               " 
 echo "#-----------------------------------------------" 
 echo "#   ===> Arguments <===                         " 
 echo "#-----------------------------------------------" 
 echo "# file-name       Uses file-name as part of the " 
 echo "#                 export file name, with the    " 
 echo "#                 timestamp automatically added." 
 echo "#-----------------------------------------------" 
 echo "#   ===> Examples <===                          " 
 echo "#-----------------------------------------------" 
 echo "# ./backup.sh   (no arguments, INTERACTIVE)     " 
 echo "# or                                            " 
 echo "# ./backup.sh file-name                         " 
 echo "# or                                            " 
 echo "# ./backup.sh -d                                " 
 echo "# or                                            " 
 echo "# ./backup.sh -D 16                             " 
 echo "# or                                            " 
 echo "# ./backup.sh -s SALESWMS,SALESMDA              " 
 echo "# or                                            " 
 echo "# ./backup.sh -F complete-name-of-dump          " 
 echo "# or                                            " 
 echo "# ./backup.sh -F complete-name-of-dump -s SALESWMS,SALESMDA " 
 echo "# or                                            " 
 echo "# ./backup.sh -F complete-name-of-dump -O       " 
 echo "# or                                            " 
 echo "# ./backup.sh -C /apps/scpp/DBs                 " 
 echo "# or                                            " 
 echo "# ./backup.sh -T                                " 
 echo "# or                                            " 
 echo "# ./backup.sh -h                                " 
 }                                                
################################################
# BEGIN/START MAIN LOGIC HERE                     
##################################################
#################################################
set -a
#-----------------------------------------------#
operation="BACKUP"
# Script defaults                                 
#						  
defaultDMPname=`who -m |awk '{print $1"_"$NF}'|sed 's/[^a-z,0-9,_,\.]//g'` 
batchMODE="N"                                     
spacecheck_min_mbytes=10000                       
#                                                 
# We are going to set the next in_xxx variables   
# to default values to allow the script options to
# be entered in any order, but keep call to       
# backup_nohup.sh using positional parameters.    
#                                                 
 in_SCHEMAS="*"                                   
 in_dmp_no=8                                      
 in_tar="N"                                       
 in_over="N"                                      
 in_copy="*"                                      
 num_test='^[0-9]+$'                              
 my_trailing_parameters=""                        
mySCRIPT=backup.sh                                
#############################################################
# Script for restoring database dump into a schema
#############################################################
 while getopts :d,O,-over,T,-no-tar,h,F:-file:C:-copy:s:-schemas:D:-dumps:b:  in_option 2>/dev/null  
   do                                             
      case $in_option in                          
           F|-file) export defaultDMPname="${OPTARG}" 
                    export usr_dmp_file="${OPTARG}" 
                    export batchMODE="Y"                
           ;;                                     
           b)       export ORACLE_SID=`builtin echo "${OPTARG}"|sed 's/ //g'`
                    export batchMODE="Y"
           ;;
           d) export batchMODE="Y"                
                    #export defaultDMPname="${DMP_PREFIX}${defaultDMPname}" 
           ;;                                     
           s) export batchMODE="Y"                
              if [[ ! -z  "${OPTARG}" ]]; then
                {
                    export in_SCHEMAS="${OPTARG}" 
                }
              else
                {
                    in_rc=12
                    in_object=backup.sh
                    in_msg="-s option expects schemas to follow. No schemas read in. Aborting with no action taken."
                    alert ${in_msg}                              
                    common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}" 
                }
              fi
           ;;                                     
           D|-dumps) [[ "${OPTARG}"  =~ $num_test ]] && export in_dmp_no="${OPTARG}"  
           ;;                                     
           T|-no-tar) export batchMODE="Y"        
              export in_tar="Y"                   
              ;;                                  
           O|-over)   export batchMODE="Y"        
              export in_over="Y"                  
              export my_trailing_parameters+=" reuse_dumpfiles=Y " 
              ;;                                  
           C|-copy)   export batchMODE="Y"        
              export in_copy="${OPTARG}"          
              ;;                                  #Askew20171213-001             
           h|-help)                               
              000-usage                           
              exit                                
           ;;                                     
           \?) in_rc=14                           
               in_object="backup.sh"              
               in_msg="Option REQUIRING argument ${OPTARG} was either not found or your option string contains invalid settings. Try backup.sh -h for assistance."
               alert ${in_msg}                              
               common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}" 
           ;;                                     
           :|\;) in_rc=14
               in_object="backup.sh"              
               in_msg="Option REQUIRING argument ${OPTARG} was either not found or your option string contains invalid settings. Try backup.sh -h for assistance."
               alert ${in_msg}                              
               common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}" 
           ;;                                     
           *) export batchMODE="Y"                
           ;;                                     
      esac                                        
   done                                           
# Source a bunch of environment specific settings.
 [[ -z ${SCRIPT_DIR} ]] && SCRIPT_DIR="."
 case "${ORACLE_SID}" in
    [a-z,A-Z]*)  if [[ -s ${SCRIPT_DIR}/common_properties.${ORACLE_SID} ]]; then
                 {
                    . ${SCRIPT_DIR}/common_properties."${ORACLE_SID}" 
                 }
                 else
                   {
		       in_object="backup.sh"
		       in_rc=9
		       in_msg="Common properties file not found. Program ${mySCRIPT} was passed ${SCRIPT_DIR}/common_properties.${ORACLE_SID} as the common properties file. Aborting process with no action taken."
		       if [[ -x ${SCRIPT_DIR}/common.sh ]];then   
			 {                                        
			    . ${SCRIPT_DIR}/common.sh             
			    alert ${in_msg}                       
			 }                                        
		       else                                       
			 {                                        
			   echo "Error! --> ${in_msg}"            
			 }                                        
		       fi                                         
		       if [[ "${OPT_VERBOSE}" == "Y" ]]; then           
			   {                                              
				echo "#########################################"|tee -a "${LOG}"
				echo "# Trapped Error                          "|tee -a "${LOG}"
				echo "# Aborting process in `echo $(basename -- $(readlink -f -- $0))`"|tee -a "${LOG}"
				echo "#########################################"|tee -a "${LOG}"
				echo "# Details                                " |tee -a "${LOG}"
				echo "#---------------------------------------#" |tee -a "${LOG}"
				echo "# Script: ${in_object}                   " |tee -a "${LOG}"
				echo "# Return Code: ${in_rc}                  " 
				echo "# Message: ${in_msg}                     " 
				echo "#---------------------------------------#" |tee -a "${LOG}"
				echo "# Processing information                 " |tee -a "${LOG}"
				echo "#---------------------------------------#" |tee -a "${LOG}"
				echo -e "# Bash information: -->\c"              |tee -a "${LOG}"
				STACK=""                                         
				local i                                          
				local stack_size=${#FUNCNAME[@]}                 
				for (( i=1; i<$stack_size ; i++ )); do           
				      local func="${FUNCNAME[$i]}"               
				      [ x$func = x ] && func=MAIN                
				      local linen="${BASH_LINENO[(( i - 1 ))]}"  
				      local src="${BASH_SOURCE[$i]}"             
				      [ x"$src" = x ] && src=non_file_source     
				      STACK+=$func" "$src" "$linen               
				      echo "${STACK}"                            
				done                                             
				echo "# Error reported by function: $FUNCNAME  " |tee -a "${LOG}"
				echo "# Here is the trace of the function call:" |tee -a "${LOG}"
				echo "# ${FUNCNAME[*]}                         " 
				TRACE=""                                         
				CP=$$                                            
				while true                                       
				do
					CMDLINE=$(cat /proc/$CP/cmdline)         
					PP=$(grep PPid /proc/$CP/status | awk '{ print $2; }') 
					TRACE="$TRACE [$CP]:$CMDLINE\n"          
					if [ "$CP" == "1" ]; then                
						break                            
					fi                                       
					CP=$PP                                   
				done                                             
				echo "#---------------------------------------#"|tee -a "${LOG}"
				echo "# Backtrace of `basename "$0"`:          "|tee -a "${LOG}"
				echo "#---------------------------------------#"|tee -a "${LOG}"
				echo -en "$TRACE" | tac | grep -n ":"|tee -a "${LOG}"
				echo "#########################################"|tee -a "${LOG}"
			   }                                      
			 fi                                       
			[[ -f ${IN_PROGRESS} ]] && rm -f ${IN_PROGRESS}
			exit
                   }
                 fi
        ;;
    *) in_object="backup.sh"
       in_rc=9
       in_msg="Common properties file not found --> ${SCRIPT_DIR}/common_properties.${ORACLE_SID}"
       if [[ -x ${SCRIPT_DIR}/common.sh ]];then   
         {                                        
            . ${SCRIPT_DIR}/common.sh             
            alert ${in_msg}                       
         }                                        
       else                                       
         {                                        
           echo "Error! --> ${in_msg}"            
         }                                        
       fi                                         
                echo "#########################################"|tee -a "${LOG}"
                echo "# Trapped Error                          "|tee -a "${LOG}"
                echo "# Aborting process in `echo $(basename -- $(readlink -f -- $0))`"|tee -a "${LOG}"
                echo "#########################################"|tee -a "${LOG}"
                echo "# Details                                " |tee -a "${LOG}"
                echo "#---------------------------------------#" |tee -a "${LOG}"
                echo "# Script: ${in_object}                   " |tee -a "${LOG}"
                echo "# Return Code: ${in_rc}                  " 
                echo "# Message: ${in_msg}                     " 
                if [[ "${OPT_VERBOSE}" == "Y" ]]; then           
                  {
			echo "#---------------------------------------#" |tee -a "${LOG}"
			echo "# Processing information                 " |tee -a "${LOG}"
			echo "#---------------------------------------#" |tee -a "${LOG}"
			echo -e "# Bash information: -->\c"              |tee -a "${LOG}"
			STACK=""                                         
			local i                                          
			local stack_size=${#FUNCNAME[@]}                 
			for (( i=1; i<$stack_size ; i++ )); do           
			      local func="${FUNCNAME[$i]}"               
			      [ x$func = x ] && func=MAIN                
			      local linen="${BASH_LINENO[(( i - 1 ))]}"  
			      local src="${BASH_SOURCE[$i]}"             
			      [ x"$src" = x ] && src=non_file_source     
			      STACK+=$func" "$src" "$linen               
			      echo "${STACK}"                            
			done                                             
			echo "# Error reported by function: $FUNCNAME  " |tee -a "${LOG}"
			echo "# Here is the trace of the function call:" |tee -a "${LOG}"
			echo "# ${FUNCNAME[*]}                         " 
			TRACE=""                                         
			CP=$$                                            
			while true                                       
			do
				CMDLINE=$(cat /proc/$CP/cmdline)         
				PP=$(grep PPid /proc/$CP/status | awk '{ print $2; }') 
				TRACE="$TRACE [$CP]:$CMDLINE\n"          
				if [ "$CP" == "1" ]; then                
					break                            
				fi                                       
				CP=$PP                                   
			done                                             
			echo "#---------------------------------------#"|tee -a "${LOG}"
			echo "# Backtrace of `basename "$0"`:          "|tee -a "${LOG}"
			echo "#---------------------------------------#"|tee -a "${LOG}"
			echo -en "$TRACE" | tac | grep -n ":"|tee -a "${LOG}"
			echo "#########################################"|tee -a "${LOG}"
		   }                                      
		 fi                                       
        [[ -f ${IN_PROGRESS} ]] && rm -f ${IN_PROGRESS}
        exit
        ;;
 esac
 if [[ "${OPT_VERBOSE}" == "Y" ]];then
   {
       PRINT="echo"
   }
  else
   {
      PRINT=":"
   }
 fi
 if [[ ( ! -z "${SCRIPT_DIR}" ) && ( ! -d "${SCRIPT_DIR}" ) ]];then
   {
     in_object="backup.sh"
     in_rc=24
     in_msg="\${SCRIPT_DIR}=${SCRIPT_DIR} is unusable. Does it exist?"
     echo "################################################"
     echo "# Error! in program ${in_object}.               "
     echo "# Aborting process as ${in_object} received RC=${in_rc}."
     echo "# Details: ${in_msg}                            "
     exit 9
   }
 fi
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
               echo "# backup.sh                             "
               echo "# Error: unable to execute: ${i}          "
               echo "# Process aborting with no action taken.  "
               echo "# Returning with return code of:          "
               builtin echo -1
               exit -1
          }
        fi
   done
            export -f common_test_orcl
            export -f common_sdt_report
            export -f swat_kill
            export -f alert
            export -f debug
            export -f log
mySCRIPT=backup.sh
DMP_PREFIX="${operation}_${LOGSTAMP}_"

 ###----------------------------------------------
 ### Immediately validate export file over write  
 ###----------------------------------------------
 if [[ ( ! -z "${usr_dmp_file}" ) && ( "${in_over}" == "N" ) ]]; then 
   {                                              
       if [[ ( -f "${DB_DUMP_DIR}/${usr_dmp_file}01.dmp" ) || ( -f "${DB_DUMP_DIR}/${usr_dmp_file}.tar.gz" ) ]];then  
          {                                       
              in_object="${usr_dmp_file}"         
              in_rc=9                             
              in_msg="Export already exists! You did not specify option -O to override. Aborting" 
              alert ${in_msg}                              
              common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}" 
          }                                       
       fi                                         
   }                                              
 fi                                               
 ###
 ### We do NOT want to overwrite a soft link. It's confusing.
 ###
 for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 
   do 
	 if [[ ( -f "${DB_DUMP_DIR}/${usr_dmp_file}${i}.dmp" ) && (  "${in_over}" == "Y" ) ]]; then  
	    {                                             
	       [[ "`echo realpath ${DB_DUMP_DIR}/${usr_dmp_file}${i}.dmp`" == "" ]] && : || rm -f "${DB_DUMP_DIR}/${usr_dmp_file}${i}.dmp"  
	    }                                             
	 fi                                               
   done                                           
 #if [[ (  -f "${DB_DUMP_DIR}/${usr_dmp_file}.tar.gz" )  && (  "${in_over}" == "Y" ) ]]; then 
 #  {                                             
 #      [[ "`readlink ${DB_DUMP_DIR}/${usr_dmp_file}.tar.gz`" == "" ]] && : || rm -f "${DB_DUMP_DIR}/${usr_dmp_file}.tar.gz" 
 #  }                                             
 #fi                                              
 ###----------------------------------------------
 ### Immediately validate if remote dest exists   
 ###----------------------------------------------
 if [[ ! "${in_copy}" == "*"  ]]; then               
   {                                              
       if [[ (! -d "${in_copy}" ) && ! ( -w "${in_copy}" ) ]]; then 
          {                                       
              in_object="${in_copy}"              
              in_rc=10                            
              in_msg="Unable to access or write to ${in_copy}. Aborting" 
              alert ${in_msg}                              
              common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}" 
          }                                       
       fi                                         
       dmp_file="`basename "${usr_dmp_file}" .dmp`"
       if [[ ( -f "${in_copy}/${dmp_file}.dmp" ) ]];then
         {
           export MY_SAV_DT=`stat "${in_copy}/${dmp_file}.dmp"|sed -n -e '/Modify/s/Modify://p'|sed  -e 's/ /_/g'|cut -d. -f1`
           mv "${in_copy}/${dmp_file}.dmp" "${in_copy}/${dmp_file}.dmp${MY_SAV_DT}" 
         }
       fi
       set +evx
   }                                              
 fi                                               
 
 ###----------------------------------------------
 ### Check if export already running. Abort true  
 ###----------------------------------------------
 
 if [ -r "${IN_PROGRESS}" ]; then                  
        alert "Aborting - DB activity in progress: `cat ${IN_PROGRESS}`" 
        exit 7					  
 fi                                               
 ###----------------------------------------------
 ### No options were entered in backup.sh command 
 ### Only 1 argument passed as export name.       
 ### --> Example: backup.sh my-export-file_name   
 ###----------------------------------------------
 case $(( $OPTIND - 1 )) in                       
     0) export batchMODE="N"                      
	if [ $# -eq 1 ]; then                     
          {                                       
              export usr_dmp_file="${DMP_PREFIX}$1" 
          }                                       
        fi                                        
        ;;
     *) ;;
 esac
 ###----------------------------------------------
 ### Decide whether interactive or batch. Do I prompt user?  
 ###----------------------------------------------
if [ ! -d "${DB_DUMP_DIR}" ]; then
     if [ "${batchMODE}" != "Y" ]; then           
       {                                          
        read -e -p "Database Dump Directory does not exist \"${DB_DUMP_DIR}\". Would you like to create it? (Y/N)" createDir
       }                                          
     else                                         
       {                                          
           createDir="Y"                          
       }                                          
     fi                                           

        if [ "$createDir" == "Y" ]; then
			mkdir -p "${DB_DUMP_DIR}"
			chown `whoami`:`id -g -n $USER` "${DB_DUMP_DIR}" 
			chmod g+r+w+x+s "${DB_DUMP_DIR}"
			chmod g+x $(dirname "${DB_DUMP_DIR}")
		else
			exit -1
		fi
else
	log "Backup Directory - ${DB_DUMP_DIR}"
	chown `whoami`:`id -g -n $USER` "${DB_DUMP_DIR}" 
	chmod g+r+w+x+s "${DB_DUMP_DIR}"
	chmod g+x $(dirname "${DB_DUMP_DIR}")
fi

if [ ! -w "${DB_DUMP_DIR}" ] ; then
	alert "Aborting - User \"`whoami`\" does not have write permission to \"${DB_DUMP_DIR}\""
	exit 9
fi

spacecheck $DB_DUMP_DIR "${spacecheck_min_mbytes}" 
if [[ -z "${DB_PUMP_NAME}" ]];then 
   {
     in_object="backup.sh"
     in_rc=24
     in_msg="Unable to call ${SCRIPT_DIR}/setOracleDumpDir.sh with blank \$DB_PUMP_NAME"
     common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}"
   }
 fi
if [[ -z "${DB_DUMP_DIR}" ]];then 
   {
     in_object="backup.sh"
     in_rc=24
     in_msg="Unable to call ${SCRIPT_DIR}/setOracleDumpDir.sh with blank \$DB_DUMP_DIR"
     common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}"
   }
 fi
$SCRIPT_DIR/setOracleDumpDir.sh $DB_PUMP_NAME $DB_DUMP_DIR $SYSTEM_USER $SYSTEM_PASS 1>/dev/null
returnVal=$?

if [ $returnVal -ne 0 ]; then
	echo "Halting backup - Return value $returnVal"
	exit $returnVal
fi
if [ -z "$usr_dmp_file" ]; then                     
  if [ "${batchMODE}" == "N" ]; then              
   {                                              
        echo "\nPlease enter a name of the archive to be created (it will automatically get a datestamp):"
        echo -e "-> \c"
        read usr_dmp_file
   }                                              
  else                                            
   {                                              
        usr_dmp_file="${DMP_PREFIX}${defaultDMPname}" 
   }                                              
  fi                                              
fi

if [ -z "${usr_dmp_file}" ]; then
        dmp_file="${defaultDMPname}"              
else
	# strip off any possible .dmp ending  because i don't trust users.
	dmp_file="`basename "${usr_dmp_file}" .dmp`" 
fi
#-------------------------------------------------
# Validation complete. Prep to call backup_nohup.sh 
#-------------------------------------------------
export LOG=`pwd`/"${dmp_file}".log
 [[ -f "${LOG}" ]] && rm -f "${LOG}"              

log "Backup will be logged to ${LOG}"
log "Dump File name \"$dmp_file\""

if [ ! -z $OWNER ] && [ ! -z $EMAIL ]; then 

mail -s "{DB} Backup: `whoami` started on ${TNS}@`hostname`." -c $OWNER $EMAIL<<EOF
DB backup started for "$dmp_file" started  at `date`

Full path to archive package will be `hostname`:${DB_DUMP_DIR}/"${dmp_file}".tar.gz
EOF

else
	alert "No Email Addresses for $operation script.  Please review values here $SCRIPT_DIR/common_sdt.sh"
fi
#############################################################
# CUTOFF FOR INTERACTIVE
#############################################################
 if [ -e nohup.out ]; then                        
   {                                              
        rm nohup.out
   }                                              
 fi                                               
 if [[ "${OPT_USE_CLASSIC_NO_MODS}" != "Y" ]];then
   { 
	 sed -ne '/OPT_FLG_/p' common_properties.${ORACLE_SID}|sed 's/=/ /g'|while read x my_arg my_val 
	   do                                             
	     case ${my_val} in                            
		  \"Y\")  
		  . ${SCRIPT_DIR}/united/united_master.sh "$LOG" 
		  break;                                  
		  ;;                                      
		  *);;                                    
	     esac                                         
	   done                                           
	 myRC=$?                                          
	 if [[ $((myRC)) -ne 0 ]]; then                   
	   {                                              
	     in_object=backup.sh                          
	     in_rc=${myRC}                                
	     in_msg="Unsuccessful execution of /united_master.sh. This impacts SelectSchemaCounts.sql and other SQL. Using all sql as-is" 
	     alert ${in_msg}                              
	     common_sdt_report ${in_object} ${in_rc} "${in_msg}" > /dev/tty 2>&1|tee -a "${LOG}" 
	   }                                              
	 fi                                               
   }
 fi #/end if for OPT_USE_CLASSIC_NO_MODS
 call_backup_nohup "$LOG" "$dmp_file" "${in_SCHEMAS}" "${in_dmp_no}" "${in_tar}" "${in_copy}" "${my_trailing_parameters}"
