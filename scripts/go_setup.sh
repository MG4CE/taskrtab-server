#!/bin/sh

GO_LANG_VERSION="1.24.2"

#Script only compatible with Ubuntu based systems
if ! grep -q 'ubuntu' /etc/os-release
then
    echo "This Linux distro is not supported!";
    echo "Supported Linux distros: Ubuntu";
    exit 1;
fi

#Update and Upgrade the system
sudo apt -y update
sudo apt -y upgrade

#Fetch go tar into home dir
wget https://golang.org/dl/go$GO_LANG_VERSION.linux-amd64.tar.gz -P /tmp/

#TODO: SHA256 checksum of tarball

#TODO: remove old go installs

#Unpack go tar
sudo tar -C /usr/local -xvf /tmp/go$GO_LANG_VERSION.linux-amd64.tar.gz

#Setting up .bashrc export path
if ! grep -q "/usr/local/go/bin" ~/.bashrc
then
    echo "export PATH=\$PATH:/usr/local/go/bin" >>  ~/.bashrc
    echo "export PATH="$HOME/go/bin"" >>  ~/.bashrc
fi

# shellcheck source=/dev/null
. "$HOME/.bashrc"

go version #NOTE: sometimes source doesent not work...

#Cleanup
rm /tmp/go$GO_LANG_VERSION.linux-amd64.tar.gz
