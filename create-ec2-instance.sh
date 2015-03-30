#!/bin/bash
#--------------------------------------------
# Name:     CREATE AWS EC2 INSTANCE
# Author:   Tomas Nevar (tomas@lisenet.com)
# Version:  v1.0
# Licence:  copyleft free software
#--------------------------------------------
#
# Set of IAM permissions needed for the script:
# "ec2:DescribeImages",
# "ec2:DescribeInstanceAttribute",
# "ec2:DescribeInstanceStatus",
# "ec2:DescribeSubnets",
# "ec2:DescribeVpcs",
# "ec2:AllocateAddress",
# "ec2:AuthorizeSecurityGroupIngress",
# "ec2:AssociateAddress",
# "ec2:CreateSecurityGroup",
# "ec2:CreateTags",
# "ec2:RunInstances"
#
# Provide your AWS keys below
ACCESS_KEY="";
SECRET_KEY="";

# Default AMI ID to use, change it
AMI_ID="ami-00000000";

# Temp log files
TMP="/tmp/tmp.log";
AMI_FILE="/tmp/amis.log";
VPC_FILE="/tmp/vpcs.log";
SUBNET_FILE="/tmp/subnets.log";
SG_FILE="/tmp/secgroup.log"
INS_FILE="/tmp/instance.log";
VOL_FILE="/tmp/vol.log";
STATUS_FILE="/tmp/status.log";
EIP_FILE="/tmp/eip.log";

#############################################
# CHECK IF RUNNING AS ROOT                  #
#############################################
if [ "$EUID" -eq "0" ]; then
  echo "Please be nice and don't run as root.";
  exit 1;
fi
#############################################
# CHECK FOR AWS CLI INSTALLATION            #
#############################################
type aws >/dev/null 2>&1 || { echo "ERROR: I require awscli, but it's not installed. Aborting.
To fix this on Debian/Ubuntu, do:
# apt-get install python2.7 python-pip
# pip install awscli";
exit 1; };
#############################################
# CONFIGURE AWS CLI AND TRY TO CONNECT      #
#############################################
if [ ! -d ""$HOME"/.aws" ]; then
  mkdir "$HOME"/.aws ;
fi

cat > "$HOME"/.aws/config << EOL
[default]
region = eu-west-1
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
output = text
EOL

if aws ec2 describe-vpcs >/dev/null 2>&1; then
  echo -e "\nTest connection to AWS was successful.";
else
  echo -e "\nERROR: test connection to AWS failed. Please check the AWS keys.";
  exit 1;
fi
#############################################
# GATHER INFORMATION ABOUT THE NEW INSTANCE #
#############################################
echo -e "\n(1) Please type the new instance name in full (example: PROJECT-NAME):";
read NAME;
# Check if the string provided has the length of zero
if [ -z "$NAME" ];then
  echo "ERROR: The instance name you have provided is an empty string! Exiting.";
  exit 1;
fi
# Check if the string is no more than 20 characters
LENGTH="${#NAME}";
if ! [ "$LENGTH" -le "20" ] ; then
  echo "ERROR: The string you have supplied is too long (>20 chars) Exiting.";
  exit 1;
fi

echo -e "Making all letters uppercase and removing whitespaces if any.\n";
# Make all lowercase letter uppercase
NAME=$(echo "$NAME"|sed 's/./\U&/g');
# Remove all whitespaces
NAME="$(echo -e "${NAME}" | tr -d '[[:space:]]')"

while true; do
  read -p "Do you wish to use "$NAME" (y/n)? " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) echo "Exiting." && exit 1;;
    * ) echo "Please answer 'y' or 'n'.";;
  esac
done
#############################################
# GATHER INFORMATION ABOUT AMI              #
#############################################
# Get all AMIs where owner is the sender of the request
if ! aws ec2 describe-images --owners self >"$TMP";then
  echo -e "\nERROR: failed to describe images. Please check the AMI permissions.";
  exit 1;
fi

grep IMAGES "$TMP"|cut -f 6,7|awk '{print $2" "$1}'|cut -d"/" -f2|awk '{print $2" "$1}' >"$AMI_FILE";

