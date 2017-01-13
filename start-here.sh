#/bin/sh
###
#
# ansible-ec2-hadoop-cluster
# Written by: Jeffrey Aven
#             Aven Solutions Pty Ltd
#             http://avensolutions.com
#
# Prerequisities:
#    PEM File needs to be present in the Ansible control node users home directory
#    Permissions need to be set to 400
#
###

# local variables
SCRIPT=`basename ${BASH_SOURCE[0]}`
g_local_ansible="~/.ansible"
g_local_inventory="$g_local_ansible/local_inventory/ansible-ec2-hadoop-cluster"
g_rc=0

# little function to get user input
function read_entry {
  local l_prompt="$1"
  local l_read_opts="$2"
  local l_value="$3"
  local l_default="$4"

  # anything to do?
  [ x"$l_value" != x ] && echo "$l_value" && return 0

  # display prompt (with optional default)
  local l_prompt_display="$l_prompt"
  [ x"$l_default" != x ] && l_prompt_display="$l_prompt [$l_default]"

  # read the value and get the result
  eval read -p "'$l_prompt_display: '" $l_read_opts VAR
  local l_rc=$?

  # interpret the result - permit default value
  [ $l_rc -ne 0 ] && return $l_rc
  [ x"$VAR" = x ] && [ x"$l_default" != x ] && VAR="$l_default"
  [ x"$VAR" = x ] && return 1
  echo $VAR
  return 0
}

# clean up inventory directories
rm -rf "$g_local_inventory"

# read command line options
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc
while getopts a::s::r::w::v::u::g::i::o::x::p::k::n::d::e::m::l::z::q::c::h FLAG; do
  case "$FLAG" in
    a) AWS_ACCESS_KEY_ID="$OPTARG" ;;
    s) AWS_SECRET_ACCESS_KEY="$OPTARG" ;;
    r) AWS_REGION="$OPTARG" ;;
    w) AWS_REGION_AZ="$OPTARG" ;;
    v) AWS_VPC_ID="$OPTARG" ;;
    u) AWS_SUBNET_RANGE="$OPTARG" ;;
    g) AWS_IGW_ID="$OPTARG" ;;
    i) AWS_AMI_ID="$OPTARG" ;;
    o) AWS_SSH_LOGIN="$OPTARG" ;;
    x) AWS_PREFIX="$OPTARG" ;;
    p) PEMKEYNAME="$OPTARG" ;;
    k) PEMKEY="$OPTARG" ;;
    n) HDPCLUSTERNAME="$OPTARG" ;;
    d) HDPDOMAINNAME="$OPTARG" ;;
    e) EDGEINSTANCETYPE="$OPTARG" ;;
    m) MASTERINSTANCETYPE="$OPTARG" ;;
    l) DATAINSTANCETYPE="$OPTARG" ;;
    z) DATAVOLUMESIZE="$OPTARG" ;;
    c) DATACOUNT="$OPTARG" ;;
    b) BLUEPRINT="$OPTARG" ;;
    h)
      cat << EOF
Usage:
  $SCRIPT [options]

Options:
  -a - AWS Access Key
  -s - AWS Secret Key
  -r - AWS Region
  -w - AWS Region Availability Zone (AZ)
  -v - AWS Virtual Private Cloud (VPC) ID
  -u - AWS Subnet Range
  -g - AWS Internet Gateway (IGW) ID
  -i - AWS Amazon Machine Image (AMI) ID
  -o - AWS SSH Login name (e.g. 'centos' or 'ec2-user')
  -x - AWS Prefix (prepended to tag values)
  -p - AWS keypair name to use to access AWS
  -k - Private key file to use to access AWS
  -n - Name to use for the cluster
  -d - Domain Name to use for the cluster components
  -e - EC2 instance type for EDGE node
  -m - EC2 instance type for MASTER node
  -l - EC2 instance type for DATA node(s)
  -z - EC2 volume size (GB) to attach to each DATA node
  -c - Number of EC2 DATA node(s)
  -b - Name of the blueprint (assumed in 'blueprints' folder)
EOF
      exit 0;;
    *) echo "Invalid option '$FLAG'" ; exit 1 ;;
  esac
done

