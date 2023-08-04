#!/bin/bash

# script to update overpass database from open street maps change files (osc).
# Geofabrik.de generates osc files DAILY for many areas.
#
# This script is part of my Guide for overpass installation and setup for limited
# area on Linux Slackware system. The Guide repository can be found here:
# "https://github.com/waelhammoudeh/overpass-4-slackware"
#
# Input:
# Script input is a text file named "newerFiles.txt" produced by "getdiff"
# program and placed in its work directory. The file lists newly retrieved
# osc (differ) files and their corresponding state.txt files (in pairs) preceded
# by a path suffix - path part after "getdiff" download directory; to get full
# path we append the suffix below to our {DIFF_DIR}.
# The list is sorted in ascending order.
#
# example "newerFiles.txt" - it includes path suffix - not full path!
#
# /000/003/641.osc.gz
# /000/003/641.state.txt
# /000/003/642.osc.gz
# /000/003/642.state.txt
# /000/003/643.osc.gz
# /000/003/643.state.txt
# /000/003/644.osc.gz
# /000/003/644.state.txt
# /000/003/645.osc.gz
# /000/003/645.state.txt
# /000/003/646.osc.gz
# /000/003/646.state.txt
#
## end example "newerFiles.txt" FORMAT.
#
# Output:
# script empties the input file when done; we just renames it on exit.
#
# Notes & warnings:
# script will NOT work to update database initialed with "--keep-attic" switch
# This script should NOT run while my "op_area_update.sh" is running
# Script needs to run to completion to avoid corrupted database.

# function to check database directory
# directory can be real or a link to directory, directory can not be empty.
check_database_directory() {
    local DIR=$1
    # we check for just few files
    local REQUIRED_FILES=("node_keys.bin" "relation_keys.bin" "way_keys.bin" "transactions.log")

    if [ -L "$DIR" ] || [ -d "$DIR" ] && [ -n "$(ls -A "$DIR")" ]; then
        for file in "${REQUIRED_FILES[@]}"; do
            if [ ! -e "$DIR/$file" ]; then
                echo "Error: Required file: ($file) not found in the database directory."
                return 1
            fi
        done
    else
        echo "Error: The database directory ($DIR) does not exist or is not a symbolic link to a non-empty directory."
        return 1
    fi
#    echo "$0: Directory $DIR checked okay"
    return 0
}

OP_USR_ID=367

if [[ $EUID -ne $OP_USR_ID ]]; then
    echo "$0: ERROR Not overpass user! You must run this script as the \"overpass\" user."
    echo ""
    echo " This script is part of the Guide for \"overpassAPI\" installation and setup on"
    echo "Linux Slackware system. The Guide repository can be found here:"
    echo "https://github.com/waelhammoudeh/overpass-4-slackware"
    echo ""

    exit 1
fi

# file system root directory
SYS_ROOT=/var/lib

# overpass directory
OP_DIR=$SYS_ROOT/overpass

# overpass database directory
DB_DIR=$OP_DIR/database

# getdiff Work Directory
GETDIFF_WD=$OP_DIR/getdiff

# getdiff download directory
DIFF_DIR=$GETDIFF_WD/diff

# log file directory
LOG_DIR=$OP_DIR/logs

# script log file : TODO: get script name from shell
LOGFILE=$LOG_DIR/op_update_db.log

# input to script "newerFiles.txt"
NEWER_FILES=$GETDIFF_WD/newerFiles.txt

# executables directory
EXEC_DIR=/usr/local/bin

# exectables we use
OP_CTL=$EXEC_DIR/op_ctl.sh
DISPATCHER=$EXEC_DIR/dispatcher
UPDATER=$EXEC_DIR/update_database
OSM3S_EXEC=$EXEC_DIR/osm3s_query

# area template - path installed by my Slackware package
AREA_TEMPLATE=/usr/local/rules/areas.osm3s

# call check_database_directory() function to verify database directory
check_database_directory "$DB_DIR"
if [[ ! $? -eq 0 ]]; then
    echo "$0: Error failed check_database_directory() function!"
#    echo "$(date '+%F %T'): Error failed check_database_directory() function" >>$LOGFILE
    exit 1
fi