AMI_COUNT=$(wc -l "$AMI_FILE"|cut -d" " -f1);
echo -e "\n(2) The number of AMIs found is "$AMI_COUNT". Listing:\n";
while read AMI
do
  echo "$AMI"
done <"$AMI_FILE";

# Ask which AMI to use
echo -e "\nWhich AMI do you want to use?
The default AMI to use is "$AMI_ID".
Please type the full AMI ID (i.e. ami-12345678) or '1' to use the default AMI:\n"
read AMI_TO_USE

if ! [ "$AMI_TO_USE" -eq "1" ] 2>/dev/null; then
  # Check if the VPC provided exists and if so, 
  if cut -d" " -f1 "$AMI_FILE"|grep -Fxq "$AMI_TO_USE"; then
    AMI_ID="$AMI_TO_USE";
  else
    echo "ERROR: the AMI you entered was not found. Exiting.";
    exit 1;
  fi
fi
#############################################
# GATHER INFORMATION ABOUT VPC              #
#############################################
# Get a list of all available VPCs
if ! aws ec2 describe-vpcs|grep "vpc-........"|cut -f2,7 >"$VPC_FILE"; then
  echo -e "\nERROR: failed to describe VPCs. Please check the AMI permissions.";
  exit 1;
fi

# Print all VPCs on a screen
VPC_COUNT=$(wc -l "$VPC_FILE"|cut -d" " -f1);
echo -e "\n(3) The number of VPCs found is "$VPC_COUNT". Listing:\n";
while read VPC
do
  echo "$VPC"
done <"$VPC_FILE";

# Ask which VPC to use
echo -e "\nWhich VPC do you want to use?
Please type the full VPC ID (i.e. vpc-12345678):\n"
read VPC_TO_USE

# Check if the VPC provided exists and if so, 
if cut -f2 "$VPC_FILE"|grep -Fxq "$VPC_TO_USE"; then
  VPC_ID="$VPC_TO_USE";
else
  echo "ERROR: the VPC you entered was not found. Exiting.";
  exit 1;
fi
#############################################
# GATHER INFORMATION ABOUT SUBNET           #
#############################################
# Get a list of all subnets for the VPC chosen
if ! aws ec2 describe-subnets|grep "$VPC_TO_USE"|cut -f2,4,8 >"$SUBNET_FILE"; then
  echo -e "\nERROR: failed to describe subnets. Please check the AMI permissions.";
  exit 1;
fi

# Print all subnets on a screen
SUBNET_COUNT=$(wc -l "$SUBNET_FILE"|cut -d" " -f1);
echo -e "\n(4) The number of subnets found for the VPC "$VPC_TO_USE" is "$SUBNET_COUNT". Listing:\n";
while read SUBNET
do
  echo "$SUBNET"
done <"$SUBNET_FILE";

# Ask which subnet to use
echo -e "\nWhich subnet do you want to use?
Please type the full subnet ID (i.e. subnet-12341234):\n"
read SUBNET_TO_USE

# Check if the subnet provided exists and if so, 
if cut -f3 "$SUBNET_FILE"|grep -Fxq "$SUBNET_TO_USE"; then
  SUBNET_ID="$SUBNET_TO_USE";
  AV_ZONE=$(grep "$SUBNET_TO_USE" "$SUBNET_FILE"|cut -f1);
else
  echo "ERROR: the subnet you entered was not found. Exiting.";
  exit 1;
fi
#############################################
# GATHER INFORMATION ABOUT MANAGEMENT PORT  #
#############################################
echo -e "\n(5) Please type a TCP port number that should be opened for VM management.
It may be 22 for SSH or 3389 for RDP or something else. This script is
limited to one port only. More ports can be opened from AWS Console.";

read PORT;

# Check if the string has the length of zero
if [ -z "$PORT" ];then
  echo "ERROR: The port you have provided is an empty string! Exiting.";
  exit 1;
fi

# Check if the string contains integers only
if ! [ "$PORT" -eq "$PORT" ] 2>/dev/null; then
  echo "ERROR: The port must contain integers only. Exiting."
  exit 1;
fi

# Remove all non numeric characters
PORT="${PORT//[!0-9]/}";

