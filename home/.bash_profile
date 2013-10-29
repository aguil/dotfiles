export PATH=~/.rbenv/shims:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}

# rbenv completions
source ~/.rbenv/completions/rbenv.bash

LANG="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_CTYPE="en_US.UTF-8"
LC_MESSAGES="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_ALL="en_US.UTF-8"

# Git and SVN
export EDITOR='/usr/local/bin/vim -f'
source ~/.svn-completion.bash
source ~/.git-completion.bash
git config --global color.ui true


# Ant
ant () { command ant  -logger org.apache.tools.ant.listener.AnsiColorLogger "$@" | sed 's/2;//g' ; }

# todo.txt
export TODOTXT_DEFAULT_ACTION=ls
source /usr/local/etc/bash_completion.d/todo_completion
alias todo='todo.sh -a'
complete -F _todo todo

# virtualenvwrapper
export WORKON_HOME=~/virtualenvs
source /usr/local/bin/virtualenvwrapper.sh

# Prompt
#export PS1='\[\e]2;\w\a\n[\!]\u@\h: \w \[$(tput bold)\]$(__git_ps1 "(%s)")\n\$ \[$(tput sgr0)\]'
#export PS1='\[\e]2;\w\a\n\]\[\e]1;\]$(basename "$(dirname "$PWD")")/\W\[\a\][\t]\u@\h: \w \[$(tput bold)\]$(__git_ps1 "(%s)")\n\$ \[$(tput sgr0)\]'
source ~/.bash/gitprompt.sh
#PROMPT_START="$IBLACK$Time12a$ResetColor$Yellow$PathShort$ResetColor"
#PROMPT_END="\n$ "

alias homeshick="$HOME/.homesick/repos/homeshick/home/.homeshick"

[ -r ~/.extra ] && source ~/.extra
