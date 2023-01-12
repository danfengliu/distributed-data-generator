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
    etcdctl get /kibishii/nodes/ --prefix --endpoints=http://etcd-client:2379 | grep /kibishii/nodes | wc -l
    echo "GET-1-1"
	RUNNING_NODES=`etcdctl get /kibishii/nodes/ --prefix --endpoints=http://etcd-client:2379 | grep /kibishii/nodes | wc -l`
    echo "Get RUNNING_NODES: $RUNNING_NODES"
    ret=$?
    if [ $ret -ne 0 ]
    then
        RUNNING_NODES=0
    fi
    i=$((i+1))
    echo "Next round of getting kibishii node:$i"
done
echo "------RUNNING_NODES------"
echo $RUNNING_NODES

echo "{\"opID\":\"$OPID\",\"cmd\":\"verify\",\"levels\":\"$LEVELS\",\"dirsPerLevel\":\"$DIRSPERLEVEL\",\"filesPerLevel\":\"$FILESPERLEVEL\",\"fileLength\":\"$FILELENGTH\",\"blockSize\":\"$BLOCKSIZE\",\"passNum\":\"$PASSNUM\"}" | etcdctl put /kibishii/control --endpoints=http://etcd-client:2379
STATUS="running"
ret=1
i=0
while  [ $i -lt 60 ] &&  { [ "$STATUS" = 'running' ] || [  "$ret" -ne "0" ]; }
do
    echo "GET-2"
	sleep 10
	STATUS=`etcdctl get /kibishii/ops/$OPID --endpoints=http://etcd-client:2379 --print-value-only | jq ".status" | sed -e 's/"//g'`
	ret=$?
    if [ $ret -ne 0 ]
    then
        STATUS="running"
    fi
    i=$((i+1))
    echo $i
done
echo "------STATUS------"
echo $STATUS

ret=1
i=0
while  [ $i -lt 60 ] && [  "$ret" -ne "0" ]
do
    echo "GET-3"
    sleep 10
    NODES_COMPLETED=`etcdctl get /kibishii/ops/$OPID --endpoints=http://etcd-client:2379 --print-value-only | jq ".nodesCompleted" | sed -e 's/"//g'`
	ret=$?
    if [ $ret -eq 0 ]
    then
        echo "break"
        break
    fi
    i=$((i+1))
    echo $i
done

if [ "$NODES_COMPLETED" != "$NODES" ] 
then
	STATUS="failed"
fi
echo $STATUS
if [ "$STATUS" = 'success' ]
then
    nodes=`etcdctl get /kibishii/nodes/ --prefix --endpoints=http://etcd-client:2379 | grep ^kibishii-deployment`
    echo "nodes"
    echo $nodes
    for node in $nodes
    do
        results=`etcdctl get /kibishii/results/$OPID/$node --endpoints=http://etcd-client:2379 --print-value-only | jq ".missingDirs,.missingFiles"`
        for result in $results
        do
            if [ -z $result ]; then
                exit 2
            fi
            if [ "$result" !=  '0' ]; then
                exit $result
            fi
        done
    done
	exit 0
fi

exit 1


