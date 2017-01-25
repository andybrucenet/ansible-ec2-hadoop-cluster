#!/bin/bash
# hdp-test-integration.sh, ABr
# See http://www.michael-noll.com/blog/2011/04/09/benchmarking-and-stress-testing-an-hadoop-cluster-with-terasort-testdfsio-nnbench-mrbench/
# Heavily adapted and updated to work with HDP 2.5

# globals
HADOOP_HOME=/usr/hdp/current
HADOOP_CLIENT="$HADOOP_HOME/hadoop-client"
MAPREDUCE_CLIENT="$HADOOP_HOME/hadoop-mapreduce-client"

# setup mandatory output
sudo su - hdfs -c "hdfs dfs -ls /benchmarks" >/dev/null 2>&1
l_rc=$?
if [ $l_rc -ne 0 ]; then
  echo "Create /benchmarks folder for $(whoami)..."
  sudo su - hdfs -c "hdfs dfs -mkdir /benchmarks"
  sudo su - hdfs -c "hdfs dfs -chown $(whoami) /benchmarks"
fi

# test jars
l_jobclient_tests_jar="$MAPREDUCE_CLIENT/hadoop-mapreduce-client-jobclient-tests.jar"
l_mapreduce_examples_jar="$MAPREDUCE_CLIENT/hadoop-mapreduce-examples.jar"

echo "Test 1: TestDFSIO"
hadoop jar "$l_jobclient_tests_jar" TestDFSIO -clean
hadoop jar "$l_jobclient_tests_jar" TestDFSIO -write -nrFiles 10 -fileSize 1000
hadoop jar "$l_jobclient_tests_jar" TestDFSIO -read -nrFiles 10 -fileSize 1000

echo "Test 2: Terasort"
hadoop jar "$l_mapreduce_examples_jar" teragen 30000000 /user/$(whoami)/terasort-input
hadoop jar "$l_mapreduce_examples_jar" terasort /user/$(whoami)/terasort-input /user/$(whoami)/terasort-output
hadoop jar "$l_mapreduce_examples_jar" teravalidate /user/$(whoami)/terasort-output /user/$(whoami)/terasort-validate

echo "Test 3: NNBench"
hadoop jar "$l_jobclient_tests_jar" nnbench -operation create_write \
  -maps 12 -reduces 6 -blockSize 1 -bytesToWrite 0 -numberOfFiles 1000 \
	-replicationFactorPerFile 3 -readFileAfterOpen true \
	-baseDir /benchmarks/NNBench-`hostname -s`

echo "Test 4: MRBench"
hadoop jar "$l_jobclient_tests_jar" mrbench -numRuns 10

