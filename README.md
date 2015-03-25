# aws-scripts
Various scripts to make AWS management easier.

Developed and tested (mainly) on Debian Wheezy with Bash 4.2 and Python 2.7:
```
# apt-get install python2.7 python-pip
# pip install awscli
```
```
$ aws --version
aws-cli/1.3.4 Python/2.7.3 Linux/3.2.0-4-amd64
```

## backup-audit-aws
Python script that connects to AWS, calculates a number of snaphosts availabe for each volume and sends a summary (a .csv file) via email. 

The script can check multiple AWS accounts. You need to have AWS access and secret keys, plus your AWS account ID. Account ID is used by *get_all_snapshots* and *get_all_images*.

SMTP server details are required if you want to send emails.

The **_getFreeSnapshots_** function can be used to remove snapshots that have:
* no AMI *and*
* no existing volume.

This function is not called by default. 

### Usage
`$ python ./backup-audit-aws.py`

## bulk-mod-of-aws-security-groups
Bash script that opens a TCP/UDP/ICMP port on all AWS security groups. Script requires Python and aws cli.

## create-ec2-instance
Bash script that creates a new EC2 instance inside a VPC from an AMI. Script requires Python and aws cli.

## ses-smtp-converter
Bash script that converts AWS IAM user's credentials to Amazon SES SMTP credentials. Script requires OpenSSL.

### Usage
`$ ./ses-smtp-conv.sh AWSAccessKeyID AWSSecretAccessKey`
