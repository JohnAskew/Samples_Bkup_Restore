#!/bin/bash
#-------------------------------------------------#Synopsis
# name: restore.sh                                #Synopsis
#-------------------------------------------------#Synopsis
# desc: Restore db from export taken with backup.sh#Synopsis
# usage: ./restore.sh (Interactive)               #Synopsis
#-------------------------------------------------#
#-------------------------------------------------#
# Change Control                                  #
#-------------------------------------------------#
# Date       Author    Desc.                      #
# 2017.12.08 Askew     Make production ready.     
# 2017.12.14 Askew     Change spacecheck arg. from
#                      1000 MB to 12000 MB.       
# 2017.12.18 Askew     Production ready           
# 2017.12.18 Askew     Add space mgmt. for moving 
#                      dumps to alt. location.    
# 2017.12.19 Askew     Prod. readiness            
# 2017.12.19 Askew     Continue with Askew20171218-002
#                      and make compatible with   
#                      with new backups.sh        
#2018.02.02 Askew      Incorporate swat_import.sh 
#                      batch features into restore.sh
#                      and update to meet production
#                      readiness standards.
#-------------------------------------------------#
export -n mySCRIPT=restore.sh
OPERATION="RESTORE"
TABLE_INFO_FILE_EXT="tabs"
HOST_INFO_FILE_EXT="hostInfo"
SCRIPT_DIR=/home/oracle/tools/Backup                              
SPACE_CHK_MIN_MBYTES=12000                       
TO_AVOID="archive"                                
#--> DB_DUMP_DIR is set in common_properties.$ORACLE_SID.

#----------------------------------------#
 function 000-usage() {
#----------------------------------------#
        echo "################################################"
        echo "# Program: ${mySCRIPT}                          "
        echo "################################################"
        echo "# Usage:                                        "
        echo "# ${mySCRIPT} takes no more than 5 options and 5 arguments."
        echo "#-----------------------------------------------"
        echo "#   ===> Arguments <===                         "
        echo "#-----------------------------------------------"
        echo "# -d|--databases  Database to import           "
        echo "#  ** If not provided, defaults to ORACLE_SID   "
        echo "#                 in the .bash_profile env.     "
        echo "# -D|--directories Override place to write      "
        echo "#                 logs and read dump, providing user has"
        echo "#                 write permissions             "
        echo "# -c|--credentials The database logon/password  "
        echo "#                 in the format: user/password  "
        echo "# -R|--remap      List of comma delimited mappings"
        echo "#                 for mapping old schema to new "
        echo "#                 schema.                       "
        echo "#                 format: aaa:zzz,bbb:yyy       "
        echo "# -x|--xray       Non destructive debug mode.   "
        echo "#                 Options are:                  "
        echo "#                 y|Y for displaying the default"
        echo "#                 output w/o making changes.    "
        echo "#                 a|A for verbose trace output  "
        echo "#                 w/o making changes.           "
        echo "# -h|--help       (display usage)               "
        echo "#                                               "
        echo "#-----------------------------------------------"
        echo "#   ===> Examples <===                          "
        echo "#-----------------------------------------------"
        echo "# ./${mySCRIPT}   (no arguments, take defaults) "
        echo "# or                                            "
        echo "# ./${mySCRIPT} -d mydb -c system/oracle        "
        echo "# or                                            "
        echo "# ./${mySCRIPT} -d mydb -R aaa:zzz,bbb:yyy      "
        echo "# or                                            "
        echo "# ./${mySCRIPT} -D /dir/to/write/to             "
        echo "# or                                            "
        echo "# ./${mySCRIPT} -d mydb -D /dir/to/write/to     "
        echo "# or                                            "
        echo "# ./${mySCRIPT} -R aaa:zzz,bbb:yyy -D /tmp -d mydb"
        echo "# or                                            "
        echo "# ./${mySCRIPT} -c user/pw -d mydb -x y         "
        echo "# or                                            "
        echo "# ./${mySCRIPT} -d mydb -x A -D /dir/to/write   "

 }


