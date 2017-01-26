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

1. *UI Node Access*. VNC is *not* started on the node.
   * Login via SSH to the UI node.
   * Start VNC:

        ```
        sudo su - l.login
        vncserver
        exit
        ```

   * Now you can access the UI node from VNC. Use `[AWS_EC2_PUBLIC_IP]:5901` to access the server.
   * VNC password is whatever was placed in the Ansible variables file
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

