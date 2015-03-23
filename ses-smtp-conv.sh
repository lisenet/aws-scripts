#!/bin/bash
#--------------------------------------------
# Name:     SES SMTP CONVERTER
# Author:   Tomas Nevar (tomas@lisenet.com)
# Version:  v1.0
# Date:     14/10/2014 (dd/mm/yy)
# Licence:  copyleft free software
#--------------------------------------------
#
# Many thanks to: 
# http://blog.celingest.com/en/2014/02/12/new-ses-endpoints-creating-ses-credentials-iam-users/

# Check for OpenSSL installation, exit if not present
type openssl >/dev/null 2>&1 || { echo >&2 "I require OpenSSL, but it's not installed. Aborting."; exit 1; };

# If you want to provide the AWS keys below rather than supplying on a CLI,
# you can do so and comment out everything in between dashes (#---)
#IAMUSER="";
#IAMSECRET="";

#--------------------------------------------
IAMUSER="$1";
IAMSECRET="$2";

if [ "$#" -ne "2" ];then
  echo "Usage: ./ses-smtp-conv.sh <AWSAccessKeyID> <AWSSecretAccessKey>";
  echo "Alternatively, you can put the AWS keys in the script.";
  exit 1
fi
#--------------------------------------------

# You do not need to modify anything below this line
MSG="SendRawEmail";
VerInBytes="2";
VerInBytes=$(printf \\$(printf '%03o' "$VerInBytes"));

SignInBytes=$(echo -n "$MSG"|openssl dgst -sha256 -hmac "$IAMSECRET" -binary);
SignAndVer=""$VerInBytes""$SignInBytes"";
SmtpPass=$(echo -n "$SignAndVer"|base64);

echo "SMTP User: ""$IAMUSER";
echo "SMTP Pass: ""$SmtpPass";

exit 0
