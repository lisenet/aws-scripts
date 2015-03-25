#--------------------------------------------
# Name:     AWS EC2 BACKUP AUDIT
# Author:   Tomas Nevar (tomas@lisenet.com)
# Version:  v1.0
# Licence:  copyleft free software
#--------------------------------------------
#
# Developed using Python 2.7 on Debian Wheezy
#
import boto.ec2
import csv
import datetime
import glob
import io
import os
import smtplib
import sys
import time

from email.mime.text import MIMEText
from email import Encoders
from email.MIMEBase import MIMEBase
from email.MIMEMultipart import MIMEMultipart

MACHINE = "AWS Backup Audit Server"
MAILSERVER = "mail.example.com"
FROMADDR = "backup-audit@example.com"
TOADDR = ["admin@example.com"]

# AWS IAM credentials for multiple accounts
authAWS_1 = {"aws_access_key_id": "", "aws_secret_access_key": ""}
authAWS_2 = {"aws_access_key_id": "", "aws_secret_access_key": ""}

mypath = "/tmp"
outputFile = mypath+ "/BackupAudit.txt"

# set the current server weekday to a variable
weekDay = datetime.datetime.today().weekday()

aaa=bbb=ccc=ddd=eee=0

def main():

    # (0 Monday - 6 Sunday)
    currentDay = "Today is: %s" % str(weekDay)
    print (currentDay)

    removeOldFiles()
    getAmazonList()
    sendAttachment()

def removeOldFiles():

    print ("Entering removeOldFiles routine.")

    try:
        filesToRemove = glob.glob(mypath+ "/*.csv")
        for filename in filesToRemove:
            os.remove(filename)
    except:
         print('Failed to remove old CSV files.')

def getAmazonList():

    print("Entering getAmazonList routine.")

    try:
        value = 1
        ec21 = boto.ec2.connect_to_region("eu-west-1", **authAWS_1)
        value = 2
        ec22 = boto.ec2.connect_to_region("eu-west-1", **authAWS_2)

    except Exception, e1:
        error1 = "Error1: %s" % str(e1)
        value = str(value)
        print(error1)
        email("Failed to login to AWS. ", error1+ "\n\nAccount: " +value+ "\n\nCredentials may have changed. Script exits here.")
        sys.exit(1)

    try:
        f1 = open(outputFile, 'w')
        f1.write("\nAmazon volume code, a volume name (if specified) and a number of backups found.\n\n\n")

        csvFile = timeStamped('BackupAudit.csv')
        c = csv.writer(open(csvFile, "wb"))
        c.writerow(["Account","numberOfSnapshots","haveExistingVolumes","haveAMI","have_noAMI_noVolume","snapsDeleted"])

        vol1 = ec21.get_all_volumes()
        snaps1 = ec21.get_all_snapshots(owner="000000000001")
        ami1 = ec21.get_all_images(owners="000000000001")

        vol2 = ec22.get_all_volumes()
        snaps2 = ec22.get_all_snapshots(owner="000000000002")
        ami2 = ec22.get_all_images(owners="000000000002")

        # you can add more AWS accounts here

        # does the file have any new records
        fileRecords = 0

        # AWS account 1
        do_once = 0
        getFreeSnapshots(vol1,snaps1,ami1,ec21,"AWS_1")
        c.writerow(["AWS_1",aaa,bbb,ccc,ddd,eee])

        for volume in vol1:
           b = 0
           for snapshot in snaps1:
                if (volume.id in snapshot.volume_id):
                  b += 1
           if ((b != 28) and (b != 29)): #(1 backup per day for 28 days total of 28)
            if (do_once == 0):
                c.writerow(["Volume ID","Volume Status","Volume Name (Tag)","Volume Size (GB)","No of Backups"])
                do_once = 1
            cd = str(volume.id)
            cs = str(volume.status)
            ct = str(volume.tags)
            cz = str(volume.size)
            cb = str(b)
            c.writerow([cd,cs,ct,cz,cb])
            f1.write(cd+"  "+cs+"  "+ct+"  "+cz+ "  " +cb+"\n")
            fileRecords += 1
           else:
            continue

        # AWS account 2
        do_once = 0
        getFreeSnapshots(vol2,snaps2,ami2,ec22,"AWS_2")
        c.writerow(["AWS_2",aaa,bbb,ccc,ddd,eee])

        for volume in vol2:
           b = 0
           for snapshot in snaps2:
                if (volume.id in snapshot.volume_id):
                  b += 1
           if ((b != 56) and (b != 57)): #(2 backups per day for 28 days total of 56)
            if (do_once == 0):
                c.writerow(["Volume ID","Volume Status","Volume Name (Tag)","Volume Size (GB)","No of Backups"])
                do_once = 1
            cd = str(volume.id)
            cs = str(volume.status)
            ct = str(volume.tags)
            cz = str(volume.size)
            cb = str(b)
            c.writerow([cd,cs,ct,cz,cb])
            f1.write(cd+"  "+cs+"  "+ct+"  "+cz+ "  " +cb+"\n")
            fileRecords += 1
           else:
            continue

	# You can add more AWS accounts here

        # Close the backup-audit.txt file
        f1.close()

    except Exception, e2:
        error2 = "Error2: %s" % str(e2)
        print(error2)
        email("Backup audit has failed. ", error2+ "\n\nPlease check the code. Script exits here.")
        sys.exit(1)

    # exit if no records were added to the backup file
    try:
        if (fileRecords == 0):
            sys.exit(0)

    except Exception, e3:
        error3 = "Error3: %s" % str(e3)
        print(error3)
        sys.exit(1)

