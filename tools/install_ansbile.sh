# !/bin/bash
set -e 

OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "無法辦定 Operating system version (/etc/os-release不存在) "
    exit 1
fi

echo "檢察系統: $OS"
if
echo "檢測到系統: $OS"

if [[ "$OS == ubuntu " || "debian" ]]; then
    echo "ubuntu/Debian installion procedure "
    sudo apt update -y
    sudo apt install -y ansible tree

elif [[ "$OS" == "rocky" || "$OS" == "centos" ]]; then
    echo " Rocky/Rhel/centOS installion procedure "
    sudo dnf makecache -y 
    sudo dnf install -y epel-release
    sudo dnf install -y ansible tree
else
    echo "沒有支持該系統 : $OS"
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