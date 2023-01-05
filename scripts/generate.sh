#!/bin/sh
OPID=`date +%s`
LEVELS=$1
DIRSPERLEVEL=$2
FILESPERLEVEL=$3
FILELENGTH=$4
BLOCKSIZE=$5
PASSNUM=$6
NODES=$7
export ETCDCTL_API=3
RUNNING_NODES=0

ret=1
i=0
while  [ $i -lt 60 ] &&  { [ $RUNNING_NODES -lt $NODES ] || [  "$ret" -ne "0" ]; }
do
    echo "GET-1"
	sleep 10
	RUNNING_NODES=`etcdctl get /kibishii/nodes/ --prefix --endpoints=http://etcd-client:2379 | grep /kibishii/nodes | wc -l`
	ret=$?
    if [ "$ret" -ne "0" ]
    then
        RUNNING_NODES=0
    fi
    i=$((i+1))
done
echo "{\"opID\":\"$OPID\",\"cmd\":\"generate\",\"levels\":\"$LEVELS\",\"dirsPerLevel\":\"$DIRSPERLEVEL\",\"filesPerLevel\":\"$FILESPERLEVEL\",\"fileLength\":\"$FILELENGTH\",\"blockSize\":\"$BLOCKSIZE\",\"passNum\":\"$PASSNUM\"}" | etcdctl put /kibishii/control --endpoints=http://etcd-client:2379

STATUS="running"
NODES_COMPLETED=0
ret=1
i=0
while  [ $i -lt 60 ] &&  { [ "$STATUS" = 'running' ] || [  "$ret" -ne "0" ]; }
do
    echo "GET-2"
	sleep 10
	STATUS=`etcdctl get /kibishii/ops/$OPID --endpoints=http://etcd-client:2379 --print-value-only | jq ".status" | sed -e 's/"//g'`
	ret=$?
    if [ "$ret" -ne "0" ]
    then
        STATUS="running"
    fi
    i=$((i+1))
done

ret=1
i=0
while  [ $i -lt 60 ] && [  "$ret" -ne "0" ]
do
    echo "GET-3"
    sleep 10
    NODES_COMPLETED=`etcdctl get /kibishii/ops/$OPID --endpoints=http://etcd-client:2379 --print-value-only | jq ".nodesCompleted" | sed -e 's/"//g'`
	ret=$?
    if [ "$ret" -ne "0" ]
    then
        NODES_COMPLETED=0
    fi
    i=$((i+1))
    echo $i
done

if [ "$NODES_COMPLETED" -ne "$NODES" ] 
then
	STATUS="failed"
fi
echo $STATUS
if [ "$STATUS" = 'success' ]
then
	exit 0
fi
exit 1
