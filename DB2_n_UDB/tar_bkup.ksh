#!usr/bin/ksh
#
#
#
. ~/sqllib/db2profile
export myHost=`uname -a|awk '{print $2}'`
export TOOLZ_DIR=TOOLZ
export INSTANCE=$1
export DB_NAME=$2
export DB_NAME_CAPS=`echo $DB_NAME|tr '[a-z]' '[A-Z]'`
export DB2_USER=`whoami`
export myDate=`date +%y%m%d%H%M%S`
export SQLLIB=sqllib
export SCRIPT_DIR=scripts
export SQL_DIR=sql
export TMP_DIR=/tmp
#export DB2_ARCH_DIR=/db2/backup/db2archive/db2p01/DB_NAME/NODE0000/C0000003
export BACKUP_DIR=/dblogs/db_backup/$DB_NAME
export BACKUP_SCRIPT_DIR=${TOOLZ_DIR}/${SCRIPT_DIR}
export EXPORT_DIR=export
export TAR_DIR=$BACKUP_DIR
myARCDIR1=`db2 get db cfg for $DB_NAME|grep LOGARCHMETH1|cut -d":" -f2|awk '{print $1}'`
myARCDIR2=`echo $DB2INSTANCE`
myARCDIR3=`echo $DB_NAME|tr 'a-z' 'A-Z'`
myARCDIRALL=$myARCDIR1$myARCDIR2/$myARCDIR3/NODE0000/C00*
export DB2_ARCH_DIR=$myARCDIRALL
export mySCRIPT_NUM_DAYS_KEEP=90
#----------------------#
# Extract DB infor     #
#----------------------#
db2 connect to $DB_NAME
db2 get dbm cfg                     > $TMP_DIR/$DB_NAME.dbmcfg
db2 get db cfg for $DB_NAME         > $TMP_DIR/$DB_NAME.dbcfg
db2 get admin cfg                   > $TMP_DIR/$DB_NAME.admcfg
db2 get snapshot for all on $DB_NAME > $TMP_DIR/$DB_NAME.snapshot 
db2 get monitor switches            > $TMP_DIR/$DB_NAME.mon_sw
db2 get contacts                    > $TMP_DIR/$DB_NAME.contacts
db2look -d $DB_NAME -l -xd -f -e    > $TMP_DIR/$DB_NAME.db2look
db2mtrk -i -d -p -v                 > $TMP_DIR/$DB_NAME.mtrk
db2 get db cfg for $DB_NAME|grep \(|cut -d"(" -f2|sed 's/)//g'|sed 's/  / /g'|awk '$3 ~ /[A-Z0-9]/ {  print $0  }'|sed 's/=//'|awk '{print "update db cfg for $DB_NAME USING " $0, ";"}'|sort -u|tr [a-z] [A-Z]|egrep -i "on|off|auto|recover|_"|egrep -v "TSM|collate" > $TMP_DIR/$DB_NAME.setdbcfg 
db2 get snapshot for db on $DB_NAME|egrep "HADR|Role|State|Synchronization|Connection|Heart|Local host|Local service|Remote|timeout|position|Log gap" > $TMP_DIR/$DB_NAME.hadr_status
db2 connect reset;
db2licm -l show detail             > $TMP_DIR/$DB_NAME.install_info
export DB2_HOME=/home/db2inst1
export DBA_oncall=`cat $DB2_HOME/$TOOLZ_DIR/admin/.DBA_$DB_NAME.oncall`
export DB2_DIR=$DB2_HOME/sqllib
export LOG_DIR=`cat $TMP_DIR/$DB_NAME.dbcfg|grep "Path to log files"|cut -d"=" -f2`
#----------------------#
# Report Info
#----------------------#
echo 'INSTANCE          = ' $INSTANCE
echo 'DB_NAME           = ' $DB_NAME
echo 'DB_NAME_CAPS      = ' $DB_NAME_CAPS
echo 'DB2_USER          = ' $DB2_USER
echo 'DB2_HOME          = ' $DB2_HOME
echo 'DB2_DIR           = ' $DB2_DIR
echo 'SQLLIB            = ' $DB2_HOME/$SQLLIB
echo 'SCRIPT_DIR        = ' $DB2_HOME/$SCRIPT_DIR
echo 'SQL_DIR           = ' $DB2_HOME/$SQL_DIR 
echo 'BACKUP_SCRIPT_DIR = ' $DB2_HOME/$BACKUP_SCRIPT_DIR
echo 'BACKUP_DIR        = ' $BACKUP_DIR
echo 'EXPORT_DIR        = ' $BACKUP_DIR/$EXPORT_DIR
echo 'LOG_DIR           = ' $LOG_DIR
echo 'DB2_ARCH_DIR      = ' $DB2_ARCH_DIR
echo 'TAR_DIR           = ' $TAR_DIR
echo 'TMP_DIR           = ' $TMP_DIR
echo 'TOOLZ_DIR         = ' $DB2_HOME/$TOOLZ_DIR
echo 'DBA_oncall        = ' $DBA_oncall
echo 'myDate            = ' $myDate
echo '####################' 
echo '# Build Bkup SQL   #'
echo '####################' 
echo db2 connect to $DB_NAME\;                                      > $BACKUP_DIR/backup_$DB_NAME.sql
echo db2 BACKUP DATABASE  $DB_NAME ONLINE TO \"$BACKUP_DIR\" WITH 3 BUFFERS BUFFER 1024 PARALLELISM 3 UTIL_IMPACT_PRIORITY 50 INCLUDE LOGS WITHOUT PROMPTING\;          >> $BACKUP_DIR/backup_$DB_NAME.sql
#cat  $BACKUP_DIR/backup_$DB_NAME.sql
chmod 700 $BACKUP_DIR/backup_$DB_NAME.sql
#-----------------------------------------#
# Remove old backups and logs
#-----------------------------------------#
find $BACKUP_DIR/archive/. -type f -mtime ${mySCRIPT_NUM_DAYS_KEEP}  -name 'DB_NAME.0.db2p01.NODE0000.CATN0000*.gz' -exec rm -f {} \;
find $DB2_ARCH_DIR/. -type f -mtime ${mySCRIPT_NUM_DAYS_KEEP}  -name '*.gz' -exec rm -f {} \;
find $LOG_DIR/. -type f -mtime ${mySCRIPT_NUM_DAYS_KEEP}  -name '*.LOG' -exec rm -f {} \;
#-----------------------------------------#
# Move zip current backups and archive
#-----------------------------------------#
gzip -f $BACKUP_DIR/*.001
mv $BACKUP_DIR/*.001.gz $BACKUP_DIR/archive/.
mv $BACKUP_DIR/*.LOG* $BACKUP_DIR/archive/.
rm $BACKUP_DIR/*.LOG
rm $BACKUP_DIR/*.001
gzip -f $DB2_ARCH_DIR/*.LOG
#
# AT THIS POINT, THE DB IMAGE COPYS ARE
# ARCHIVED and BACKUP_DIR should not have
# any backup images.
#   Any new logs are taken during backup.
#
#-----------------------------------------#
# Clean the current log file
#-----------------------------------------#
echo '####################' 
echo '# Switch logs       ' 
echo '####################' 
echo 'db2 archive log for database $DB_NAME;'
db2 archive log for database $DB_NAME > @tmp.3
cat  @tmp.3
myRC=`cat @tmp.3|grep -i "The ARCHIVE LOG command completed successfully"|wc -l`
if [ $myRC -ne 1 ]
   then
      echo $0 failed|mailx -s $myHost $DBA_oncall
   else
       cat @tmp.3
fi
rm  @tmp.3
#-----------------------------------------#
# copy current logs to archive dir
#-----------------------------------------#
###########################################
# TAKE BACKUP
###########################################
echo '####################' 
echo '# TAKE BACKUP'
echo '####################' 
. $BACKUP_DIR/backup_$DB_NAME.sql > @tmp.1
cat @tmp.1
#>>> END BACKUP
myTIMESTMP=`cat @tmp.1|grep timestamp|awk '{print $NF}'`
#>>> END BACKUP
echo '#>>> END BACKUP'
db2 archive log for database $DB_NAME > @tmp.4
echo '####################' 
echo '# Backup Info.     #'
echo '####################' 
#echo db2 db2 list history backup since $myTIMESTMP for db $DB_NAME 
db2 list history backup since $myTIMESTMP for db $DB_NAME > @tmp.2 
cat @tmp.2
echo '#------------------#'
echo '# End Backup Info. #'
echo '#------------------#'
###########################################
# Take Export
###########################################
cd $BACKUP_DIR/$EXPORT_DIR
#db2move $DB_NAME_CAPS export

###########################################
# SAVE LOGS
###########################################
cp $DB2_ARCH_DIR/*.LOG $BACKUP_DIR
#-----------------------------------------#
# SAVE Supplementary INFO
#-----------------------------------------#
cp  $TMP_DIR/$DB_NAME.dbmcfg         $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.dbcfg          $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.admcfg         $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.snapshot       $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.mon_sw         $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.contacts       $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.db2look        $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.mtrk           $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.setdbcfg       $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.hadr_status    $BACKUP_DIR
cp  $TMP_DIR/$DB_NAME.install_info   $BACKUP_DIR
crontab -l >                         $BACKUP_DIR/crontab.sav
cp ~/sqllib/db2profile               $BACKUP_DIR
env >                                $BACKUP_DIR/$DB2_USER.env.sav
#-----------------------------------------#
# Create TAR of Backup Dir and 
# add SQLLIB to TAR
#-----------------------------------------#
echo '####################' 
echo '# TAR Inventory     ' 
echo '####################' 
cd $BACKUP_DIR
tar  -cvf  DB2_DATABASE.tar  /dev/null 
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $DB_NAME_CAPS.*
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $DB_NAME.*
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar *.LOG
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $DB2_USER.*
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $TOOLZ_DIR 
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $EXPORT_DIR
cd $DB2_HOME
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $SQLLIB 
tar  -Xuvf $BACKUP_SCRIPT_DIR/scripts/exclude.txt $BACKUP_DIR/DB2_DATABASE.tar $SCRIPT_DIR 
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $SQL_DIR 
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $BACKUP_SCRIPT_DIR 
tar  -uvf  $BACKUP_DIR/DB2_DATABASE.tar $TOOLZ_DIR 
echo '##########################################'
echo '# END of Backup Job'
echo '##########################################'
for i in ${BACKUP_SCRIPT_DIR} ${BACKUP_DIR} ${DB2_HOME}
{
     for j in 1 2 3 4 5 6 7 8 9 0
         {
            rm $i/@tmp.$j
            rm @tmp.$j
         }
}
rm   $TMP_DIR/$DB_NAME.dbmcfg $TMP_DIR/$DB_NAME.dbcfg $TMP_DIR/$DB_NAME.admcfg $TMP_DIR/$DB_NAME.snapshot $TMP_DIR/$DB_NAME.mon_sw $TMP_DIR/$DB_NAME.contacts $TMP_DIR/$DB_NAME.db2look $TMP_DIR/$DB_NAME.mtrk $TMP_DIR/$DB_NAME.setdbcfg $TMP_DIR/$DB_NAME.hadr_status $TMP_DIR/$DB_NAME.install_info   

