#!/bin/sh

# This distribution contains contributions or derivatives under copyright
# as follows:
#
# Copyright (c) 2010, Texas Instruments Incorporated
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# - Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# - Neither the name of Texas Instruments nor the names of its
#   contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

cwd=`dirname $0`
. $cwd/common.sh

echo
echo "--------------------------------------------------------------------------------"
echo "This step will set up the u-boot variables for booting the EVM."

ipdefault=`ifconfig | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1 }'`
platform=`grep PLATFORM= $cwd/../Rules.make | cut -d= -f2`
prompt="RHINO #"

echo "Autodetected the following ip address of your host, correct it if necessary"
read -p "[ $ipdefault ] " ip
echo

if [ ! -n "$ip" ]; then
    ip=$ipdefault
fi

if [ -f $cwd/../.targetfs ]; then
    rootpath=`cat $cwd/../.targetfs`
else
    echo "Where is your target filesystem extracted?"
    read -p "[ ${HOME}/targetNFS ]" rootpath

    if [ ! -n "$rootpath" ]; then
        rootpath="${HOME}/targetNFS"
    fi
    echo
fi

uimage="uImage-""$platform"".bin"
uimagesrc=`ls -1 $cwd/../firmware/am3517/prebuilt-images/$uimage`
uimagedefault=`basename $uimagesrc`

baseargs="console=ttyO0,115200n8 rw noinitrd"
videoargs=""
fssdargs="root=/dev/mmcblk0p2 rootfstype=ext3 rootwait"
fsnfsargs1="root=/dev/nfs nfsroot="
fsnfsargs2="$ip:"
fsnfsargs3="$rootpath"
fsnfsargs4=",nolock,rsize=1024,wsize=1024"
fsnfsargs=$fsnfsargs1$fsnfsargs2$fsnfsargs3$fsnfsargs4

echo "Select Linux kernel location:"
echo " 1: TFTP"
echo " 2: SD card"
echo
read -p "[ 1 ] " kernel

if [ ! -n "$kernel" ]; then
    kernel="1"
fi

echo
echo "Select root file system location:"
echo " 1: NFS"
echo " 2: SD card"
echo
read -p "[ 1 ] " fs

if [ ! -n "$fs" ]; then
    fs="1"
fi