#######
## Take users partial entry and search for .tar.gz files
## In Oracles Data Dump Directory
######
#-------------------------------------------------
function promptUserForDBFile () {
#-------------------------------------------------

	# TODO REMOVE CD
	cd ${DB_DUMP_DIR}

	# if user passed in a partial file name see if one or more files match that 
	searchCrit="*.tar.gz"
        if [[  "${batchMODE}" == "Y"  ]];then 
          {
             if [[ ( ! -z "${DMP_FILE}" ) && ( -f "${DMP_FILE}" )  ]];then
               {
                 archive="${DMP_FILE}"
               }
             else
               {
                  archive="wmqa17_seed_gold.tar.gz"
               }
             fi
          }
         else 
          {
            if [ ! -z $1 ]; then
                {
			searchCrit="*$1*.tar.gz"
			numFiles=$(ls -1 $searchCrit 2>/dev/null | wc -l)

			if [ $numFiles -eq 0 ]; then
				searchCrit="*.tar.gz"
			else
				echo "File(s) found with a Partial Match for Entry \"$1\""
			fi
		
			gotfile=0

			while [ $gotfile == 0 ]; do

			
			echo "${GREEN}-----------[FILES $searchCrit ]-------------${RESET}"
			ls -1 $searchCrit 2>/dev/null
			echo "${GREEN}--------------------------------------------${RESET}"

			echo "Enter Backup File: "
			read inputline

			if [ -r "${inputline}" ]; then
				echo "looking at that.tar.gz..."
				export DMP_FILE=`basename $inputline .tar.gz`
				export archive="$inputline"
			else
				export DMP_FILE="$inputline"
				export archive="${DMP_FILE}.tar.gz"
			fi

			if [ -r "${archive}" ]; then
				gotfile=1
			else
				ech "Could not find readable file \"$inputline\" or \"$inputline.tar.gz\" in ${DB_DUMP_DIR}"
				# After first iteration - show user all files if they didn't find what they want
				searchCrit="*.tar.gz"
			fi

			done
               }
            fi
          }
        fi
        ###                                       
        ### Fetch the softlink back to dump dir as physical file 
        ###                                       
         if [[  "${batchMODE}" == "Y"  ]];then
           {
             if [[ ! -f "${DB_DUMP_DIR}"/"${archive}" ]];then
               {
                  cp -p "${archive}" "${DB_DUMP_DIR}"/.
               }
             fi
           }
         else
           {
              echo "$(readlink ${archive})  mv `echo readlink ${archive}` ${DB_DUMP_DIR}" 
              [[ "`echo readlink ${archive}`" == "" ]] && : || mv "`echo readlink ${archive}`" "${DB_DUMP_DIR}" 
           }
         fi

	cd -

}

