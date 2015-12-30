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
echo -n " Press any key to continue ... "
set answer = $<
clear

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
echo -n " Press any key to continue."
set answer = $<
clear

FDK:
clear
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 6 :  Used Foundry                                                 -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo " Please select the foundry development kit data you want to deploy:       " | tee -a $logfile
echo " " | tee -a $logfile
echo " 1. XFAB" | tee -a $logfile
echo " 2. UMC" | tee -a $logfile
echo " " | tee -a $logfile
echo -n " Please select 1/2: "
set foundry = $<
if($foundry == "1")then
else
	if($foundry == "2") then
	else
		echo " Incorrect choice, please try again!" | tee -a $logfile
		echo -n " Press any key to continue.... " | tee -a $logfile
		set answer = $<
		goto FDK
	endif
endif

echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 7 :  Deploying design environment                                 -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo " Checking if environment init folder exists." | tee -a $logfile

set envinitlocal = /mnt/ed/caddata/init
set envinitprod = /mnt/ed-prod/caddata/init
set toolsinitlocal = /mnt/ed/caddata/tools_init
set toolsinitprod = /mnt/ed-prod/caddata/tools_init
set pythonlocal = /mnt/ed/ct/lnx/rh/53/64/python
set pythonprod = /mnt/ed-prod/ct/lnx/rh/53/64/python
set ctinitlocal = /mnt/ed/ct/init
set ctinitprod = /mnt/ed-prod/ct/init
set envrlog = /tmp/rsynclogs/env

if(-d $envrlog) then
	find $envrlog/ -type f -exec rm -Rf {} \;
else
	mkdir -p $envrlog
endif

if(-d $envinitlocal) then
	echo " Environment init folder exists ... cleaning folder first." | tee -a $logfile
	find $envinitlocal -type f -exec rm -Rf {} \;
else
	echo " Environment init folder doesn't exists ... creating folder." | tee -a $logfile
	mkdir -p $envinitlocal
endif

if(-d $toolsinitlocal) then
	echo " Tools init folder exists ... cleaning folder first." | tee -a $logfile
	find $toolsinitlocal -type f -exec rm -Rf {} \;
	find $toolsinitlocal -type d -exec rm -Rf {} \;
	find $toolsinitlocal -type l -exec rm -Rf {} \;
	mkdir -p $toolsinitlocal
else
	echo " Tools init folder doesn't exists ... creating folder." | tee -a $logfile
	mkdir -p $toolsinitlocal
endif

echo " Deploying environmental files" | tee -a $logfile
if($foundry == "2") then
echo " UMC:" | tee -a $logfile
echo " - calibre.cshrc as calibre.cshrc in $envinitlocal" | tee -a $logfile
echo " - mlxskill_umc.il as mlxskill_umc.il in $envinitlocal" | tee -a $logfile
endif
echo " ENV:" | tee -a $logfile
echo " - design.cshrc as design.cshrc in $envinitlocal" | tee -a $logfile
echo " - mlxskill.il in $envinitlocal" | tee -a $logfile
echo " - mlxtools.cshrc in $envinitlocal" | tee -a $logfile
echo " - ptc_check.cshrc in $envinitlocal" | tee -a $logfile
echo " - dassault synchronicity in $envinitlocal" | tee -a $logfile
echo " - cdnmenus in $envinitlocal" | tee -a $logfile
echo " TOOLS:" | tee -a $logfile
echo " - mcad initialization script in $toolsinitlocal" | tee -a $logfile
echo " - bpc initialization script in $toolsinitlocal" | tee -a $logfile
echo " - vncserver initialization script in $toolsinitlocal" | tee -a $logfile
echo " - diskqouta initialization script in $toolsinitlocal" | tee -a $logfile 
echo " - mhelp initialization script in $toolsinitlocal" | tee -a $logfile
echo " - lmstat 9.22 initialization script in $toolsinitlocal" | tee -a $logfile
echo " - borders initialization script in $toolsinitlocal" | tee -a $logfile
echo " - cadence custom views initialization script in $toolsinitlocal" | tee -a $logfile
echo " - celldocu initialization script in $toolsinitlocal" | tee -a $logfile
echo " - MIM CAP checker script in $toolsinitlocal" | tee -a $logfile
echo " - PVS latest script in $toolsinitlocal" | tee -a $logfile
echo " - Nedit syntax recognition for verilog-a in $toolsinitlocal" | tee -a $logfile
echo " - OCCbrowser in $toolsinitlocal" | tee -a $logfile
echo " - PCT in $toolsinitlocal" | tee -a $logfile
echo " - Image printer in $toolsinitlocal" | tee -a $logfile
echo " - Python base release 2.7 / 3.4 in $pythonlocal" | tee -a $logfile 
echo " - License Tool in $toolsinitlocal" | tee -a $logfile 
echo " - XLS Pack in $toolsinitlocal" | tee -a $logfile 
echo " - Revision tool in $toolsinitlocal" | tee -a $logfile
echo " - User Preference tool in $toolsinitlocal" | tee -a $logfile
echo " - Hierarchical checker tool in $toolsinitlocal" | tee -a $logfile
echo " PATCH:" | tee -a $logfile
echo " - firefox patch vncsessions in $toolsinitlocal" | tee -a $logfile
echo " - openoffice patch in $toolsinitlocal" | tee -a $logfile

