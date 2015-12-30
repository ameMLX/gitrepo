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
echo " Mounting cadenceed production volume temporarely under /mnt/ed-prod ..." | tee -a $logfile
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

basereleasemenu:
clear
echo "---------------------------------------------------" | tee -a $logfile
echo "- STEP 2 : Cadence platform release               -" | tee -a $logfile
echo "---------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo " Please select the cadence platform release you want to deploy:"
echo " 1. IC5" 
echo " 2. IC6"
echo -n " Select the flatform release you want to deploy [1/2]: " 
set baserelease = $<
switch ($baserelease)
case 1:
echo " Cadence base release IC5 has been selected! " | tee -a $logfile
echo " Proceeding with selecting the sub-releases ... " | tee -a $logfile
set ICmcad = /mnt/ed-prod/ct/lnx/rh/53/64/CADENCE_releases/ic5/
set ICmcadlocal = /mnt/ed/ct/lnx/rh/53/64/CADENCE_releases/ic5/
set ICrelease = IC5
breaksw
case 2:
echo " Cadence base release IC6 has been selected! " | tee -a $logfile
echo " Proceeding with selecting the sub-releases ... " | tee -a $logfile
set ICmcad = /mnt/ed-prod/ct/lnx/rh/53/64/CADENCE_releases/ic6/
set ICmcadlocal = /mnt/ed/ct/lnx/rh/53/64/CADENCE_releases/ic6/
set ICrelease = IC6
breaksw
default:
	echo " Your choice is out of range! Please define your platform release properly (option 1 or option 2)! "
	echo -n " Press any key to return to the menu...."
	set answer = $<
	goto basereleasemenu 
endsw
ICbase:
clear
set relarray = `ls $ICmcad`
set trel = `echo $#relarray`
echo "--------------------------------------------------------" | tee -a $logfile
echo "- STEP 3 : Cadence platform release $ICrelease - subreleases  -" | tee -a $logfile
echo "--------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo " Please select the IC platform release you want to deploy:"
echo " "
set irel = 1
foreach x ($relarray)
	echo " $irel : $x"
	@ irel ++
end
echo " "
echo -n " Select your release: "
set subicrelease = $<
if($subicrelease > $trel || `echo $subicrelease | cut -c1` == "0") then
	echo " Your choice is out of range! Please define your subrelease properly!" 
	echo -n " Press any key to return to the menu ..." 
	set answer = $<
	goto ICbase
endif
echo " " | tee -a $logfile
clear

echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 4 : Rsyncing cadence platform release $ICrelease - $subicrelease  -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo " Starting rsyncs ... " | tee -a $logfile
echo " " | tee -a $logfile
set cdnsreleasenr = $relarray[$subicrelease]
set relpackages = `ls $ICmcad/$relarray[$subicrelease]`
foreach x ($relpackages)
	echo $x "\n"
	if(`find $ICmcad/$relarray[$subicrelease]/$x -type l -xtype l -exec file {} \; | awk -F'broken symbolic link to ' '{print $2}'` != "") then
        	set sourcepath = `find $ICmcad/$relarray[$subicrelease]/$x -type l -xtype l -exec file {} \; | awk -F'broken symbolic link to ' '{print $2}' | awk -F"'" '{print $1}' | sed -e "s/\/ed\//\/ed-prod\//g" | sed "s/^.//"`
		set destpath = `echo $sourcepath | sed -e "s/\/ed-prod\//\/ed\//g"`
	else
		set sourcepath = `readlink $ICmcad/$relarray[$subicrelease]/$x | sed -e "s/\/ed\//\/ed-prod\//g"`
		set destpath = `readlink $ICmcad/$relarray[$subicrelease]/$x`
	endif
	if(-d $destpath) then
		#do nothing / path exists
	else
		mkdir -p $destpath
	endif
	echo " Rsync package $x from $sourcepath to $destpath." | tee -a $logfile
	if(-d $sourcepath) then
		rsync -avz --force --delete $sourcepath/ $destpath/ > $cdnsrlog/$x"_rsync.log" &
		if(-d $ICmcadlocal/$cdnsreleasenr) then
		else
			mkdir -p $ICmcadlocal/$cdnsreleasenr
		endif
		ln -s $destpath $ICmcadlocal/$cdnsreleasenr/$x
	else
		echo " Rsync failed -> $sourcepath not available" | tee -a $logfile
	endif
end
echo " " | tee -a $logfile
echo " Waiting for Rsync processes to finish. " | tee -a $logfile
echo " " | tee -a $logfile
wait
echo " Checking if all rsync processes are executed... " | tee -a $logfile
if(`lsof -ad3-999 -c rsync | grep /mnt/ed` == "")then
	echo " OK: No resync processes running anymore." | tee -a $logfile
endif
echo " " | tee -a $logfile
echo " Checking if errors appeared during rsync ..." | tee -a $logfile
set rsynclog = `ls $cdnsrlog/`
foreach x ($rsynclog)
 	set cdnstool = `echo $x | awk -F"_rsync.log" '{print $1}'`
	if(`cat $cdnsrlog/$x | grep -i "rsync error:"` != "")then
		echo " ERROR: an error occured with one of the syncs for package $cdnstool!" | tee -a $logfile
		echo " The error log file will be opened, close the log to continue with the deployment" | tee -a $logfile
		echo -n " Click any key to open the log file." | tee -a $logfile
		set answer = $<
		nedit $cdnsrlog/$x &
		wait
	else
		echo " OK : RSYNC for package $cdnstool went without errors." | tee -a $logfile
	endif
end
echo " " | tee -a $logfile

echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 5 :  Deploying software initialization scripts                    -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
set mcadinitlocal = /mnt/ed/ct/init/mcadinit/rh53/`echo $ICrelease | tr '[:upper:]' '[:lower:]'`
set mcadinitprod = /mnt/ed-prod/ct/init/mcadinit/rh53/`echo $ICrelease | tr '[:upper:]' '[:lower:]'`
echo " Checking if cadence init folder exists." | tee -a $logfile
if(-d $mcadinitlocal) then
	echo " Cadence init folder exists ... cleaning folder first." | tee -a $logfile
	find $mcadinitlocal -type f -exec rm -Rf {} \;
	find $mcadinitlocal -type l -exec rm -Rf {} \;
else
	echo " Cadence init folder doesn't exist ... creating folder." | tee -a $logfile
	mkdir -p $mcadinitlocal
endif
echo " Deploying release init files." | tee -a $logfile
# cdnsreleasenr = containing the specific cadence release number e.g. release_113
echo " - $cdnsreleasenr.cshrc" | tee -a $logfile
echo " - symlink release_production.cshrc to $cdnsreleasenr.cshrc" | tee -a $logfile
echo " " | tee -a $logfile
scp $mcadinitprod/$cdnsreleasenr.cshrc $mcadinitlocal/
cd $mcadinitlocal
ln -s $cdnsreleasenr.cshrc release_production.cshrc
chmod -R 775 *
echo " Cadence release init files are deployed."

echo " "
echo " Un-mounting ed-prod volume " | tee -a $logfile
umount -l /mnt/ed-prod
echo " Done!"
echo " Ciao"

#echo -n " Press any key to continue ... "
#set answer = $<
#clear