#-------------------------------------------------
function extractDumpFil () {
#-------------------------------------------------

	cd ${DB_DUMP_DIR}
        echo "function extractDumpFile: DMP_FILE=${DMP_FILE}"
        if [[ ( "${batchMODE}" == "Y" ) && ( ! -z "${DMP_FILE}" ) ]];then 
          {
            :
          }
        elif [ ! -z $1 ]; then
		DMP_FILE=$1
	else
		alert "No Dump File to Extract."
		exit -1
	fi

	log "Decompressing dump file \"$DMP_FILE.tar.gz\"..."
#######3
exit
#######
 ###                                              
 ### Fetch softlink into Dump dir as physical file
 ###                                              
        [[ "`echo $(realpath ${DMP_FILE}.tar.gz)`" == "" ]] && : || mv "`echo $(realpath ${DMP_FILE}.tar.gz)`" "${DB_DUMP_DIR}" 
	gunzip $DMP_FILE.tar.gz >> $LOG
	log "Extracting dump contents..."
	tar -xvf $DMP_FILE.tar >> $LOG
	chmod 777 $DMP_FILE*


	##############################################################
	# Following section checks that the backup package is well formed, like a baby's stool.
	##############################################################

	BACKUP_SCHEMAS="${DMP_FILE}.${TABLE_INFO_FILE_EXT}"
	if [ -r ${BACKUP_SCHEMAS} -a -s ${BACKUP_SCHEMAS} ]; then
		log "Package includes readable table manifest in \"${BACKUP_SCHEMAS}\""
	else
		alert "Dump package did not contain a \"${DMP_FILE}.${TABLE_INFO_FILE_EXT}\" file."
		
		read -e -n 1 -p "Do you want to continue? You will need to specify each schema to map. (y/n)" CONTINUE
		
		if [ "$CONTINUE" != "Y" ] && [ "$CONTINUE" != "y" ]; then 
		   exit 3
        fi
	fi

	numFiles=$(ls $DMP_FILE*.dmp 2>/dev/null | wc -l)
	
	if [ $numFiles -eq 0 ]; then
		alert "Package did not contain a data dump (.dmp) file!"
		exit 4
	else
		log "Package includes $numFiles dump files."
		
		for dumpFile in $(ls ${DMP_FILE}*.dmp 2>/dev/null)
		do
			if [ ! -r $dumpFile ]; then
				alert "$dumpFile in Package is not Readable!"
				exit 4
			fi
		done
	fi
	log "Package includes readable data dump."
	
	cd -
}

