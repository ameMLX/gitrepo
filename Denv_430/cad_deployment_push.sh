#!/bin/bash
clear
# set the mail logfile
function readdmz {
	echo -n " Please define the DMZ server's DNS name: "
	read dmzdns
	if [ "$dmzdns" == "" ]; then
		echo -n " *ERROR* Empty name provided, please try again!" | tee -a $logfile
		read answer
		readdmz
	else
		echo " Checking if DMZ server responds..." | tee -a $logfile	
		pingdmz
	fi
}
function pingdmz {
	ping -c 3 $dmzdns > /dev/null 2>&1
	if [ $? -ne 0 ];
	then
		echo " *ERROR* Server is not online ... please define your DMZ server again!" | tee -a $logfile
		readdmz
	fi
}
function sshdmz {
	status=`nmap $dmzdns -PN -p 22 | egrep 'open|closed|filtered' | awk -F"tcp " '{print $2}' | awk -F" " '{print $1}'`
	if [ "$status" == "open" ]; then
		echo " DMZ SSH connection open." | tee -a $logfile
	else
		echo " *ERROR* DMZ SSH connection failed! Make sure that the SSH daemon is started on the DMZ server!" | tee -a $logfile
		exit
	fi
}
function keygen {
	echo " --------------------------------------------------------" | tee -a $logfile
	echo " - STEP 1 : Setup an RSA trust connection to DMZ server -" | tee -a $logfile
	echo " --------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	if [ ! -d /tmp/exnetscripts/dmzinfo ]; then
		mkdir -p /tmp/exnetscripts/dmzinfo
	fi
	cat /dev/zero | ssh-keygen -q -N ""
	ssh-copy-id root@$dmzdns
	echo $dmzdns > /tmp/exnetscripts/dmzinfo/dmzdns.cfg
	sudo su <<'ROOT'
	export dmzdns=`cat /tmp/exnetscripts/dmzinfo/dmzdns.cfg`
	cat /dev/zero | ssh-keygen -q -N ""
	cat /root/.ssh/id_rsa.pub | ssh root@$dmzdns 'cat >> /root/.ssh/authorized_keys'
ROOT
	echo " SSH KEY has been set, continuing ..."  | tee -a $logfile
}
function remotedirs {
	clear
	echo " --------------------------------------------------------" | tee -a $logfile
	echo " - STEP 2 : Creating remote directory structure on DMZ  -" | tee -a $logfile
	echo " --------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo " Creating remote directory structure on DMZ server " | tee -a $logfile
	export hostserver=`hostname`
	rm -Rf /tmp/exnetscripts
	mkdir -p /tmp/exnetscripts
	cd /tmp/exnetscripts
	rm -Rf *.*
	svn co --username cvsupdate --password updatecvs https://svn.tess.elex.be/tkit/cadsupport/trunk/projects/EXNET/deployment_scripts/ .
	chmod -R 775 *
	rsync -avz --force --delete /tmp/exnetscripts/ root@$dmzdns:/tmp/exnetscripts/
	ssh root@$dmzdns << 'ENDSSH'
		cd /tmp/exnetscripts
		./prepserver.sh
ENDSSH
	echo " Remote directories are created. Continuing ....." | tee -a $logfile
}
function cdnsplatform {
	clear
	echo "---------------------------------------------------" | tee -a $logfile
	echo "- STEP 3 : Cadence platform release               -" | tee -a $logfile
	echo "---------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo " Please select the cadence platform release you want to deploy:"
	echo " 1. IC5" 
	echo " 2. IC6"
	echo -n " Select the flatform release you want to deploy [1/2]: " 
	read baserelease
	case $baserelease in
	1)
		echo " Cadence base release IC5 has been selected! " | tee -a $logfile
		echo " Proceeding with selecting the sub-releases ... " | tee -a $logfile
		ICmcad=/mnt/ed/ct/lnx/rh/53/64/CADENCE_releases/ic5/
		ICrelease=IC5
		;;
	2)
		echo " Cadence base release IC6 has been selected! " | tee -a $logfile
		echo " Proceeding with selecting the sub-releases ... " | tee -a $logfile
		ICmcad=/mnt/ed/ct/lnx/rh/53/64/CADENCE_releases/ic6/
		ICrelease=IC6
		;;
	*)
		echo " Your choice is out of range! Please define your platform release properly (option 1 or option 2)! "
		echo -n " Press any key to return to the menu...."
		read answer
		clear
		cdnsplatform
		;;
	esac
	relarray=(`ls $ICmcad`)
	trel=`echo ${#relarray[@]}`
}
function cdnsubplatform {
    clear
    echo " "
	echo "--------------------------------------------------------" | tee -a $logfile
	echo "- STEP 4 : Cadence platform release $ICrelease - subreleases  -" | tee -a $logfile
	echo "--------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo " Please select the IC platform release you want to deploy:"
	echo " "
	irel=1
	for x in "${relarray[@]}"
	do
		echo " $irel : $x"
		irel=$[$irel +1]
	done
	echo " "
	echo -n " Select your release: "
	read subicrelease
	re='^[0-9]+$'
	if [ "$subicrelease" -gt "$trel" ] || [ "`echo $subicrelease | cut -c1`" == "0" ] || ! [[ $subicrelease =~ $re ]]; then
		echo " Your choice is out of range! Please define your subrelease properly!" 
		echo -n " Press any key to return to the menu ..." 
		read answer
		cdnsubplatform
	fi
	subicrelease=$[$subicrelease -1]
	echo " " | tee -a $logfile
}
function deploycdns {
	clear
	echo "--------------------------------------------------------------------------" | tee -a $logfile
	echo "- STEP 5 : Rsyncing cadence platform release $ICrelease - $subicrelease  -" | tee -a $logfile
	echo "--------------------------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo " Starting rsyncs ... " | tee -a $logfile
	echo " " | tee -a $logfile
	cdnsreleasenr=${relarray[$subicrelease]}
	relpackages=(`ls $ICmcad/${relarray[$subicrelease]}`)
	echo $relpackages
	if [ ! -d /tmp/exnetscripts/cdnssymlinks/ ]; then
		mkdir /tmp/exnetscripts/cdnssymlinks/
	fi
	if [ -f /tmp/exnetscripts/cdnssymlinks/symlink.sh ]; then
		rm /tmp/exnetscripts/cdnssymlinks/symlink.sh
	fi
	echo "#!/bin/bash" > /tmp/exnetscripts/cdnssymlinks/symlink.sh
	echo "mkdir -p $ICmcad$cdnsreleasenr" >> /tmp/exnetscripts/cdnssymlinks/symlink.sh
	for x in "${relpackages[@]}"
	do
		echo $x
		if [ "`find $ICmcad/${relarray[$subicrelease]}/$x -type l -xtype l -exec file {} \; | awk -F'broken symbolic link to ' '{print $2}'`" != "" ]; then
        	cdnsubpath=`find $ICmcad/${relarray[$subicrelease]}/$x -type l -xtype l -exec file {} \; | awk -F'broken symbolic link to ' '{print $2}' | awk -F"'" '{print $1}'`			
		else
			cdnsubpath=`readlink $ICmcad/${relarray[$subicrelease]}/$x`
		fi
		echo " Rsync package $x from $cdnsubpath to $cdnsubpath." | tee -a $logfile
		rsync -avz --force --delete $cdnsubpath/ root@$dmzdns:$cdnsubpath/ > $cdnsrlog/$x"_rsync.log" &
		echo "ln -s $cdnsubpath $ICmcad$cdnsreleasenr/$x" >> /tmp/exnetscripts/cdnssymlinks/symlink.sh
	done
	echo " " | tee -a $logfile
	echo " Waiting for Rsync processes to finish. " | tee -a $logfile
	echo " " | tee -a $logfile
	wait
	echo " Checking if all rsync processes are executed... " | tee -a $logfile
	if [ "`/usr/sbin/lsof -ad3-999 -c rsync | grep /mnt/ed`" == "" ]; then
		echo " OK: No resync processes running anymore." | tee -a $logfile
	fi
	echo " " | tee -a $logfile
	echo " Checking if errors appeared during rsync ..." | tee -a $logfile
	rsynclog=(`ls $cdnsrlog/`)
	for x in "${rsynclog[@]}"
	do
		cdnstool=`echo $x | awk -F"_rsync.log" '{print $1}'`
		if [ "`cat $cdnsrlog/$x | grep -i "rsync error:"`" != "" ]; then
			echo " ERROR: an error occured with one of the syncs for package $cdnstool!" | tee -a $logfile
			echo " The error log file will be opened, close the log to continue with the deployment" | tee -a $logfile
			echo -n " Click any key to open the log file." | tee -a $logfile
			read answer
			nedit $cdnsrlog/$x &
			wait
		else
			echo " OK : RSYNC for package $cdnstool went without errors." | tee -a $logfile
		fi
	done
	echo " Creating symlinks on DMZ server from release folder to individual packages."
	ssh root@$dmzdns << 'ENDSSH'
			mkdir -p /tmp/exnetscripts/cdnssymlinks/
ENDSSH
	rsync -avz --force --delete /tmp/exnetscripts/cdnssymlinks/symlink.sh root@$dmzdns:/tmp/exnetscripts/cdnssymlinks/symlink.sh
	ssh root@$dmzdns << 'ENDSSH'
			chmod 775 /tmp/exnetscripts/cdnssymlinks/symlink.sh
			cd /tmp/exnetscripts/cdnssymlinks/
			./symlink.sh
ENDSSH
	echo " " | tee -a $logfile
	echo -n " Press any key to continue ... "
	read answer
}
function softinitsetup {
	clear
	echo "--------------------------------------------------------------------------" | tee -a $logfile
	echo "- STEP 6 :  Deploying software initialization scripts                    -" | tee -a $logfile
	echo "--------------------------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	export mcadinit=/mnt/ed/ct/init/mcadinit/rh53/`echo $ICrelease | tr '[:upper:]' '[:lower:]'`
	if [ ! -d /tmp/exnetscripts/globalvars/ ]; then
		mkdir /tmp/exnetscripts/globalvars/
	fi
	if [ -f /tmp/exnetscripts/globalvars/var.sh ]; then
		rm /tmp/exnetscripts/globalvars/var.sh
	fi
	echo "#!/bin/bash" > /tmp/exnetscripts/globalvars/var.sh
	echo "export ICrelease=$ICrelease" >> /tmp/exnetscripts/globalvars/var.sh
	echo "export cdnsreleasenr=$cdnsreleasenr" >> /tmp/exnetscripts/globalvars/var.sh
	echo "export mcadinit=$mcadinit" >> /tmp/exnetscripts/globalvars/var.sh
	echo "ln -s $mcadinit/$cdnsreleasenr.cshrc $mcadinit/release_production.cshrc" >> /tmp/exnetscripts/globalvars/var.sh
	ssh root@$dmzdns << 'ENDSSH'
			mkdir -p /tmp/exnetscripts/globalvars/
ENDSSH
	rsync -avz --force --delete /tmp/exnetscripts/globalvars/var.sh root@$dmzdns:/tmp/exnetscripts/globalvars/var.sh
	ssh root@$dmzdns <<'SOFTINIT'
	    chmod 775 /tmp/exnetscripts/globalvars/var.sh
		source /tmp/exnetscripts/globalvars/var.sh
		echo " Checking if cadence init folder exists."
		if [ -d $mcadinit ]; then
			echo " Cadence init folder exists ... cleaning folder first."
		find $mcadinit -type f -exec rm -Rf {} \;
		find $mcadinit -type l -exec rm -Rf {} \;
	else
		echo " Cadence init folder doesn't exist ... creating folder."
		mkdir -p $mcadinit
	fi
	echo " Deploying release init files."
	# cdnsreleasenr = containing the specific cadence release number e.g. release_113
	echo " - $cdnsreleasenr.cshrc"
	echo " - symlink release_production.cshrc to $cdnsreleasenr.cshrc" 
	echo " "
SOFTINIT
	rsync -avz $mcadinit/$cdnsreleasenr.cshrc root@$dmzdns:$mcadinit/$cdnsreleasenr.cshrc
	ssh root@$dmzdns <<'SOFTINIT2'
	source /tmp/exnetscripts/globalvars/var.sh
	cd $mcadinit
	chmod -R 775 *
	echo " Cadence release init files are deployed."
SOFTINIT2
}

