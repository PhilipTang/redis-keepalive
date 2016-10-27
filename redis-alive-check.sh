#!/bin/bash
# Program:
#   This Program is used to test if a connection is still alive, or to measure latency.
# History:
# 2016/10/27 Philip First release

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

########################## define function ##########################

function prerr () {
    echo "[$curdatetime] ERROR:" $1
}

function prinfo () {
    echo "[$curdatetime] INFO:" $1
}

function connect() {
    host=$1
    port=$2
    password=$3
    result=`redis-cli -h "$host" -p "$port" -a "$password" PING`
    if [ "$result" == "PONG" ]; then
        return 1
    else
        return 0
    fi
}

function switch() {
    if [ $1 == "A" ]; then
        prinfo "rm -f config && ln -s configA config"
        rm -f "$config"
        ln -s "$configA" "$config"
    else
        prinfo "rm -f config && ln -s configB config"
        rm -f "$config"
        ln -s "$configB" "$config"
    fi
    writelog $1
}

function writelog() {
    prinfo "echo -n $1 > $curfilename"
    touch $curfilename
    echo -n "$1" > $curfilename
}

function choice() {
    # new tmpdir
    tmpdir="$workdir/tmp"
    prinfo "rm -rf tmpdir && mkdir -p tmpdir"
    rm -rf "$tmpdir"
    mkdir -p "$tmpdir"

    # get remote connection logs
    prinfo "scp root@$host1:$lastfilename $tmpdir/$host1.$datetime.log"
    scp root@$host1:$lastfilename $tmpdir/$host1.$datetime.log
    prinfo "result="$?

    prinfo "scp root@$host2:$lastfilename $tmpdir/$host2.$datetime.log"
    scp root@$host2:$lastfilename $tmpdir/$host2.$datetime.log
    prinfo "result="$?

    prinfo "scp root@$host3:$lastfilename $tmpdir/$host3.$datetime.log"
    scp root@$host3:$lastfilename $tmpdir/$host3.$datetime.log
    prinfo "result="$?

    prinfo "scp root@$host4:$lastfilename $tmpdir/$host4.$datetime.log"
    scp root@$host4:$lastfilename $tmpdir/$host4.$datetime.log
    prinfo "result="$?

    # count
    sumA=`grep A $tmpdir -irl | wc -l`
    sumB=`grep B $tmpdir -irl | wc -l`
    prinfo "sumA=$sumA"
    prinfo "sumB=$sumB"

    # detect the choice
    # initialization, default choice A
    if [ "$sumA" -eq 0 ] && [ "$sumB" -eq 0 ]; then
        prinfo "initialization, default choice A"
        thechoice="A"
    # choose A
    elif [ "$sumA" -ne 0 ] && [ "$sumB" -eq 0 ]; then
        prinfo "A -ne 0 B -eq 0"
        thechoice="A"
    # choose B
    elif [ "$sumA" -eq 0 ] && [ "$sumB" -ne 0 ]; then
        prinfo "A -eq 0 B -ne 0"
        thechoice="B"
    # choose A
    elif [ "$sumA" -gt "$sumB" ]; then
        prinfo "A -gt B"
        thechoice="A"
    # choose B
    elif [ "$sumB" -gt "$sumA" ]; then
        prinfo "B -gt A"
        thechoice="B"
    # excetipn. force connect to A
    elif [ "$sumA" -eq "$sumB" ]; then
        prinfo "excetipn. force connect to A"
        thechoice="A"
    fi

    # get local last choice
    localchoice="--"
    if [ -e "$lastfilename" ]; then
        localchoice=`cat $lastfilename`
    fi

    # format return value: 1 A 2 B 0 do nothing
    if [ "$thechoice" == "$localchoice" ]; then
        prinfo "thechoice == localchoice, do nothing"
        writelog $thechoice
        return 0
    elif [ "$thechoice" == "A" ]; then
        prinfo "choice A"
        return 1
    else
        prinfo "choice B"
        return 2
    fi
}

########################## start ##########################

curdatetime=$(date "+%Y%m%d%H%M")
prinfo "start"

# define offset minutes
if [ $1 != "" ]; then
    # manual offset minutes
    prinfo "use input offsetminutes=$1"
    offsetminutes=$1
else
    # default offset minutes
    prinfo "use default offsetminutes=5"
    offsetminutes=5
fi
datetime=$(date --date="$offsetminutes minute ago" "+%Y%m%d%H%M")

# define log name
workdir="/data/switchredis"
logsdir="$workdir/logs"
lastfilename="${logsdir}/${datetime}.log"
curfilename="${logsdir}/${curdatetime}.log"
prinfo "lastfilename=$lastfilename"
prinfo "curfilename=$curfilename"

# A huang wu redis
hostA="10.3.142.241"
portA="6379"
pwdA="HF123"

# B zhong jin redis
hostB="10.3.142.241"
portB="6379"
pwdB="HF123"

# define host
host1="10.3.158.62"
host2="10.3.158.63"
host3="10.19.140.112"
host4="10.19.140.113"

# config file location
config="/data/odp/conf/be-ng"
configA="/data/odp/conf/be-ng.prod.A"
configB="/data/odp/conf/be-ng.prod.B"

# test file exist
if [ ! -e "$config" ]; then
    prerr "$config does not exist"
    exit 1
fi

if [ ! -e "$configA" ]; then
    prerr "$configA does not exist"
    exit 1
fi

if [ ! -e "$configB" ]; then
    prerr "$configB does not exist"
    exit 1
fi

# check local workspace
if [ ! -e "$workdir/logs" ]; then
    prinfo "mkdir -p $workdir/logs"
    mkdir -p "$workdir/logs"
fi

# try to connect redis
connect "$hostA" "$portA" "$pwdA"
resultA=$?
connect "$hostB" "$portB" "$pwdB"
resultB=$?

# decision
if [ "$resultA" == 1 ] && [ "$resultB" == 1 ]; then
    prinfo "A and B are all alive"
    prinfo "choice A or B"
    choice
    decision=$?
    if  [ "$decision" == 1 ]; then
        prinfo "switch to A"
        switch "A"
    elif [ "$decision" == 2 ]; then
        prinfo "switch to B"
        switch "B"
    else
        prinfo "do nothing"
    fi
elif [ "$resultA" == 1 ] && [ "$resultB" == 0 ]; then
    prinfo "A is alive but B did not alive"
    prinfo "switch to A"
    switch "A"
elif [ "$resultB" == 1 ] && [ "$resultA" == 0 ]; then
    prinfo "B is alive but A did not alive"
    prinfo "switch to B"
    switch "B"
else
    prerr "A and B were not alive"
    prerr "exit 1"
    exit 1
fi

prinfo "end"

########################## end ##########################
