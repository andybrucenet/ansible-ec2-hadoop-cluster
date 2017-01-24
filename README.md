# ansible-ec2-hadoop-cluster

Scripted deployment of a multi node HDP 2.4 (HDFS HA) in AWS (EC2) using
Ansible Playbooks
Ambari Blueprints

## Initial Setup

Sample command to build this environment:

```
# text values to feed to the process
AWS_CREDENTIALS=~/.aws/credentials
AWS_PEMKEY=~/.ssh/aws-devenv-key.pem
AWS_PEMKEYNAME='aws-devenv-key'
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

Follow the instructions printed out; there will be a cluster post-processing step you need to
Workload:

1. Logon to Tools node.

2. Smoke test:

```
sudo su - hdfs
mkdir -p ./test/10gsort
hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar teragen 100000 ./test/10gsort/input
```

3. SWIM (https://github.com/SWIMProjectUCB/SWIM):

```
# one call does it all - as centos user
TARGET_DATA_NODES=2
TARGET_NUM_PARTITIONS=100
./swim-integration.sh $TARGET_DATA_NODES $TARGET_NUM_PARTITIONS
```

To show all jobs from above:

```
# to show jobs:
cd /usr/hdp/current/hadoop-client/scriptsTest
l_jobs=$(ls WorkGenLogs | sed -e 's#job-\([0-9]\+\).*#\1#' | sort -nr | head -n 1)
echo " Job | Seconds" ;
for i in $(seq 0 $l_jobs) ; do
  l_elapsed=$(cat ./WorkGenLogs/job-$i.txt | grep "The job took" | awk '{print $4}')
  printf " %3d | %7d\n" $i $l_elapsed
done
```

4. Benchmark Tests

```
# one call does it all - as centos user
./hdp-test-integration.sh
```



