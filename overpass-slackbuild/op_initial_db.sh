#!/bin/bash

# initial_op_db.sh : script to initialize Overpass database; takes TWO arguments
# $1 : inputfile where file is any OSM data file supported by "osmium" program
# $2 : DB_DIR destination database directory - must be empty
#
# Scripts requires "osmium" to be installed.

SCRIPT_NAME=$(basename $0)

OP_USR_ID=367

if [[ $EUID -ne $OP_USR_ID ]]; then
    echo "$SCRIPT_NAME: ERROR Not overpass user! You must run this script as the \"overpass\" user."
    echo ""
    echo "This script is part of the Guide for \"overpassAPI\" installation and setup on"
    echo "Linux Slackware system. The Guide repository can be found here:"
    echo "https://github.com/waelhammoudeh/overpass-4-slackware"
    echo ""

    exit 1
fi

INFILE=$1
DB_DIR=$2

# EXEC_DIR : overpass bin directory from Slackware package
EXEC_DIR=/usr/local/bin

# update_database and osmium executables
UPDATE_EXEC=$EXEC_DIR/update_database
OSMIUM=$EXEC_DIR/osmium

# option to use - recommended is "--meta"
META=--meta

# WARNING avoid this option, NOT supported for limited area extract; has multiple issues.
# META=--keep-attic

# accepted values are one of [ no| gz | lz4 ]
COMPRESSION=no

# controls amount of RAM usage by "update_database" program.
# with 16 GB ram I set this to 4.
FLUSH_SIZE=8

set -e

if [[ -z $2 ]]; then
    echo "$SCRIPT_NAME: Error missing argument(s); 2 are required"
    echo "usage: $SCRIPT_NAME inputfile db_dir"
    echo "        where"
    echo " inputfile: OSM data file in any osmium supported file format"
    echo " db_dir: destination directory for Overpass database"
    exit 1
fi

# Ensure DB_DIR has a trailing slash using a regular expression
if [[ ! $DB_DIR =~ .*/$ ]]; then
    DB_DIR="$DB_DIR/"
fi

if [[ ! -d $DB_DIR ]]; then
    echo "$SCRIPT_NAME: Error could not find destination directory: $DB_DIR"
    echo " Please create the directory and change ownership to overpass."
    exit 1
fi

if [[ -n "$(ls -A $DB_DIR)" ]]; then
    echo "$SCRIPT_NAME: Error destination directory is not empty: $DB_DIR"
    echo " Please specify an empty directory."
    exit 1
fi

if [[ ! -s $INFILE ]]; then
    echo "$SCRIPT_NAME: Error could not find input file (maybe empty): $INFILE"
    exit 1
fi

if [[ ! -x $OSMIUM ]]; then
    echo "$SCRIPT_NAME: Error could not find \"osmium\" executable"
    echo " Please install osmium-tool package"
    exit 1
fi

if [[ ! -x $UPDATE_EXEC ]]; then
    echo "$SCRIPT_NAME: Error could not find \"update_database\" executable"
    echo " Please install or reinstall overpassAPI package"
    exit 1
fi

SEQ_NUM=$($OSMIUM fileinfo --no-progress -e -g header.option.osmosis_replication_sequence_number $INFILE)

TIMESTAMP=$($OSMIUM fileinfo --no-progress -e -g data.timestamp.last $INFILE)

REPLICATE_ID="replicate_id"

# osmconvert : is an alternative to osmium

# set -o pipefail --> $? get sets if either fails
set -o pipefail

# commands are run in a pipe:

$OSMIUM cat $INFILE -o - -f .osc | $UPDATE_EXEC --db-dir=$DB_DIR \
                                                --version=$TIMESTAMP \
                                                $META \
                                                --flush-size=$FLUSH_SIZE \
                                                --compression-method=$COMPRESSION \
                                                --map-compression-method=$COMPRESSION 2>&1 >/dev/null

# Check the exit status of the pipeline
if [[ $? -ne 0 ]]; then
    echo "$SCRIPT_NAME: Error Database initialization failed."
    exit 1
else
    echo "$SCRIPT_NAME: Database initialization successful."
    echo "  Timestamp Last Date: $TIMESTAMP"
    echo "  Input OSM data file Replication Sequence Number: $SEQ_NUM"
    echo "  Finishing up ..."
fi

# Write SEQ_NUM to replicate_id file - we do NOT use this!?
# somebody might need hourly or minutely updates ...
# Geofabrik has the files to trim "planet" .osc Change Files.
# I absolutely have no plans to do that, good luck.
echo "$SEQ_NUM" > "$DB_DIR$REPLICATE_ID"

# To make the custom output feature operational
# copy templates directory to database directory:
# this is where overpassAPI expects to them
TEMPLATES_DIR=/usr/local/templates

if [ -d ${TEMPLATES_DIR} ]; then
  cp -pR ${TEMPLATES_DIR} ${DB_DIR}
fi

echo "$SCRIPT_NAME is done."

exit 0