#-------------------------------------------------
function compareDmpSchemasToCurrent () {
#-------------------------------------------------
##############################################################
# Following section discovers source and destination schema 
##############################################################

	if [ ! -z $1 ]; then
		DMP_FILE=$1
	else
		alert "No Dump File to Extract."
		exit -1
	fi

	dmpHostInfoFile="${DMP_FILE}.${HOST_INFO_FILE_EXT}"
	dmpTabInfoFile="${DMP_FILE}.${TABLE_INFO_FILE_EXT}"
	currentTabInfoFile="${DMP_FILE}.${TABLE_INFO_FILE_EXT}.current"

	# TODO REMOVE use of cd - either sub shell with () of use full paths
	cd $DB_DUMP_DIR
	
	log "Comparing current schema with backup in "$dmpTabInfoFile"..."

        sqlFile="${select_schema_count}"            

	resultTmpFile=/tmp/$(basename "$currentTabInfoFile").tmp

	log "Counting tables for %DEVINT% with userid $SYSTEM_USER with script $sqlFile "

	rm -f $resultTmpFile
	$SCRIPT_DIR/exportDataFromSQLOnSchema.sh $sqlFile $SYSTEM_USER $SYSTEM_PASS $resultTmpFile 0 >/dev/null 

	cat $resultTmpFile | grep '[[:blank:]]' > $currentTabInfoFile
	#rm -f $resultTmpFile

	# Check for commas - if none found, we are restoring from an "Old Format" - eg 2015 Release or earlier
    if [ $(cat "$dmpTabInfoFile" 2>/dev/null | grep , | wc -l) -eq 0 ]; then
		SCHEMAS_IN_DUMP=$(awk 'NR == 2 || NR == 5 || NR == 8' "$dmpTabInfoFile" 2>/dev/null | sort)
	else
		SCHEMAS_IN_DUMP=$(cat "$dmpTabInfoFile" | cut -f 1 -d , | sort)
	fi

        
	SCHEMAS_IN_CURRENT=$(cat $currentTabInfoFile | cut -f 1 -d , | sort)

	#if [ -z $SCHEMAS_IN_DUMP] ||  [ ${#SCHEMAS_IN_DUMP[@]} -eq 0 ]; then 
	if [[ ( -z $SCHEMAS_IN_DUMP] ) ||  ( ${#SCHEMAS_IN_DUMP[@]} -eq 0 ) ]]; then 
	
		log "No Schemas List with Dump File.  User must supply schema mapping."

		export REMAP=1
		export TABLEMATCH=0	  
	else
		log "Checking Schema List supplied with Dump File to map to %DEVINT% Schemas in Current DB."

		export REMAP=0
		export TABLEMATCH=1
	
		for dmpSchema in $SCHEMAS_IN_DUMP 
		do

			if [ $(cat "$dmpTabInfoFile" | grep , | wc -l) -eq 0 ]; then
				dmpSchemaTableCnt=0
				if [ "$dmpSchema" == "$(awk 'NR == 2' "$dmpTabInfoFile" | xargs )" ]; then
					dmpSchemaTableCnt=$(awk 'NR == 3' "$dmpTabInfoFile" | xargs )
				fi
				if [ "$dmpSchema" == "$(awk 'NR == 5' "$dmpTabInfoFile" | xargs )" ]; then
					dmpSchemaTableCnt=$(awk 'NR == 6' "$dmpTabInfoFile" | xargs )
				fi
				if [ "$dmpSchema" == "$(awk 'NR == 8' "$dmpTabInfoFile" | xargs )" ]; then 
					dmpSchemaTableCnt=$(awk 'NR == 9' "$dmpTabInfoFile" | xargs )
				fi	
			else
				dmpSchemaTableCnt=$(grep "$dmpSchema" "$dmpTabInfoFile" | cut -f 2 -d , )
			fi

			currentSchema=$(grep "$dmpSchema" $currentTabInfoFile | cut -f 1 -d , )
			currentSchemaTableCnt=$(grep "$dmpSchema" $currentTabInfoFile | cut -f 2 -d , )
			
			if [ -z $currentSchema ]; then
				alert "SCHEMA $dmpSchema not found in Current DB "
				# TODO - prompt user for one
				export REMAP=1
				export TABLEMATCH=0
				#exit -1
			else
				log "SCHEMA $dmpSchema found in Current DB "
				log "Table Count ( Dump == Current ) "
				log "Table Count ( $dmpSchemaTableCnt == $currentSchemaTableCnt ) "
				if [ $dmpSchemaTableCnt -ne $currentSchemaTableCnt ]; then 
					export TABLEMATCH=0
				fi
			fi
		done
	fi

	if [ $REMAP -eq 1 ]; then 
		promptUserForSchemaMap "${SCHEMAS_IN_CURRENT[@]}" "${SCHEMAS_IN_DUMP[@]}" 
	else
		if [ $TABLEMATCH -eq 1 ]; then 
		# Check the host info saved in the dmp - if nothing there, or different server that force a full restore to avoid issues with data only import
		
			if [ ! -r "$dmpHostInfoFile" ]; then
				log "No host information supplied with dump - $dmpHostInfoFile -  Defaulting to Full Restore."
				export TABLEMATCH=0
			else
				dmpHostName=$(cat "$dmpHostInfoFile" | cut -d , -f 1 )
				if [ -z  "$dmpHostName" ] || [ "$dmpHostName" != "$(hostname)" ]; then
					log "Host information supplied with dump - $dmpHostInfoFile. Backup came from another host - $dmpHostName.   Defaulting to Full Restore."
					export TABLEMATCH=0
				else
					log "Host information supplied with dump - $dmpHostInfoFile. Backup came from the same host  - $dmpHostName.   Data only restore will be used."
				fi				
			fi
		
		fi
	fi
	cd -
	log "SCHEMAS IN DUMP - $SCHEMAS_IN_DUMP"
	log "SCHEMAS IN CURRENT - $SCHEMAS_IN_CURRENT"
	
	#TODO	
}

#-------------------------------------------------
function promptUserForSchemaMap () {
#-------------------------------------------------

	note "---------------------------------------------"
	note "Please map each Schema from the Dump file to the current Schema"
	note "---------------------------------------------"
	note "${GREEN} Schema Mapping  ${RESET}"
	note "---------------------------------------------"
	note "${YELLOW} DMP Schema List  ${RESET}"
	note "---------------------------------------------"

	dmpSchemas="$2"
	if [ -z "$dmpSchemas" ] || [ ${#dmpSchemas[@]} -eq 0 ]; then 
		note "${RED}No Schema List from DMP provided! ${RESET}"
		#exit 0
	else
		echo $dmpSchemas
	fi

	note "---------------------------------------------"
	note "${GREEN} Current Schema List  ${RESET}"
	note "---------------------------------------------"
	currentSchemas="$1"
	if [ -z "$currentSchemas" ] || [ ${#currentSchemas[@]} -eq 0 ]; then 
		echo "No Schema List for Current DB provided"
		exit 0
	else
		echo $currentSchemas
	fi
	note "---------------------------------------------"
	echo


	firstMatch=1
	for newSchema in $currentSchemas
	do
		# TODO Validate entry
		read -e -p "Enter (DMP) Schema to restore to $newSchema: " oldSchema
		if [ $firstMatch -eq 1 ]; then
			mapList="$oldSchema:$newSchema"
			firstMatch=0
		else
			mapList="$mapList,$oldSchema:$newSchema"
		fi
	done

	export remap="remap_schema=$mapList"
	echo "User mapping election: $remap"
}
###########################################################################
# Script for restoring database dump into a schema-Last Modified-10-14-10 #
###########################################################################
# BEGIN MAIN LOGIC HERE                           
##################################################
batchMODE="N"
spacecheck_min_mbytes=10000
 [[ -z ${SCRIPT_DIR} ]] && SCRIPT_DIR="./"
 case "${ORACLE_SID}" in
    [a-z,A-Z]*)  [ -s ${SCRIPT_DIR}/common_properties.${ORACLE_SID} ] && . ${SCRIPT_DIR}/common_properties."${ORACLE_SID}" 
        ;;
    *) [ -s ${SCRIPT_DIR}/common_properties.orcl ] && . ${SCRIPT_DIR}/common_properties.orcl
        ;;
 esac

 for i in common.sh common_validation.sh 000-swat-functions
   {
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
   }                                          
 export -n mySCRIPT=restore.sh
  echo "# Started processing at `date +%D-%T`"
while getopts R:-remap:d:-database:c:-credentials:D:-directories:x:-xray:F:-f:h-help in_option 2>/dev/null
   do
        case $in_option in
        R|-remap) export SCHEMA_LIST="$OPTARG"
                  echo -e "# \c"
                  tput setaf 2
                  echo -e "SCHEMA_LIST\c"
                  tput setaf 4
                  echo "=${SCHEMA_LIST}"
                  tput setaf 0
                  export batchMODE="Y"
                  ;;
        d|-database) export ORACLE_SID=$OPTARG
                  echo -e "# \c"
                  tput setaf 2
                  echo -e "database\c"
                  tput setaf 4
                  echo -e "=${ORACLE_SID}"
                  tput setaf 0
                  export batchMODE="Y"
                  ;;
        D|-directory)  export DB_DUMP_DIR=$OPTARG
                  echo -e "# \c"
                  tput setaf 2
                  echo -e "Export Dir\c"
                  tput setaf 4
                  echo "=${DB_DUMP_DIR}"
                  export batchMODE="Y"
                  ;;
        c|-credentials) export in_CREDENTIALS=$OPTARG
                  echo -e "# \c"
                  tput setaf 2
                  echo -e "Credentials\c"
                  tput setaf 4
                  echo -e "=`echo ${in_CREDENTIALS}|cut -d'/' -f1|awk '{print $0"/xxxxx"}'`"
                  tput setaf 0
                  export batchMODE="Y"
                  ;;
        h|-help) 000-usage
                 tput sgr0
                 exit 0
                 ;;
        x|-xray)  export in_XRAY=$OPTARG
                  echo -e "# \c"
                  tput setaf 2
                  echo -e "XRAY \c"
                  tput setaf 4
                  echo "option=${in_XRAY}"
                  tput setaf 0
                  export batchMODE="Y"
                  ;;
        F|-f)     export DMP_FILE=$OPTARG
                  echo -e "# \c"
                  tput setaf 2
                  echo -e "DUMPFILE\c"
                  tput setaf 4
                  echo "=${DMP_FILE}"
                  tput setaf 0
                  export batchMODE="Y"
                  ;;
        *|\?)     tput setaf 1
                  echo "# ERROR: Incoming argument not understood"
                  echo "# ${mySCRIPT} unable to parse options --> ${in_option} $OPTARG " 1>&2
                  echo -e "# Incoming options read in --> \c"
                  tput setaf 4
                  echo -e "$@"
                  tput setaf 1
                  echo "# Aborting script with no action taken.   "
                  tput setaf 0
                  000-usage
                  tput sgr0
                  exit -1
                  ;;
        esac
   done
  if [ ! -z ${in_XRAY}  ]; then
    {
        case ${in_XRAY} in
        y|Y)    export in_XRAY="Noexec"
                ;;
        a|A)    export in_XRAY="All"
                set -vx
                ;;
        *)      tput setaf 1
                echo "# Error: XRAY argument not understood"
                echo "# ${mySCRIPT} unable to parse options --> ${in_XRAY}"
                echo -e "# Incoming options read in --> \c"
                tput setaf 4
                echo -e "$@"
                tput setaf 1
                echo "# Aborting script with no action taken."
                tput sgr0
                exit -1
                ;;
        esac
    }
  fi
