#!/bin/sh
java --release=8 -cp "/opt/share/kibishii/lib/*" -jar /opt/share/kibishii/kibishii.jar $HOSTNAME http://etcd-client:2379 /data