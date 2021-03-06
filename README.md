# bkzones

This is a script to backup SmartOS VMs (KVM and OS zones).

It uses zfs snapshot, zfs send, zfs receive. And it uses SSH to transfer the stuff.

## Warning

This script is **very far** from being reliable and secure.

Use it at your own risk!

## Installation

On the global zone make a directory under /opt/custom (or whatever persistent directory)

```mkdir /opt/custom/bk```

Copy the shell scripts (bkzones.sh, bkzones.conf, nagios_nsca.sh, nagios_nsca.conf) inside such dir.<br />
Create a file called ```excluded``` even if you plan to don't use it.

```excluded``` file will contain all the uuid of zones and KVM machines you don't want to backup

On the destination host, create a zpool to store the zfs dataset and the other files.

```zfs create zones/backup```

On the destination host, create a directory under the directory of the new zfs

```mkdir /zones/backup/indexes_and_conf/```

such directory will contain the index file ```/etc/zones/index``` of each GZ and the ```/etc/zones/*.xml``` files of each backed up zone.

## Configuration

Edit the bkzones.conf file and change the variables in order to reflect your environment.<br />
Like:

- ```bkdestserver="yourbackup.server.host"``` the destination host (via SSH)
- ```bkdestdir="/zones/backup/indexes_and_conf"``` on the destination host the destination 
- ```sshparam="root@bkdestserver"``` user@destinationhost and any ssh parameter
- ```destinationpool="zones/backup"``` the destination zfs dataset (on the remote host, see above)

## Nagios passive check

Passing ```-n``` to the script, you can invoke the external script ```nagios_nsca.sh``` to send a passive check to Nagios, using the send_nsca command.<br />
Edit ```nagios_nsca.conf``` and ```send_nsca.cfg``` to suit your needs.

You must have a working send_nsca environment (see [this post](http://blogoless.blogspot.it/2013/08/using-sendnsca-from-smartos-global-zone.html) for a working setup).

## Logging

Passing ```-v``` to the script, logs are also displayed on standard output. Without this argument, only the log file is produced.