def getFreeSnapshots(_vol,_snaps,_ami,_ec2,_name):

    print("Running getFreeSnapshots routine for: " +_name)

    amiList = []
    volumeList = []
    snapsDeleted=numberOfSnapshots=haveExistingVolumes=haveExistingVolumes=haveAMI=have_noAMI_noVolume=0

    try:
        for image in _ami:
            # the below line returns the first snapshot ID only
            # if AMI has more that one snapshot, this will fail
            ami_snapshot_id = image.block_device_mapping.current_value.snapshot_id
            amiList.append(ami_snapshot_id)

        for volume in _vol:
            volumeList.append(volume.id)

        for snaps in _snaps:
            numberOfSnapshots += 1

            # check for snapshots that have no AMI
            if snaps.id in amiList:
                haveAMI += 1
            else:
                # if one has no AMI, check for existing volumes
                if (snaps.volume_id in volumeList):
                    haveExistingVolumes += 1
                else:
                    # if one has no AMI nor existing volume anymore, create a record
                    have_noAMI_noVolume += 1
                    # you want to leave the line below commented out
                    #ec2.delete_snapshot(snaps.id)
                    #snapsDeleted += 1

        global aaa,bbb,ccc,ddd,eee
        aaa = numberOfSnapshots
        bbb = haveExistingVolumes
        ccc = haveAMI
        ddd = have_noAMI_noVolume
        eee = snapsDeleted
        print("numberOfSnapshots, haveExistingVolumes, haveAMI, have_noAMI_noVolume,snapsDeleted")
        print(numberOfSnapshots, haveExistingVolumes, haveAMI, have_noAMI_noVolume, snapsDeleted)
        print ""

    except Exception, e3:
        error3 = "Error3: %s" % str(e3)
        print(error3)
        email("Server: "+MACHINE+ ". Failed to purge 'free' snapshots.","Error3: " +str(e3))
        sys.exit(1)

def sendAttachment():

    print ("Entering sendAttachment routine.")

    try:
        csvFile = timeStamped('BackupAudit.csv')
        msg2 = MIMEMultipart()
        msg2['Subject'] = 'AWS Backup Audit Script'
        msg2.attach( MIMEText("No backups (or less than required) have been found for the following volumes. \n\nPlease check the file attached.") )
        k = MIMEBase('application', "octet-stream")
        k.set_payload(open(csvFile,"rb").read())
        Encoders.encode_base64(k)
        k.add_header('Content-Disposition', 'attachment; filename="%s"' % os.path.basename(csvFile))
        msg2.attach(k)
        s = smtplib.SMTP(MAILSERVER)
        s.sendmail(FROMADDR, TOADDR, msg2.as_string())

    except Exception, e4:
        error4 = "Error4: %s" % str(e4)
        print(error4)
        email("Failed to send the attachment. ", error4+ "\n\nPlease check the backup audit script. Script exits here.")
        sys.exit(1)

def email(subject,message):
    server = smtplib.SMTP(MAILSERVER)
    for add in TOADDR:
        msg1= "From: " +FROMADDR+"\nTo: "+add+"\nSubject: "+subject+"\n\r\n"+message
        server.sendmail(FROMADDR,add,msg1)

def timeStamped(fname, fmt=mypath+'/%d-%m-%Y_{fname}'):
    return datetime.datetime.now().strftime(fmt).format(fname=fname)

if __name__ == '__main__':
    main()
