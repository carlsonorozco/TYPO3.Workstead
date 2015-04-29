#!/usr/bin/env bash

DB=$1;

mysql -uworkstead -psecret -e "DROP DATABASE IF EXISTS \`$DB\`";
mysql -uworkstead -psecret -e "CREATE DATABASE \`$DB\` DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci";