if [[ ! -d $LOG_DIR ]]; then
    mkdir $LOG_DIR
fi

# create log file
touch $LOGFILE

if [[ ! $? -eq 0 ]]; then
    echo "$0: Error failed to create log file"
    exit 1
fi

echo "$(date '+%F %T'): op_update_db.sh started ..." >>$LOGFILE
echo "$(date '+%F %T'): database directory to update: $DB_DIR" >>$LOGFILE

# need error exit function maybe ... code & log msg?
ERR_FOOTER="x=x=x=x=x=x=x=x=x=x=x=x= Exiting with ERROR =x=x=x=x=x=x=x=x=x=x=x=x=x=x=x"

# check input file - it is NOT an error when file is empty or not found
if [[ ! -s $NEWER_FILES ]]; then
   echo "$0: NEWER_FILES: \"$NEWER_FILES\" not found or empty."
   echo "$0: Nothing to do with no new change files. Exiting"
   echo "$(date '+%F %T'): No new change files to update. Exiting." >>$LOGFILE
   echo "++++++++++++++++++++++++++ No New Change Files Found +++++++++++++++++++++++++++" >>$LOGFILE
   exit 0
fi

# check for executables we use

if [[ ! -x $OP_CTL ]]; then
    echo "$0: Error could not find \"op_ctl.sh\" control script"
    echo " Please install / reinstall overpass package"
    echo "$(date '+%F %T'): Error could not find \"op_ctl.sh\" control script" >>$LOGFILE
    echo $ERR_FOOTER >>$LOGFILE
    exit 1
fi

if [[ ! -x $DISPATCHER ]]; then
    echo "$0: Error could not find \"dispatcher\" executable"
    echo " Please install / reinstall overpass package"
    echo "$(date '+%F %T'): Error could not find \"dispatcher\" executable" >>$LOGFILE
    echo $ERR_FOOTER >>$LOGFILE
    exit 1
fi

if [[ ! -x $UPDATER ]]; then
    echo "$0: Error could not find \"update_database\" executable"
    echo " Please install or reinstall overpassAPI package"
    echo "$(date '+%F %T'): Error could not find \"update_database\" executable" >>$LOGFILE
    echo $ERR_FOOTER >>$LOGFILE
    exit 1
fi

if [[ ! -x $OSM3S_EXEC ]]; then
    echo "$0: Error could not find \"osm3s_query\" executable"
    echo " Please install / reinstall overpass package"
    echo "$(date '+%F %T'): Error could not find \"osm3s_query\" executable" >>$LOGFILE
    echo $ERR_FOOTER >>$LOGFILE
    exit 1
fi

# check for areas.osm3s template; needed to update areas
if [[ ! -s $AREA_TEMPLATE ]]; then
   echo "$0: Error: Areas template \"areas.osm3s\" not found or empty"
   echo "$(date '+%F %T'): Error: Areas template \"areas.osm3s\" not found or empty" >>$LOGFILE
   echo $ERR_FOOTER >>$LOGFILE
   exit 1
fi

# multiple overpass databases could be present in one machine
# ensure that we are updating the database currently managed
# by the dispatcher.

# dispatcher needs to be running to get database directory {INUSE_DIR}
if (! pgrep -f $DISPATCHER 2>&1 > /dev/null) ; then
   echo " Error: overpass dispatcher program is not running !!!"
   echo "$(date '+%F %T'): Error dispatcher is not running " >>$LOGFILE
   echo $ERR_FOOTER >>$LOGFILE
   exit 1
fi

# "dispatcher --show-dir" returns current database directory
INUSE_DIR=$($DISPATCHER --show-dir)

if [[ $INUSE_DIR != "$DB_DIR/" ]]; then
   echo "Error: Not same INUSE_DIR and DB_DIR"
   echo "$(date '+%F %T'): Error dispatcher manages different database than destination" >>$LOGFILE
   echo $ERR_FOOTER >>$LOGFILE
   exit 1
fi

# all checks were good, lets go to work.

# initial an empty array
declare -a newFilesArray=()

# read NEWER_FILES placing each line in an array element
while IFS= read -r line
do
{
    newFilesArray+=($line)
}
done < "$NEWER_FILES"

