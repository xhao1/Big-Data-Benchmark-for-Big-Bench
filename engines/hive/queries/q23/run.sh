#!/usr/bin/env bash

#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

RESULT_TABLE1="${RESULT_TABLE}1"
RESULT_DIR1="$RESULT_DIR/$RESULT_TABLE1"
RESULT_TABLE2="${RESULT_TABLE}2"
RESULT_DIR2="$RESULT_DIR/$RESULT_TABLE2"

BINARY_PARAMS+=(--hiveconf RESULT_TABLE1=$RESULT_TABLE1 --hiveconf RESULT_DIR1=$RESULT_DIR1 --hiveconf RESULT_TABLE2=$RESULT_TABLE2 --hiveconf RESULT_DIR2=$RESULT_DIR2)

query_run_main_method () {

	QUERY1_SCRIPT="$QUERY_DIR/q23_1.sql"
	if [ ! -r "$QUERY1_SCRIPT" ]
	then
		echo "SQL file $QUERY1_SCRIPT can not be read."
		exit 1
	fi

	QUERY2_SCRIPT="$QUERY_DIR/q23_2.sql"
	if [ ! -r "$QUERY2_SCRIPT" ]
	then
		echo "SQL file $QUERY2_SCRIPT can not be read."
		exit 1
	fi

	QUERY3_SCRIPT="$QUERY_DIR/q23_3.sql"
	if [ ! -r "$QUERY3_SCRIPT" ]
	then
		echo "SQL file $QUERY3_SCRIPT can not be read."
		exit 1
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 1 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 1/4: make view"
		echo "========================="
		runCmdWithErrorCheck runEngineCmd -f "$QUERY1_SCRIPT"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 2 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 2/4: make result 1"
		echo "========================="
		runCmdWithErrorCheck runEngineCmd -f "$QUERY2_SCRIPT"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 3 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 3/4: make result 2"
		echo "========================="
		runCmdWithErrorCheck runEngineCmd -f "$QUERY3_SCRIPT"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 4 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 4/4: cleanup"
		echo "========================="
		runCmdWithErrorCheck runEngineCmd -f "${QUERY_DIR}/cleanup.sql"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi
}

query_run_clean_method () {
	runCmdWithErrorCheck runEngineCmd -e "DROP VIEW IF EXISTS $TEMP_TABLE; DROP TABLE IF EXISTS $RESULT_TABLE1; DROP TABLE IF EXISTS $RESULT_TABLE2;"
	return $?
}

query_run_validate_method () {
	VALIDATION_TEMP_DIR="`mktemp -d`"
	runCmdWithErrorCheck runEngineCmd -e "INSERT OVERWRITE LOCAL DIRECTORY '$VALIDATION_TEMP_DIR' SELECT * FROM $RESULT_TABLE1 LIMIT 10;"
	if [ `wc -l < "$VALIDATION_TEMP_DIR/000000_0"` -ge 1 ]
	then
		echo "Validation passed: Query 1 returned results"
	else
		echo "Validation failed: Query 1 did not return results"
	fi
	rm -rf "$VALIDATION_TEMP_DIR/*"

	runCmdWithErrorCheck runEngineCmd -e "INSERT OVERWRITE LOCAL DIRECTORY '$VALIDATION_TEMP_DIR' SELECT * FROM $RESULT_TABLE2 LIMIT 10;"
	if [ `wc -l < "$VALIDATION_TEMP_DIR/000000_0"` -ge 1 ]
	then
		echo "Validation passed: Query 2 returned results"
	else
		echo "Validation failed: Query 2 did not return results"
	fi
	rm -rf "$VALIDATION_TEMP_DIR"
}
