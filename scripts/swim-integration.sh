#!/bin/bash
# swim-integration.sh, ABr
# Integrate SWIM with cluster (https://github.com/SWIMProjectUCB/SWIM)

# arguments:
#   number of data nodes in cluster
i_datanodes="$1"; shift
#   number of partitions to create (controls total bytes used)
i_numpartitions="$1"; shift

# globals
HADOOP_HOME=/usr/hdp/current
HADOOP_CLIENT="$HADOOP_HOME/hadoop-client"
MAPREDUCE_CLIENT="$HADOOP_HOME/hadoop-mapreduce-client"
g_datablock_size=67108864

# derived values
g_totalbytes=$((i_numpartitions * g_datablock_size))

# setup ssh client
if [ ! -s ~/.ssh/config ]; then
  cat > ~/.ssh/config << EOF
Host *
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null
EOF
  chmod 600 ~/.ssh/config
fi

# require git
sudo yum install -y git

# project setup
mkdir -p proj/git
cd proj/git
l_git_dir=$(pwd)
cd -
mkdir -p proj/data
cd proj/data
l_data_dir=$(pwd)

# pull if necessary
cd "$l_git_dir"
if [ ! -d ./SWIM ]; then
  git clone https://github.com/SWIMProjectUCB/SWIM.git
fi
cd ./SWIM/workloadSuite
l_swim_proj_dir=$(pwd)

# data and build setup
mkdir -p "$l_data_dir"/SWIM/data "$l_data_dir"/SWIM/build
cd "$l_data_dir"/SWIM/data
l_swim_data_dir=$(pwd)
cd "$l_data_dir"/SWIM/build
l_swim_build_dir=$(pwd)

# create synthetic workload
cd "$l_swim_proj_dir"
if [ ! -s "$l_swim_build_dir"/GenerateReplayScript.class ]; then
  echo "Compile GenerateReplayScript.java..."
  javac -g -d "$l_swim_build_dir" GenerateReplayScript.java
fi
if [ ! -s "$l_swim_data_dir/run-jobs-all.sh" ]; then
  echo "Generate scripts for synthetic workload..."
  yes | java -cp "$l_swim_build_dir" GenerateReplayScript \
    FB-2009_samples_24_times_1hr_0_first50jobs.tsv \
    600 \
    "$i_datanodes" \
    $g_datablock_size \
    $i_numpartitions \
    "$l_swim_data_dir" \
    workGenInput \
    workGenOutputTest \
    $g_datablock_size \
    WorkGenLogs \
    hadoop \
    WorkGen.jar \
    "$HADOOP_CLIENT/conf/workGenKeyValue_conf.xsl"
fi

# locate jar command (not necessarily in path...)
l_jar_cmd=$(ls -la $(sudo find / -name jar -type f 2>/dev/null) | grep -e '^...x..x..x' | head -n 1 | awk '{print $9}')

# MR job to write input data set
cd "$l_swim_proj_dir"
mkdir -p "$l_swim_build_dir"/hdfsWrite
if [ ! -s "$l_swim_build_dir"/hdfsWrite/HDFSWrite.class ]; then
  echo "Compile HDFSWrite.java..."
  javac -g -d "$l_swim_build_dir/hdfsWrite" \
    -classpath "$HADOOP_CLIENT"/client/\* \
    HDFSWrite.java
fi
if [ ! -s "$l_swim_build_dir"/HDFSWrite.jar ]; then
  echo "Build HDFSWrite.jar..."
  $l_jar_cmd -cvf "$l_swim_build_dir"/HDFSWrite.jar -C "$l_swim_build_dir/hdfsWrite" .
fi

# MR job to read/shuffle/write data with data ratios
cd "$l_swim_proj_dir"
mkdir -p "$l_swim_build_dir"/workGen
if [ ! -s "$l_swim_build_dir"/workGen/WorkGen.class ]; then
  echo "Compile WorkGen.java..."
  javac -g -d "$l_swim_build_dir/workGen" \
    -classpath "$HADOOP_CLIENT"/client/\* \
    WorkGen.java
fi
if [ ! -s "$l_swim_build_dir"/WorkGen.jar ]; then
  echo "Build WorkGen.jar..."
  $l_jar_cmd -cvf "$l_swim_build_dir"/WorkGen.jar -C "$l_swim_build_dir/workGen" .
fi

# setup xml file
cd "$l_swim_proj_dir"
yes | sudo cp ./randomwriter_conf.xsl ./workGenKeyValue_conf.xsl "$HADOOP_CLIENT"/conf/
sudo sed -i -e "s#4294967296#$g_totalbytes#" "$HADOOP_CLIENT"/conf/randomwriter_conf.xsl

# create work folder in hdfs
sudo su - hdfs -c "hdfs dfs -ls /user/$(whoami)" >/dev/null 2>&1
l_rc=$?
if [ $l_rc -ne 0 ]; then
  echo "Create folder for $(whoami)..."
  sudo su - hdfs -c "hdfs dfs -mkdir /user/$(whoami)"
  sudo su - hdfs -c "hdfs dfs -chown $(whoami) /user/$(whoami)"
fi

# generate the input
hdfs dfs -ls ./workGenInput/ >/dev/null 2>&1
l_rc=$?
if [ $l_rc -ne 0 ]; then
  echo "Generate input..."
  hadoop jar "$l_swim_build_dir"/HDFSWrite.jar \
    org.apache.hadoop.examples.HDFSWrite \
    -conf ${HADOOP_CLIENT}/conf/randomwriter_conf.xsl workGenInput
fi

# run the job in the background
echo "Running all jobs in background..."
sudo rm -fR "$HADOOP_CLIENT"/scriptsTest
sudo mkdir "$HADOOP_CLIENT"/scriptsTest
yes | sudo cp -r "$l_swim_data_dir"/* "$l_swim_build_dir"/WorkGen.jar "$HADOOP_CLIENT"/scriptsTest/
sudo chown -R $(whoami) "$HADOOP_CLIENT"/scriptsTest/
cd "$HADOOP_CLIENT"/scriptsTest
for i in $(seq 0 99) ; do
  sed -i -e "\$H;x;1,/^sleep/s/^sleep .*/\/usr\/bin\/sleep $((RANDOM % 30))/;1d" ./run-jobs-all.sh
done
nohup ./run-jobs-all.sh &

echo "Jobs running in background. Check job history for information."

