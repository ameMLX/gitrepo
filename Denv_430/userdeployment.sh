#!/bin/tcsh
# User deployment Script
# -----------------------
setenv TERM "dumb"
set logfile = "/tmp/usercreation.log"
newaccount:
TRI:
clear
echo -n " Define the trigram you want to create: "
set trigram = $<
echo -n " Define the UID: "
set uid = $<
echo -n " Define the users new password: "
set passwd = $<
set trlength = `echo $trigram | awk '{print length($0)}'`
echo $trlength
if($trlength != 3) then
        echo -n " Error, length not correct! Please try again."
        set answer = $<
        goto TRI
endif
echo " Creating new user on the system: $trigram with UID $uid"
useradd $trigram -u $uid -s /bin/tcsh -d /home/$trigram
echo "$passwd\n$passwd" | passwd --stdin $trigram 
echo " User created, password has been set."
clear
echo " Creating homedrive for user: $trigram" | tee -a $logfile
set homedrive = "/home/$trigram"
if(-d $homedrive) then
        echo " Homedrive already exists" | tee -a $logfile
else
        mkdir -p $homedrive
        chown -R $trigram $homedrive
        chgrp -R users $homedrive
        chmod -R 775 $homedrive
        echo " Homedrive created!" | tee -a $logfile
endif
clear
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
        touch $homedrive/.cshrc
	echo "source /mnt/ed/caddata/init/design.cshrc" > $homedrive/.cshrc
endif
chmod 775 $homedrive/.cshrc
chown $trigram $homedrive/.cshrc
chgrp users $homedrive/.cshrc
echo " " | tee -a $logfile
clear
echo " Setting new VNC passwd for user $trigram"
runuser -l $trigram -c 'echo "'$passwd'\n'$passwd'" | vncpasswd'
echo " Setting-up new VNC session"
su - $trigram -c "/mnt/ed/caddata/tools_init/vncserver/vncserver.sh"
echo " Session has been set!"
echo " "
newaccountq:
echo -n " Do you want to create another account? [Y/N]: "
set answer = $<
if($answer == "Y" || $answer == "y") then
   goto newaccount
else
 if ($answer == "N" || $answer == "n") then
	echo " Thank you, ending script now!"
 else
	echo " Invalid answer given, please answer Y/N"
        goto newaccountq
 endif
endif

