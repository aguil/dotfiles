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
echo "Setting up dotfiles..."
homeshick clone aguil/dotfiles
homeshick check

# python setuptools -- pip requirement
echo "Python 2.7: setuptools"
curl -o setuptools-0.6c11-py2.7.egg https://pypi.python.org/packages/2.7/s/setuptools/setuptools-0.6c11-py2.7.egg#md5=fe1f997bc722265116870bc7919059ea
sh setuptools-0.6c11-py2.7.egg

# pip
echo "Python 2.7: pip"
curl -O https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python get-pip.py

# Powerline
pip install --user git+git://github.com/Lokaltog/powerline

# install powerline fonts

# virtualenv and virtualenvwrapper
pip install virtualenv
pip install virtualenvwrapper
export WORKON_HOME=~/virtualenvs
mkdir -p $WORKON_HOME