#--------------------------------------------------------#
# validate the local dir or OPTION -D
#--------------------------------------------------------#
 if [[ ( -z ${DB_DUMP_DIR} ) && ( "${batchMODE}" == "Y" ) ]]; then
  {
        export DB_DUMP_DIR=$HOME/DBs
        tput setaf 0                                    
        echo -e "# \c"
        tput setaf 4
        echo -e "${mySCRIPT}\c"                                 
        tput setaf 0
        echo -e ": DATAPUMP DIR taking default of: \c"          
        tput setaf 4
        echo "${DB_DUMP_DIR}"                    
        tput setaf 0
  }
 fi
#--------------------------------------------------------#
# validate the SID or OPTION -c
#--------------------------------------------------------#
 validate_in_sid ${ORACLE_SID}

#--------------------------------------------------------#
# validate the DUMP or -F
#--------------------------------------------------------#
 if [[ ( "${batchMODE}" == "Y" ) && ( -z "${DMP_FILE}" ) ]];then
   {
     in_object="restore.sh"
     in_rc=12
     in_msg="Option -F: Dump File was not specified. Option -F requires a valid name of a dump file."
     common_sdt_report "{$in_object}" $((in_rc)) "${in_msg}"
     exit 12
   }
 fi
 if [[ ( "${batchMODE}" == "Y" ) && ( ! -f "${DB_DUMP_DIR}"/"${DMP_FILE}" ) ]]; then
   {
          in_object="restore.sh"
     in_rc=12
     in_msg="Option -F: Dump File was not found: ${DB_DUMP_DIR}/${DMP_FILE}" 
     common_sdt_report "{$in_object}" $((in_rc)) "${in_msg}"
     exit 12
   }
 fi

  case $(( $OPTIND - 1 )) in
     0) export batchMODE="N"
        if [ $# -eq 1 ]; then
          {
              export DMP_FILE="$1"
          }
        fi
        ;;
     *) ;;
 esac


