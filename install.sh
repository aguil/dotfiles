# Install brew then brew install all dependencies in the Brewfile.
ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"
brew bundle

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