# verify input:
# array length must be even number - file pairs
# a pair must have same file name number - .osc file & .state.txt file
length=${#newFilesArray[@]}

if [[ $length -lt 2 ]]; then
   echo "$0: Error number of lines is less than 2"
   echo "$(date '+%F %T'): Error number of lines in newer file is less than 2" >>$LOGFILE
   echo $ERR_FOOTER >>$LOGFILE
   exit 1
fi

echo "$(date '+%F %T'): Read input file with number of lines: $length" >>$LOGFILE

# is number EVEN?
rem=$(( $length % 2 ))
if [[ $rem -ne 0 ]]; then
   echo "$0: Error found ODD number of lines"
   echo "$(date '+%F %T'): Error found ODD number of lines in input file." >>$LOGFILE
   echo $ERR_FOOTER >>$LOGFILE
   exit 1
fi

# check that change file matches the very next state file
# checking ALL file pairs - it is ALL or NOTHING deal
# assumes list is sorted

# Note about variable names below:
#
# changeFileName: variable includes path suffix - /000/003/641.osc.gz
# changeName: file name only - 641.osc.gz
# changeFileNumber: number only - 641
# changeFile : full path - {DIFF_DIR}/000/003/641.osc.gz

# stateFileName: /000/003/641.state.txt
# stateName: 641.state.txt
# stateFileNumber 641
# stateFile {DIFF_DIR}/000/003/641.state.txt

i=0
j=0

while [ $i -lt $length ]
do
    j=$((i+1))
    changeFileName=${newFilesArray[$i]}
    stateFileName=${newFilesArray[$j]}

    # get file names ONLY - drop path part
    changeName=`basename $changeFileName`
    stateName=`basename $stateFileName`

    # get string number from file names
    changeFileNumber=`echo "$changeName" | cut -f 1 -d '.'`
    stateFileNumber=`echo "$stateName" | cut -f 1 -d '.'`

    # they better be the same numbers
    if [[ $changeFileNumber -ne $stateFileNumber ]]; then
        echo "$0: Error Not same files; change and state!"
        echo "changeFileName : $changeFileName"
        echo "stateFileName : $stateFileName"
        echo "$(date '+%F %T'): Error changeFileName and stateFileName do NOT match" >>$LOGFILE
        echo $ERR_FOOTER >>$LOGFILE
        exit 1
    fi

    # check they exist in diff directory
    changeFile=$DIFF_DIR$changeFileName
    stateFile=$DIFF_DIR$stateFileName
    if [[ ! -s $changeFile ]]; then
        echo "$0: Error missing or empty changeFile $changeFile"
        echo "$(date '+%F %T'): Error missing or empty changeFile" >>$LOGFILE
        echo $ERR_FOOTER >>$LOGFILE
        exit 1
    fi

    if [[ ! -s $stateFile ]]; then
        echo "$0: Error missing or empty stateFile $stateFile"
        echo "$(date '+%F %T'): Error missing or empty stateFile" >>$LOGFILE
        echo $ERR_FOOTER >>$LOGFILE
        exit 1
    fi

    # move to next pair
     i=$((j+1))
done

# done checking

# wait for op_update_areas.sh script to finish if running
SLEEP_FLAG=TRUE
AREA_UPDATE_SCRIPT=op_update_areas*

while [[ $SLEEP_FLAG = "TRUE" ]]; do
{
    # do NOT use -f switch as we are looking for process name & use quotes
    if ( pgrep "$AREA_UPDATE_SCRIPT"  2>&1 > /dev/null) ; then
        echo "$(date '+%F %T'): Areas are being updated; running \"op_update_areas.sh\" found" >>$LOGFILE
        echo "$(date '+%F %T'): Waiting 5 minutes; for \"Area Update\" script to finish!" >>$LOGFILE
        sleep 300
    else
        SLEEP_FLAG=FALSE
    fi

}; done

# dispatcher can not be running when using overpass "update_database" program
# stop dispatcher before updating
$OP_CTL stop 2>&1 >/dev/null

if [[ ! $? -eq 0 ]]; then
    echo "$0: Error could not stop dispatcher!"
    echo "$(date '+%F %T'): Error could not stop dispatcher! I think we are dead already?" >>$LOGFILE
    echo $ERR_FOOTER >>$LOGFILE
    exit 1
fi

# log stopped dispatcher message
echo "$(date '+%F %T'): stopped dispatcher daemon" >>$LOGFILE
echo "stopped dispatcher daemon"

# update_database changable options
META=--meta
FLUSH_SIZE=4
COMPRESSION=no

i=0
j=0

while [ $i -lt $length ]
do
    j=$((i+1))
    changeFileName=${newFilesArray[$i]}
    stateFileName=${newFilesArray[$j]}

    changeFile=$DIFF_DIR$changeFileName
    stateFile=$DIFF_DIR$stateFileName

    # get date string "YYYY-MM-DD" from state.txt & use as version number
    VERSION=`cat $stateFile | grep timestamp | cut -d 'T' -f -1 | cut -d '=' -f 2`

    echo "$(date '+%F %T'): applying update from:" >>$LOGFILE
    echo "                   Change File: <$changeFile>" >>$LOGFILE
    echo "                   File Dated: <$VERSION>" >>$LOGFILE

    echo " applying update from Change File: <$changeFile> Dated: <$VERSION>"

    # Usage: update_database [--db-dir=DIR] [--version=VER] [--meta|--keep-attic] [--flush_size=FLUSH_SIZE] [--compression-method=(no|gz|lz4)] [--map-compression-method=(no|gz|lz4)]

    gunzip <$changeFile | $UPDATER --db-dir=$DB_DIR \
                                   --version=$VERSION \
                                   $META \
                                   --flush-size=$FLUSH_SIZE \
                                   --compression-method=$COMPRESSION \
                                   --map-compression-method=$COMPRESSION 2>&1 >/dev/null

    if [[  ! $? -eq 0 ]]; then
        # set -e ????
        echo "$(date '+%F %T'): Failed to update from file $changeFile" >>$LOGFILE
        echo $ERR_FOOTER >>$LOGFILE
        exit 1
    fi

    echo "$(date '+%F %T'): done update from file $changeFile" >>$LOGFILE
    echo "done update from file $changeFile"

    # wait 1 seconds to update next changeFile
    sleep 1

    # move to next pair
     i=$((j+1))
done

# restart dispatcher
$OP_CTL start 2>&1 >/dev/null
if [[ ! $? -eq 0 ]]; then
    echo "$0: Error failed to restart dispatcher!"
    echo "$(date '+%F %T'): Error failed to restart dispatcher!" >>$LOGFILE
    echo $ERR_FOOTER >>$LOGFILE
    exit 1
fi

echo "$(date '+%F %T'): started dispatcher daemon again" >>$LOGFILE
echo "started dispatcher daemon again"

# make sure dispatcher started
sleep 2

# update areas data - we apply ALL changeFile(s) then use ONE area update call

# this is an experiment, database is not compromised.
# assumes rules directory path: /usr/local/rules
# set iCount to a lot smaller number compared to IMAX in "op_area_update.sh" script
# DO NOT SET LESS THAN TEN
# do NOT set < 10

iCount=10

echo "$(date '+%F %T'): @@@@ updating overpass areas: With Loop Counter = $iCount" >>$LOGFILE

for ((i=1; i<=$iCount; i++)); do
{
#   ionice -c 2 -n 7 nice -n 19 osm3s_query --progress --rules < areas.osm3s 2>&1 >/dev/null
   ionice -c 2 -n 7 nice -n 19 $OSM3S_EXEC --progress --rules < $AREA_TEMPLATE 2>&1 >/dev/null
   sleep 3
}; done

echo "$(date '+%F %T'): @@@@ Done areas update; Loop Counter: $iCount" >>$LOGFILE
echo " @@@@ Done areas update; Loop Counter: $iCount"

# empty input file; rename using RENAME_TAG
RENAME_TAG=updated_op_db

mv $NEWER_FILES $NEWER_FILES.$RENAME_TAG

echo "$(date '+%F %T'): Moved $NEWER_FILES TO: $NEWER_FILES.$RENAME_TAG" >>$LOGFILE

echo "$(date '+%F %T'): ---------------------------------------- DONE --------------------------------------" >>$LOGFILE
echo "$0: All Done."

exit 0