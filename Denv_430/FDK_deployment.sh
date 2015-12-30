#!/bin/tcsh
clear
# set the mail logfile
setenv logfile /tmp/cad_deployment_`hostname -a`.log
# cleanup old sync log files from previous deployments if exist / create directory structure if not existing.
if(-d /tmp/rsynclogs/cdns) then
	find /tmp/rsynclogs/cdns/ -type f -exec rm -Rf {} \;
else
	mkdir -p /tmp/rsynclogs/cdns
endif
if(-d /tmp/rsynclogs/fdks) then
	find /tmp/rsynclogs/fdks/ -type f -exec rm -Rf {} \;
else
	mkdir -p /tmp/rsynclogs/fdks
endif
setenv cdnsrlog /tmp/rsynclogs/cdns
setenv fdksrlog /tmp/rsynclogs/fdks
echo "###################################################" | tee -a $logfile
echo "# CAD deployment script for EXNET servers         #" | tee -a $logfile
echo "# ---------------------------------------         #" | tee -a $logfile
echo "# `date '+DATE: %d/%m/%y TIME:%H:%M:%S'`          #" | tee -a $logfile
echo "# This script will deploy a full CAD environment  #" | tee -a $logfile
echo "# based on several project parameters (develop)   #" | tee -a $logfile
echo "###############################################" | tee -a $logfile
echo "  "  | tee -a $logfile

echo "---------------------------------------------------" | tee -a $logfile
echo "- STEP 1 : local mount cadeneed on the system     -" | tee -a $logfile
echo "---------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo " Mounting cadeneed production volume temporarely under /mnt/ed-prod ..." | tee -a $logfile
if(-d /mnt/ed-prod/) then
	echo " Mount directory /mnt/ed-prod already exists on the system ... continuing" | tee -a $logfile
else
	echo " Mount directory /mnt/ed-prod doesn't exist on the system, creating local directory first." | tee -a $logfile
	mkdir -p /mnt/ed-prod
	echo " Directory /mnt/ed-prod created!" | tee -a $logfile
endif
echo " " | tee -a $logfile
echo " Checking if mount cadenceed already exists on the system..." | tee -a $logfile
if(`grep "/mnt/ed-prod" /proc/mounts` == "") then
	echo " Mount doesn't exist, creating mount." | tee -a $logfile
	# mount doesn't exist yet
	mount cadenceed:/vol/cadenceed/cadenceed /mnt/ed-prod
	echo " Mount created." | tee -a $logfile
else
	# mount exists, checking if it goes to the correct volume
	echo " Mount already exists, checking if it points to the correct volume." | tee -a $logfile
	if(`grep "/mnt/ed-prod" /proc/mounts | grep "cadenceed:/vol/cadenceed/cadenceed"` == "") then
		echo " Wrong volume mounted under /mnt/ed-prod, unmounting volume and re-mounting correct volume." | tee -a $logfile
		umount -l /mnt/ed-prod
		mount cadenceed:/vol/cadenceed/cadenceed /mnt/ed-prod
		echo " Volume cadeneed:/vol/cadenceed/cadenceed is mounted under /mnt/ed-prod."
	else
		echo " Correct volume mounted under /mnt/ed-prod." | tee -a $logfile
	endif
endif
echo " " | tee -a $logfile
echo "---------------------------------------------------" | tee -a $logfile
echo "- STEP 1 : Done! Please press any key to continue!-" | tee -a $logfile
echo -n "---------------------------------------------------" | tee -a $logfile   
set answer = $<

# ICrelease = contains IC5 / IC6
FDKbase:
clear
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 7 :  Deploying the Foundry Development Kit data                   -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile

set ICrelease = IC6

set fdklocal = /mnt/ed/caddata/xfb/mcad_tkits/`echo $ICrelease | sed 's/./\L&/g'`
set fdkprod = /mnt/ed-prod/caddata/xfb/mcad_tkits/`echo $ICrelease | sed 's/./\L&/g'`
echo " Checking if local FDK deployment folder exists." | tee -a $logfile
if(-d $fdklocal) then
	echo " Local deployment folder exists." | tee -a $logfile
else
	echo " Local deployment folder doesn't exist. Creating local folder." | tee -a $logfile
	mkdir -p $fdklocal
endif
set relarray = `ls $fdkprod`
set trel = `echo $#relarray`
echo " Select the technology you want to deploy:"
set irel = 1
foreach x ($relarray)
	echo " $irel : $x"
	@ irel ++
end
echo " "
echo -n " Select your release: "
set tech = $<
if($tech > $trel || `echo $tech | cut -c1` == "0") then
	echo " Your choice is out of range! Please define your technology properly!" 
	echo -n " Press any key to return to the menu ..." 
	set answer = $<
	goto FDKbase
endif
set tech = $relarray[$tech]
echo " " | tee -a $logfile
clear
FDKreleasebase:
clear
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 8 :  Deploying the Foundry Development Kit data release           -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
set fdklocal = $fdklocal/$tech
set fdkprod = $fdkprod/$tech
if(-d $fdklocal) then
	echo " Local deployment folder exists." | tee -a $logfile
else
	echo " Local deployment folder doesn't exist. Creating local folder." | tee -a $logfile
	mkdir -p $fdklocal
endif
set relarray = `ls $fdkprod`
set trel = `echo $#relarray`
echo " Select the release you want to deploy:"
set irel = 1
foreach x ($relarray)
	echo " $irel : $x"
	@ irel ++
end
echo " "
echo -n " Select your release: "
set techrelease = $<
if($techrelease > $trel || `echo $tech | cut -c1` == "0") then
	echo " Your choice is out of range! Please define your technology properly!" 
	echo -n " Press any key to return to the menu ..." 
	set answer = $<
	goto FDKreleasebase
endif
set techrelease = $relarray[$techrelease]
set fdklocalroot = $fdklocal
set fdklocal = $fdklocal/$techrelease
set fdkprod = $fdkprod/$techrelease
echo " Starting rsync on FDK data from $fdkprod to $fdklocal" | tee -a $logfile
rsync -avz --exclude ".svn" $fdkprod/ $fdklocal/ > $fdksrlog/$tech"_"$techrelease.log &
echo " Waiting for rsync to be finished ...."
wait
echo " Rsync finished, deployment FDK done!" | tee -a $logfile
cd $fdklocalroot
ln -s $techrelease release_production

echo " "
echo " Un-mounting ed-prod volume " | tee -a $logfile
umount -l /mnt/ed-prod
echo " Done!"
echo " Ciao"

#echo -n " Press any key to continue ..." 
#set answer = $<
