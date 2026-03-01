export PATH=/usr/local/opt/coreutils/libexec/gnubin:${PATH}
export PATH=~/.rbenv/shims:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}

# dart-lang's pub installs executables here
export PATH=$PATH:"$HOME/.pub-cache/bin"

export PATH=$PATH:"$HOME/.girpl/bin"

# Go configuration for go modules
export GO111MODULE="auto"  # this may or may not have to be set, or can be set to "auto"

export DART_FLAGS="--checked --load_deferred_eagerly"
export DARTIUM_EXPIRATION_TIME=1577836800
export GOPATH=$HOME/code/gopath
export PATH=$PATH:$GOPATH/bin
export GOPRIVATE=github.com/Workiva
export PATH=$PATH:/usr/local/bin/nimrod/bin

export PATH=`/usr/libexec/java_home -v 11`"/bin:$PATH"
export PATH=$PATH:"/usr/local/texlive/2021basic/bin/universal-darwin"

if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
  source ~/.wk/profile
fi

export PATH=$PATH:/Users/jasonaguilon/.local/bin

if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"

    . $HOME/.asdf/asdf.sh
fi

# HACK: to get conda 4.7.5 working again
# Which broke after upgrading from 4.5.11 using:
#  conda update -n base conda
#
# from https://github.com/conda/conda/issues/8867#issuecomment-508820119:
# brew install libarchive then set LIBARCHIVE.
export LIBARCHIVE=/usr/local/Cellar/libarchive/3.3.3/lib/libarchive.13.dylib


# alias to enable some dev commands that are still using the pub command.
alias pub='dart pub'
alias dart2js='dart compile js'

# bash completions
[[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]] && . "$(brew --prefix)/etc/profile.d/bash_completion.sh"

# rbenv completions
if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    source ~/.rbenv/completions/rbenv.bash
fi

if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi

source ~/.tig-completion.bash

if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc"
fi

LANG="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_CTYPE="en_US.UTF-8"
LC_MESSAGES="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_ALL="en_US.UTF-8"

# Git and SVN
if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    export EDITOR='/usr/local/bin/vim -f'

    git config --global color.ui true
fi

# Maven
export MAVEN_OPTS="-Xmx4096m -Xss1024m"

# Ant
export ANT_OPTS="-Xms512m -Xmx1024m"
ant () { command ant  -logger org.apache.tools.ant.listener.AnsiColorLogger "$@" | sed 's/2;//g' ; }

# todo.txt
export TODOTXT_DEFAULT_ACTION=ls
source /opt/homebrew/etc/bash_completion.d/todo_completion
alias todo='todo.sh -a'
if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    complete -F _todo todo
fi

# Only load Liquid Prompt in interactive shells, not from a script or from scp
# https://github.com/nojhan/liquidprompt
if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    if [ -f /opt/homebrew/share/liquidprompt ]; then
        . /opt/homebrew/share/liquidprompt
    fi
fi

[ -r ~/.extra ] && source ~/.extra

# nvm, for node version management
export NVM_DIR="$HOME/.nvm"
if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/jasonaguilon/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/jasonaguilon/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/Users/jasonaguilon/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/jasonaguilon/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    conda activate
    # . /Users/jason.aguilon/anaconda2/etc/profile.d/conda.sh  # commented out by conda initialize
fi

# Added by Toolbox App
export PATH="$PATH:/usr/local/bin"

export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