###                                               
### Define the SQL to be used. If you do not like 
### like my solution, simply put your version of  
### any SQL in a directory above mine. The find   
### will pick up your version over mine and use it
###                                               
select_schema_count=`find $SCRIPT_DIR -name 'SelectSchemaCount.sql' -type f -print|grep -v "${TO_AVOID}"|head -1` 
 
# Source a bunch of environment specific settings.

if [ -r "${IN_PROGRESS}" ]; then
	alert "Aborting - DB activity in progress: `cat ${IN_PROGRESS}`"
	exit 7
fi
if [ ! -d "${DB_DUMP_DIR}" ]; then
        read -e -p "Database Dump Directory does not exist \"${DB_DUMP_DIR}\". Would you like to create it? (Y/N)" createDir

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

# Ensure oracle knows about the directory to restore from
echo "$SCRIPT_DIR/setOracleDumpDir.sh $DB_PUMP_NAME $DB_DUMP_DIR $SYSTEM_USER $SYSTEM_PASS" 
$SCRIPT_DIR/setOracleDumpDir.sh $DB_PUMP_NAME $DB_DUMP_DIR $SYSTEM_USER $SYSTEM_PASS 1>/dev/null
#------------#
echo "DB_DUMP_DIR=${DB_DUMP_DIR}"
echo "DMP_FILE=${DMP_FILE}"
#------------#

