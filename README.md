# ansible-ec2-hadoop-cluster

Scripted deployment of a multi node HDP 2.5 (HDFS HA) in AWS (EC2) using
* Ansible Playbooks
* Ambari Blueprints

Suitable for testing potential Hadoop Sysadmin candidates in a real-world environment.

## Cluster Setup

Assumption is that the nodes are CentOS images. Ansible scripts are coded for CentOS 7.

Cluster consists of:
* *Master Node* - 2
* *Data Nodes* - You control the number
* *Tools Nodes* - 1 (runs Zeppelin)
* *Extra Data Nodes* - You control the number; these nodes are not initially in the cluster
* *UI Node* - A "minimal" Gnome Desktop is installed along with Firefox.

## Initial Setup

Sample commands to build this environment (note you should create an SSH key file to share with the candidate):

```
# text values to feed to the process
AWS_CREDENTIALS=~/.aws/credentials
AWS_PEMKEY=[FULL_PATH_TO_CREATED_SSH_KEY_FILE]
AWS_PEMKEYNAME='aws-hdp-tclu'
AWS_REGION='us-west-2'
AWS_REGION_AZ='us-west-2b'
AWS_VPC_NAME='lm-guest-env-01-vpc'
AWS_SUBNET_RANGE='172.20.242.16/28'
AWS_IGW_NAME='lm-guest-env-01-vpc-igw'

# hard-coded CentOS 7 image ID
AWS_AMI_ID='ami-d2c924b2'
AWS_SSH_LOGIN='centos'
AWS_PREFIX='lm-guest-env-01'

# lookups
AWS_CREDENTIAL_ACCESS_KEY_ID=$(cat $AWS_CREDENTIALS | grep -e 'aws_access_key_id' | awk -F'=' '{print $2}' | sed -e 's#\s##g')
AWS_CREDENTIAL_SECRET_ACCESS_KEY=$(cat $AWS_CREDENTIALS | grep -e 'aws_secret_access_key' | awk -F'=' '{print $2}' | sed -e 's#\s##g')
AWS_VPC_ID=$(aws-cli ec2 describe-vpcs --filter Name=tag:Name,Values=$AWS_VPC_NAME --query 'Vpcs[].VpcId' --output text | sed -e 's#\s##g')
AWS_IGW_ID=$(aws-cli ec2 describe-internet-gateways --filter Name=tag:Name,Values=$AWS_IGW_NAME --query 'InternetGateways[].InternetGatewayId' --output text | sed -e 's#\s##g')

# PASSWORDs:
# * Default is baked-in; see Ansible 'variables.yml' and Ambaria blueprint
# * You can use a different password.
# * Be sure you use the *same* password for the playbook / blueprint

# invoke with the options above...but prompt for all others
./start-here.sh \
  -a $AWS_CREDENTIAL_ACCESS_KEY_ID \
  -s $AWS_CREDENTIAL_SECRET_ACCESS_KEY \
  -r $AWS_REGION \
  -w $AWS_REGION_AZ \
  -v $AWS_VPC_ID \
  -u $AWS_SUBNET_RANGE \
  -g $AWS_IGW_ID \
  -i $AWS_AMI_ID \
  -o $AWS_SSH_LOGIN \
  -x $AWS_PREFIX \
  -p $AWS_PEMKEYNAME \
  -k $AWS_PEMKEY
```

Normal processing is to specify 2 data nodes initially, and 4 "extra" data nodes. Otherwise, the performance tests below can take a long time and your cluster keeps reporting under-replicated blocks.

## Post-Processing

1. *UI Node Access*. You can login to the UI node via VNC.
   * Use `[AWS_EC2_PUBLIC_IP]:5901` to access the server.
   * Password is whatever was placed in the Ansible variables file
<br />
1. *Cluster Start*. 
   * Should start automatically (normally less than 15 minutes).
   * Restart the data nodes (they will timeout waiting for the master nodes to install / start).
<br />
1. *Cluster Post-Process*.
   * After the cluster starts successfully, then execute the post-processing command emitted by the `start-here.sh` shell script above.
   * I have seen problems with my REST API calls to restart Atlas and Falcon services; to be sure everything is OK recommend restarting these services manually from Ambari UI.
   * Wait for the cluster to report completely clean (should be the case after Atlas / Falcon restarted).
