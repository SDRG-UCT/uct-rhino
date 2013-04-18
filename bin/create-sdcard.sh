#!/bin/bash
# Authors:
#    LT Thomas <ltjr@ti.com>
#    Chase Maupin
# create-sdcard.sh v0.3

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

# Determine the absolute path to the executable
# EXE will have the PWD removed so we can concatenate with the PWD safely
PWD=`pwd`
EXE=`echo $0 | sed s=$PWD==`
EXEPATH="$PWD"/"$EXE"
clear
cat << EOM

################################################################################

This script will create a bootable SD card from custom or pre-built binaries.

The script must be run with root permissions and from the bin directory of
the SDK

Example:
 $ sudo ./create-sdcard.sh

Formatting can be skipped if the SD card is already formatted and
partitioned properly.

################################################################################

EOM

AMIROOT=`whoami | awk {'print $1'}`
if [ "$AMIROOT" != "root" ] ; then

	echo "	**** Error *** must run script with sudo"
	echo ""
	exit
fi

THEPWD=$EXEPATH
PARSEPATH=`echo $THEPWD | grep -o '.*ti-sdk.*.[0-9]/'`

if [ "$PARSEPATH" != "" ] ; then
PATHVALID=1
else
PATHVALID=0
fi

#Precentage function
untar_progress ()
{
    TARBALL=$1;
    DIRECTPATH=$2;
    BLOCKING_FACTOR=$(($(gzip --list ${TARBALL} | sed -n -e "s/.*[[:space:]]\+[0-9]\+[[:space:]]\+\([0-9]\+\)[[:space:]].*$/\1/p") / 51200 + 1));
    tar --blocking-factor=${BLOCKING_FACTOR} --checkpoint=1 --checkpoint-action='ttyout=Written %u%  \r' -zxf ${TARBALL} -C ${DIRECTPATH}
}

#copy/paste programs
cp_progress ()
{
	CURRENTSIZE=0
	while [ $CURRENTSIZE -lt $TOTALSIZE ]
	do
		TOTALSIZE=$1;
		TOHERE=$2;
		CURRENTSIZE=`sudo du -c $TOHERE | grep total | awk {'print $1'}`
		echo -e -n "$CURRENTSIZE /  $TOTALSIZE copied \r"
		sleep 1
	done
}

