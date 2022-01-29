#! /bin/bash -e
# Pull incremental btrfs snapshots from remote server
#
# Commandline options:
# -r root directory where local subvolumes and their snapshots are placed
# -s comma-separated subvolume list to snapshot and mirror
# -h hostname:prefix for remote server

TIMEFORMAT="Took %lR"

while getopts ":r:s:h:" opt; do
  case $opt in
    r) ROOT=$OPTARG ;;
    s) SUBS=$OPTARG ;;
    h) HOST=$OPTARG ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done
if [[ -z $ROOT ]] || [[ -z $SUBS ]] || [[ -z $HOST ]]; then
  echo "Usage: $0 -r root -s subvolumes -h hostname:prefix" >&2
  exit 1
fi
REMOTE="${HOST%*:*}"
PREFIX="${HOST#*:}"
echo "Root: $ROOT, Subs: $SUBS, Host: $REMOTE, Prefix: $PREFIX"

EXIT=0
for sv in ${SUBS//,/ }; do
  echo "=== Processing subvolume $sv" $(date)

  # get name of two most recent remote snapshots
  mr=($(ssh $REMOTE "ls -1rtd $PREFIX/$sv-???" | tail -n 2))
  if [[ ${#mr[*]} -lt 2 ]]; then
    echo Only ${#mr[*]} remote snaps found: "${mr[@]}", cannot ship incremental
    EXIT=1
    continue
  fi

  echo "Fetching incremental from ${mr[0]} to ${mr[1]}"
  btrfs subvolume delete $ROOT/$(basename ${mr[1]}) 2>/dev/null || true
  time ssh $REMOTE "btrfs send -p ${mr[0]} ${mr[1]}" | \
    ( btrfs receive $ROOT || ( \
      echo "You may have to ssh $REMOTE btrfs send ${mr[0]} | btrfs receive $ROOT"; \
      EXIT=1 ))
done
echo "=== Done, exit=$EXIT" $(date)
exit $EXIT
