#!/bin/bash

# Install givn beat and version
# Will replace any old/new version already installed

BEAT_NAME=$1
STACK_VER=$2

_fail() {
  echo $@ >&2
  exit 1
}

# Test that programmes we are going to use are installed
for c in curl lsb_release; do
  test -x "$(which $c)" || _fail "Programme '$c' appears to be missing"
done

test -z "$BEAT_NAME" && _fail "Beat name argument misssing"
test -z "$STACK_VER" && _fail "Stack version argument missing"

install_on_Debian() {

  # Test if we already added the elastic repository, and add it if not
  if ! test -f /etc/apt/sources.list.d/elastic-7.x.list ; then
  
    DEBIAN_FRONTEND=noninteractive apt-get -y install apt-transport-https ca-certificates
  
    curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" \
      > /etc/apt/sources.list.d/elastic-7.x.list >/dev/null
    
    apt-get update
  fi

  test -f /etc/$BEAT_NAME/$BEAT_NAME.yml && 
    mv /etc/$BEAT_NAME/$BEAT_NAME.yml /etc/$BEAT_NAME/$BEAT_NAME.old.yml 
    
  DEBIAN_FRONTEND=noninteractive apt-get --allow-downgrades -y -o Dpkg::Options::="--force-confask,confnew,confmiss" install $BEAT_NAME=$STACK_VER
  
  cp /etc/$BEAT_NAME/$BEAT_NAME.yml /etc/$BEAT_NAME/$BEAT_NAME.example.yml
  
} # End: install_on_Debian

# Same as debian
install_on_Ubuntu() { install_on_Debian; }


install_on_CentOS() {

  # Test if we already added the elastic repository, and add it if not
  if ! test -f /etc/yum.repos.d/elastic.repo ; then
  
    rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch

    cat >/etc/yum.repos.d/elastic.repo <<_EOF_ 
[elastic-7.x]
name=Elastic repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
_EOF_

    #yum repolist
  fi

  test -f /etc/$BEAT_NAME/$BEAT_NAME.yml && 
    mv /etc/$BEAT_NAME/$BEAT_NAME.yml /etc/$BEAT_NAME/$BEAT_NAME.old.yml 
    
  # Install our list of beats
  yum -y install $BEAT_NAME-$STACK_VER
  
  cp /etc/$BEAT_NAME/$BEAT_NAME.yml /etc/$BEAT_NAME/$BEAT_NAME.example.yml
} # End: install_on_CentOS

# Same as CentOS 
install_on_RHEL() { install_on_CentOS; }

#########################################################################

if [ -x "$(which $BEAT_NAME)" ]; then

  CURRENT_VER=$($BEAT_NAME version | sed -Ee 's/.*version (\S*) .*/\1/')
  if [ "$CURRENT_VER" != "$STACK_VER" ]; then
    install_on_$(lsb_release -is)
  fi
  
else
  install_on_$(lsb_release -is)
fi

$BEAT_NAME -c "$BEAT_NAME.example.yml" keystore create --force

# Will be started by the ec spout startup script
systemctl disable $BEAT_NAME
systemctl stop $BEAT_NAME
