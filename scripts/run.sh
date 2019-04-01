#!/bin/bash
# run benchmark
adb -s $1 shell pm disable com.example.benchmark_withjson
sleep 1
adb -s $1 shell pm enable com.example.benchmark_withjson

printf "Rebooting and running benchmark on device %s\n" $1

adb -s $1 reboot
adb -s $1 wait-for-device
sleep 40
printf "Rebooted\n"
adb root
sub=""
while [ "$sub" != "uid=0(" ]; do
	sleep 5
	var=$(adb shell id)
	sub=${var%%root*}  # var:4:1
	printf ".\n"
done
sleep 40
printf "Rooted\n"

adb -s $1 shell sh /data/removeBenchmarkData.sh
adb -s $1 shell sh /data/preBenchmark.sh $2 $3 $4 $5 $6 $7 #create database
adb -s $1 shell pm disable com.example.benchmark_withjson
sleep 5
adb -s $1 shell pm enable com.example.benchmark_withjson

sleep 15 # Let phone settle before starting script:
echo "Starting phone script"
#adb -s $1 shell sh /data/benchmark.sh $4 $5 #run queries -- specify governor ($4) and speed ($5)
#adb shell "nohup > data/output.out sh /data/benchmark.sh $4 $5 &" &
#adb shell 'nohup > data/output.out sh /data/benchmark.sh $4 $5 $2 $3 $6 $7 & echo $!' &
adb shell sh /data/start_benchmark.sh $4 $5 &

echo "WAITING -- START MONSOON"
# Block to allow manual phone disconnect during run for energy measurement:
#sleep 30

sleep 5 # Make sure on-phone script is running and blocking:

ykushcmd -d 1
sleep 30

./server.exe 2016
result=$?
if [ "$result" != "0" ]; then
	echo "Error on wifi block"
	exit 3
else
	echo "OK on wifi block"
fi
ykushcmd -u 1

# Block until phone is manually reconnected after measurement:
result="1"
while [ "$result" = "1" ]; do
	sleep 5
	echo "Try... ${result}"
	#result=$(adb shell id 2>&1)
	adb shell id 2>&1
	result="$?"
done

# Get results (and trap for error):
result="$(adb shell cat /data/results.txt)"
#error=${result:0:3}
#if [ ${error} == "ERR" ]; then
#	echo "Error on phone:  $result"
#	exit 1
#fi

# pull log
adb -s $1 pull /data/trace.log
# $2 = DB (sql, bdb, bdb100); $3 = workload (A, B, C etc.); $6 = delay (lognormal etc.)
if [ "$6" = "lognormal" ]; then
	delay="log"
else
	delay="$6"
fi
timestamp="$(date +%Y%m%d%H%M%S)"
#filename="YCSB_${2}_${3}_${delay}_${4}_${5}_$timestamp"
filename="YCSB_${2}_${3}_${delay}_${4}_${5}"
#filename="YCSB_Workload${3}_TimingA${2}.log" # old style filename
mv trace.log logs/$filename
gzip logs/$filename
sleep 1
printf "FILENAME:  %s\n" "$filename"

echo "RESULTS: $result"

printf "Completed benchmark for device %s\n" $1

# Sanity check:  Verify main phone script matches:
adb pull /data/start.txt
result1="$(cat start.txt)"
echo "Script pid:  $result1"
adb shell rm /data/start.txt
if [ "$result1" != "  AC powered: false" ]; then
	echo "Error on script pid"
	#exit 1
else
	echo "OK on script pid"
fi

# Sanity check:  Verify benchmark was run on-battery:
adb pull /data/power.txt
result2="$(cat power.txt)"
echo "BATTERY:  $result2"
adb shell rm /data/power.txt
if [ "$result2" != "  AC powered: false" ]; then
	echo "Error on battery power"
	exit 2
else
	echo "OK on battery power"
fi


#TODO:
# (1) remove redundant pm di/enable at start
# (2) do wait-for-device after root; verify rather than busywait
# (3) combine removeBenchmark and preBenchmark
# (4) combine pm dis/enable after preBenchmark with preBenchmark
# (5) on on-phone script, fix error exit for governors:  do ping to desktop, drop wakelock etc.
# (6) create after-pre-before-main benchmark script
# (7) parameterize TCP wifi wait port
# (8) in general -- add confirm message to pipes etc.
# (9) add socket apps to repo and push in script
# (10) adb:  when USB connection is cut, the foreground proc dies, even if run with sighup -- ?! (which signal?  kill?)
# (11) adb:  proc on desktop blocks until all phone procs exit, even if already reparented to init -- ?!
# (12) Fix ERR result from results.txt

# re:  blocking syscalls and spurious wakeup -- why while () and not if ()?
# syncing accept() and connect()