populate_3_partitions() {
    ENTERCORRECTLY="0"
	while [ $ENTERCORRECTLY -ne 1 ]
	do
		read -e -p 'Enter path where SD card tarballs were downloaded : '  TARBALLPATH

		echo ""
		ENTERCORRECTLY=1
		if [ -d $TARBALLPATH ]
		then
			echo "Directory exists"
			echo ""
			echo "This directory contains:"
			ls $TARBALLPATH
			echo ""
			read -p 'Is this correct? [y/n] : ' ISRIGHTPATH
				case $ISRIGHTPATH in
				"y" | "Y") ;;
				"n" | "N" ) ENTERCORRECTLY=0;continue;;
				*)  echo "Please enter y or n";ENTERCORRECTLY=0;continue;;
				esac
		else
			echo "Invalid path make sure to include complete path"
			ENTERCORRECTLY=0
            continue
		fi
        # Check that tarballs were found
        if [ ! -e "$TARBALLPATH""/boot_partition.tar.gz" ]
        then
            echo "Could not find boot_partition.tar.gz as expected.  Please"
            echo "point to the directory containing the boot_partition.tar.gz"
            ENTERCORRECTLY=0
            continue
        fi

        if [ ! -e "$TARBALLPATH""/rootfs_partition.tar.gz" ]
        then
            echo "Could not find rootfs_partition.tar.gz as expected.  Please"
            echo "point to the directory containing the rootfs_partition.tar.gz"
            ENTERCORRECTLY=0
            continue
        fi

        if [ ! -e "$TARBALLPATH""/start_here_partition.tar.gz" ]
        then
            echo "Could not find start_here_partition.tar.gz as expected.  Please"
            echo "point to the directory containing the start_here_partition.tar.gz"
            ENTERCORRECTLY=0
            continue
        fi
	done

        # Make temporary directories and untar mount the partitions
        mkdir $PWD/boot
        mkdir $PWD/rootfs
        mkdir $PWD/start_here
        mkdir $PWD/tmp

        mount -t vfat "/dev/""$DEVICEDRIVENAME""1" boot
        mount -t ext3 "/dev/""$DEVICEDRIVENAME""2" rootfs
        mount -t ext3 "/dev/""$DEVICEDRIVENAME""3" start_here

        # Remove any existing content in case the partitions were not
        # recreated
        sudo rm -rf boot/*
        sudo rm -rf rootfs/*
        sudo rm -rf start_here/*

        # Extract the tarball contents.
cat << EOM

################################################################################
        Extracting boot partition tarball

################################################################################
EOM
        untar_progress $TARBALLPATH/boot_partition.tar.gz tmp/
        if [ -e "./tmp/MLO" ]
        then
            cp ./tmp/MLO boot/
        fi
        cp -rf ./tmp/* boot/

cat << EOM

################################################################################
        Extracting rootfs partition tarball

################################################################################
EOM
        untar_progress $TARBALLPATH/rootfs_partition.tar.gz rootfs/

cat << EOM

################################################################################
        Extracting start_here partition to temp directory

################################################################################
EOM
        rm -rf tmp/*
        untar_progress $TARBALLPATH/start_here_partition.tar.gz tmp/

cat << EOM

################################################################################
        Extracting CCS tarball

################################################################################
EOM
        mv tmp/CCS-5*.tar.gz .
        untar_progress CCS-5*.tar.gz tmp/
        rm CCS-5*.tar.gz

cat << EOM

################################################################################
        Copying Contents to START_HERE

################################################################################
EOM

        TOTALSIZE=`sudo du -c tmp/* | grep total | awk {'print $1'}`
        cp -rf tmp/* start_here/ &
        cp_progress $TOTALSIZE start_here/
        sync;sync
        # Fix up the START_HERE partitoin permissions
        chown nobody -R start_here
        chgrp nogroup -R start_here
        chmod -R g+r+x,o+r+x start_here/CCS

        umount boot rootfs start_here
        sync;sync

        # Clean up the temp directories
        rm -rf boot rootfs start_here tmp
}


# find the avaible SD cards
echo " "
echo "Availible Drives to write images to: "
echo " "
ROOTDRIVE=`mount | grep 'on / ' | awk {'print $1'} |  cut -c6-8`
echo "#  major   minor    size   name "
cat /proc/partitions | grep -v $ROOTDRIVE | grep '\<sd.\>' | grep -n ''
echo " "

ENTERCORRECTLY=0
while [ $ENTERCORRECTLY -ne 1 ]
do
	read -p 'Enter Device Number: ' DEVICEDRIVENUMBER
	echo " "
	DEVICEDRIVENAME=`cat /proc/partitions | grep -v 'sda' | grep '\<sd.\>' | grep -n '' | grep "${DEVICEDRIVENUMBER}:" | awk '{print $5}'`

	DRIVE=/dev/$DEVICEDRIVENAME
	DEVICESIZE=`cat /proc/partitions | grep -v 'sda' | grep '\<sd.\>' | grep -n '' | grep "${DEVICEDRIVENUMBER}:" | awk '{print $4}'`


	if [ -n "$DEVICEDRIVENAME" ]
	then
		ENTERCORRECTLY=1
	else
		echo "Invalid selection"
	fi

	echo ""
done

echo "$DEVICEDRIVENAME was selected"
#Check the size of disk to make sure its under 16GB
if [ $DEVICESIZE -gt 17000000 ] ; then
cat << EOM

################################################################################

		**********WARNING**********

	Selected Device is greater then 16GB
	Continuing past this point will erase data from device
	Double check that this is the correct SD Card

################################################################################

EOM
	ENTERCORRECTLY=0
	while [ $ENTERCORRECTLY -ne 1 ]
	do
		read -p 'Would you like to continue [y/n] : ' SIZECHECK
		echo ""
		echo " "
		ENTERCORRECTLY=1
		case $SIZECHECK in
		"y")  ;;
		"n")  exit;;
		*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
		esac
		echo ""
	done

fi

echo ""



DRIVE=/dev/$DEVICEDRIVENAME

echo "Checking the device is unmounted"
#unmount drives if they are mounted
unmounted1=`df | grep '\<'$DEVICEDRIVENAME'1\>' | awk '{print $1}'`
unmounted2=`df | grep '\<'$DEVICEDRIVENAME'2\>' | awk '{print $1}'`
unmounted3=`df | grep '\<'$DEVICEDRIVENAME'3\>' | awk '{print $1}'`
if [ -n "$unmounted1" ]
then
	echo " unmounted ${DRIVE}1"
	sudo umount -f ${DRIVE}1
fi
if [ -n "$unmounted2" ]
then
	echo " unmounted ${DRIVE}2"
	sudo umount -f ${DRIVE}2
fi
if [ -n "$unmounted3" ]
then
	echo " unmounted ${DRIVE}3"
	sudo umount -f ${DRIVE}3
fi
echo ""
# check to see if the device is already partitioned
SIZE1=`cat /proc/partitions | grep -v 'sda' | grep '\<'$DEVICEDRIVENAME'1\>'  | awk '{print $3}'`
SIZE2=`cat /proc/partitions | grep -v 'sda' | grep '\<'$DEVICEDRIVENAME'2\>'  | awk '{print $3}'`
SIZE3=`cat /proc/partitions | grep -v 'sda' | grep '\<'$DEVICEDRIVENAME'3\>'  | awk '{print $3}'`
SIZE4=`cat /proc/partitions | grep -v 'sda' | grep '\<'$DEVICEDRIVENAME'4\>'  | awk '{print $3}'`
echo "${DEVICEDRIVENAME}1  ${DEVICEDRIVENAME}2   ${DEVICEDRIVENAME}3"
echo $SIZE1 $SIZE2 $SIZE3 $SIZE4
echo ""

PARTITION="0"
if [ -n "$SIZE1" -a -n "$SIZE2" ] ; then
	if  [ "$SIZE1" -gt "72000" -a "$SIZE2" -gt "700000" ]
	then
		PARTITION=1

		if [ -z "$SIZE3" -a -z "$SIZE4" ]
		then
			#Detected 2 partitions
			PARTS=2

		elif [ "$SIZE3" -gt "1000" -a -z "$SIZE4" ]
		then
			#Detected 3 partitions
			PARTS=3

		else
			echo "SD Card is not correctly partitioned"
			PARTITION=0
		fi
	fi
else
	echo "SD Card is not correctly partitioned"
	PARTITION=0
	PARTS=0
fi


#Partition is found
if [ "$PARTITION" -eq "1" ]
then
cat << EOM

################################################################################

   Detected device has $PARTS partitions already

   Re-partitioning will allow the choice of 2 or 3 partitions

################################################################################

EOM

	ENTERCORRECTLY=0
	while [ $ENTERCORRECTLY -ne 1 ]
	do
		read -p 'Would you like to re-partition the drive anyways [y/n] : ' CASEPARTITION
		echo ""
		echo " "
		ENTERCORRECTLY=1
		case $CASEPARTITION in
		"y")  echo "Now partitioning $DEVICEDRIVENAME ...";PARTITION=0;;
		"n")  echo "Skipping partitioning";;
		*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
		esac
		echo ""
	done

fi

#Partition is not found, choose to partition 2 or 3 segments
if [ "$PARTITION" -eq "0" ]
then
cat << EOM

################################################################################

	Select 2 partitions if only need boot and rootfs (most users)
	Select 3 partitions if need SDK & CCS on SD card.  This is usually used
        by device manufacturers with access to partition tarballs.

	****WARNING**** continuing will erase all data on $DEVICEDRIVENAME

################################################################################

EOM
	ENTERCORRECTLY=0
	while [ $ENTERCORRECTLY -ne 1 ]
	do

		read -p 'Number of partitions needed [2/3] : ' CASEPARTITIONNUMBER
		echo ""
		echo " "
		ENTERCORRECTLY=1
		case $CASEPARTITIONNUMBER in
		"2")  echo "Now partitioning $DEVICEDRIVENAME with 2 partitions...";PARTITION=2;;
		"3")  echo "Now partitioning $DEVICEDRIVENAME with 3 partitions...";PARTITION=3;;
		"n")  exit;;
		*)  echo "Please enter 2 or 3";ENTERCORRECTLY=0;;
		esac
		echo " "
	done
fi



#Section for partitioning the drive

#create 3 partitions
if [ "$PARTITION" -eq "3" ]
then

# set the PARTS value as well
PARTS=3

cat << EOM

################################################################################

		Now making 3 partitions

################################################################################

EOM

dd if=/dev/zero of=$DRIVE bs=1024 count=1024

SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`

echo DISK SIZE - $SIZE bytes

CYLINDERS=`echo $SIZE/255/63/512 | bc`

sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE << EOF
,9,0x0C,*
10,90,,-
100,,,-
EOF

cat << EOM

################################################################################

		Partitioning Boot

################################################################################
EOM
	mkfs.vfat -F 32 -n "boot" ${DRIVE}1
cat << EOM

################################################################################

		Partitioning Rootfs

################################################################################
EOM
	mkfs.ext3 -L "rootfs" ${DRIVE}2
cat << EOM

################################################################################

		Partitioning START_HERE

################################################################################
EOM
	mkfs.ext3 -L "START_HERE" ${DRIVE}3
	sync
	sync

#create only 2 partitions
elif [ "$PARTITION" -eq "2" ]
then

# Set the PARTS value as well
PARTS=2
cat << EOM

################################################################################

		Now making 2 partitions

################################################################################

EOM
dd if=/dev/zero of=$DRIVE bs=1024 count=1024

SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`

echo DISK SIZE - $SIZE bytes

CYLINDERS=`echo $SIZE/255/63/512 | bc`

sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE << EOF
,9,0x0C,*
10,,,-
EOF

cat << EOM

################################################################################

		Partitioning Boot

################################################################################
EOM
	mkfs.vfat -F 32 -n "boot" ${DRIVE}1
cat << EOM

################################################################################

		Partitioning rootfs

################################################################################
EOM
	mkfs.ext3 -L "rootfs" ${DRIVE}2
	sync
	sync
	INSTALLSTARTHERE=n
fi



#Break between partitioning and installing file system
cat << EOM


################################################################################

   Partitioning is now done
   Continue to install filesystem or select 'n' to safe exit

   **Warning** Continuing will erase files any files in the partitions

################################################################################


EOM
ENTERCORRECTLY=0
while [ $ENTERCORRECTLY -ne 1 ]
do
	read -p 'Would you like to continue? [y/n] : ' EXITQ
	echo ""
	echo " "
	ENTERCORRECTLY=1
	case $EXITQ in
	"y") ;;
	"n") exit;;
	*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
	esac
done

# If this is a three partition card then we will jump to a function to
# populate the three partitions and then exit the script.  If not we
# go on to prompt the user for input on the two partitions
if [ "$PARTS" -eq "3" ]
then
    populate_3_partitions
    exit 0
fi

#Add directories for images
export START_DIR=$PWD
mkdir $START_DIR/tmp
export PATH_TO_SDBOOT=boot
export PATH_TO_SDROOTFS=rootfs
export PATH_TO_TMP_DIR=$START_DIR/tmp


echo " "
echo "Mount the partitions "
mkdir $PATH_TO_SDBOOT
mkdir $PATH_TO_SDROOTFS

sudo mount -t vfat ${DRIVE}1 boot/
sudo mount -t ext3 ${DRIVE}2 rootfs/



echo " "
echo "Emptying partitions "
echo " "
sudo rm -rf  $PATH_TO_SDBOOT/*
sudo rm -rf  $PATH_TO_SDROOTFS/*

echo ""
echo "Syncing...."
echo ""
sync
sync
sync

cat << EOM
################################################################################

	Choose file path to install from

	1 ) Install pre-built images from SDK
	2 ) Enter in custom boot and rootfs file paths

################################################################################

EOM
ENTERCORRECTLY=0
while [ $ENTERCORRECTLY -ne 1 ]
do
	read -p 'Choose now [1/2] : ' FILEPATHOPTION
	echo ""
	echo " "
	ENTERCORRECTLY=1
	case $FILEPATHOPTION in
	"1") echo "Will now install from SDK pre-built images";;
	"2") echo "";;
	*)  echo "Please enter 1 or 2";ENTERCORRECTLY=0;;
	esac
done

# SDK DEFAULTS
if [ $FILEPATHOPTION -eq 1 ] ; then

	#check that in the right directory

	THEEVMSDK=`echo $PARSEPATH | grep -o 'ti-sdk-.*[0-9]'`

	if [ $PATHVALID -eq 1 ]; then
	echo "now installing:  $THEEVMSDK"
	else
	echo "no SDK PATH found"
	ENTERCORRECTLY=0
		while [ $ENTERCORRECTLY -ne 1 ]
		do
			read -e -p 'Enter path to SDK : '  SDKFILEPATH

			echo ""
			ENTERCORRECTLY=1
			if [ -d $SDKFILEPATH ]
			then
				echo "Directory exists"
				echo ""
				PARSEPATH=`echo $SDKFILEPATH | grep -o '.*ti-sdk.*.[0-9]/'`
				#echo $PARSEPATH

				if [ "$PARSEPATH" != "" ] ; then
				PATHVALID=1
				else
				PATHVALID=0
				fi
				#echo $PATHVALID
				if [ $PATHVALID -eq 1 ] ; then

				THEEVMSDK=`echo $SDKFILEPATH | grep -o 'ti-sdk-.*[0-9]'`
				echo "Is this the correct SDK: $THEEVMSDK"
				echo ""
				read -p 'Is this correct? [y/n] : ' ISRIGHTPATH
					case $ISRIGHTPATH in
					"y") ;;
					"n") ENTERCORRECTLY=0;;
					*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
					esac
				else
				echo "Invalid SDK path make sure to include ti-sdk-xxxx"
				ENTERCORRECTLY=0
				fi

			else
				echo "Invalid path make sure to include complete path"

				ENTERCORRECTLY=0
			fi
		done
	fi



	#check that files are in SDK
	BOOTFILEPATH="$PARSEPATH/board-support/prebuilt-images"
	MLO=`ls $BOOTFILEPATH | grep MLO | awk {'print $1'}`
	UIMAGE=`ls $BOOTFILEPATH | grep uImage | awk {'print $1'}`
	BOOTIMG=`ls $BOOTFILEPATH | grep u-boot | grep .img | awk {'print $1'}`
	BOOTBIN=`ls $BOOTFILEPATH | grep u-boot | grep .bin | awk {'print $1'}`
	#rootfs
	ROOTFILEPARTH="$PARSEPATH/filesystem"
	#ROOTFSTAR=`ls  $ROOTFILEPARTH | grep tisdk-rootfs | awk {'print $1'}`

	#Make sure there is only 1 tar
	CHECKNUMOFTAR=`ls $ROOTFILEPARTH | grep "tisdk-rootfs" | grep 'tar.gz' | grep -n '' | grep '2:' | awk {'print $1'}`
	if [ -n "$CHECKNUMOFTAR" ]
	then
cat << EOM

################################################################################

   Multiple rootfs Tarballs found

################################################################################

EOM
		ls $ROOTFILEPARTH | grep "tisdk-rootfs" | grep 'tar.gz' | grep -n '' | awk {'print "	" , $1'}
		echo ""
		read -p "Enter Number of rootfs Tarball: " TARNUMBER
		echo " "
		FOUNDTARFILENAME=`ls $ROOTFILEPARTH | grep "rootfs" | grep 'tar.gz' | grep -n '' | grep "${TARNUMBER}:" | cut -c3- | awk {'print$1'}`
		ROOTFSTAR=$FOUNDTARFILENAME

	else
		ROOTFSTAR=`ls  $ROOTFILEPARTH | grep "tisdk-rootfs" | grep 'tar.gz' | awk {'print $1'}`
	fi

	ROOTFSUSERFILEPATH=$ROOTFILEPARTH/$ROOTFSTAR
	BOOTPATHOPTION=1
	ROOTFSPATHOPTION=2

elif [ $FILEPATHOPTION -eq 2  ] ; then
cat << EOM
################################################################################

  For Boot partition

  If files are located in Tarball write complete path including the file name.
      e.x. $:  /home/user/MyCustomTars/boot.tar.gz

  If files are located in a directory write the directory path
      e.x. $: /ti-sdk/board-support/prebuilt-images/

  and the beginning of the files should be labeled with MLO, u-boot, uImage
      i.e.   test_MLO_image must be labeled as MLO_test_image

  NOTE: Not all platforms will have an MLO file and this file can
        be ignored for platforms that do not support an MLO
################################################################################

EOM
	ENTERCORRECTLY=0
	while [ $ENTERCORRECTLY -ne 1 ]
	do
		read -e -p 'Enter path for Boot Partition : '  BOOTUSERFILEPATH

		echo ""
		ENTERCORRECTLY=1
		if [ -f $BOOTUSERFILEPATH ]
		then
			echo "File exists"
			echo ""
		elif [ -d $BOOTUSERFILEPATH ]
		then
			echo "Directory exists"
			echo ""
			echo "This directory contains:"
			ls $BOOTUSERFILEPATH
			echo ""
			read -p 'Is this correct? [y/n] : ' ISRIGHTPATH
				case $ISRIGHTPATH in
				"y") ;;
				"n") ENTERCORRECTLY=0;;
				*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
				esac
		else
			echo "Invalid path make sure to include complete path"

			ENTERCORRECTLY=0
		fi
	done

cat << EOM


################################################################################

   For Rootfs partition

   If files are located in Tarball write complete path including the file name.
      e.x. $:  /home/user/MyCustomTars/rootfs.tar.gz

  If files are located in a directory write the directory path
      e.x. $: /ti-sdk/targetNFS/

################################################################################

EOM
	ENTERCORRECTLY=0
	while [ $ENTERCORRECTLY -ne 1 ]
	do
		read -e -p 'Enter path for Rootfs Partition : ' ROOTFSUSERFILEPATH
		echo ""
		ENTERCORRECTLY=1
		if [ -f $ROOTFSUSERFILEPATH ]
		then
			echo "File exists"
			echo ""
		elif [ -d $ROOTFSUSERFILEPATH ]
		then
			echo "This directory contains:"
			ls $ROOTFSUSERFILEPATH
			echo ""
			read -p 'Is this correct? [y/n] : ' ISRIGHTPATH
				case $ISRIGHTPATH in
				"y") ;;
				"n") ENTERCORRECTLY=0;;
				*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
				esac

		else
			echo "Invalid path make sure to include complete path"

			ENTERCORRECTLY=0
		fi
	done
	echo ""


	# Check if user entered a tar or not for Boot
	ISBOOTTAR=`ls $BOOTUSERFILEPATH | grep .tar.gz | awk {'print $1'}`
	if [ -n "$ISBOOTTAR" ]
	then
		BOOTPATHOPTION=2
	else
		BOOTPATHOPTION=1
		BOOTFILEPATH=$BOOTUSERFILEPATH
		MLO=`ls $BOOTFILEPATH | grep MLO | awk {'print $1'}`
		UIMAGE=`ls $BOOTFILEPATH | grep uImage | awk {'print $1'}`
		BOOTIMG=`ls $BOOTFILEPATH | grep u-boot | grep .img | awk {'print $1'}`
		BOOTBIN=`ls $BOOTFILEPATH | grep u-boot | grep .bin | awk {'print $1'}`
	fi

	#Check if user entered a tar or not for Rootfs
	ISROOTFSTAR=`ls $ROOTFSUSERFILEPATH | grep .tar.gz | awk {'print $1'}`
	if [ -n "$ISROOTFSTAR" ]
	then
		ROOTFSPATHOPTION=2
	else
		ROOTFSPATHOPTION=1
		ROOTFSFILEPATH=$ROOTFSUSERFILEPATH
	fi
fi

cat << EOM
################################################################################

	Copying files now... will take minutes

################################################################################

Copying boot partition
EOM


if [ $BOOTPATHOPTION -eq 1 ] ; then

	echo ""
	#copy boot files out of board support
	if [ "$MLO" != "" ] ; then
		cp $BOOTFILEPATH/$MLO $PATH_TO_SDBOOT/MLO
		echo "MLO copied"
	else
		echo "MLO file not found"
	fi

	echo ""

	if [ "$BOOTBIN" != "" ] ; then
		cp $BOOTFILEPATH/$BOOTBIN $PATH_TO_SDBOOT/u-boot.bin
		echo "u-boot.bin copied"
	else
		echo "u-boot.bin file not found"
	fi

	echo ""

	if [ "$BOOTIMG" != "" ] ; then
		cp $BOOTFILEPATH/$BOOTIMG $PATH_TO_SDBOOT/u-boot.img
		echo "u-boot.img copied"
	else
		echo "u-boot.img file not found"
	fi

	echo ""

	if [ "$UIMAGE" != "" ] ; then
		cp $BOOTFILEPATH/$UIMAGE $PATH_TO_SDBOOT/uImage
		echo "uImage copied"
	else
		echo "uImage file not found"
	fi

elif [ $BOOTPATHOPTION -eq 2  ] ; then
	untar_progress $BOOTUSERFILEPATH $PATH_TO_TMP_DIR
	cp -rf $PATH_TO_TMP_DIR/* $PATH_TO_SDBOOT
	echo ""

fi

echo ""
sync

echo "Copying rootfs System partition"
if [ $ROOTFSPATHOPTION -eq 1 ] ; then
	TOTALSIZE=`sudo du -c $ROOTFSUSERFILEPATH/* | grep total | awk {'print $1'}`
	sudo cp -r $ROOTFSUSERFILEPATH/* $PATH_TO_SDROOTFS & cp_progress $TOTALSIZE $PATH_TO_SDROOTFS

elif [ $ROOTFSPATHOPTION -eq 2  ] ; then
	untar_progress $ROOTFSUSERFILEPATH $PATH_TO_SDROOTFS
fi

echo ""
echo ""
echo "Syncing..."
sync
sync
sync
sync
sync
sync
sync
sync


echo " "
echo "Un-mount the partitions "
sudo umount -f $PATH_TO_SDBOOT
sudo umount -f $PATH_TO_SDROOTFS


echo " "
echo "Remove created temp directories "
sudo rm -rf $PATH_TO_TMP_DIR
sudo rm -rf $PATH_TO_SDROOTFS
sudo rm -rf $PATH_TO_SDBOOT


echo " "
echo "Operation Finished"
echo " "