function designenv {
	clear
	echo "--------------------------------------------------------------------------" | tee -a $logfile
	echo "- STEP 7 :  Deploying design environment                                 -" | tee -a $logfile
	echo "--------------------------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo " Checking if environment init folder exists." | tee -a $logfile
	if [ ! -d /tmp/exnetscripts/globalvars/ ]; then
		mkdir /tmp/exnetscripts/globalvars/
	fi
	if [ -f /tmp/exnetscripts/globalvars/var.sh ]; then
		rm /tmp/exnetscripts/globalvars/var.sh
	fi
	
	export envinit=/mnt/ed/caddata/init
	export toolsinit=/mnt/ed/caddata/tools_init
	export python=/mnt/ed/ct/lnx/rh/53/64/python
	export ctinit=/mnt/ed/ct/init
	export envrlog=/tmp/rsynclogs/env
	
	echo "#!/bin/bash" > /tmp/exnetscripts/globalvars/var.sh
	echo "export envinit=$envinit" >> /tmp/exnetscripts/globalvars/var.sh
	echo "export toolsinit=$toolsinit" >> /tmp/exnetscripts/globalvars/var.sh
	echo "export python=$python" >> /tmp/exnetscripts/globalvars/var.sh
	echo "export ctinit=$ctinit" >> /tmp/exnetscripts/globalvars/var.sh
	echo "export envrlog=$envrlog" >> /tmp/exnetscripts/globalvars/var.sh
	
	ssh root@$dmzdns << 'ENDSSH'
			mkdir -p /tmp/exnetscripts/globalvars/
ENDSSH
	
	rsync -avz --force --delete /tmp/exnetscripts/globalvars/var.sh root@$dmzdns:/tmp/exnetscripts/globalvars/var.sh

	if [ -d $envrlog ]; then
		find $envrlog/ -type f -exec rm -Rf {} \;
	else
		mkdir -p $envrlog
	fi


	echo " Deploying environmental files" | tee -a $logfile
	echo " UMC:" | tee -a $logfile
	echo " - calibre.cshrc as calibre.cshrc in $envinit" | tee -a $logfile
	echo " - mlxskill_umc.il as mlxskill_umc.il in $envinit" | tee -a $logfile
	echo " ENV:" | tee -a $logfile
	echo " - design_dmz.cshrc as design.cshrc in $envinit" | tee -a $logfile
	echo " - mlxskill.il in $envinit" | tee -a $logfile
	echo " - mlxtools.cshrc in $envinit" | tee -a $logfile
	echo " - ptc_check.cshrc in $envinit" | tee -a $logfile
	echo " - dassault synchronicity in $envinit" | tee -a $logfile
	echo " - cdnmenus in $envinit" | tee -a $logfile
	echo " TOOLS:" | tee -a $logfile
	echo " - mcad initialization script in $toolsinit" | tee -a $logfile
	echo " - bpc initialization script in $toolsinit" | tee -a $logfile
	echo " - vncserver initialization script in $toolsinit" | tee -a $logfile
	echo " - diskqouta initialization script in $toolsinit" | tee -a $logfile 
	echo " - mhelp initialization script in $toolsinit" | tee -a $logfile
	echo " - lmstat 9.22 initialization script in $toolsinit" | tee -a $logfile
	echo " - borders initialization script in $toolsinit" | tee -a $logfile
	echo " - cadence custom views initialization script in $toolsinit" | tee -a $logfile
	echo " - celldocu initialization script in $toolsinit" | tee -a $logfile
	echo " - MIM CAP checker script in $toolsinit" | tee -a $logfile
	echo " - PVS latest script in $toolsinit" | tee -a $logfile
	echo " - Nedit syntax recognition for verilog-a in $toolsinit" | tee -a $logfile
	echo " - OCCbrowser in $toolsinit" | tee -a $logfile
	echo " - PCT in $toolsinit" | tee -a $logfile
	echo " - Image printer in $toolsinit" | tee -a $logfile
	echo " - Python base release 2.7 / 3.4 in $python" | tee -a $logfile 
	echo " - License Tool in $toolsinit" | tee -a $logfile 
	echo " - XLS Pack in $toolsinit" | tee -a $logfile 
	echo " - Revision tool in $toolsinit" | tee -a $logfile
	echo " - User Preference tool in $toolsinit" | tee -a $logfile
	echo " - Hierarchical checker tool in $toolsinit" | tee -a $logfile
	echo " - IMD checker in $toolsinit" | tee -a $logfile
	echo " PATCH:" | tee -a $logfile
	echo " - firefox patch vncsessions in $toolsinit" | tee -a $logfile
	echo " - openoffice patch in $toolsinit" | tee -a $logfile

	cd $envinit
	rsync -avz --exclude --force --delete $envinit/design_dmz.cshrc root@$dmzdns:$envinit/design.cshrc
	rsync -avz --exclude --force --delete $envinit/mlxskill.il  root@$dmzdns:$envinit/mlxskill.il
	rsync -avz --exclude --force --delete $envinit/mlxtools.cshrc  root@$dmzdns:$envinit/mlxtools.il
	rsync -avz --exclude --force --delete $envinit/local.cshrc  root@$dmzdns:$envinit/local.cshrc
	rsync -avz --exclude --force --delete $envinit/dassault.cshrc  root@$dmzdns:$envinit/dassault.cshrc
	rsync -avz --exclude --force --delete $envinit/dessync_wrapper.cshrc  root@$dmzdns:$envinit/dessync_wrapper.cshrc
	rsync -avz --exclude --force --delete $envinit/calibre.cshrc  root@$dmzdns:$envinit/calibre.cshrc
	rsync -avz --exclude --force --delete $envinit/mlxskill_umc.il  root@$dmzdns:$envinit/mlxskill_umc.il
	rsync -avz --exclude --force --delete $envinit/syncinit.cshrc  root@$dmzdns:$envinit/syncinit.cshrc

	cd $toolsinit

	rsync -avz --exclude ".svn" --force --delete $python/  root@$dmzdns:$python/ > $envrlog/python.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/mcad/   root@$dmzdns:$toolsinit/mcad/  > $envrlog/mcad.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/gds_ipc/   root@$dmzdns:$toolsinit/gds_ipc/  > $envrlog/gdsipc.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/vncserver/   root@$dmzdns:$toolsinit/vncserver/  > $envrlog/vncserver.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/disk_quota/   root@$dmzdns:$toolsinit/disk_quota/  > $envrlog/diskquota.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/mhelp/   root@$dmzdns:$toolsinit/mhelp/  > $envrlog/mhelp.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/lmstat9.22/   root@$dmzdns:$toolsinit/lmstat9.22/  > $envrlog/lmstat.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/borders/   root@$dmzdns:$toolsinit/borders/  > $envrlog/borders.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/cdnsviews/   root@$dmzdns:$toolsinit/cdnsviews/  > $envrlog/cdnsviews.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/celldocu/   root@$dmzdns:$toolsinit/celldocu/  > $envrlog/celldocu.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/firefox/   root@$dmzdns:$toolsinit/firefox/  > $envrlog/firefox.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/mlx_cmim/   root@$dmzdns:$toolsinit/mlx_cmim/  > $envrlog/mlxcmim.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/mlx_env/   root@$dmzdns:$toolsinit/mlx_env/  > $envrlog/mlxenv.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/mlxooffice/   root@$dmzdns:$toolsinit/mlxooffice/  > $envrlog/mlxooffice.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/nedit/   root@$dmzdns:$toolsinit/nedit/  > $envrlog/nedit.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/occbrowser/   root@$dmzdns:$toolsinit/occbrowser/  > $envrlog/occbrowser.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/office/   root@$dmzdns:$toolsinit/office/  > $envrlog/office.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/pct/   root@$dmzdns:$toolsinit/pct/  > $envrlog/pct.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/print2image_tool/   root@$dmzdns:$toolsinit/print2image_tool/  > $envrlog/print2image.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/license_tool/   root@$dmzdns:$toolsinit/license_tool/  > $envrlog/licensetool.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/xls_pack/   root@$dmzdns:$toolsinit/xls_pack/  > $envrlog/xlspack.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/revision_tool/   root@$dmzdns:$toolsinit/revision_tool/  > $envrlog/revtool.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/user_pref_tool/   root@$dmzdns:$toolsinit/user_pref_tool/  > $envrlog/userpreftool.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/hierarchical_checker/   root@$dmzdns:$toolsinit/hierarchical_checker/  > $envrlog/hierarchicalchecker.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/imd_check/   root@$dmzdns:$toolsinit/imd_check/  > $envrlog/imdcheck.log &
	rsync -avz --exclude ".svn" --force --delete $toolsinit/supp_sens_cmod/   root@$dmzdns:$toolsinit/supp_sens_cmod/  > $envrlog/suppsenscmod.log &
	rsync -avz --exclude ".svn" --force --delete $ctinit/cdnmenus/   root@$dmzdns:$ctinit/cdnmenus/  > $envrlog/cdnmenus.log &
	echo " Waiting for rsync to be finished ..." 
	wait
	
	ssh root@$dmzdns <<'ENDSSH'
			chmod 775 /tmp/exnetscripts/globalvars/var.sh
			source /tmp/exnetscripts/globalvars/var.sh
			chmod -R 775 $toolsinit/*
			chmod -R 775 $envinit/*
ENDSSH

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
	read answer
}

function fdkrelease {
	clear
	echo "--------------------------------------------------------------------------" | tee -a $logfile
	echo "- STEP 8 :  Used Foundry                                                 -" | tee -a $logfile
	echo "--------------------------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo " Please select the foundry development kit data you want to deploy:       " | tee -a $logfile
	echo " " | tee -a $logfile
	echo " 1. XFAB" | tee -a $logfile
	echo " 2. UMC" | tee -a $logfile
	echo " " | tee -a $logfile
	echo -n " Please select 1/2: "
	read foundry
	if [ $foundry == "1" ]; then
		echo ""
	else
		if [ $foundry == "2" ]; then
			echo ""
		else
			echo " Incorrect choice, please try again!" | tee -a $logfile
			echo -n " Press any key to continue.... " | tee -a $logfile
			read answer
			fdkrelease
		fi
	fi
	if [ $foundry == "1" ]; then
		export fdk=/mnt/ed/caddata/xfb/mcad_tkits/`echo $ICrelease | sed 's/./\L&/g'`	
	else
		if [ $foundry == "2" ]; then
			export fdk=/mnt/ed/caddata/umc/mcad_kits/`echo $ICrelease | sed 's/./\L&/g'`	
		fi
	fi
	fdktech
	fdksubtech
	echo " Starting rsync on FDK data from $fdkprod to $fdklocal" | tee -a $logfile
	rsync -avz --exclude ".svn" $fdk/ root@$dmzdns:$fdk/ > $fdksrlog/$tech"_"$techrelease.log &
	echo " Waiting for rsync to be finished ...."
	wait
	echo " Rsync finished, deployment FDK done!" | tee -a $logfile
	if [ ! -d /tmp/exnetscripts/fdk/ ]; then
		mkdir -p /tmp/exnetscripts/fdk/
	else
		if [ -f /tmp/exnetscripts/fdk/fdksymlink.sh ]; then	
			rm /tmp/exnetscripts/fdk/fdksymlink.sh
		fi
	fi
	echo "#!/bin/bash" > /tmp/exnetscripts/fdk/fdksymlink.sh
	echo "cd $fdk" >> /tmp/exnetscripts/fdk/fdksymlink.sh
	echo "cd .." >> /tmp/exnetscripts/fdk/fdksymlink.sh
	echo "ln -s $techrelease release_production" >> /tmp/exnetscripts/fdk/fdksymlink.sh
	rsync -avz /tmp/exnetscripts/fdk/fdksymlink.sh root@$dmzdns:/tmp/exnetscripts/fdk/fdksymlink.sh
	wait
	ssh root@$dmzdns <<'ENDSSH'
			source /tmp/exnetscripts/fdk/fdksymlink.sh
ENDSSH
	echo -n " Press any key to continue ..." 
	read answer

}
function fdktech {
	clear
	echo "----------------------------------------------" | tee -a $logfile
	echo "- STEP 9 :  Select your technology           -" | tee -a $logfile
	echo "----------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	relarray=(`ls $fdk`)
	trel=`echo ${#relarray[@]}`
	echo " Select the technology you want to deploy:"
	export irel=1

	for x  in "${relarray[@]}"
	do
		echo " $irel : $x"
		irel=$[$irel +1]
	done
	
	echo " "
	echo -n " Select your release: "
    read tech
	re='^[0-9]+$'
	if [ "$tech" -gt "$trel" ] || [ `echo $tech | cut -c1` == "0" ] || ! [[ $tech =~ $re ]]; then
		echo " Your choice is out of range! Please define your technology properly!" 
		echo -n " Press any key to return to the menu ..." 
		read answer
		fdktech
	fi
	tech=$[$tech -1]
	tech=${relarray[$tech]}
	fdk=$fdk/$tech
	echo " " | tee -a $logfile
	clear
}
function fdksubtech {
	clear
	echo "-------------------------------------------------------" | tee -a $logfile
	echo "- STEP 10 :  Select your technology release           -" | tee -a $logfile
	echo "-------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	echo $fdk
	echo $tech
	if [ ! -d /tmp/exnetscripts/fdk/ ]; then
		mkdir -p /tmp/exnetscripts/fdk/
	else
		if [ -f /tmp/exnetscripts/fdk/fdktech.sh ]; then	
			rm /tmp/exnetscripts/fdk/fdktech.sh
		fi
	fi
	echo "#!/bin/bash" > /tmp/exnetscripts/fdk/fdktech.sh
	echo "mkdir -p $fdk" >> /tmp/exnetscripts/fdk/fdktech.sh
	ssh root@$dmzdns <<'ENDSSH'
			mkdir -p /tmp/exnetscripts/fdk/
ENDSSH
	rsync -avz /tmp/exnetscripts/fdk/fdktech.sh root@$dmzdns:/tmp/exnetscripts/fdk/fdktech.sh
	wait
	ssh root@$dmzdns <<'ENDSSH'
			source /tmp/exnetscripts/fdk/fdktech.sh
ENDSSH
    echo $fdk
	relarray=(`ls $fdk`)
	trel=`echo ${#relarray[@]}`
	echo " Select the release you want to deploy:"
	export irel=1
	for x  in "${relarray[@]}"
	do
		echo " $irel : $x"
		irel=$[$irel +1]
	done
	echo " "
	echo -n " Select your release: "
	read techrelease
	re='^[0-9]+$'
	if [ "$techrelease" -gt "$trel" ] || [ `echo $tech | cut -c1` == "0" ] || ! [[ $techrelease =~ $re ]]; then
		echo " Your choice is out of range! Please define your technology properly!" 
		echo -n " Press any key to return to the menu ..." 
		read answer 
		fdksubtech
	fi
	techrelease=$[$techrelease -1]
	export techrelease=${relarray[$techrelease]}
	export fdkroot=$fdk
	export fdk=$fdk/$techrelease
}
function deploydss {
	clear
	echo "--------------------------------------------------------------------------" | tee -a $logfile
	echo "- STEP 11 :  Deploying DSS environment on the system                      -" | tee -a $logfile
	echo "--------------------------------------------------------------------------" | tee -a $logfile   
	echo " " | tee -a $logfile
	dmsoft=/mnt/ed/ct/lnx/rh/53/dm
	echo -n " Do you want to deploy the DSS environment on the system? [Y/N]:"
	read answer
	if [ "$answer" == "Y" ] || [ "$answer" == "y" ] || [ "$answer" == "Yes" ] || [ "$answer" == "yes" ]; then
		echo " " | tee -a $logfile
		echo " Deploying DSS environment on the system .... " | tee -a $logfile
	else
		if [ "$answer" == "N" ] || [ "$answer" == "n" ] || [ "$answer" == "No" ] || [ "$answer" == "no" ]; then
			deployuser
		else
			echo -n " Error validating you answer. Please answer with Y or N. Press any key to continue ..."
			read answer
			deploydss
		fi
	fi
	if [ ! -d /tmp/exnetscripts/dss ]; then
		mkdir -p /tmp/exnetscripts/dss
	else
		if [ ! -f /tmp/exnetscripts/dss/installdir.sh ]; then
			touch /tmp/exnetscripts/dss/installdir.sh
		else
			rm -Rf /tmp/exnetscripts/dss/installdir.sh
		fi
	fi
	ssh root@$dmzdns <<'ENDSSH'
		mkdir -p /tmp/exnetscripts/dss
ENDSSH
	echo "#!/bin/bash" > /tmp/exnetscripts/dss/installdir.sh
	echo "mkdir -p $dmsoft" >> /tmp/exnetscripts/dss/installdir.sh
	rsync -avz /tmp/exnetscripts/dss/installdir.sh root@$dmzdns:/tmp/exnetscripts/dss/installdir.sh
	ssh root@$dmzdns <<'ENDSSH'
		source /tmp/exnetscripts/dss/installdir.sh
ENDSSH
	if [ -d /tmp/rsynclogs/dss ]; then
		find /tmp/rsynclogs/dss/ -type f -exec rm -Rf {} \;
	else
		mkdir -p /tmp/rsynclogs/dss
	fi
    dssrsynclog=/tmp/rsynclogs/dss/dssrsync.log
	echo " Start synchronizing the DSS environment." | tee -a $logfile
	cd $dmsoft
	rsync -avz --force --delete --exclude '*/syncinc/custom/servers/' $dmsoft/ root@$dmzdns:$dmsoft/ > $dssrsynclog
	echo -n " DSS environment deployed! Press any key to continue ... " | tee -a $logfile
	read answer

}
function deployuser {
    clear
	ssh root@$dmzdns <<'ENDSSH'
		mkdir -p /tmp/exnetscripts/user/
ENDSSH
	rsync -avz --force --delete $scriptsource/userdeployment.sh root@$dmzdns:/tmp/exnetscripts/user/userdeployment.sh
	ssh -t root@$dmzdns /tmp/exnetscripts/user/userdeployment.sh
}
function mainmenu {
	clear
	echo " ###################################################" | tee -a $logfile
	echo " # CAD deployment script for EXNET servers         #" | tee -a $logfile
	echo " # ---------------------------------------         #" | tee -a $logfile
	echo " # `date '+DATE: %d/%m/%y TIME:%H:%M:%S'`          #" | tee -a $logfile
	echo " # This script will deploy a full CAD environment  #" | tee -a $logfile
	echo " # based on several project parameters (develop)   #" | tee -a $logfile
	echo " ###############################################" | tee -a $logfile
	echo " " | tee -a $logfile
	echo " Please select what you want todo: " | tee -a $logfile
	echo " " | tee -a $logfile
	echo " 1. Deploy full DMZ server configuration" | tee -a $logfile
	echo " 2. Deploy only CDN software releases" | tee -a $logfile
	echo " 3. Deploy only FDK releases" | tee -a $logfile
	echo " 4. Deploy / Update design environment" | tee -a $logfile
	echo " 5. Configure new users to the DMZ" | tee -a $logfile
	echo " 6. Quit the script" | tee -a $logfile
	echo " "  | tee -a $logfile
	echo -n " Please make your choice [1/6]:" | tee -a $logfile
	read answer
	case $answer in
	1)
		echo " Full deployment selected..."  | tee -a $logfile
		remotedirs
		cdnsplatform
		cdnsubplatform
		deploycdns
		softinitsetup
		designenv
		fdkrelease
		deploydss
		deployuser
		;;
	2)
		echo " Cadence software deployment selected ..."  | tee -a $logfile
		remotedirs
		cdnsplatform
		cdnsubplatform
		deploycdns
		softinitsetup
		;;
	3) 
		echo " FDK deployment selected ..."  | tee -a $logfile
		remotedirs
		fdkrelease
		;;
	4)
		echo " Design Environment deployment selected ..."  | tee -a $logfile
		remotedirs
		designenv
		;;
	5)
		echo " Deployment individual users .... "  | tee -a $logfile
		deployuser
		;;
	6)
		exit
		;;
	*)
		echo -n " *ERROR* Your selection is out-of-range. Please make your selection again."
		read answer2
		mainmenu
		;;
	esac
}
echo " Welcome to EXNET 1.1.0, your deployment script!"
echo " We're going to deploy automatically the whole"
echo " CAD environment on a remote DMZ server. "
echo " "
scriptsource=`pwd`
# Request the DNS name on the DMZ server
readdmz

