#!/bin/bash
#--------------------------------------------
# Name:     BULK MOD OF AWS SECURITY GROUPS
# Author:   Tomas Nevar (tomas@lisenet.com)
# Version:  v1.0
# Licence:  copyleft free software
#--------------------------------------------
#
# IAM user permissions needed for the script:
# "ec2:AuthorizeSecurityGroupIngress",
# "ec2:DescribeSecurityGroups"
#
# Default parameters
SG_FILE="/tmp/secgroups.log";
SECGRP_ID=""; 
PROTOCOL="tcp"; # Default protocol to use
PORT="80"; # Default port to use
CIDR="0.0.0.0/0" # Default Classless Inter-Domain Routing

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
# ASK FOR A PROTOCOL TO USE                 #
#############################################
echo -e "\nWhat protocol do you want to use?.";
OPTIONS=("tcp" "udp" "icmp" "QUIT")
select PROTOCOL in "${OPTIONS[@]}"
do
  case "$PROTOCOL" in
    "tcp")
      echo "Your chose tcp."; break
      ;;
    "udp")
      echo "You chose udp."; break
      ;;
    "icmp")
      echo "You chose icmp."; break
      ;;
    "QUIT")
      exit 0
      ;;
     *) echo Invalid option.;;
  esac
done

#############################################
# IF TCP OR UDP HAS BEEN CHOSEN             #
#############################################
if [ "$PROTOCOL" == "tcp" ] || [ "$PROTOCOL" == "udp" ]; then
  # Ask for the new port that needs to be opened
  echo -e "\nPlease type the port number that should be opened (example: 80).";
  echo -e "Note that this port will be opened on all existing AWS security groups!";

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
fi

#############################################
# IF ICMP HAS BEEN CHOSEN                   #
#############################################
if [ "$PROTOCOL" == "icmp" ]; then
  PORT="-1";
  echo -e "Note that all ICMP will be allowed.";
fi

#############################################
# ASK FOR IP AND SUBNET MASK THAT SHOULD BE #
# ALLOWED ACCESS                            #
#############################################
echo -e "\nPlease type the IP address where access should be allowed from.
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

echo -e "\nPlease type the subnet mask (between 0 and 32):";
read ACL_MASK;

if ! [[ "$ACL_MASK" -ge "0" && "$ACL_MASK" -le "32" ]]; then
    echo "ERROR: Subnet mask must be between 0 and 32. Exiting.";
    exit 1;
fi

#############################################
# VERIFICATION                              #
#############################################
# CIDR to use for security groups
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
# CONFIGURE AWS CLI                         #
#############################################
if [ ! -d ""$HOME"/.aws" ]; then
  mkdir "$HOME"/.aws ;
fi

cat > "$HOME"/.aws/config << EOL
[default]
region = eu-west-1
aws_access_key_id = AWS_ACCESS_KEY_GOES_HERE
aws_secret_access_key = AWS_SECRET_KEY_GOES_HERE
output = json
EOL

#############################################
# GET A LIST OF ALL AWS SECURITY GROUPS     #
#############################################
echo -e "\nRetrieving a list of all AWS security groups.";
aws ec2 describe-security-groups|grep GroupId|cut -d'"' -f4 >"$SG_FILE";

#############################################
# MODIFY AWS SECURITY GROUPS                #
#############################################
for SECGRP_ID in `cat "$SG_FILE"`
do
  echo "Modifying "$SECGRP_ID"...";
  aws ec2 authorize-security-group-ingress --group-id "$SECGRP_ID" --protocol "$PROTOCOL" --port "$PORT" --cidr "$CIDR" >/dev/null;
done

# Remove log files
rm -f "$SG_FILE";

exit 0;
