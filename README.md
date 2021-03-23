# Bitwarden custom scripts
By [Zidmann](mailto:emmanuel.zidel@gmail.com) :bow:

## Description
This project consists in developing some scripts to maintain the security of a device with Bitwarden server by upgrading regularly the system and backuping the data (keys, logs, configurations).
The backups will be encrypted and sent to a cloud environment in the case the Bitwarden hosting device collapsed without exposing the credentials.

## Source
Before developing this code I looked for other public projects which create Bitwarden backups.
The one which inspired me the most is https://github.com/jamesonp/Bitwarden-Backup.
The project was not forked since I preferred in this case to start from nothing but the Bitwarden-Backup was used like a template.

## Prerequisites
* The user managing Bitwarden must be 'bitwarden'
* The Bitwarden host system must be Debian
* The cloud environment must be Google Cloud Platform which supposes that you own an account or at least have access on bucket storage
* RSA private and public keys must be created previously and only the public one must be on the Bitwarden hosting machine

## Scheduling
The scripts will be scheduled by calling sched/main.sh every day at 02' when no user should use Bitwarden.

Below the crontab configuration :
```bash
0 2 * * * /root/Bitwarden-CustomScripts/src/sched/main.sh >/dev/null 2>&1
```

## Dependancies
* To ensure the link between Bitwarden host machine and Google Cloud Platform the Cloud SDK must be installed and configured.

## Directories
* src/ contains the Linux source which must be deployed on the Bitwarden hosting machine
* gcp/ contains the Terraform script to use on Google Cloud Platform

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

