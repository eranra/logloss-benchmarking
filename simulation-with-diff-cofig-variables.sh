#! /bin/bash

#ensure you got podman --version  podman version 2.1.xx

if [ $1 = "--help"  ]
then
	echo Give command line argument as :  Messagelines_per_sec Log-size-max report-interval
	echo Example: simulation-with-diff-cofig-variables.sh 100 1000000 5
	exit
fi

export LOCALBIN=${HOME}/go/src/github.com/containers/podman/bin
export MSGPERSEC=$1
export MAXSIZE=$2
export REPORT_INTERVAL=$3

export PAYLOAD_SIZE=1024 
export DISTRIBUTION=gaussian 
export PAYLOAD_GEN=fixed
export STDDEV=32 
export OUTPUT=stdout 
export REPORT=inline 
#for total size 100mb set the below value
export TOTAL_SIZE=100

export NOW=$(date +"%m%d%Y%H%M")

echo Messagelines_per_sec=$MSGPERSEC Max_size_log_file_limit=$MAXSIZE Report Interval=$REPORT_INTERVAL Payload_size bytes=$PAYLOAD_SIZE Payload Gen Method=${PAYLOAD_GEN} Payload std dev=${STDDEV} Logs from container writing to data pipe type=$OUTPUT Reporting method=$REPORT Report Interval=$REPORT_INTERVAL TOTAL_SIZE considered for counting log-loss =$TOTAL_SIZE


function pause(){
   read -p "$*"
}


#load-logs-drive image needs to be built first by following the below steps
#step 1 cd ${HOME}/FlowControl/logging-load-driver
#step 2 make all

#get imageid post getting the image built
export imageid=`${LOCALBIN}/podman images | grep latest | grep logging-load-driver | awk '{print $3}'`

#build a custom conmon in ${HOME}/FlowControl/Containers/conmon by building 'all' target "make all" 
#install this binary for podman by doing make podman, note this step copies bin/conmon to /usr/local/libexec/podman/conmon
#check date of binary in /usr/local/libexec/podman/conmon for checking if latest bin/conmon copied properly

export conmonlatestlib=/usr/local/libexec/podman/conmon

echo Using ImageID:$imageid
echo Using ConmonCustomBin:$conmonlatestlib

echo MAX LOG FILE SIZE SET TO=$MAXSIZE
#currently log-size-max option not support in the podman 2.1.xx version. you got to built conmon custom binary with log-size-max limit is hardcoded to 1mb
#CMD="${LOCALBIN}/podman run --log-level debug --conmon $conmonlatestlib --env MSGPERSEC --env PAYLOAD_GEN --env PAYLOAD_SIZE --env DISTRIBUTION --env STDDEV --env OUTPUT  --env REPORT --env REPORT_INTERVAL --env TOTAL_SIZE --log-opt max-size=$MAXSIZE  $imageid" 
CMD="${LOCALBIN}/podman run  --conmon $conmonlatestlib --env MSGPERSEC --env PAYLOAD_GEN --env PAYLOAD_SIZE --env DISTRIBUTION --env STDDEV --env OUTPUT  --env REPORT --env REPORT_INTERVAL --env TOTAL_SIZE --log-opt max-size=$MAXSIZE  $imageid" 
echo Going to run now: $CMD
pause 'Press [Enter] key to run container...with '

####
$CMD  &> /tmp/containerOut_$NOW.txt &
####
echo "check if container running"
${LOCALBIN}/podman ps

pause 'Press [Enter] key to get containerID...'
export containerID=`${LOCALBIN}/podman ps | awk 'NR==2{print $1}'`
echo ContainerID=$containerID

export LOGFILE=${HOME}/.local/share/containers/storage/overlay-containers/$containerID*/userdata/ctr.log

echo Checking if logfile got logs in it..
head -1 $LOGFILE

export VERIFYLOADER=${HOME}/FlowControl/logging-load-driver
pause 'Press [Enter] key to get logs verified and log-loss measured...'
tail -F $LOGFILE | $VERIFYLOADER/verify-loader --report-interval=$REPORT_INTERVAL 

echo "Running containers pids"
${LOCALBIN}/podman ps


pause 'Press [Enter] key to get clear container processes and log files...'
rm /tmp/containerOut*.txt 
rm -r ${HOME}/.local/share/containers/storage/overlay-containers/*
echo "Killing the running containers processes those are running"
${LOCALBIN}/podman stop -a
${LOCALBIN}/podman rm -a
#check if any container processes if still running
${LOCALBIN}/podman ps

