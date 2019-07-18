export PATH=~/.rbenv/shims:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}
#export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}

export DART_FLAGS="--checked --load_deferred_eagerly"
export DARTIUM_EXPIRATION_TIME=1577836800
export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:/usr/local/bin/nimrod/bin
eval "$(pyenv init -)"
export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"

# HACK: to get conda 4.7.5 working again
# Which broke after upgrading from 4.5.11 using:
#  conda update -n base conda
#
# from https://github.com/conda/conda/issues/8867#issuecomment-508820119:
# brew install libarchive then set LIBARCHIVE.
export LIBARCHIVE=/usr/local/Cellar/libarchive/3.3.3/lib/libarchive.13.dylib

# tmuxifier
export PATH="$HOME/.tmuxifier/bin:$PATH"
eval "$(tmuxifier init -)"

# dart-lang's pub installs executables here
export PATH=$PATH:~/.pub-cache/bin

# rbenv completions
source ~/.rbenv/completions/rbenv.bash

source ~/.tig-completion.sh

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

# Maven
export MAVEN_OPTS="-Xmx4096m -Xss1024m -XX:MaxPermSize=128m"

# Ant
export ANT_OPTS="-Xms512m -Xmx1024m"
ant () { command ant  -logger org.apache.tools.ant.listener.AnsiColorLogger "$@" | sed 's/2;//g' ; }

# todo.txt
export TODOTXT_DEFAULT_ACTION=ls
source /usr/local/etc/bash_completion.d/todo_completion
alias todo='todo.sh -a'
complete -F _todo todo

# virtualenvwrapper
export WORKON_HOME=~/virtualenvs
source /usr/local/bin/virtualenvwrapper.sh
pyenv virtualenvwrapper

# Prompt
#export PS1='\[\e]2;\w\a\n[\!]\u@\h: \w \[$(tput bold)\]$(__git_ps1 "(%s)")\n\$ \[$(tput sgr0)\]'
#export PS1='\[\e]2;\w\a\n\]\[\e]1;\]$(basename "$(dirname "$PWD")")/\W\[\a\][\t]\u@\h: \w \[$(tput bold)\]$(__git_ps1 "(%s)")\n\$ \[$(tput sgr0)\]'
source ~/.bash/gitprompt.sh
#PROMPT_START="$IBLACK$Time12a$ResetColor$Yellow$PathShort$ResetColor"
#PROMPT_END="\n$ "

source $HOME/.homesick/repos/homeshick/homeshick.sh

[ -r ~/.extra ] && source ~/.extra

# Generic Colouriser
# http://kassiopeia.juls.savba.sk/~garabik/software/grc/README.txt
source "`brew --prefix grc`/etc/grc.bashrc"

# bash completions
if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

# nvm, for node version management
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh


# added by Anaconda2 5.0.1 installer
export PATH="/Users/jason.aguilon/anaconda2/bin:$PATH"

function workon_dart1() {
  brew unlink dart
  brew unlink dart@1
  brew switch dart@1 1.24.3
  brew link --force dart@1
  dart --version
}

function workon_dart2() {
  brew unlink dart
  brew unlink dart@1
  brew switch dart 2.2.0
  brew link dart
  dart --version
}

# Path to Dart 2 executables
export DART_2_PATH=/usr/local/Cellar/dart/2.2.0/bin/

# The Dart SDK version you wish to solve under
export CURRENT_DART_VERSION=1.24.3

# Runs `pub get` in Dart 2 using the current Dart version as SDK constraints,
# and then runs `pub get` in Dart 1 to get the lock file in a good state.
#
# `--no-precompile` is important here so that Pub doesn't try
# and fail to compile Dart 1 executables under Dart 2.
#
# Unlike an alias (in Bash), this function also passes any
# additional arguments along to `pub`.
function pub2get() {
  _PUB_TEST_SDK_VERSION="$CURRENT_DART_VERSION" "$DART_2_PATH/pub" get --no-precompile "$@" && pub get --offline "$@"
}

function pub2upgrade() {
  _PUB_TEST_SDK_VERSION="$CURRENT_DART_VERSION" "$DART_2_PATH/pub" upgrade --no-precompile "$@" && pub get --offline "$@"
}

conda activate
. /Users/jason.aguilon/anaconda2/etc/profile.d/conda.sh