if [ "$kernel" -eq "1" ]; then
    echo
    echo "Available kernel images in /tftproot:"
    for file in /tftpboot/*; do
        basefile=`basename $file`
        echo "    $basefile"
    done
    echo
    echo "Which kernel image do you want to boot from TFTP?"
    read -p "[ $uimagedefault ] " uimage

    if [ ! -n "$uimage" ]; then
        uimage=$uimagedefault
    fi

    bootcmd="setenv bootcmd 'dhcp;setenv serverip $ip;tftpboot;bootm'"
    serverip="setenv serverip $ip"
    bootfile="setenv bootfile $uimage"

    if [ "$fs" -eq "1" ]; then
        bootargs="setenv bootargs $baseargs $videoargs $fsnfsargs ip=dhcp"
        cfg="uimage-tftp_fs-nfs"
    else
        bootargs="setenv bootargs $baseargs $videoargs $fssdargs ip=none"
        cfg="uimage-tftp_fs-sd"
    fi
else
    if [ "$fs" -eq "1" ]; then
        bootargs="setenv bootargs $baseargs $videoargs $fsnfsargs ip=dhcp"
        bootcmd="setenv bootcmd 'mmc rescan 0;fatload mmc 0 0x82000000 uImage;bootm 0x82000000'"
        cfg="uimage-sd_fs-nfs"
    else
        bootargs="setenv bootargs $baseargs $videoargs $fssdargs ip=none"
        bootcmd="setenv bootcmd 'mmc rescan 0;fatload mmc 0 0x82000000 uImage;bootm 0x82000000'"
        cfg="uimage-sd_fs-sd"
    fi
fi

echo
echo "Resulting u-boot variable settings:"
echo
echo "setenv bootdelay 3"
echo "setenv baudrate 115200"
echo $bootargs
echo $bootcmd

if [ -n "$serverip" ]; then
    echo "setenv autoload no"
    echo $serverip
fi

if [ -n "$bootfile" ]; then
    echo $bootfile
fi
echo "--------------------------------------------------------------------------------"

do_expect() {
    echo "expect {" >> $3
    check_status
    echo "    $1" >> $3
    check_status
    echo "}" >> $3
    check_status
    echo $2 >> $3
    check_status
    echo >> $3
}

echo
echo "--------------------------------------------------------------------------------"
echo "Would you like to create a minicom script with the above parameters (y/n)?"
read -p "[ y ] " minicom
echo

if [ ! -n "$minicom" ]; then
    minicom="y"
fi

#Use = instead of == for POSIX compliance and dash compatibility
if [ "$minicom" = "y" ]; then
    minicomfile=setup_$platform_$cfg.minicom
    minicomfilepath=$cwd/../$minicomfile

    if [ -f $minicomfilepath ]; then
        echo "Moving existing $minicomfile to $minicomfile.old"
        mv $minicomfilepath $minicomfilepath.old
        check_status
    fi

    timeout=300
    echo "timeout $timeout" >> $minicomfilepath
    echo "verbose on" >> $minicomfilepath
    echo >> $minicomfilepath
    do_expect "\"stop autoboot:\"" "send \"\"" $minicomfilepath
    do_expect "\"$prompt\"" "send \"setenv bootdelay 3\"" $minicomfilepath
    do_expect "\"$prompt\"" "send \"setenv baudrate 115200\"" $minicomfilepath
    do_expect "\"ENTER ...\"" "send \"\"" $minicomfilepath
    do_expect "\"$prompt\"" "send \"setenv oldbootargs \$\{bootargs\}\"" $minicomfilepath

#   For dash compatibility need to use printf instead of echo
#   because dash shell will expand the \c by default
#   do_expect "\"$prompt\"" "send \"setenv bootargs $baseargs \c\"" $minicomfilepath
    echo "expect {" >> $minicomfilepath
    check_status
    echo "    \"$prompt\"" >> $minicomfilepath
    check_status
    echo "}" >> $minicomfilepath
    check_status
    printf "send \"setenv bootargs $baseargs \c\"\n" >> $minicomfilepath
    check_status

#   For dash compatibility need to use printf instead of echo
    if [ "$fs" -eq "1" ]; then
        printf "send \"$fsnfsargs1\c\"\n" >> $minicomfilepath
        printf "send \"$fsnfsargs2\c\"\n" >> $minicomfilepath
        printf "send \"$fsnfsargs3\c\"\n" >> $minicomfilepath
        printf "send \"$fsnfsargs4 \c\"\n" >> $minicomfilepath
        echo "send \"ip=dhcp\"" >> $minicomfilepath
    else
        printf "send \"$fssdargs \c\"\n" >> $minicomfilepath
        echo "send \"ip=off\"" >> $minicomfilepath
    fi
    if [ "$kernel" -eq "1" ]; then
        do_expect "\"$prompt\"" "send \"setenv autoload no\"" $minicomfilepath
        do_expect "\"$prompt\"" "send \"setenv oldserverip \$\{serverip\}\"" $minicomfilepath
        do_expect "\"$prompt\"" "send \"$serverip\"" $minicomfilepath
        do_expect "\"$prompt\"" "send \"setenv oldbootfile \$\{bootfile\}\"" $minicomfilepath
        do_expect "\"$prompt\"" "send \"$bootfile\"" $minicomfilepath
    fi
    do_expect "\"$prompt\"" "send \"setenv oldbootcmd \$\{bootcmd\}\"" $minicomfilepath
    do_expect "\"$prompt\"" "send \"$bootcmd\"" $minicomfilepath
    do_expect "\"$prompt\"" "send \"saveenv\"" $minicomfilepath
    do_expect "\"$prompt\"" "! killall -s SIGHUP minicom" $minicomfilepath

    echo -n "Successfully wrote "
    readlink -m $minicomfilepath
    echo
    echo "Would you like to run the setup script now (y/n)? This requires you to connect"
    echo "the RS-232 cable between your host and EVM as well as your ethernet cable as"
    echo "described in the Quick Start Guide. Once answering 'y' on the prompt below"
    echo "you will have $timeout seconds to connect the board and power cycle it"
    echo "before the setup times out"
    echo
    echo "After successfully executing this script, your EVM will be set up. You will be "
    echo "able to connect to it by executing 'minicom -w' or if you prefer a windows host"
    echo "you can set up Tera Term as explained in the Software Developer's Guide."
    echo "If you connect minicom or Tera Term and power cycle the board Linux will boot."
    echo
    read -p "[ y ] " minicomsetup

    if [ ! -n "$minicomsetup" ]; then
        minicomsetup="y"
    fi

    savedir=""
#Use = instead of == for POSIX compliance and dash compatibility
    if [ "$minicomsetup" = "y" ]; then
#For dash compatibility, do not use pushd and popd
        savedir=$cwd
        cd "$cwd/.."
        check_status
        sudo minicom -S $minicomfile
        cd $savedir
        check_status
    fi

    echo "You can manually run minicom in the future with this setup script using: minicom -S $minicomfile"
fi
echo "--------------------------------------------------------------------------------"