# enter values
AWS_REGION=$(read_entry 'Enter AWS_REGION' '' "$AWS_REGION" 'us-west-2')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_REGION_AZ=$(read_entry 'Enter AWS_REGION_AZ' '' "$AWS_REGION_AZ" 'us-west-2b')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_ACCESS_KEY_ID=$(read_entry 'Enter AWS_ACCESS_KEY_ID' '' "$AWS_ACCESS_KEY_ID")
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_SECRET_ACCESS_KEY=$(read_entry 'Enter AWS_SECRET_ACCESS_KEY' '-s' "$AWS_SECRET_ACCESS_KEY")
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_VPC_ID=$(read_entry 'Enter AWS_VPC_ID' '' "$AWS_VPC_ID" 'vpc-69832d0e')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_SUBNET_RANGE=$(read_entry 'Enter AWS_SUBNET_RANGE' '' "$AWS_SUBNET_RANGE" '172.20.242.16/28')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_IGW_ID=$(read_entry 'Enter AWS_IGW_ID' '' "$AWS_IGW_ID" 'igw-35106e51')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_AMI_ID=$(read_entry 'Enter AWS_AMI_ID' '' "$AWS_AMI_ID" 'ami-d2c924b2')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_SSH_LOGIN=$(read_entry 'Enter AWS_SSH_LOGIN' '' "$AWS_SSH_LOGIN" 'centos')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

AWS_PREFIX=$(read_entry 'Enter AWS_PREFIX' '' "$AWS_PREFIX" 'centos')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

HDPCLUSTERNAME=$(read_entry 'Enter HDP Cluster Name' '' "$HDPCLUSTERNAME")
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

HDPDOMAINNAME=$(read_entry 'Enter HDP Cluster Domain Name' '' "$HDPDOMAINNAME")
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

PEMKEYNAME=$(read_entry 'Enter AWS Keypair Name Name' '' "$PEMKEYNAME")
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

PEMKEY=$(read_entry 'Enter PEMKEY' '' "$PEMKEY" "$HOME/.ssh/id_rsa")
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc
[ ! -s "$PEMKEY" ] && echo "PEMKEY '$PEMKEY' does not exist or has zero size" && exit 2
g_pemkey_perms=$(stat --format '%a' "$PEMKEY")
if echo "$g_pemkey_perms" | grep --quiet -e '^[46]\([1-9].\|.[1-9]\)'; then
  echo "PEMKEY '$PEMKEY' has invalid permissions '$g_pemkey_perms'"
  exit 1
fi

EDGEINSTANCETYPE=$(read_entry 'Enter EDGE Instance Type' '' "$EDGEINSTANCETYPE" 'm3.medium')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

MASTERINSTANCETYPE=$(read_entry 'Enter MASTER Instance Type' '' "$MASTERINSTANCETYPE" 'm3.large')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

DATAINSTANCETYPE=$(read_entry 'Enter DATA Instance Type' '' "$DATAINSTANCETYPE" 'm3.large')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

DATAVOLUMESIZE=$(read_entry 'Enter DATA Volume Size (GB)' '' "$DATAVOLUMESIZE" '300')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

DATACOUNT=$(read_entry 'Enter DATA Node Count' '' "$DATACOUNT" '2')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

BLUEPRINT=$(read_entry 'Enter BLUEPRINT file name' '' "$BLUEPRINT" 'hdp-2-5-m1-m2-data')
g_rc=$?
[ $g_rc -ne 0 ] && exit $g_rc

