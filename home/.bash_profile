export PATH=/usr/local/opt/coreutils/libexec/gnubin:${PATH}
export PATH=~/.rbenv/shims:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}
#export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}

export DART_FLAGS="--checked --load_deferred_eagerly"
export DARTIUM_EXPIRATION_TIME=1577836800
#export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
#export JAVA_HOME=`/usr/libexec/java_home -v 1.8.0_242`
#export JAVA_HOME=`/usr/libexec/java_home -v 11`
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:/usr/local/bin/nimrod/bin
#eval "$(pyenv init -)"
#export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"

export PATH=/opt/homebrew/opt/go@1.22/bin:${PATH}
export PATH="/opt/homebrew/opt/gradle@6/bin:$PATH"
export PATH=`/usr/libexec/java_home -v 11`"/bin:$PATH"
export PATH=$PATH:"/usr/local/texlive/2021basic/bin/universal-darwin"

source ~/.wk/profile

export PATH=$PATH:/Users/jasonaguilon/.local/bin

eval "$(/opt/homebrew/bin/brew shellenv)"

. $HOME/.asdf/asdf.sh

# HACK: to get conda 4.7.5 working again
# Which broke after upgrading from 4.5.11 using:
#  conda update -n base conda
#
# from https://github.com/conda/conda/issues/8867#issuecomment-508820119:
# brew install libarchive then set LIBARCHIVE.
export LIBARCHIVE=/usr/local/Cellar/libarchive/3.3.3/lib/libarchive.13.dylib

# tmuxifier
#export PATH="$HOME/.tmuxifier/bin:$PATH"
#eval "$(tmuxifier init -)"

# dart-lang's pub installs executables here
#export PATH=$PATH:~/.pub-cache/bin

# alias to enable some dev commands that are still using the pub command.
alias pub='dart pub'
alias dart2js='dart compile js'

# bash completions
[[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]] && . "$(brew --prefix)/etc/profile.d/bash_completion.sh"

#
# rbenv completions
source ~/.rbenv/completions/rbenv.bash


if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi

source ~/.tig-completion.bash

source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc"

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
git config --global color.ui true

# Maven
#export MAVEN_OPTS="-Xmx4096m -Xss1024m -XX:MaxPermSize=128m"
export MAVEN_OPTS="-Xmx4096m -Xss1024m"

# Ant
export ANT_OPTS="-Xms512m -Xmx1024m"
ant () { command ant  -logger org.apache.tools.ant.listener.AnsiColorLogger "$@" | sed 's/2;//g' ; }

# todo.txt
export TODOTXT_DEFAULT_ACTION=ls
source /opt/homebrew/etc/bash_completion.d/todo_completion
alias todo='todo.sh -a'
complete -F _todo todo

# virtualenvwrapper
#export WORKON_HOME=~/virtualenvs
#source /usr/local/bin/virtualenvwrapper.sh
#pyenv virtualenvwrapper

# Only load Liquid Prompt in interactive shells, not from a script or from scp
# https://github.com/nojhan/liquidprompt
if [ -f /opt/homebrew/share/liquidprompt ]; then
  . /opt/homebrew/share/liquidprompt
fi

#source $HOME/.homesick/repos/homeshick/homeshick.sh

[ -r ~/.extra ] && source ~/.extra

# Generic Colouriser
# http://kassiopeia.juls.savba.sk/~garabik/software/grc/README.txt
#source "`brew --prefix grc`/etc/grc.bashrc"

# bash completions
if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

# nvm, for node version management
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

conda activate
# . /Users/jason.aguilon/anaconda2/etc/profile.d/conda.sh  # commented out by conda initialize

