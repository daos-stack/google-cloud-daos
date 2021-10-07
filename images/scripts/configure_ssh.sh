#!/bin/bash

mkdir -p /root/.ssh
chmod 700 /root/.ssh
mv /tmp/id_rsa /root/.ssh/id_rsa
mv /tmp/id_rsa.pub /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
printf 'Host *\n  StrictHostKeyChecking no\n  IdentityFile /root/.ssh/id_rsa\n' > /root/.ssh/config
chown -R root:root /root/.ssh
sed -i '/^PermitRootLogin/s/no/yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd
