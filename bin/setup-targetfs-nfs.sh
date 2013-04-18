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

SDKinstall=`grep TI_SDK_PATH= $cwd/../Rules.make | cut -d= -f2`

dstdefault=$SDKinstall/targetNFS


echo "--------------------------------------------------------------------------------"
echo "In which directory do you want to install the target filesystem?(if this directory does not exist it will be created)"
read -p "[ $dstdefault ] " dst

if [ ! -n "$dst" ]; then
    dst=$dstdefault
fi
echo "--------------------------------------------------------------------------------"

echo
echo "--------------------------------------------------------------------------------"
echo "This step will extract the target filesystem to $dst"
echo
echo "Note! This command requires you to have administrator priviliges (sudo access) "
echo "on your host."
read -p "Press return to continue" REPLY

extract_fs() {
    fstar=`ls -1 $cwd/../filesystem/??sdk*rootfs*.tar.gz`
    me=`whoami`
    sudo mkdir -p $1
    check_status
    sudo tar xzf $fstar -C $1
    check_status
    sudo chown $me:$me $1
    check_status
    sudo chown -R $me:$me $1/home $1/usr $1/etc $1/lib $1/opt $1/boot
    check_status
    echo
    echo "Successfully extracted `basename $fstar` to $1"
}

if [ -d $dst ]; then
    echo "$dst already exists"
    echo "(r) rename existing filesystem (o) overwrite existing filesystem (s) skip filesystem extraction"
    read -p "[r] " exists
    case "$exists" in
      s) echo "Skipping filesystem extraction"
         echo "WARNING! Keeping the previous filesystem may cause compatibility problems if you are upgrading the SDK"
         ;;
      o) sudo rm -rf $dst
         echo "Old $dst removed"
         extract_fs $dst
         ;;
      *) dte="`date +%m%d%Y`_`date +%H`.`date +%M`"
         echo "Path for old filesystem:"
         read -p "[ $dst.$dte ]" old
         if [ ! -n "$old" ]; then
             old="$dst.$dte"
         fi
         sudo mv $dst $old
         check_status
         echo
         echo "Successfully moved old $dst to $old"
         extract_fs $dst
         ;;
    esac
else
    extract_fs $dst
fi
echo $dst > $cwd/../.targetfs
echo "set sysroot $dst" > $cwd/../.gdbinit
echo "--------------------------------------------------------------------------------"

platform=`grep PLATFORM= $cwd/../Rules.make | cut -d= -f2`
echo
echo "--------------------------------------------------------------------------------"
echo "This step will set up the SDK to install binaries in to:"
echo "    $dst/home/root/$platform"
echo
echo "The files will be available from /home/root/$platform on the target."
echo
echo "This setting can be changed later by editing Rules.make and changing the"
echo "EXEC_DIR or DESTDIR variable (depending on your SDK)."
echo
read -p "Press return to continue" REPLY

sed -i "s=EXEC_DIR\=.*$=EXEC_DIR\=$dst/home/root/$platform=g" $cwd/../Rules.make
check_status

sed -i "s=DESTDIR\=.*$=DESTDIR\=$dst=g" $cwd/../Rules.make
check_status

echo "Rules.make edited successfully.."
echo "--------------------------------------------------------------------------------"

echo
echo "--------------------------------------------------------------------------------"
echo "This step will export your target filesystem for NFS access."
echo
echo "Note! This command requires you to have administrator priviliges (sudo access) "
echo "on your host."
read -p "Press return to continue" REPLY

grep $dst /etc/exports > /dev/null
if [ "$?" -eq "0" ]; then
    echo "$dst already NFS exported, skipping.."
else
    sudo chmod 666 /etc/exports
    check_status
    sudo echo "$dst *(rw,nohide,insecure,no_subtree_check,async,no_root_squash)" >> /etc/exports
    check_status
    sudo chmod 644 /etc/exports
    check_status
fi

echo
sudo /etc/init.d/nfs-kernel-server stop
check_status
sleep 1
sudo /etc/init.d/nfs-kernel-server start
check_status
echo "--------------------------------------------------------------------------------"