<br />
1. *Smoke Test*. Now that the cluster is up and no warnings / alerts display, verify operations.
   * Login to Tools node (SSH).
   * Run the following:

        ```
        sudo su - hdfs
        hadoop jar \
          /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar \
          teragen 100000 ./test/10gsort/input
        exit
        ```

Runs cleanly? Then cluster is OK.

## Work with Candidate - Basic

The point of this test cluster is to permit testing. Here is a sample script:

1. *VNC Login*. Have the candidate verify that they can access the UI node via VNC (which verifies basic computer skills).
   * Get the UI node EC2 public DNS name from the EC2 AWS Console and paste it to the candidate.
   * The candidate will VNC connect to `[EC2-PUBLIC-DNS-NAME]:5901`
   * VNC Password: This should be the one you specified when you ran the `vncserver` command above.
   * CentOS Login Password: After opening VNC, the candidate is prompted for the "Login User" (`l.login`) password; this was set during cluster creation.
   * Have candidate start Firefox and login to the Ambari cluster. This will always be:

        ```
        http://edge.aws-test.local:8080
        ```

1. *SSH Login*. You should have generated an SSH key during cluster creation.
   * Share the private key with the candidate.
   * The candidate should know that the full key (including comments) must be pasted to a local text file.
   * The candidate should know that permissions must be no more than `0600` on the local text file.
   * The candidate must be able to login to any of the running nodes as the `centos` user.

        ```
        ssh -i [FULL_PATH_TO_LOCAL_KEY_FILE] centos@[AWS_EC2_DNS_NAME]
        ```

     If the candidate fails here...that's not a good sign.
<br />
1. *Hive and 'admin' User Home Directory*.
   * Click on the 9 boxes control menu to get to Hive view.
   * Service checks fail - missing 'admin' hdfs home.
   * Run some variant of this fix:

        ```
        sudo su - hdfs -c 'hdfs dfs -mkdir /user/admin; hdfs dfs -chown admin /user/admin'
        ```

## Work with Candidate - Tables and Backup

1. Use case: Convert sample CSV to any kind of table?
   * We did this through Hive
   * Can be any kind of table.
1. Ambari uses three databases (UMiami merged all into MySQL).
   * Identify each database in use - Ambari (PostgreSQL?), Hive (MySQL), Oozie (Built-in), HBase (Built-in). Have a
   * What is the backup strategy to use?
   * How to test a restore?

## Work with Candidate - Block Replication and Add Nodes

1. *Block Replication Problem*. Have the candidate track this down. Easy way: Use HDFS Config UI, filter on "replication". The `Block Replication` is set to 3. Ask candidate why this is a problem?
<br />
1. *Add more Data Nodes*. During the Ambari cluster create, you specified the number of "extra" data nodes to create. These nodes are available and can be added to the cluster.
   * Use the Add Host wizard.
   * "Install Options" dialog
     * Target Hosts: `extra1.aws-test.local` (that is the first data node). You can also add additional "extra" data nodes if they were created.
     * Host Registration Information: The candidate must know that they paste the entire SSH key into the Host Registration Information textbox. You may share with the candidate that the `SSH User Account` is `centos`.
   * "Confirm Hosts" dialog - Should report "Success" for registration and status checking.
   * "Assign Slaves and Clients". Use the same services as other Data Nodes (do not install the Client tools):
     * DataNode
     * NodeManager
     * RegionServer
     * Supervisor
   * The nodes will add, but will do so in a blocking (modal) browser window. Have the candidate open another Firefox tab and login to the cluster. You should see the background operation running. Have the candidate explain what is going on for the different jobs. How would a blocked job be handled?