# Check if the string starts with a zero (0)
INT1=`echo "$PORT"|cut -c1`;
if [ "$INT1" -eq "0" ]; then
  echo "ERROR: The port cannot be zero or start with a zero. Exiting.";
  exit 1;
fi

# Check if the port is in the range of 1-65535 
if ! [[ "$PORT" -gt "0" && "$PORT" -le "65535" ]]; then
  echo "ERROR: Invalid port. Must be between 1 and 65535. Exiting.";
  exit 1;
fi
#############################################
# ASK FOR IP AND SUBNET MASK THAT SHOULD BE #
# ALLOWED ACCESS                            #
#############################################
echo -e "\n(6) Please type the IP address where access should be allowed from.
Example: 0.0.0.0 or 10.10.1.15
You will be asked for a subnet mask in the next step.";
read ACL_IP;

if [[ "$ACL_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  if ! [[ ${ACL_IP[1]} -le 255 && ${ACL_IP[2]} -le 255 && ${ACL_IP[3]} -le 255 && ${ACL_IP[4]} -le 255 ]]; then
    echo "ERROR: IP address "$ACL_IP" is invalid. Exiting."
    exit 1;
  fi
else
  echo "ERROR: The IP address "$ACL_IP" does not math IPv4 pattern. Exiting.";
  exit 1;
fi

echo -e "\n(7) Please type the subnet mask (between 0 and 32):";
read ACL_MASK;

if ! [[ "$ACL_MASK" -ge "0" && "$ACL_MASK" -le "32" ]]; then
    echo "ERROR: Subnet mask must be between 0 and 32. Exiting.";
    exit 1;
fi
#############################################
# VERIFICATION OF CIDF                      #
#############################################
CIDR=""$ACL_IP"/"$ACL_MASK"";
echo "";
while true; do
  read -p "Do you wish to use "$CIDR" (y/n)? " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) echo "Exiting." && exit 1;;
    * ) echo "Please answer 'y' or 'n'.";;
  esac
done
#############################################
# ASK FOR AN INSTANCE TYPE TO USE           #
#############################################
echo -e "\n(8) Which instance type do you want to use?\n";
OPTIONS=("t1.micro" "t2.small" "m1.small" "c1.medium" "m3.medium" "m3.large" "QUIT")
select INS_TYPE in "${OPTIONS[@]}"
do
  case "$INS_TYPE" in
    "t1.micro")
      echo "Your chose t1.micro."; break
      ;;
    "t2.small")
      echo "Your chose t2.small."; break
      ;;
    "m1.small")
      echo "You chose m1.small."; break
      ;;
    "c1.medium")
      echo "You chose c1.medium."; break
      ;;
    "m3.medium")
      echo "You chose m3.medium."; break
      ;;
    "m3.large")
      echo "You chose m3.large."; break
      ;;
    "QUIT")
      exit 0
      ;;
     *) echo Invalid option.;;
  esac
done
#############################################
# VERIFICATION OF INSTANCE DETAILS          #
#############################################
echo -e "\n(9) Details to use for the new "$NAME" instance:\n";
echo "AMI:     "$AMI_ID"";
echo "VPC:     "$VPC_ID"";
echo "SUBNET:  "$SUBNET_ID"";
echo "AV ZONE: "$AV_ZONE"";
echo -e "TYPE:    "$INS_TYPE"\n";

while true; do
  read -p "Do you wish to use continue (y/n)? " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) echo "Exiting." && exit 1;;
    * ) echo "Please answer 'y' or 'n'.";;
  esac
done
#############################################
# CREATE A SECURITY GROUP                   #
#############################################
echo -e "\nCreating "$NAME" security group.";
if ! aws ec2 create-security-group --group-name "$NAME" --description "$NAME" \
  --vpc-id "$VPC_ID" >"$SG_FILE"; then
  echo -e "\nERROR: failed to create a security group. Please check the AMI permissions.";
  exit 1;
fi
SECGRP_ID=$(cut -f1 "$SG_FILE");

if ! aws ec2 authorize-security-group-ingress --group-id "$SECGRP_ID" --protocol tcp \
  --port "$PORT" --cidr "$CIDR" >/dev/null; then
  echo -e "\nERROR: failed to modify a security group. Please check the AMI permissions.";
  exit 1; 
