bkzones
=======

Script to backup SmartOS VMs (KVM and OS).

It uses zfs snapshot, zfs send, zfs receive. And it uses SSH to transfer the stuff.

Warning
=======

This script is **very far** from being reliable and secure.

Use at your own risk!

Installation
------------

On the global zone make a directory under /opt/custom (or whatever persistent directory)

```mkdir /opt/custom/bk```

Copy the shell script inside such dir.<br />
Create a file called ```excluded``` even if you plan to don't use it.

```excluded``` file will contain all the uuid of zones and KVM machines you don't want to backup

On the destination host, create a zpool to store the zfs dataset and the other files.

```zfs create zones/backup```

On the destination host, create a directory under the directory of the new zfs

```mkdir /zones/backup/indexes_and_conf/```

such directory will contain the index file ```/etc/zones/index``` of each GZ and the ```/etc/zones/*.xml``` files of each backed up zone.

Configuration
------------

Edit the script and change the variables in order to reflect your environment.<br />
Like:

- ```workdir="/opt/custom/bk"``` where is the script
- ```bkdestserver="yourbackup.server.host"``` the destination host (via SSH)
- ```bkdestdir="/zones/backup/indexes_and_conf"``` on the destination host the destination 
- ```sshparam="root@bkdestserver"``` user@destinationhost and any ssh parameter
- ```destinationpool="zones/backup"``` the destination zfs dataset (on the remote host)
