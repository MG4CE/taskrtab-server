#!/bin/sh

if [ "$(basename "$(pwd)")" != "taskrpad-server" ]
then
    echo "Please run python-setup.sh from the taskrpad-server repo directory!"
    echo "i.e. ./scripts/python-setup.sh"
    exit 1
fi

PYTHON_VENV_DIR="$(pwd)/taskrpad_pyenv"
echo $PYTHON_VENV_DIR

which python3 > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Python3 not found. Installing..."
    sudo apt update
    sudo apt install python3 -y
else
    echo "Python3 is already installed."
fi

# install venv, and postgres requirements
sudo apt install python3-venv -y
sudo apt install python3-pip -y

if [ ! -d "$PYTHON_VENV_DIR" ]; then
    echo "Creating virtual env"
    python3 -m venv "$PYTHON_VENV_DIR"
fi

# install requirements in virtual environment, pytest
"$PYTHON_VENV_DIR/bin/pip3" install -r "$(pwd)/scripts/requirements.txt"
