#!/bin/bash

#start daemon in background
ipfs daemon &
sleep 3

pid=$(echo "$!")

#get request to the ipfs
ipfs get $1

#creation of log file
touch logPeers.csv
echo  "\"IP\";\"CID\";\"Byte_received\";\"Block_received\"" >> logPeers.csv

touch logBA.csv
echo "\"CID\"" >> logBA.csv

#write on logBA.csv the list of partners in the bitswap agent list
x=$(ipfs bitswap stat --verbose | grep "\n")
j=0

for i in $x
do
    if [[ $j -gt 11 ]]; then
      echo $i >> logBA.csv
    fi
    j=$(($j+1))
done

#write on logPerrs.csv the dato on the downloaded content 
ip=$(ipfs swarm peers | cut -d/ -f3)
ip_arr=($(echo $ip | tr " " "\n"))
y=0

for id in $(ipfs swarm peers | rev | cut -d/ -f1 | rev)
do
    x=$(ipfs bitswap ledger $id | grep "Bytes received")
    nx=$(echo $x | tr ":" "\n")
    
    for byte in $nx
    do    
 	if [[ $byte != "Bytes" && $byte != "received" && $byte != "0" ]] ; then
	    
	    block=$(($byte/1204))
	    
	    log="${ip_arr[$y]};$id;$bit;$block"
	    
	    echo $log >> logPeers.csv
	fi
    done
    y=$(($y+1))
    
done

#kill the ipfs daemon in beckground
kill -2 $pid
sleep 3


