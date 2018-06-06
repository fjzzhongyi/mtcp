#! /bin/bash
./epwget 192.168.1.10/example.txt 100 -n 4 -c 1000 -f epwget-multiprocess.conf
for i in {5..7}
do
./epwget 192.168.1.10/example.txt 100 -n $i -c 1000 -f epwget-multiprocess.conf
done