cd $envinitlocal
scp $envinitprod/design.cshrc $envinitlocal/design.cshrc
scp $envinitprod/mlxskill.il $envinitlocal/mlxskill.il
scp $envinitprod/mlxtools.cshrc $envinitlocal/mlxtools.il
scp $envinitprod/local.cshrc $envinitlocal/local.il
scp $envinitprod/dassault.cshrc $envinitlocal/dassault.cshrc
scp $envinitprod/dessync_wrapper.cshrc $envinitlocal/dessync_wrapper.cshrc
if($foundry == "2") then
	scp $envinitprod/calibre.cshrc $envinitlocal/calibre.cshrc
	scp $envinitprod/mlxskill_umc.il $envinitlocal/mlxskill_umc.il
endif

cd $toolsinitlocal
mkdir -p $toolsinitlocal/mcad
mkdir -p $toolsinitlocal/gds_ipc
mkdir -p $toolsinitlocal/vncserver
mkdir -p $toolsinitlocal/disk_quota
mkdir -p $toolsinitlocal/mhelp
mkdir -p $toolsinitlocal/lmstat9.22
mkdir -p $toolsinitlocal/borders
mkdir -p $toolsinitlocal/cdnsviews
mkdir -p $toolsinitlocal/celldocu
mkdir -p $toolsinitlocal/firefox
mkdir -p $toolsinitlocal/mlx_cmim
mkdir -p $toolsinitlocal/mlx_env
mkdir -p $toolsinitlocal/mlxooffice
mkdir -p $toolsinitlocal/nedit
mkdir -p $toolsinitlocal/occbrowser
mkdir -p $toolsinitlocal/office
mkdir -p $toolsinitlocal/pct
mkdir -p $toolsinitlocal/print2image_tool
mkdir -p $toolsinitlocal/license_tool
mkdir -p $toolsinitlocal/xls_pack
mkdir -p $toolsinitlocal/revision_tool
mkdir -p $toolsinitlocal/user_pref_tool
mkdir -p $toolsinitlocal/hierarchical_checker
mkdir -p $ctinitlocal/cdnmenus
if(-d pythonlocal) then
	# do nothing
else
	mkdir -p $pythonlocal