# Check if the server is online
pingdmz
sshdmz
echo " " | tee -a $logfile
echo " Setting-up log file directory structure ..." | tee -a $logfile
# Start preparing the log file structure
export logfile=/tmp/cad_deployment_$dmzdns.log
# cleanup old sync log files from previous deployments if exist / create directory structure if not existing.
if [ -d /tmp/rsynclogs/cdns ]; then
	find /tmp/rsynclogs/cdns/ -type f -exec rm -Rf {} \;
else
	mkdir -p /tmp/rsynclogs/cdns
fi
if [ -d /tmp/rsynclogs/fdks ]; then
	find /tmp/rsynclogs/fdks/ -type f -exec rm -Rf {} \;
else
	mkdir -p /tmp/rsynclogs/fdks
fi
export cdnsrlog=/tmp/rsynclogs/cdns
export fdksrlog=/tmp/rsynclogs/fdks
echo " done ... continuing ..." | tee -a $logfile

clear
echo " ###################################################" | tee -a $logfile
echo " # CAD deployment script for EXNET servers         #" | tee -a $logfile
echo " # ---------------------------------------         #" | tee -a $logfile
echo " # `date '+DATE: %d/%m/%y TIME:%H:%M:%S'`          #" | tee -a $logfile
echo " # This script will deploy a full CAD environment  #" | tee -a $logfile
echo " # based on several project parameters (develop)   #" | tee -a $logfile
echo " ###############################################" | tee -a $logfile
echo "  "  | tee -a $logfile
# set the SSH RSA key's
echo " Setting-up the RSA key's establishing a trust connection" | tee -a $logfile
keygen
echo " RSA done ... continuing" | tee -a $logfile
clear
mainmenu


echo " All Done!"
echo " Ciao"

