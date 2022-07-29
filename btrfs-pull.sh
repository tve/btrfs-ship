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
echo "##### $0 starting" $(date) "#####"
echo "Root: $ROOT, Subs: $SUBS, Host: $REMOTE, Prefix: $PREFIX"

EXIT=0
for sv in ${SUBS//,/ }; do
  echo "=== Processing subvolume $sv" $(date)

  # get name of most recent local snapshot
  lsnap=$(cd $ROOT; ls -1rtd $sv-??? | tail -n 1)
  #echo lsnap=$lsnap
  #btrfs sub list -R $ROOT
  luuid="$(btrfs sub list -R $ROOT | grep "path $REMOTE/$lsnap" | head -1)"
  RE='received_uuid ([0-9a-f][-0-9a-f]*) path'
  if [[ "$luuid" =~ $RE ]]; then
    luuid=${BASH_REMATCH[1]}
    echo "Last local snap $lsnap : $luuid"
  else
    echo "No local snapshot found as base for incremental"
    EXIT=1
    continue
  fi

  # find corresponding remote snap
  rsnaps="$(ssh $REMOTE "btrfs sub list -u $PREFIX" )"
  if ! [[ "$rsnaps" =~ $luuid ]]; then
    echo Cannot find base snapshot on remote server
    EXIT=1
    continue
  fi

  # find most recent remote snap
  mr=($(ssh $REMOTE "ls -1rtd $PREFIX/$sv-???" | tail -n 1))
  if ! [[ "$mr" = $PREFIX/$sv-* ]]; then
    echo "No remote snap found ???"
    EXIT=1
    continue
  elif [[ "$mr" = "$PREFIX/$lsnap" ]]; then
    echo "No new remote snap found"
    EXIT=1
    continue
  fi

  br="$PREFIX/$lsnap"
  ml="$ROOT/$(basename ${mr})"
  echo "Fetching incremental from ${br} to ${mr} as $ml"
  btrfs subvolume delete $ml 2>/dev/null || true
  EX=0
  time ssh $REMOTE "btrfs send -p ${br} ${mr}" | \
    btrfs receive $ROOT || EX=1
  if [[ $EX -ne 0 ]]; then
      echo "You may have to ssh $REMOTE btrfs send ${mr} | btrfs receive $ROOT";
      EXIT=1
  fi
done
echo "=== Done, exit=$EXIT" $(date)
exit $EXIT
