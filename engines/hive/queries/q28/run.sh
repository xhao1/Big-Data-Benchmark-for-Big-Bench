#!/usr/bin/env bash

#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

TEMP_TABLE1="${TEMP_TABLE}_training"
TEMP_DIR1="$TEMP_DIR/$TEMP_TABLE1"
TEMP_TABLE2="${TEMP_TABLE}_testing"
TEMP_DIR2="$TEMP_DIR/$TEMP_TABLE2"

BINARY_PARAMS+=(--hiveconf TEMP_TABLE1=$TEMP_TABLE1 --hiveconf TEMP_DIR1=$TEMP_DIR1 --hiveconf TEMP_TABLE2=$TEMP_TABLE2 --hiveconf TEMP_DIR2=$TEMP_DIR2)

HDFS_RESULT_FILE="${RESULT_DIR}/classifierResult.txt"
HDFS_RAW_RESULT_FILE="${RESULT_DIR}/classifierResult_raw.txt"

query_run_main_method () {
	QUERY_SCRIPT="$QUERY_DIR/$QUERY_NAME.sql"
	if [ ! -r "$QUERY_SCRIPT" ]
	then
		echo "SQL file $QUERY_SCRIPT can not be read."
		exit 1
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 1 ]] ; then
		echo "========================="
		echo "$QUERY_NAME step 1/7: Executing hive queries"
		echo "tmp result in" ${TEMP_DIR1}
		echo "tmp result in" ${TEMP_DIR2}
		echo "========================="

		# Write input for k-means into temp tables
		runCmdWithErrorCheck runEngineCmd -f "$QUERY_SCRIPT"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	SEQ_FILE_1="$TEMP_DIR/Seq1"
	SEQ_FILE_2="$TEMP_DIR/Seq2"
	VEC_FILE_1="$TEMP_DIR/Vec1"
	VEC_FILE_2="$TEMP_DIR/Vec2"

	MAHOUT_TEMP_DIR="$TEMP_DIR/mahout_temp"

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 2 ]] ; then
		echo "========================="
		echo "$QUERY_NAME step 2/7: Generating sequence files"
		echo "Used Command: "mahout seqdirectory -i "$TEMP_DIR1" -o "$SEQ_FILE_1" -ow
		echo "Used Command: "mahout seqdirectory -i "$TEMP_DIR2" -o "$SEQ_FILE_2" -ow
		echo "tmp result in: $SEQ_FILE_1"
		echo "tmp result in: $SEQ_FILE_2"
		echo "========================="
		runCmdWithErrorCheck hadoop jar "${BIG_BENCH_QUERIES_DIR}/Resources/bigbenchqueriesmr.jar" io.bigdatabenchmark.v1.queries.q28.ToSequenceFile "${TEMP_DIR1}" "$SEQ_FILE_1"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
		runCmdWithErrorCheck hadoop jar "${BIG_BENCH_QUERIES_DIR}/Resources/bigbenchqueriesmr.jar" io.bigdatabenchmark.v1.queries.q28.ToSequenceFile "${TEMP_DIR2}" "$SEQ_FILE_2"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 3 ]] ; then
		echo "========================="
		echo "$QUERY_NAME step 3/7: Generating sparse vectors from sequence files"
		echo "Used Command: "mahout seq2sparse -i "$SEQ_FILE_1" -o "$VEC_FILE_1" -ow -lnorm -nv -wt tfidf
		echo "Used Command: "mahout seq2sparse -i "$SEQ_FILE_2" -o "$VEC_FILE_2" -seq -ow -lnorm -nv -wt tfidf
		echo "tmp result in: $VEC_FILE_1" 
		echo "tmp result in: $VEC_FILE_2"
		echo "========================="
		#runCmdWithErrorCheck mahout seq2sparse -i "$SEQ_FILE_2" -o "$VEC_FILE_2" -seq -ow -lnorm -nv -wt tfidf
		runCmdWithErrorCheck mahout seq2sparse -i "$SEQ_FILE_1" -o "$VEC_FILE_1" -ow -lnorm -nv -wt tfidf
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
		runCmdWithErrorCheck mahout seq2sparse -i "$SEQ_FILE_2" -o "$VEC_FILE_2" -ow -lnorm -nv -wt tfidf
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 4 ]] ; then
		echo "========================="
		echo "$QUERY_NAME step 4/7: Training Classifier"
		echo "Used Command: "mahout trainnb -i "$VEC_FILE_1/tfidf-vectors" -o "$TEMP_DIR/model" -el -li "$TEMP_DIR/labelindex" -ow 
		echo "tmp result in: $TEMP_DIR/model"
		echo "========================="
		runCmdWithErrorCheck mahout trainnb --tempDir "$MAHOUT_TEMP_DIR" -i "$VEC_FILE_1/tfidf-vectors" -o "$TEMP_DIR/model" -el -li "$TEMP_DIR/labelindex" -ow
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 5 ]] ; then
		echo "========================="
		echo "$QUERY_NAME step 5/7: Testing Classifier"
		echo "Used Command: "mahout testnb -i "$VEC_FILE_2/tfidf-vectors" -m "$TEMP_DIR/model" -l "$TEMP_DIR/labelindex" -ow -o "$TEMP_DIR/result"
		echo "tmp result in: $TEMP_DIR/result"
		echo "========================="

		runCmdWithErrorCheck mahout testnb --tempDir "$MAHOUT_TEMP_DIR" -i "$VEC_FILE_2/tfidf-vectors" -m "$TEMP_DIR/model" -l "$TEMP_DIR/labelindex" -ow -o "$TEMP_DIR/result" |& tee >( grep -A 300 "Standard NB Results:" | hadoop fs  -copyFromLocal -f - "$HDFS_RESULT_FILE" )
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 6 ]] ; then
		echo "========================="
		echo "$QUERY_NAME step 6/7: dump result to hdfs"
		echo "IN: $TEMP_DIR/result/part-m-00000"
		echo "OUT: $HDFS_RAW_RESULT_FILE"
		echo "========================="

		runCmdWithErrorCheck mahout seqdumper --tempDir "$MAHOUT_TEMP_DIR" -i "$TEMP_DIR/result/part-m-00000" | hadoop fs -copyFromLocal -f - "$HDFS_RAW_RESULT_FILE"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 7 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 7/7: Clean up"
		echo "========================="
		runCmdWithErrorCheck runEngineCmd -f "${QUERY_DIR}/cleanup.sql"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
		runCmdWithErrorCheck hadoop fs -rm -r -f "$TEMP_DIR"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	echo "========================="
	echo "to display : hadoop fs -cat $HDFS_RESULT_FILE"
	echo "to display raw : hadoop fs -cat $HDFS_RAW_RESULT_FILE"
	echo "========================="
}

query_run_clean_method () {
	runCmdWithErrorCheck runEngineCmd -e "DROP TABLE IF EXISTS $TEMP_TABLE1; DROP TABLE IF EXISTS $TEMP_TABLE2; DROP TABLE IF EXISTS $RESULT_TABLE;"
	runCmdWithErrorCheck hadoop fs -rm -r -f "$HDFS_RESULT_FILE"
	runCmdWithErrorCheck hadoop fs -rm -r -f "$HDFS_RAW_RESULT_FILE"
	return $?
}

query_run_validate_method () {
	VALIDATION_TEMP_FILE="`mktemp -u`"
	runCmdWithErrorCheck hadoop fs -copyToLocal "$HDFS_RESULT_FILE" "$VALIDATION_TEMP_FILE"
	if [ `wc -l < "$VALIDATION_TEMP_FILE"` -ge 1 ]
	then
		echo "Validation passed: Query returned results"
	else
		echo "Validation failed: Query did not return results"
	fi
	rm -rf "$VALIDATION_TEMP_FILE"
}
