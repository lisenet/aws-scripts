# aws-scripts
Various scripts to make AWS management easier.

Developed and tested (mainly) on Debian Wheezy with Bash 4.2 and Python 2.7:

<pre># apt-get install python2.7 python-pip
# pip install awscli</pre>

<pre>$ aws --version
aws-cli/1.3.4 Python/2.7.3 Linux/3.2.0-4-amd64</pre>

## bulk-mod-of-aws-security-groups
Bash script that opens a TCP/UDP/ICMP port on all AWS security groups. Script requires Python and aws cli.

## create-ec2-instance
Bash script that creates a new EC2 instance inside a VPC from an AMI. Script requires Python and aws cli.

## ses-smtp-converter
Bash script that converts AWS IAM user's credentials to Amazon SES SMTP credentials. Script requires OpenSSL.

### Usage
<pre>$ ./ses-smtp-conv.sh AWSAccessKeyID AWSSecretAccessKey</pre>
