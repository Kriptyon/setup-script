#!/bin/bash

# Main script

# Define the desired hostname
DESIRED_HOSTNAME="DESIRED-HOSTNAME"
# Specify if Docker should be installed (1 = Yes, 0 = No)
INSTALL_DOCKER=1

### Do not edit below this line unless you know what you're doing ###

# Function to check if a password meets the required criteria
check_password() {
    password=$1

    # Check if the password meets the length criteria
    if [ ${#password} -lt 8 ]; then
        echo "BAD PASSWORD: The password is shorter than 8 characters"
        return 1
    fi

    # Check if the password contains at least one uppercase letter
    if ! [[ $password =~ [[:upper:]] ]]; then
        echo "BAD PASSWORD: The password contains less than 1 uppercase letter"
        return 1
    fi

    # Check if the password is found in the dictionary
    if grep -q "^$password$" /usr/share/dict/words; then
        echo "DEBUG: Password found in the dictionary: $password"
        echo "BAD PASSWORD: The password is too common or easily guessable"
        return 1
    else
        echo "DEBUG: Password not found in the dictionary: $password"
    fi

    # If all checks pass, return success
    return 0
}

echo "@@@@@@ $DESIRED_HOSTNAME @@@@@@"
apt update

#Pevents the pouup of udisks2.service and automates the restart of it
sudo NEEDRESTART_MODE=a apt-get dist-upgrade --yes



# Configure the hostname of the instance
if [ -n "$DESIRED_HOSTNAME" ]; then
    echo "$DESIRED_HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$DESIRED_HOSTNAME"
    sed -i "s/127.0.0.1 localhost/127.0.0.1 localhost $DESIRED_HOSTNAME/g" /etc/hosts
fi

# Configure SSH
sed -i 's/session    optional     pam_motd.so  motd=\/run\/motd.dynamic/#session    optional     pam_motd.so  motd=\/run\/motd.dynamic/' /etc/pam.d/sshd
sed -i 's/#Banner none/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
chmod 664 /etc/issue.net
echo -e "* * * * * * * * * * W A R N I N G * * * * * * * * * *\n\nThis system is the private property, for authorized personnel only.\nBy using this system, you agree to comply with the company Information Technology Policies & Standards.\nUnauthorized or improper use of this system may result in administrative disciplinary action,\ncivil charges/criminal penalties, and/or other sanctions according to company policies, Spain and European Union laws.\n\n\nBy continuing to use this system you indicate your awareness of and consent to these terms and conditions of use.\n\n* * * * * * * * * * * * * * * * * * * * * * * *\n\n\n* * * * * * * * * * AVISO * * * * * * * * * *\n\nEste sistema es propiedad privada, sólo para personal autorizado.\nAl utilizar este sistema, usted acepta cumplir con las Políticas, normas de uso de las tecnologías de información y comunicaciones.\nEl uso no autorizado o inapropiado de este sistema, podrá causar acciones disciplinarias administrativas,\ncargos civiles o sanciones penales, además de otras sanciones de acuerdo con las políticas de la compañía, las leyes de España y la Unión Europea.\n\n\nAl continuar utilizando este sistema, usted indica que conoce y acepta estos términos y condiciones de uso.\n\n* * * * * * * * * * * * * * * * * * * * * * *" > /etc/issue.net
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication no/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
#systemctl restart sshd
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target


# Install and configure Zabbix
apt install zabbix-agent -y
sed -i 's/ServerActive=127.0.0.1/ServerActive=zabbix.DOMINIO/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/Server=127.0.0.1/Server=zabbix.DOMINIO/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/# Hostname=/Hostname='"${DESIRED_HOSTNAME}"'.DOMINIO/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/# DenyKey=system.run[*]/AllowKey=system.run[*]/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/# LogRemoteCommands=0/LogRemoteCommands=1/' /etc/zabbix/zabbix_agentd.conf
systemctl restart zabbix-agent.service

# Monitor authentication
chmod g+r /var/log/auth.log
chgrp zabbix /var/log/auth.log



# Password Complexity (Using PAM modules)
# Install necessary packages
apt install libpam-pwquality -y

# Configure PAM
sed -i '/pam_pwquality.so/d' /etc/pam.d/common-password
echo "password requisite pam_pwquality.so retry=3 minlen=8 maxrepeat=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 difok=3 gecoscheck=1 reject_username enforce_for_root" >> /etc/pam.d/common-password


# Notify via Telegram
curl -X POST https://api.telegram.org/BOT/sendMessage \
     -H 'Content-Type: application/json' \
     -d '{"chat_id": "IDCHAT", "disable_notification": true, "text": "Instance created successfully: '"${DESIRED_HOSTNAME}"'"}'

# Execute pam-auth-update
 sudo pam-auth-update --force --package pwquality



# Instalar docker
if [ "$INSTALL_DOCKER" = 1 ]
then  
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt remove $pkg; done
  apt install ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
fi

# IF USER DON'T PASS THE AUTH MINIMUMS AND WHEN TRY AGAIN SELECTS NO, THE UNSECURE PASS WILL BE ASSIGNED