#!/bin/bash

# Exit immediately if any commands return a non-zero status.
set -e

# Install homebrew then brew install all dependencies in the Brewfile.
echo "Installing homebrew..."
xcode-select --install
mkdir /usr/local/homebrew && curl -L
https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /usr/local/homebrew
brew bundle

# setup dotfiles using homeshick.
homeshick clone aguil/dotfiles
homeshick check

# python setuptools -- pip requirement
curl -o setuptools-0.6c11-py2.7.egg https://pypi.python.org/packages/2.7/s/setuptools/setuptools-0.6c11-py2.7.egg#md5=fe1f997bc722265116870bc7919059ea
sh setuptools-0.6c11-py2.7.egg

# pip
curl -O https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python get-pip.py

# bpython
pip install bpython

# Powerline
pip install --user git+git://github.com/Lokaltog/powerline

# install powerline fonts

# virtualenv and virtualenvwrapper
pip install virtualenv
pip install virtualenvwrapper
export WORKON_HOME=~/virtualenvs
mkdir -p $WORKON_HOME

# Anaconda
# From https://docs.anaconda.com/anaconda/install/mac-os/
curl -O https://repo.anaconda.com/archive/Anaconda3-2019.03-MacOSX-x86_64.sh
./verify.sh /Anaconda3-2019.03-MacOSX-x86_64.sh 46709a416be6934a7fd5d02b021d2687
EXITCODE = $?
if [ $EXITCODE -ne 0 ]; then
  exit $EXITCODE
fi
# NOTE: Heads up as Anaconda's install shell script requires some interaction.
bash ./Anaconda3-2019.03-MacOSX-x86_64.sh

echo "Apps this script doesn't install:
Alfred
Better Touch Tool
Box
Disk Inventory X
Docker
Dropbox
Evernote
Firefox
GeekTool
Gimp
IntelliJ IDEA
iTerm2
kdiff3
LibreOffice
MacVim
p4merge
Slack
Wireshark
"
