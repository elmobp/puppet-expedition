node default {
$cert = @(EOF)
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
| EOF

$key = @(EOF)
-----BEGIN RSA PRIVATE KEY-----
-----END RSA PRIVATE KEY-----
| EOF

  class{'expedition':
    mysql_root_password => "paloalto",
    ssl_certificate     => $cert,
    ssl_key             => $key
  }

}
