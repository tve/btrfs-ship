#! /bin/bash -e
# use btrfs commands to create daily snapshots, with weekly rollover
# usage is something like btrfs-snap.sh /mnt/ssd/@ /mnt/ssd/@home

suffix=$(date +%a | tr 'A-Z' 'a-z')  # mon, tue, ...

date
for vol in "$@"; do
  [[ -d "$vol" ]] || ( echo "$vol not found"; exit 1 )
  age=$(( ( $(date +%s) - $(date +%s -r "$vol") ) / 3600))
  [[ age < 24 ]] && ( echo "$vol too recent ($age hours)"; exit 1)
  touch $vol
  btrfs subvolume delete $vol-$suffix 2>/dev/null || true
  btrfs subvolume snapshot -r $vol $vol-$suffix # prints a "Create snapshot ..." message
done
