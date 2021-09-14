# Bitwarden custom scripts
By [Zidmann](mailto:emmanuel.zidel@gmail.com) :bow:

## Description
This project consists in developing some scripts to maintain the security of a device with Bitwarden server by upgrading regularly the system and backuping the data (keys, logs, configurations).
The backups will be encrypted and sent to a cloud environment in the case the Bitwarden hosting device collapsed without exposing the credentials.

## Prerequisites
* The user which launch the scripts must be 'bitwarden'
* The user managing Bitwarden must be 'bitwarden'
* The Bitwarden host system must be Debian
* The cloud environment must be Google Cloud Platform which supposes that you own an account or at least have access on bucket storage
* RSA private and public keys must be created previously and only the public one must be on the Bitwarden hosting machine

## Scheduling
The scripts will be scheduled by calling sched/main.sh every day at 03' when no user should use Bitwarden.
The Bitwarden application will be maintained up (and restarted if necessary) with the script sched/keep_up.sh scheduled every 2 hours.

Below the crontab configuration :
```bash
0 3 * * * /home/bitwarden/Bitwarden-CustomScripts/src/sched/main.sh >/dev/null 2>&1
0 */2 * * * /home/bitwarden/Bitwarden-CustomScripts/src/sched/keep_up.sh >/dev/null 2>&1
```

## Dependancies
* To ensure the link between Bitwarden host machine and Google Cloud Platform the Cloud SDK must be installed and configured.

## Directories
* src/ contains the Linux source which must be deployed on the Bitwarden hosting machine
* cloud/ contains the Terraform script to use on Google Cloud Platform

## Encryption
Bitwarden uses AES-CBC 256-bit encryption for the encrypted passwords, and PBKDF2 SHA-256 to derive your encryption key.
To secure the archive the AES-CBC 256-bit encryption method will be used another time with OpenSSL and the key file used will be encrypted itself with an RSA public key.

To build a RSA public and private key :
```bash
openssl genrsa -out bitwarden.pem 2048
openssl rsa -in bitwarden.pem -out bitwarden.pub -outform PEM -pubout
```

To decrypt the key and the archive :
```bash
# Step 1 - Decrypting the AES key file with private RSA key to pass.bin file
openssl rsautl -decrypt -inkey bitwarden.pem -in pass.<DATE>.<TIME>.bin.enc -out pass.bin

# Step 2 - Decrypting the archive to bitwarden.tar.gz file
openssl enc -aes-256-cbc -pbkdf2 -d -pass file:pass.bin -in bitwarden.<DATE>.<TIME>.tar.gz.enc -out bitwarden.tar.gz
```

To check the content in an archive :
```bash
tar -tvf bitwarden.tar.gz
```

## Install gsutil
All information are in this link <https://cloud.google.com/storage/docs/gsutil_install>

## GCP cloud setup

Set the environment variables (choose a unique PROJECT_ID)
```
PROJECT_ID=my-project-id
SERVICE_ACCOUNT=terraform-deployer
```

Authenticate
```
gcloud auth login
```

Create the GCP project where to store the backups
```
gcloud projects create $PROJECT_ID
```

Define service account dedicated to the Terraform script to build the different components
```
gcloud iam service-accounts create $SERVICE_ACCOUNT --project $PROJECT_ID
```

Create Service Account keys
```
gcloud iam service-accounts keys create tf/sa.json --iam-account $SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID
```

Grant admin roles (Storage/PubSub/CloudScheduler/CloudFunction/BigQuery) to the service account
```
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/storage.admin --project $PROJECT_ID
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/pubsub.admin --project $PROJECT_ID
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/cloudscheduler.admin --project $PROJECT_ID
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/cloudfunctions.admin --project $PROJECT_ID
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/bigquery.admin --project $PROJECT_ID
```

## GCP cloud configuration
To send backups to the Google Cloud Platform, you have to define new environment variables.
To do it you have to add in the file ~/.bashrc the content below :
```bash
BITWARDEN_BACKUP_TAR_BUCKET=gs://bitwardenbucket
BITWARDEN_BACKUP_KEY_BUCKET=gs://keybucket
BITWARDEN_BACKUP_SA_PATH=path_to_credential_file
```

The gsutil command which is used in the script push_data.sh to send the files to the storage is initiate by this line :
```bash
gcloud auth activate-service-account --key-file <BITWARDEN_BACKUP_SA_PATH>
```

## References
Before developing this code I looked for other public projects which create Bitwarden backups.
The one which inspired me the most is https://github.com/jamesonp/Bitwarden-Backup.
The project was not forked since I preferred in this case to start from nothing but the Bitwarden-Backup was used like a template.

