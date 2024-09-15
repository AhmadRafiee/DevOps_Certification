#!/bin/bash
slave_nu=$(docker ps | grep redis-cluster_slave_* | wc -l)
sentinel_nu=$(docker ps | grep redis-cluster_sentinel_* | wc -l)
MASTER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' redis-cluster_master_1)


echo --------------------------
echo "######  INFORMATION ######"
echo --------------------------
echo Redis Slave Numbers: $slave_nu
echo Redis Sentinel Numbers: $sentinel_nu
echo --------------------------
echo
echo --------------------------
echo Redis master: $MASTER_IP
echo --------------------------
echo
echo --------------------------
for ((i=1;i<=$slave_nu;i++));
 do
 SLAVE_IP_[$i]=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' redis-cluster_slave_$i)
 echo Redis Slave $i: "${SLAVE_IP_[$i]}"
 echo --------------------------
 done
echo
echo -----------------------------
for ((i=1;i<=$sentinel_nu;i++));
 do
 SENTINEL_IP_[$i]=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' redis-cluster_sentinel_$i)
 echo Redis Sentinel $i: "${SENTINEL_IP_[$i]}"
 echo -----------------------------
 done


echo --------------------------
echo Initial status of sentinel
echo --------------------------
#docker exec redis-cluster_sentinel_1 redis-cli -p 26379 info Sentinel
echo Current master is
#docker exec redis-cluster_sentinel_1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
docker-compose exec sentinel redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
echo ------------------------------------------------

echo Stop redis master
docker pause redis-cluster_master_1
echo Wait for 15 seconds
sleep 15
echo Current infomation of sentinel
#docker exec redis-cluster_sentinel_1 redis-cli -p 26379 info Sentinel
#docker-compose exec sentinel redis-cli -p 26379 info sentinel
echo Current master is
#docker exec redis-cluster_sentinel_1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
docker-compose exec sentinel redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

echo ------------------------------------------------
echo Restart Redis master
docker unpause redis-cluster_master_1
#sleep 5
echo Current infomation of sentinel
#docker exec redis-cluster_sentinel_1 redis-cli -p 26379 info Sentinel
#docker-compose exec sentinel redis-cli -p 26379 info sentinel
echo Current master is
#docker exec redis-cluster_sentinel_1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
docker-compose exec sentinel redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

