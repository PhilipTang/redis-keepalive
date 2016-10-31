#!/bin/bash
# Program:
#   This Program is used to test if a connection is still alive, or to measure latency.
#   Reference: https://github.com/PhilipTang/redis-keepalive
# History:
# 2016/10/27 Philip First release

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

########################## define function ##########################

function perr () {
    echo "[$curdatetime] ERROR:" $1
}

function pinfo () {
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
        pinfo "rm -f config && ln -s configA config"
        rm -f "$config"
        ln -s "$configA" "$config"
    else
        pinfo "rm -f config && ln -s configB config"
        rm -f "$config"
        ln -s "$configB" "$config"
    fi
    writelog $1
}

function writelog() {
    yestoday=$(date --date="yesterday" "+%Y%m%d")
    cleanfiles="${logsdir}/${yestoday}*.log"
    pinfo "rm -f ${cleanfiles}"
    rm -f $cleanfiles
    pinfo "echo -n $1 > $curfilename"
    touch $curfilename
    echo -n "$1" > $curfilename
}

function choice() {
    # new tmpdir
    tmpdir="$workdir/tmp"
    pinfo "rm -rf tmpdir && mkdir -p tmpdir"
    rm -rf "$tmpdir"
    mkdir -p "$tmpdir"

    # get remote connection logs
    pinfo "scp root@$host1:$lastfilename $tmpdir/$host1.$datetime.log"
    scp root@$host1:$lastfilename $tmpdir/$host1.$datetime.log
    pinfo "result="$?

    pinfo "scp root@$host2:$lastfilename $tmpdir/$host2.$datetime.log"
    scp root@$host2:$lastfilename $tmpdir/$host2.$datetime.log
    pinfo "result="$?

    pinfo "scp root@$host3:$lastfilename $tmpdir/$host3.$datetime.log"
    scp root@$host3:$lastfilename $tmpdir/$host3.$datetime.log
    pinfo "result="$?

    pinfo "scp root@$host4:$lastfilename $tmpdir/$host4.$datetime.log"
    scp root@$host4:$lastfilename $tmpdir/$host4.$datetime.log
    pinfo "result="$?

    # count
    sumA=`grep A $tmpdir -irl | wc -l`
    sumB=`grep B $tmpdir -irl | wc -l`
    pinfo "sumA=$sumA"
    pinfo "sumB=$sumB"

    # detect the choice
    # initialization, default choice A
    if [ "$sumA" -eq 0 ] && [ "$sumB" -eq 0 ]; then
        pinfo "initialization, default choice A"
        thechoice="A"
    # choose A
    elif [ "$sumA" -ne 0 ] && [ "$sumB" -eq 0 ]; then
        pinfo "A -ne 0 B -eq 0"
        thechoice="A"
    # choose B
    elif [ "$sumA" -eq 0 ] && [ "$sumB" -ne 0 ]; then
        pinfo "A -eq 0 B -ne 0"
        thechoice="B"
    # choose A
    elif [ "$sumA" -gt "$sumB" ]; then
        pinfo "A -gt B"
        thechoice="A"
    # choose B
    elif [ "$sumB" -gt "$sumA" ]; then
        pinfo "B -gt A"
        thechoice="B"
    # excetipn. force connect to A
    elif [ "$sumA" -eq "$sumB" ]; then
        pinfo "excetipn. force connect to A"
        thechoice="A"
    fi

    # get local last choice
    localchoice="--"
    if [ -e "$lastfilename" ]; then
        localchoice=`cat $lastfilename`
    fi

    # format return value: 1 A 2 B 0 do nothing
    if [ "$thechoice" == "$localchoice" ]; then
        pinfo "thechoice == localchoice, do nothing"
        writelog $thechoice
        return 0
    elif [ "$thechoice" == "A" ]; then
        pinfo "choice A"
        return 1
    else
        pinfo "choice B"
        return 2
    fi
}

########################## start ##########################

curdatetime=$(date "+%Y%m%d%H%M")
pinfo "start"

# define offset minutes
if [ $1 != "" ]; then
    # manual offset minutes
    pinfo "use input offsetminutes=$1"
    offsetminutes=$1
else
    # default offset minutes
    pinfo "use default offsetminutes=5"
    offsetminutes=5
fi
datetime=$(date --date="$offsetminutes minute ago" "+%Y%m%d%H%M")

# define log name
workdir="/data/switchredis"
logsdir="$workdir/logs"
lastfilename="${logsdir}/${datetime}.log"
curfilename="${logsdir}/${curdatetime}.log"
pinfo "lastfilename=$lastfilename"
pinfo "curfilename=$curfilename"

# A huang wu redis
hostA="127.0.0.1"
portA="3306"
pwdA="password"

# B zhong jin redis
hostB="127.0.0.1"
portB="3306"
pwdB="password"

# define host
host1="ip1"
host2="ip2"
host3="ip3"
host4="ip4"

# config file location
config="/data/odp/conf/be-ng"
configA="/data/odp/conf/be-ng.prod.A"
configB="/data/odp/conf/be-ng.prod.B"

# test file exist
if [ ! -e "$config" ]; then
    perr "$config does not exist"
    exit 1
fi

if [ ! -e "$configA" ]; then
    perr "$configA does not exist"
    exit 1
fi

if [ ! -e "$configB" ]; then
    perr "$configB does not exist"
    exit 1
fi

# check local workspace
if [ ! -e "$workdir/logs" ]; then
    pinfo "mkdir -p $workdir/logs"
    mkdir -p "$workdir/logs"
fi

# try to connect redis
connect "$hostA" "$portA" "$pwdA"
resultA=$?
connect "$hostB" "$portB" "$pwdB"
resultB=$?

# decision
if [ "$resultA" == 1 ] && [ "$resultB" == 1 ]; then
    pinfo "A and B are all alive"
    pinfo "choice A or B"
    choice
    decision=$?
    if  [ "$decision" == 1 ]; then
        pinfo "switch to A"
        switch "A"
    elif [ "$decision" == 2 ]; then
        pinfo "switch to B"
        switch "B"
    else
        pinfo "do nothing"
    fi
elif [ "$resultA" == 1 ] && [ "$resultB" == 0 ]; then
    pinfo "A is alive but B did not alive"
    pinfo "switch to A"
    switch "A"
elif [ "$resultB" == 1 ] && [ "$resultA" == 0 ]; then
    pinfo "B is alive but A did not alive"
    pinfo "switch to B"
    switch "B"
else
    perr "A and B were not alive"
    perr "exit 1"
    exit 1
fi

pinfo "end"

########################## end ##########################