endif
rsync -avz --exclude ".svn" $pythonprod/ $pythonlocal/ > $envrlog/python.log &
rsync -avz --exclude ".svn" $toolsinitprod/mcad/  $toolsinitlocal/mcad/  > $envrlog/mcad.log &
rsync -avz --exclude ".svn" $toolsinitprod/gds_ipc/  $toolsinitlocal/gds_ipc/  > $envrlog/gdsipc.log &
rsync -avz --exclude ".svn" $toolsinitprod/vncserver/  $toolsinitlocal/vncserver/  > $envrlog/vncserver.log &
rsync -avz --exclude ".svn" $toolsinitprod/disk_quota/  $toolsinitlocal/disk_quota/  > $envrlog/diskquota.log &
rsync -avz --exclude ".svn" $toolsinitprod/mhelp/  $toolsinitlocal/mhelp/  > $envrlog/mhelp.log &
rsync -avz --exclude ".svn" $toolsinitprod/lmstat9.22/  $toolsinitlocal/lmstat9.22/  > $envrlog/lmstat.log &
rsync -avz --exclude ".svn" $toolsinitprod/borders/  $toolsinitlocal/borders/  > $envrlog/borders.log &
rsync -avz --exclude ".svn" $toolsinitprod/cdnsviews/  $toolsinitlocal/cdnsviews/  > $envrlog/cdnsviews.log &
rsync -avz --exclude ".svn" $toolsinitprod/celldocu/  $toolsinitlocal/celldocu/  > $envrlog/celldocu.log &
rsync -avz --exclude ".svn" $toolsinitprod/firefox/  $toolsinitlocal/firefox/  > $envrlog/firefox.log &
rsync -avz --exclude ".svn" $toolsinitprod/mlx_cmim/  $toolsinitlocal/mlx_cmim/  > $envrlog/mlxcmim.log &
rsync -avz --exclude ".svn" $toolsinitprod/mlx_env/  $toolsinitlocal/mlx_env/  > $envrlog/mlxenv.log &
rsync -avz --exclude ".svn" $toolsinitprod/mlxooffice/  $toolsinitlocal/mlxooffice/  > $envrlog/mlxooffice.log &
rsync -avz --exclude ".svn" $toolsinitprod/nedit/  $toolsinitlocal/nedit/  > $envrlog/nedit.log &
rsync -avz --exclude ".svn" $toolsinitprod/occbrowser/  $toolsinitlocal/occbrowser/  > $envrlog/occbrowser.log &
rsync -avz --exclude ".svn" $toolsinitprod/office/  $toolsinitlocal/office/  > $envrlog/office.log &
rsync -avz --exclude ".svn" $toolsinitprod/pct/  $toolsinitlocal/pct/  > $envrlog/pct.log &
rsync -avz --exclude ".svn" $toolsinitprod/print2image_tool/  $toolsinitlocal/print2image_tool/  > $envrlog/print2image.log &
rsync -avz --exclude ".svn" $toolsinitprod/license_tool/  $toolsinitlocal/license_tool/  > $envrlog/licensetool.log &
rsync -avz --exclude ".svn" $toolsinitprod/xls_pack/  $toolsinitlocal/xls_pack/  > $envrlog/xlspack.log &
rsync -avz --exclude ".svn" $toolsinitprod/revision_tool/  $toolsinitlocal/revision_tool/  > $envrlog/revtool.log &
rsync -avz --exclude ".svn" $toolsinitprod/user_pref_tool/  $toolsinitlocal/user_pref_tool/  > $envrlog/userpreftool.log &
rsync -avz --exclude ".svn" $toolsinitprod/hierarchical_checker/  $toolsinitlocal/hierarchical_checker/  > $envrlog/hierarchicalchecker.log &
rsync -avz --exclude ".svn" $ctinitprod/cdnmenus/  $ctinitlocal/cdnmenus/  > $envrlog/cdnmenus.log &
echo " Waiting for rsync to be finished ..." 
wait

