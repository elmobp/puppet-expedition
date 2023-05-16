#!/usr/bin/env bash
wget https://apt.puppetlabs.com/puppet7-release-$(lsb_release -cs).deb
dpkg -i puppet7-release-$(lsb_release -cs).deb
apt update
apt -y install puppet-agent
gem install librarian-puppet
librarian-puppet install
/opt/puppet/bin/puppet apply site.pp
