class expedition (
  String $mysql_root_password = 'paloalto',
  Boolean $enable_ssl = true,
  String $ssl_certificate = '---BEGIN--',
  String $ssl_key = '---BEGIN--',
  String $vhost_name = $facts['networking']['fqdn'],
) {
  Class['Apt::Update'] -> Package<| |>
  # Classes to include
  include apt
  include mysql::server
  include rabbitmq
  include apache
  include apache::mod::php
  include php
  include php::globals
  include php::apache_config
  include python

  class { 'apache':
    default_mods => ['rewrite'],
    mpm_module   => 'prefork',
  }
  ~> class { 'apache::mod::php':
    php_version => '7.0',
  }
  ~> class { 'php::globals':
    php_version => '7.0',
    config_root => '/etc/php/7.0',
  }
  ~> class { 'php':
    manage_repos => true,
    settings     => {
      'PHP/mysqli.reconnect' => 'On',
      extensions             => {
        'bcmath'   => {},
        'mbstring' => {},
        'gd'       => {},
        'soap'     => {},
        'zip'      => {},
        'xml'      => {},
        'curl'     => {},
        'bz2'      => {},
        'mcrypt'   => {},
        'ldap'     => {},
        'mysql'    => {},
        'radius'   => {},
        'opcache'  => { 'zend' => true },
      },
    },
  }
  ~> class { 'php::apache_config':
    settings => {
      'PHP/mysqli.reconnect' => 'On',
    },
  }
  ~> apt::source { 'ubuntu':
    location => 'http://au.archive.ubuntu.com/ubuntu/',
    repos    => 'main restricted universe multiverse',
    release  => $facts['os']['distro']['codename'],
    include  => {
      'src' => true,
    },
  }
  ~> apt::source { 'ubuntu-updates':
    location => 'http://au.archive.ubuntu.com/ubuntu/',
    release  => "${facts['os']['distro']['codename']}-updates",
    repos    => 'main restricted universe multiverse',
    include  => {
      'src' => true,
    },
  }
  ~> apt::source { 'ubuntu-security':
    location => 'http://au.archive.ubuntu.com/ubuntu/',
    release  => "${facts['os']['distro']['codename']}-security",
    repos    => 'main restricted universe multiverse',
    include  => {
      'src' => true,
    },
  }
  ~> apt::source { 'conversionupdates.paloaltonetworks.com':
    location       => 'https://conversionupdates.paloaltonetworks.com/',
    release        => '',
    repos          => 'expedition-updates/',
    allow_unsigned => true,
  }
  ~> file { '/home/userSpace':
    ensure => directory,
    owner  => 'www-data',
    user   => 'www-data',
  }
  package { ['python3', 'python3-pip', 'liblist-moreutils-perl', 'openjdk-8-jre-headless', 'libjpeg-dev', 'zlib1g-dev', 'zip']:
    ensure => installed,
  }
  ~> package { 'Pillow':
    ensure   => '5.4.1',
    provider => 'pip3',
    require  => Package['python3'],
  }
  ~> package { ['chardet','lxml','matplotlib']:
    ensure   => present,
    provider => 'pip3',
  }
  file { '/etc/ssl/certs/cert.pem':
    ensure  => file,
    content => $ssl_certificate,
  }
  ~> file { '/etc/ssl/private/key.pem':
    ensure  => file,
    content => $ssl_key,
  }
  ~> file { '/data/pandb.sql':
    ensure => file,
    source => 'puppet:///modules/expedition/sql/pandb.sql',
  }
  ~> file { '/data/pandbRBAC.sql':
    ensure => file,
    source => 'puppet:///modules/expedition/sql/pandbRBAC.sql',
  }
  ~> file { '/data/BestPractices.sql':
    ensure => file,
    source => 'puppet:///modules/expedition/sql/BestPractices.sql',
  }
  ~> file { '/data/RealTimeUpdates.sql':
    ensure => file,
    source => 'puppet:///modules/expedition/sql/RealTimeUpdates.sql',
  }
  ~> file { '/lib/systemd/system/panReadOrders.service':
    ensure => file,
    source => 'puppet:///modules/expedition/panReadOrders.service',
  }
  ~> file { '/etc/systemd/system/multi-user.target.wants/panReadOrders.service':
    ensure => link,
    target => '/lib/systemd/system/panReadOrders.service',
  }
  ~> file { '/etc/ssl/certs/cert.pem':
    ensure  => file,
    content => $ssl_cert,
  }
  ~> file { '/etc/ssl/private/key.pem':
    ensure  => file,
    content => $ssl_key,
  }
  ~> class { 'mysql::server':
    root_password           => $mysql_root_password,
    managed_dirs            => undef,
    remove_default_accounts => true,
    override_options        => {
      'mysqld' => {
        'max_allowed_packet' => '64M',
        'bind_address'       => '::',
        'binlog_format'      => 'mixed',
      },
    },
  }
  ~> mysql::db { 'pandb':
    sql => ['/data/pandb.sql'],
  }
  ~> mysql::db { 'pandbRBAC':
    sql => ['/data/pandbRBAC.sql'],
  }
  ~> mysql::db { 'BestPractices':
    sql => ['/data/BestPractices.sql'],
  }
  ~> mysql::db { 'RealTimeUpdates':
    sql => ['/data/RealTimeUpdates.sql'],
  }
  ~> user { 'expedition':
    groups => ['expedition', 'www-data'],
  }
  ~> class { 'rabbitmq':
    manage_python => false,
  }
  ~> apache::vhost { "${vhost_name}-http":
    port            => 80,
    docroot         => '/var/www/html',
    redirect_status => 'permanent',
    redirect_dest   => "https://${vhost_name}/",
    serveraliases   => [$facts['networking']['fqdn']],
  }
  ~> apache::vhost { $vhost_name:
    port             => 443,
    docroot          => '/var/www/html',
    ssl              => true,
    ssl_cert         => '/etc/ssl/certs/cert.pem',
    ssl_key          => '/etc/ssl/private/key.key',
    fallbackresource => '/index.php',
  }
  ~> package { ['expedition-beta', 'expeditionml-dependencies-beta']:
    ensure => present,
  }
  ~> file_line { 'db_password':
    path  => '/home/userSpace/userDefinitions.php',
    line  => "define ('DBPass', '${myql_root_password}');",
    match => '^define (\'DBPass',
  }
  ~> service { 'panReadOrders':
    ensure => running,
    enable => true,
  }
}