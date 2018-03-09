#!/usr/bin/env bash
# Author: Ambroise Maupate

. `dirname $0`/ftp-credentials.sh || {
    echo "`dirname $0`/ftp-credentials.sh";
    echo 'Impossible to import your configuration.';
    exit 1;
}

mkdir -p /mnt/ftpbackup;
#
# Mount the FTP folder .
#
curlftpfs ${FTP_USER}:${FTP_PASS}@${FTP_HOST}:${FTP_PORT} /mnt/ftpbackup/;

# IF you need to use SFTP, use sshfs
# echo "${FTP_PASS}" | sshfs -p ${FTP_PORT} -o password_stdin ${FTP_USER}@${FTP_HOST}:. /mnt/ftpbackup;
 
# Remove every backup file older than 15 days.
# ATTENTION, make sure to find IN /mnt/ftpbackup/docker-bck
# not to delete files outside of your FTP folder.
#
find /mnt/ftpbackup/docker-bck/. -type f -ctime +15 -exec rm {} \;
#
# Unmount the FTP folder.
#
umount /mnt/ftpbackup;