#operate in the user's data pump directory.
{

	 if [[ ( "${batchMODE}" == "N" ) || ( ! -f "${DB_DUMP_DIR}"/"${DMP_FILE}" ) ]];then
	   {
		unset DMP_FILE
		unset archive

		if [ ! -z $1 ] && [ -r ${DB_DUMP_DIR}/"$1" ]; then
		   export DMP_FILE=`basename $1 .tar.gz`
		   export archive="${DMP_FILE}.tar.gz"
		else
			if [ -r "$1.tar.gz" ]; then
				export DMP_FILE="$1"
				export archive="${DMP_FILE}.tar.gz"
			fi
		fi
		
		if [ -z $archive ] || [ ! -r ${DB_DUMP_DIR}/$archive ]; then
			promptUserForDBFile $1
		fi
	   }
	 fi

	
	# Set Log File Now that dump file was selected 
	export LOG=`pwd`/${OPERATION}_${DMP_FILE}.log
	
	#LOGSTAMP="`date +%Y%m%d%H%M`"
	if [ -f $LOG ]; then
		mv $LOG $LOG.bak$LOGSTAMP
	fi
	
	export start=`date +%s`

	echo "Current Directory: `pwd`"

	note "---------------------------------------------"
	note "${GREEN}Restoring "
	note "  from dump file \"${archive}\"${RESET}"
	note "Working directory: `pwd`"
	note "Import directory: ${DB_DUMP_DIR}"
	note "Restore log: \"$LOG\""
	note "---------------------------------------------"

	spacecheck $DB_DUMP_DIR "${SPACE_CHK_MIN_MBYTES}" 
	extractDumpFile $DMP_FILE

	compareDmpSchemasToCurrent $DMP_FILE
	echo "Current Directory: `pwd`"
	
	if [ $REMAP -eq 0 ] && [ $TABLEMATCH -eq 1 ]; then
		TYPE="DATAONLY"
	else
		TYPE="FULL"
	fi

##############
exit
##############
	#############################################################
	# CUTOFF FOR INTERACTIVE
	#############################################################


	echo "Current Directory: `pwd`"
        [[ -f nohup.out ]] && rm -f nohup.out     

	nohup ${SCRIPT_DIR}/restore_nohup.sh "$DMP_FILE" "$LOG" "$TYPE" "$SYSTEM_USER" "$SYSTEM_PASS"   > "$LOG" &

	note "------------"
	note "Going silent.  You can log out, you will receive an email in 40 minutes."
	note "------------"

if [ ! -z $OWNER ] && [ ! -z $EMAIL ]; then

mail -s "{DB} Restore: `whoami` started on ${TNS}@`hostname`." -c $OWNER $EMAIL<<EOF
DB Restore started at `date`
EOF

else
        alert "No Email Addresses for $OPERATION script.  Please review values here $SCRIPT_DIR/common_sdt.sh"
fi

}
