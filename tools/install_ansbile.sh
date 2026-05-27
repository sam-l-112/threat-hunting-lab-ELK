# !/bin/bash
set -e 

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "無法辦定 Operating system version (/etc/os-release不存在) "
    exit 1
fi
echo "檢察系統: $OS"

if [[ "$OS" == "ubuntu " || "$OS" == "debian" ]]; then
    echo "ubuntu/Debian installion procedure "
    sudo apt update -y
    sudo apt install -y ansible tree
    ansible --version

elif [[ "$OS" == "rocky" || "$OS" == "centos" ]]; then
    echo " Rocky/Rhel/centOS installion procedure "
    sudo dnf makecache -y 
    sudo dnf install -y epel-release
    # sudo dnf install -y ansible tree
    sudo dnf install -y ansible-core
    ansible --version
else
    echo "System not supported : $OS"
    exit 1
fi


# ubuntu
# #!/bin/bash
# set -e

# # Update package list
#  sudo apt update && sudo apt upgrade -y

#  # Install additional tools
#  sudo apt-get dist-upgrade -y

# # Install ansible
# sudo apt install -y ansible

# # Install additional tools
# sudo apt install -y tree

# # Ensure Python venv module is installed
# sudo apt install -y python3.12-venv

# # # Create Python virtual environment if not exists
# if [ ! -d ".venv" ]; then
#   python3 -m venv .venv
# fi


# # 以下自行輸入
# # # Activate the virtual environment
# # source .venv/bin/activate

# # # Upgrade pip and install Ansible
# # pip install --upgrade pip
# # pip install ansible requests joblib tqdm

# # echo "Virtual environment and Ansible are ready."