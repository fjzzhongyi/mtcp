#! /bin/bash
./epserver -p /home/hhy/Desktop/www -f epserver-multiprocess.conf -c 0
for i in {1..3}
do
./epserver -p /home/hhy/Desktop/www -f epserver-mutliprocess.conf -c $i
done
