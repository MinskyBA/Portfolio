#!/bin/bash
#####################################################################################
## requires input of machine-name to copy key to ####################################
#####################################################################################


##    .bash_profile loads when you first log into a machine
##**  .bashrc loads *every time* you open a terminal

echo ""
echo "####################################################################"
echo -e "###### Configuring profile on \e[01;31m$1\e[0;0m"
echo "####################################################################"
echo ""

## ssh-keygen.exe to generate new key

## make authorized_keys file on $1
#ssh $1 "mkdir ~/.ssh; touch ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys;cp -p ~/.ssh/authorized_keys ~/.ssh/existing_keys"

## copy key data to $1
#scp ~/.ssh/id_rsa.pub $1:~/.ssh/authorized_keys
#ssh $1 "cat ~/.ssh/existing_keys >> ~/.ssh/authorized_keys;sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys;rm ~/.ssh/existing_keys"
#ssh $1 "echo "### Key successfully added to:";hostname" # echo from $2 to confirm


cat ~/.ssh/id_rsa.pub | ssh $1 "mkdir -p ~/.ssh;cat >> ~/.ssh/authorized_keys;chmod 600 ~/.ssh/authorized_keys;sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys"


ssh $1 "echo "### Key successfully added to:";hostname" # echo from $1 to confirm





## copy .bashrc to $1
#scp ~/bash/bashrc_bminsky_remote $1:~/.bashrc
scp ~/.bash_function $1:~/.bash_function
scp ~/.bash_alias $1:~/.bash_alias
scp ~/.bash_profile $1:~/.bash_profile
scp ~/.bashrc $1:~/.bashrc
ssh $1 "echo "### .bashrc, .bash_function, .bash_alias, and .bash_profile  successfully copied to: ";hostname" # echo from $1 to confirm


## copy .bashrc for apache and root to bminsky/home/bash/
ssh $1 "mkdir ~/bash;touch ~/bash/bashrc_root;touch ~/bash/bashrc_apache;touch ~/.hushlogin"
scp ~/bash/bashrc_root $1:~/bash/
scp ~/bash/bashrc_apache $1:~/bash/


#ssh $1 "sudo cp -v /home/bminsky/bash/bashrc_root /root/.bashrc"

#ssh $1 "sudo su - apache -c 'cp -v /home/bminsky/bash/bashrc_apache /home/apache/.bashrc'"




##   add script to be run from remote machine that sets root/bash rc
#scp ~/bash/set_bashrc_apache_root.sh $1:~/bash/

echo ""
echo "###########################################################"
echo -e "###### Profile configured on \e[01;32m$1\e[0;0m"
echo "###########################################################"
echo ""