<br />
1. *Under Replication Goes Down*. Verify that - over time - the under replicated blocks go down. Have candidate explain why.
<br />
1. *Generate Initial Load*. We use the SWIM benchmark (https://github.com/SWIMProjectUCB/SWIM/wiki).
   * Interviewer logs into Tools node as `centos`
   * Invoke the SWIM wrapper (it should be in the home directory):

        ```
        ./swim-integration.sh [NUM_DATA_NODES] [NUM_64MB_PARTITIONS]
        ```

        Use the number of data nodes you specified when building the cluster, and the number of 64MB partitions you want. Here's a typical usage:

        ```
        ./swim-integration.sh 2 100
        ```

   * The above command does a lot of work; pulls down code and compiles, sets up folders in HDFS, creates test data (which itself generates load), and then runs the benchmarks that run lots of jobs in the background. You can quiz the Hadoop admin on:
     * How well do Jobs Run?
     * Yarn Memory consumption (goes critical during the data generation phase)
     * Under-replicated blocks (goes critical under HDFS tab)
     * Here is some sample output from the build phase. Have the candidate explain it:

            ```
            17/01/24 20:16:54 INFO mapreduce.Job:  map 75% reduce 0%
            17/01/24 20:16:58 INFO mapreduce.Job:  map 77% reduce 0%
            17/01/24 20:17:02 INFO mapreduce.Job:  map 78% reduce 0%
            17/01/24 20:17:04 INFO mapreduce.Job:  map 79% reduce 0%
            17/01/24 20:17:16 INFO mapreduce.Job:  map 80% reduce 0%
            ```

   * You will know when the SWIM tests complete because 50 jobs will finish. Also, you will see no `RUNNING | ACCEPTED` jobs under the Yarn Resource Manager UI. Have the candidate find these values for you and tell you when the jobs are all finished.

       ```
       # to show jobs:
       cd /usr/hdp/current/hadoop-client/scriptsTest
       l_jobs=$(ls WorkGenLogs | sed -e 's#job-\([0-9]\+\).*#\1#' | sort -nr | head -n 1)
       echo " Job | Seconds" > /tmp/scriptsTest.log
       for i in $(seq 0 $l_jobs) ; do
         l_elapsed=$(cat ./WorkGenLogs/job-$i.txt | grep "The job took" | awk '{print $4}')
         printf " %3d | %7d\n" $i $l_elapsed >> /tmp/scriptsTest.log
       done
       cat /tmp/scriptsTest.log
       rm -f /tmp/scriptsTest.log
       ```
<br />
1. *Configuration Changes*. As deployed, there are various optimizations / restarts that can make the cluster go faster.
   * MapReduce2 - `Map Memory` and `AppMaster Memory` both can be bumped up to 2048MB. This in turn affects other parameters. Have the candidate explain why.

## Work with Candidate - Load Testing

Now that the cluster should be humming along with multiple data nodes, we can run some more load onto it.

1. General Notes:
   * Logon to the Tools node as `centos`
   * The script `./hdp-test-integration.sh` should exist. Run it without parameters.
   * As tests complete, you will have output available. Paste in portions of the output to have the candidate comment on what is going on. Here is an example:

        ```
        17/01/24 20:41:42 INFO fs.TestDFSIO: ----- TestDFSIO ----- : read
        17/01/24 20:41:42 INFO fs.TestDFSIO:            Date & time: Tue Jan 24 20:41:42 UTC 2017
        17/01/24 20:41:42 INFO fs.TestDFSIO:        Number of files: 10
        17/01/24 20:41:42 INFO fs.TestDFSIO: Total MBytes processed: 10000.0
        17/01/24 20:41:42 INFO fs.TestDFSIO:      Throughput mb/sec: 75.01256460457127
        17/01/24 20:41:42 INFO fs.TestDFSIO: Average IO rate mb/sec: 89.54175567626953
        17/01/24 20:41:42 INFO fs.TestDFSIO:  IO rate std deviation: 33.578914837457944
        17/01/24 20:41:42 INFO fs.TestDFSIO:     Test exec time sec: 52.858
        ```

1. *DFS IO* - This test writes 10GB of data to the HDFS file system. It will generate Yarn Memory warnings. The write portion of the test took quite a while to run, perhaps because of the under-replicated blocks were also auto-correcting.
<br />
1. *Terasort* - This test performs the standard Terasort benchmark with 3GB of data.
<br />
1. *NNBench* - Runs with 1000 files
<br />
1. *MRBench* - Runs with 50 jobs.

While the above is running - you should see the Under Replicated Blocks count go down. However, they may never quite reach zero. (In the test run I'm documenting as I write this, the block count is stuck at 2.) Have the candidate explain why this is so - how many data nodes must be added for the count to go down to zero?

## Work with Candidate - PigMix

The PigMix project (https://cwiki.apache.org/confluence/display/PIG/PigMix) is a set of queries used to test pig performance from release to release.

Here's how to run the test:

1. Logon to Tools node (centos user).
<br />
1. Run the `./pigmix-integration.sh` script. No parameters needed.
<br />
1. The script does a full build of pigmix which was quite a pain.
<br />
1. Even with the multiple 'extra' data nodes the process is slow.