fi

echo "TCP port "$PORT" has been opened for "$CIDR" on the "$NAME" security group.";
#############################################
# CREATE A NEW AWS EC2 INSTANCE             #
#############################################
echo "Creating "$NAME" "$INS_TYPE" instance inside "$AV_ZONE".";
if ! aws ec2 run-instances  \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INS_TYPE" \
  --security-group-ids "$SECGRP_ID" \
  --disable-api-termination \
  --subnet-id "$SUBNET_ID" \
  --monitoring Enabled=false \
  --instance-initiated-shutdown-behavior stop \
  --no-ebs-optimized \
  --associate-public-ip-address >"$INS_FILE";then
  echo -e "\nERROR: failed to run a new instance. Please check the AMI permissions.";
  exit 1;
fi

# Get the instance ID
INS_ID=$(grep -wo "i-........" "$INS_FILE");
echo ""$NAME" instance has been started. Instance ID is: "$INS_ID"";
echo "Instance termination protection has been enabled.";
sleep 10;

echo "Adding "$NAME" tag to the new instance."
if ! aws ec2 create-tags --resources "$INS_ID" --tags Key=Name,Value="$NAME" >/dev/null; then
  echo -e "\nERROR: failed to create tags. Please check the AMI permissions.";
  echo "This error does not cause the script to terminate.";
fi

echo "Adding a name tag to the root volume.";
if ! aws ec2 describe-instance-attribute --instance-id "$INS_ID" \
  --attribute blockDeviceMapping >"$VOL_FILE"; then
  echo -e "\nERROR: failed to describe instance attributes. Please check the AMI permissions.";
  echo "This error does not cause the script to terminate.";
  exit 1;
fi
# Assuming that the first volume ID returned is the root one
VOL_ROOT=$(grep -wo "vol-........" "$VOL_FILE"|head -n1);
if ! aws ec2 create-tags --resources "$VOL_ROOT" \
  --tags Key=Name,Value=""$NAME" ROOT" >/dev/null; then
  echo -e "\nERROR: failed to create tags. Please check the AMI permissions.";
  echo "This error does not cause the script to terminate.";
fi

# Wait for the new instance to become available online
echo "Waiting for the new instance to initialise. This may take a while."
while true;do
  if ! aws ec2 describe-instance-status --instance-ids "$INS_ID" >"$STATUS_FILE"; then
    echo -e "\nERROR: failed to describe instance status. Please check the AMI permissions.";
    echo "This error does not cause the script to terminate.";
    # Wait for 60 seconds, break the loop and try to assign an EIP
    sleep 60;
    break;
  fi 

  if grep passed "$STATUS_FILE"; then
    echo "Instance "$NAME" has passed security checks on Amazon.";
    break;
  else
    echo "Instance is initialising. Script sleeping for 60 seconds..."
    sleep 60;
  fi
done

# Allocate an EIP for the new instance
# Abort if the limit for EIPs is reached
if aws ec2 allocate-address --domain vpc >"$EIP_FILE";then
  EIP_ALLOC=$(cut -f1 "$EIP_FILE");
  EIP_VALUE=$(cut -f3 "$EIP_FILE");
  echo "Allocating a new EIP "$EIP_VALUE" for the instance."
else
  echo "ERROR: The maximum number of EIP addresses has been reached. 
You may need to contact AWS support to increase the EIP limit for VPC.
Script has finished, but no EIP was assigned to the instance.";
  exit 1;
fi

# Associate the new EIP with the new instance
echo "Associating the new EIP "$EIP_VALUE" with the "$NAME" instance."
if ! aws ec2 associate-address --instance-id "$INS_ID" \
  --allocation-id "$EIP_ALLOC" >/dev/null; then
  echo -e "\nERROR: failed to associate an EIP address. Please check the AMI permissions.";
  echo "This error does not cause the script to terminate.";
fi

# Delete temp files
rm -f "$TMP" "$AMI_FILE" "$VPC_FILE" "$SUBNET_FILE" "$SG_FILE" \
  "$INS_FILE" "$VOL_FILE" "$STATUS_FILE" "$EIP_FILE";

exit 0;
