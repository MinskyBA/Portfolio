# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

source ~/.bash_function
source ~/.bash_alias

export PATH=$PATH:$HOME/.local/bin:$HOME/bin:/data/apps/scripts


##################
####  HISTORY ####
##################

export HISTTIMEFORMAT="[%F %a %T] "
export HISTSIZE=2000000

export HIST_USER_COMBINED=~/.history/history.user.combined	# master history file
HISTFILE=~/.history/history.$$				# terminal session-PID history file

[ ! -d ~/.history ] && mkdir ~/.history			# create history folder if it doesn't exist

#function hist {
#        /bin/grep -e '^\['$1 $HIST_USER_COMBINED
#}
#export -f hist
#
#function com {          # outputs combined history, highlights PID if provided
#	if [ $# -eq 0 ]; then
#		cat $HIST_USER_COMBINED
#	else
#		grep -e '^\['$1'\].*' -e $ $HIST_USER_COMBINED --color
#	fi
#};export -f com

case $TERM in 
	xterm*)
		export PROMPT_COMMAND='echo -ne "\033]0;$USER@$HOSTNAME: $PWD\007";history -a;echo -n "[$$]" >> $HIST_USER_COMBINED ;[ ! -e $HISTFILE ] && (echo " <--NEW TERMINAL OPENED-->" >> $HIST_USER_COMBINED;touch $HISTFILE;fun) || history 1 >> $HIST_USER_COMBINED'
		;;
	*)
		export PROMPT_COMMAND='history -a;echo -n "[$$]" >> $HIST_USER_COMBINED ;[ ! -e $HISTFILE ] && (echo " <--NEW TERMINAL OPENED-->" >> $HIST_USER_COMBINED;touch $HISTFILE;fun) || history 1 >> $HIST_USER_COMBINED'
		;;
esac


shopt -s histappend

##################
##################
##################


GREEN_b="\[\e[01;32m\]"
WHITE_b="\[\e[01;37m\]"
TEAL_b="\[\e[01;36m\]"
RED_b="\[\e[01;31m\]"
cEnd="\[\e[0m\]"

source ~/.bash_colors

if [ `hostname` = "MinskyNOC" ] ; then
	export PS1="\n\[\e[01;36m\]┌─[\[\e[01;32m\]\$$\[\e[01;36m\]:\[\e[01;32m\]\!\[\e[01;36m\]]─[\[\e[01;32m\]\t\[\e[01;36m\]|\[\e[01;32m\]\d\[\e[01;36m\]]─[\[\e[01;32m\]\u\[\e[01;36m\]@\[\e[01;32m\]\H\[\e[01;36m\]|\[\e[01;33m\]\w\[\e[01;36m\]]\[\e[01;32m\]\n\[\e[01;36m\]└[\[\e[01;33m\]\W\[\e[01;36m\]|\[\e[01;32m\]\\$ \[\e[0m\]"

else 
	export PS1="\n\[\e[01;36m\]┌─[\[\e[01;32m\]\$$\[\e[01;36m\]:\[\e[01;32m\]\!\[\e[01;36m\]]─[\[\e[01;32m\]\t\[\e[01;36m\]|\[\e[01;32m\]\d\[\e[01;36m\]]─[\[\e[01;32m\]\u\[\e[01;36m\]@\[\e[01;31m\]\H\[\e[01;36m\]|\[\e[01;33m\]\w\[\e[01;36m\]]\[\e[01;32m\]\n\[\e[01;36m\]└[\[\e[01;33m\]\W\[\e[01;36m\]|\[\e[01;32m\]\\$ \[\e[0m\]"
fi

cd ~