# confirm
CONFTEXT="You are about to deploy a new cluster with the following properties:"
CONFTEXT="$CONFTEXT\n\nAWS_REGION=$AWS_REGION"
CONFTEXT="$CONFTEXT\nAWS_REGION_AZ=$AWS_REGION_AZ"
CONFTEXT="$CONFTEXT\nAWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
CONFTEXT="$CONFTEXT\nAWS_SECRET_ACCESS_KEY=*****"
CONFTEXT="$CONFTEXT\nAWS_VPC_ID=$AWS_VPC_ID"
CONFTEXT="$CONFTEXT\nAWS_SUBNET_RANGE=$AWS_SUBNET_RANGE"
CONFTEXT="$CONFTEXT\nAWS_IGW_ID=$AWS_IGW_ID"
CONFTEXT="$CONFTEXT\nAWS_AMI_ID=$AWS_AMI_ID"
CONFTEXT="$CONFTEXT\nAWS_SSH_LOGIN=$AWS_SSH_LOGIN"
CONFTEXT="$CONFTEXT\nAWS_PREFIX=$AWS_PREFIX"
CONFTEXT="$CONFTEXT\nHDP Cluster Name=$HDPCLUSTERNAME"
CONFTEXT="$CONFTEXT\nHDP Cluster Domain Name=$HDPDOMAINNAME"
CONFTEXT="$CONFTEXT\nPEMKEYNAME=$PEMKEYNAME"
CONFTEXT="$CONFTEXT\nPEMKEY=$PEMKEY"
CONFTEXT="$CONFTEXT\nEDGE Instance Type=$EDGEINSTANCETYPE"
CONFTEXT="$CONFTEXT\nMASTER Instance Type=$MASTERINSTANCETYPE"
CONFTEXT="$CONFTEXT\nDATA Instance Type=$DATAINSTANCETYPE"
CONFTEXT="$CONFTEXT\nDATA Volume Size=$DATAVOLUMESIZE"
CONFTEXT="$CONFTEXT\nDATA Node Count=$DATACOUNT"
CONFTEXT="$CONFTEXT\nBLUEPRINT=$BLUEPRINT"
CONFTEXT="$CONFTEXT\n\nPress [OK] to continue or [Ctrl+C] to cancel"
echo -n -e "$CONFTEXT"
read OK_PROMPT
g_rc=$?
echo ''
[ $g_rc -ne 0 ] && exit $g_rc

# sudo flags (see http://docs.ansible.com/ansible/intro_configuration.html#sudo-flags)
l_ansible_sudo_flags='-H -S'

# create instances
echo "Create instances..."
ANSIBLE_SUDO_FLAGS="'$l_ansible_sudo_flags'" \
AWS_REGION=$AWS_REGION \
AWS_REGION_AZ=$AWS_REGION_AZ \
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
AWS_VPC_ID=$AWS_VPC_ID \
AWS_SUBNET_RANGE=$AWS_SUBNET_RANGE \
AWS_IGW_ID=$AWS_IGW_ID \
AWS_AMI_ID=$AWS_AMI_ID \
AWS_SSH_LOGIN=$AWS_SSH_LOGIN \
AWS_PREFIX=$AWS_PREFIX \
HDPCLUSTERNAME=$HDPCLUSTERNAME \
HDPDOMAINNAME=$HDPDOMAINNAME \
PEMKEYNAME=$PEMKEYNAME \
PEMKEY=$PEMKEY \
EDGENODETYPE=$EDGEINSTANCETYPE \
MASTERNODETYPE=$MASTERINSTANCETYPE \
DATANODETYPE=$DATAINSTANCETYPE \
NUMNODES=$DATACOUNT \
EBSVOLSIZE=$DATAVOLUMESIZE \
BLUEPRINT=$BLUEPRINT \
ANSIBLE_HOST_KEY_CHECKING=False \
PATH="$PWD/scripts:$PATH" \
TOPFOLDER="$PWD" \
ansible-playbook -v ./ansible/create-instances.yml
echo ''

# configure cluster
echo "Configure cluster"
ANSIBLE_SUDO_FLAGS="'$l_ansible_sudo_flags'" \
HDPCLUSTERNAME=$HDPCLUSTERNAME \
HDPDOMAINNAME=$HDPDOMAINNAME \
AWS_SSH_LOGIN=$AWS_SSH_LOGIN \
PEMKEYNAME=$PEMKEYNAME \
PEMKEY=$PEMKEY \
NUMNODES=$DATACOUNT \
BLUEPRINT=$BLUEPRINT \
ANSIBLE_HOST_KEY_CHECKING=False \
PATH="$PWD/scripts:$PATH" \
TOPFOLDER="$PWD" \
ansible-playbook -v -i "$g_local_inventory/$HDPCLUSTERNAME/all_nodes" ./ansible/configure-cluster.yml
echo ''

