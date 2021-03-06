#!/bin/bash

ANSIBLECAP_PATH="/var/lib/ansible/local"
GIT_REPO_URL="https://github.com/bibliosansfrontieres/ideascube-cleanup-configure.git"
ANSIBLE_BIN="/usr/bin/ansible-pull"
ANSIBLE_ETC="/etc/ansible/facts.d/"
BRANCH="master"

[ $EUID -eq 0 ] || {
    echo "Error: you have to be root to run this script." >&2
    exit 1
}

function internet_check()
{
    echo -n "[+] Check Internet connection... "
    if [[ ! `ping -q -c 2 github.com` ]]
    then
        echo "ERROR: Repository is unreachable, check your Internet connection." >&2
        exit 1
    fi
    echo "Done."
}

function install_ansible()
{
    echo -n "[+] Updating APT cache... "
    internet_check
    apt-get update --quiet --quiet
    echo 'Done.'

    echo -n "[+] Install ansible... "
    apt-get install --quiet --quiet -y software-properties-common git lsb-release jq
    apt-add-repository --yes --update ppa:ansible/ansible
    apt-get install --quiet --quiet -y ansible
    echo 'Done.'
}

function clone_ansiblecube()
{
    echo -n "[+] Checking for internet connectivity... "
    internet_check
    echo 'Done.'

    echo -n "[+] Clone ansiblecap repo... "
    mkdir --mode 0755 -p ${ANSIBLECAP_PATH}
    cd ${ANSIBLECAP_PATH}/../
    git clone ${GIT_REPO_URL} local

    mkdir --mode 0755 -p ${ANSIBLE_ETC}
    cp ${ANSIBLECAP_PATH}/hosts /etc/ansible/hosts
    echo 'Done.'
}

[ -x /usr/bin/ansible ] || install_ansible
[ -d ${ANSIBLECAP_PATH} ] || clone_ansiblecube

echo "Checking file access" >> /var/log/ansible-pull.log
[ $? -ne 0 ] && echo "No space left to write logs or permission problem, exiting." && exit 1

while [[ $# -gt 0 ]]
do
    case $1 in
        -n|--name)

            if [ -z "$2" ]
            then
                echo -e "\n\t[+] ERROR\n\t--name : Missing device name\n"

                exit 0;
            fi
            PROJECT_NAME=$2

        shift
        ;;
        *)
            exit
        ;;
    esac
    shift
done

cd $ANSIBLECAP_PATH

echo "$ANSIBLE_BIN --purge -C $BRANCH -d $ANSIBLECAP_PATH -i hosts -U $GIT_REPO_URL main.yml --extra-vars \"project_name=$PROJECT_NAME\"" >> /var/lib/ansible/ansible-pull-cmd-line.sh
echo -e "\n[+] Start configuration...follow logs : tail -f /var/log/ansible-pull.log"

$ANSIBLE_BIN --purge -C $BRANCH -d $ANSIBLECAP_PATH -i hosts -U $GIT_REPO_URL main.yml --extra-vars "project_name=$PROJECT_NAME"
