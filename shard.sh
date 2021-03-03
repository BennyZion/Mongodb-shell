#!/bin/bash
# shard1 configure
for port in {27017,27018,27019}
do
mkdir -pv /var/lib/mongodb/${port}/{db,log}
cat > $port.conf <<EOF
port=$port
dbpath=/var/lib/mongodb/${port}/db
logpath=/var/lib/mongodb/${port}/log/mongodb.log
logappend=true
fork=true
bind_ip=0.0.0.0
replSet=repl1
shardsvr=true
EOF
mongod -f ${port}.conf
done
mongo 127.0.0.1:27017/admin --eval "rs.initiate({_id: 'repl1', members: [ {_id: 0, host: '192.168.219.200:27017'}, {_id: 1, host: '192.168.219.200:27018'}, {_id: 2, host: '192.168.219.200:27019'}] })"
# shard2 configure
for port in {37017,37018,37019}
do
mkdir -pv /var/lib/mongodb/${port}/{db,log}
cat > $port.conf <<EOF
port=$port
dbpath=/var/lib/mongodb/${port}/db
logpath=/var/lib/mongodb/${port}/log/mongodb.log
logappend=true
fork=true
bind_ip=0.0.0.0
replSet=repl2
shardsvr=true
EOF
mongod -f ${port}.conf
done
mongo 127.0.0.1:37017/admin --eval "rs.initiate({_id: 'repl2', members: [ {_id: 0, host: '192.168.219.200:37017'}, {_id: 1, host: '192.168.219.200:37018'}, {_id: 2, host: '192.168.219.200:37019'}] })"
# configrepl
for port in {47017,47018,47019}
do
mkdir -pv /var/lib/mongodb/${port}/{db,log}
cat > $port.conf <<EOF
systemLog:
  destination: file
  path: /var/lib/mongodb/${port}/log/mongodb.log
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /var/lib/mongodb/${port}/db
  directoryPerDB: true
  #engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 0.0.0.0
  port: ${port}
replication:
  oplogSizeMB: 2048
  replSetName: configReplSet
sharding:
  clusterRole: configsvr
processManagement: 
  fork: true
EOF
mongod -f ${port}.conf
done
mongo 127.0.0.1:47017/admin --eval "rs.initiate({_id: 'configReplSet', members: [ {_id: 0, host: '192.168.219.200:47017'}, {_id: 1, host: '192.168.219.200:47018'}, {_id: 2, host: '192.168.219.200:47019'}] })"
# mongos nodes
port=57017
mkdir -pv /var/lib/mongodb/${port}/{db,log}
cat > $port.conf <<EOF
systemLog:
  destination: file
  path: /var/lib/mongodb/${port}/log/mongodb.log
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: $port
sharding:
  configDB: configReplSet/192.168.219.200:47017,192.168.219.200:47018,192.168.219.200:47019
processManagement: 
  fork: true
EOF
mongos -f 57017.conf
mongo 127.0.0.1:57017/admin --eval "db.runCommand( { addshard : 'repl1/192.168.219.200:27017,192.168.219.200:27018,192.168.219.200:27019',name:'shard1'} )"
mongo 127.0.0.1:57017/admin --eval "db.runCommand( { addshard : 'repl2/192.168.219.200:37017,192.168.219.200:37018,192.168.219.200:37019',name:'shard2'} )"
mongo 127.0.0.1:57017/admin --eval "db.runCommand( { listshards : 1 } )"