chmod -R 775 $toolsinitlocal/*
chmod -R 775 $envinitlocal/*
echo " ENV: design.cshrc deployed." | tee -a $logfile
echo " ENV: mlxskill.il deployed" | tee -a $logfile
echo " ENV: mlxtools.cshrc deployed" | tee -a $logfile
echo " ENV: local.cshrc deployed" | tee -a $logfile
echo " ENV: dassault.cshrc deployed" | tee -a $logfile
echo " " | tee -a $logfile
echo " TOOLS: mcad deployed!" | tee -a $logfile
echo " TOOLS: bpc deployed!" | tee -a $logfile
echo " TOOLS: vncserver deployed!" | tee -a $logfile
echo " TOOLS: disk quoate deployed!" | tee -a $logfile
echo " TOOLS: mhelp deployed!" | tee -a $logfile
echo " TOOLS: lmstat deployed!" | tee -a $logfile
echo " TOOLS: borders deployed!" | tee -a $logfile
echo " TOOLS: custom views deployed!" | tee -a $logfile
echo " TOOLS: celldocu deployed!" | tee -a $logfile
echo " TOOLS: mim caps deployed!" | tee -a $logfile
echo " TOOLS: pvs latest deployed!" | tee -a $logfile
echo " TOOLS: nedit deployed!" | tee -a $logfile
echo " TOOLS: occ deployed!" | tee -a $logfile
echo " TOOLS: pct deployed!" | tee -a $logfile
echo " TOOLS: image tool deployed!" | tee -a $logfile
echo " TOOLS: python 2.7 and 3.4 deployed!" | tee -a $logfile
echo " TOOLS: license tool deployed!" | tee -a $logfile
echo " TOOLS: XLS pack deployed!" | tee -a $logfile
echo " TOOLS: Revision tool deployed!" | tee -a $logfile 
echo " TOOLS: User preference tool deployed!" | tee -a $logfile 
echo " " | tee -a $logfile
echo " PATCH: firefox deployed!" | tee -a $logfile
echo " PATCH: openoffice deployed!" | tee -a $logfile
echo " " | tee -a $logfile
echo " Environment deployed!" | tee -a $logfile
echo -n " Press any key to continue ... " 
set answer = $<
# ICrelease = contains IC5 / IC6

FDKbase:
if($foundry == "1") then
	set fdklocal = /mnt/ed/caddata/xfb/mcad_tkits/`echo $ICrelease | sed 's/./\L&/g'`
	set fdkprod = /mnt/ed-prod/caddata/xfb/mcad_tkits/`echo $ICrelease | sed 's/./\L&/g'`
else
	if($foundry == "2") then
		set fdklocal = /mnt/ed/caddata/umc/mcad_kits/`echo $ICrelease | sed 's/./\L&/g'`
		set fdkprod = /mnt/ed-prod/caddata/umc/mcad_kits/`echo $ICrelease | sed 's/./\L&/g'`
	endif
endif
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
echo -n " Press any key to continue ..." 
set answer = $<

DSS:
clear
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- STEP 9 :  Deploying DSS environment on the system                      -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
set dmsoftloc = /mnt/ed/ct/lnx/rh/53/dm
set dmsoftprod = /mnt/ed-prod/ct/lnx/rh/53/dm
echo -n " Do you want to deploy the DSS environment on the system? [Y/N]:"
set answer = $<
if($answer != "Y" || $answer != "y" || $answer != "Yes" || $answer != "yes") then
	echo " " | tee -a $logfile
	echo " Deploying DSS environment on the system .... " | tee -a $logfile
else
	if($answer != "N" || $answer != "n" || $answer != "No" || $answer != "no") then
		goto TRI
	else
		echo -n " Error validating you answer. Please answer with Y or N. Press any key to continue ..."
		set answer = $<
		goto DSS
	endif
endif
if(-d $dmsoftloc) then
	echo " Local install directory $dmsoftloc exists! continuing..." | tee -a $logfile
else
	echo " Local install directory doesn't exist, creating $dmsoftloc ." | tee -a $logfile
	mkdir -p $dmsoftloc
endif
if(-d /tmp/rsynclogs/dss) then
	find /tmp/rsynclogs/dss/ -type f -exec rm -Rf {} \;
else
	mkdir -p /tmp/rsynclogs/dss
endif
set dssrsynclog = /tmp/rsynclogs/dss/dssrsync.log
echo " Start synchronizing the DSS environment." | tee -a $logfile
cd $dmsoftloc
rsync -avz --force --delete $dmsoftprod/ $dmsoftloc/ > $dssrsynclog
echo -n " DSS environment deployed! Press any key to continue ... " | tee -a $logfile
set answer = $<
TRI:
clear
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- Setting CAD profile for user                                           -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile   
echo " " | tee -a $logfile
echo -n " Define the trigram you want to configure: "
set trigram = $<
set trlength = `echo $trigram | awk '{print length($0)}'`
echo $trlength
if($trlength != 3) then
	echo -n " Error, length not correct! Please try again." 
	set answer = $<
	goto TRI
endif
echo " Creating homedrive for user: $trigram" | tee -a $logfile
set homedrive = "/home/$trigram"
if(-d $homedrive) then
	echo " Homedrive already exists" | tee -a $logfile
else
	mkdir -p $homedrive
	chown -R $trigram $homedrive
	chgrp -R users $homedrive
	echo " Homedrive created!" | tee -a $logfile
endif
echo " Deploying CAD profile ..." 
if(-f $homedrive/.cshrc) then
	echo " Local user profile .cshrc exists." | tee -a $logfile
	echo " Checking if design.cshrc is being loaded. " | tee -a $logfile
	if(`cat $homedrive/.cshrc | grep "source /mnt/ed/caddata/init/design.cshrc"` == "") then
		echo " Profile not loaded, patching the user profile." | tee -a $logfile
		sed '$ a source /mnt/ed/caddata/init/design.cshrc' $homedrive/.cshrc
		echo " Profile pacthed. Continuing." | tee -a $logfile
	else
		echo " Profile loaded, nothing todo." | tee -a $logfile
	endif
else
	echo " Local user profile doesn't exists. Creating..." | tee -a $logfile
	scp $envinitlocal/local.il $homedrive/.cshrc
endif
echo " " | tee -a $logfile
echo -n " Press any key to continue ..."
set answer = $<
clear
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo "- Deployment summary                                                     -" | tee -a $logfile
echo "--------------------------------------------------------------------------" | tee -a $logfile
echo " " | tee -a $logfile
echo " Cadence version: $ICrelease " | tee -a $logfile
echo " Cadence release: $subicrelease " | tee -a $logfile
echo " " | tee -a $logfile
echo " FDK technology: $tech " | tee -a $logfile
echo " FDK technology release: $techrelease " | tee -a $logfile
echo " " | tee -a $logfile
echo " CAD profile enabled for user: $trigram" | tee -a $logfile
echo " " | tee -a $logfile
echo " CAD environment deployed: " | tee -a $logfile
echo " + ENV: design.cshrc deployed." | tee -a $logfile
echo " + ENV: mlxskill.il deployed" | tee -a $logfile
echo " + ENV: mlxtools.cshrc deployed" | tee -a $logfile
echo " " | tee -a $logfile
echo " + TOOLS: mcad deployed!" | tee -a $logfile
echo " + TOOLS: bpc deployed!" | tee -a $logfile
echo " + TOOLS: vncserver deployed!" | tee -a $logfile
echo " + TOOLS: disk quoate deployed!" | tee -a $logfile
echo " + TOOLS: mhelp deployed!" | tee -a $logfile
echo " + TOOLS: lmstat deployed!" | tee -a $logfile
echo " + TOOLS: borders deployed!" | tee -a $logfile
echo " + TOOLS: custom views deployed!" | tee -a $logfile
echo " + TOOLS: celldocu deployed!" | tee -a $logfile
echo " + TOOLS: mim caps deployed!" | tee -a $logfile
echo " + TOOLS: pvs latest deployed!" | tee -a $logfile
echo " + TOOLS: nedit deployed!" | tee -a $logfile
echo " + TOOLS: occ deployed!" | tee -a $logfile
echo " + TOOLS: pct deployed!" | tee -a $logfile
echo " + TOOLS: image tool deployed!" | tee -a $logfile
echo " + TOOLS: python 2.7 and 3.4 deployed!" | tee -a $logfile
echo " " | tee -a $logfile
echo " + PATCH: firefox deployed!" | tee -a $logfile
echo " + PATCH: openoffice deployed!" | tee -a $logfile
echo " " | tee -a $logfile
echo " Uploading all log file to Jira!" | tee -a $logfile
echo " Tarring separate rsync log files under /tmp/rsynclogs/" | tee -a $logfile
tar cfv /tmp/rsync.tar /tmp/rsynclogs/
echo " Done."
echo -n " Enter your username (trigram): " | tee -a $logfile
set username = $<
stty -echo
echo -n " Enter your password : " | tee -a $logfile
set passwd = $<
stty echo
echo " "
echo -n " Enter the Jira ticket number (e.g. REQ-37271): "
set ticketnr = $<
curl -s --user $username":"$passwd -H "X-Atlassian-Token: nocheck" 'https://extranet.melexis.com/jira/rest/api/2/issue/'$ticketnr'/attachments' -X POST -F file=@/tmp/rsync.tar
curl -s --user $username":"$passwd -H "X-Atlassian-Token: nocheck" 'https://extranet.melexis.com/jira/rest/api/2/issue/'$ticketnr'/attachments' -X POST -F file=@$logfile
echo " "
echo " Un-mounting ed-prod volume " | tee -a $logfile
umount -l /mnt/ed-prod
echo " All Done!"
echo " Ciao"

