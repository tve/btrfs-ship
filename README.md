# btrfs-ship

Extremely simple bash scripts to create daily incremental snapshots of btrfs subvolumes on one server and pull them incrementally from another server.
Incrementals are rotated for one week, e.g. `@subvol-mon`, `@subvol-tue`, ... `@subvol-sun`.

TODO:

- script to start / repair incremental set-up

Expected set-up:

- btrfs subvolume at `/some/path/@subvol` on source server
- `btrfs-snap.sh /some/path/@subvol` run daily on source server
- ability of the destination server to ssh to source server
- `btrfs-pull.sh -r /dest/path -s @,@subvol -h srcserver:/some/path` run daily on dest server

Typical crontab entries:

``` cron
# btrfs snapshots just before midnight
55 23   * * *     root  /home/src/btrfs-ship/btrfs-snap.sh /mnt/ssd/@ /mnt/ssd/@home >>/var/log/btrfs-snap 2>&1
```

``` cron
# Mirror btrfs snapshots from srcserver
7  0    * * *   root    /home/btrfs-ship/btrfs-pull.sh -h srcserver:/mnt/ssd -s @ @home -r /mirror/srcserver >>/var/log/btrfs-pull 2>&1
```
