#!/bin/bash
# pigmix-integration.sh, ABr
# Integrate PigMix with cluster (https://cwiki.apache.org/confluence/display/PIG/PigMix)

# this was a tough one. we must run as hdfs user.

########################################################################
# globals
g_pig_repo='http://apache.mirrors.hoobly.com/pig/latest/'

########################################################################
# pigmix functions (as hdfs)

# main entry point as hdfs user
function pigmix-integration-x-as-hdfs {
  local l_jar_cmd="$1"
  local l_latest_pig="$2"

  # create the work folder
  mkdir -p ~/proj/pig
  cd ~/proj/pig
  local l_pig_dir="$(pwd)"

  # pull down pig
  if [ ! -s ./pig.tar.gz ] ; then
    echo "Pull pig archive..."
    wget -O ./pig.tar.gz "${g_pig_repo}${l_latest_pig}.tar.gz"
  fi

  # extract
  local l_latest_pig_dir="$(find . -maxdepth 1 -name 'pig*' -type d 2>/dev/null | head -n 1)"
  if [ x"$l_latest_pig_dir" = x ]; then
    echo "Extract pig..."
    tar zxf ./pig.tar.gz
    l_latest_pig_dir="$(find . -maxdepth 1 -name 'pig*' -type d 2>/dev/null | head -n 1)"
  fi
  if [ x"$l_latest_pig_dir" = x ]; then
    echo "Unable to locate extracted pig version directory"
    return 1
  fi
  echo "Pig version dir: $l_latest_pig_dir"
  cd "$l_latest_pig_dir"

  # prepare
  echo "Setup hdfs folders..."
  hadoop fs -mkdir -p /user/pig/tests/data
  hadoop fs -rm -r /user/pig/tests/data/* 2>/dev/null

  # and run
  echo "Run pigmix..."
  ant -Dharness.hadoop.home=/usr/hdp/current/hadoop-client pigmix-deploy
}

########################################################################
# main entry point (no parms, as sudo-capable user)
function pigmix-integration-x-main {
  echo "Detected main entry as $(whoami)..."
  
  echo "Install ant..."
  sudo yum install -y ant

  echo "Copy script to hdfs user..."
  yes | sudo cp $(pwd)/pigmix-integration.sh /home/hdfs/
  sudo chown hdfs /home/hdfs/pigmix-integration.sh
  sudo chmod +x /home/hdfs/pigmix-integration.sh

  echo "Locate jar..."
  local l_jar_cmd=$(ls -la $(sudo find / -name jar -type f 2>/dev/null) | grep -e '^...x..x..x' | head -n 1 | awk '{print $9}')
  echo "  $l_jar_cmd"

  echo "Locate pig version..."
  local l_latest_pig="$(curl --silent $g_pig_repo | grep 'pig-[0-9.]\+\.tar\.gz' | sed -e 's#^.*\(pig-[0-9.]\+\)\(\.tar\.gz\).*#\1#')"
  echo "Latest pig: $l_latest_pig"

  # we must manually patch hdfs config *before* calling to hdfs.
  local l_hadoop_conf='/usr/hdp/current/hadoop-client/conf/hadoop-env.sh'
  local l_pig_jar="/home/hdfs/proj/pig/$l_latest_pig/build/$l_latest_pig-SNAPSHOT.jar"
  if ! grep --quiet -e "^export HADOOP_CLASSPATH=$l_pig_jar:" "$l_hadoop_conf" ; then
    echo "Patch $l_hadoop_conf..."
    sudo sed -i -e "s#^\(export HADOOP_CLASSPATH\)=\(.*\)#\1=$l_pig_jar:\2#" "$l_hadoop_conf"
  fi

  echo "Execute as hdfs..."
  sudo su - hdfs -c "/home/hdfs/pigmix-integration.sh as-hdfs '$l_jar_cmd' '$l_latest_pig'"
}

# conditionally run the main process; permits this script to be reused
if [ x"$1" = x ]; then
  # standard no-parms entry; assume run as sudo-capable user
  pigmix-integration-x-main
else
  if [ "x$1" != 'xsource-only' ]; then
    # assume called to run as a particular user (via sudo)
    the_entry="$1"; shift
    pigmix-integration-x-$the_entry $*
  fi
fi

