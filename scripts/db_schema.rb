#!/usr/local/bin/ruby19
# -*- coding: utf-8 -*-

require 'mysql'

# before require of schema.rb
#  init.rb MUST be already loaded with $YABITZ_RUN_ON_TEST_ENVIRONMENT = true
#  for use in setup/teardown on testing
require_relative '../lib/yabitz/misc/init'

module Yabitz::Schema
  def self.main()
    drop_database(*(Yabitz.config().dbparams))
    create_database(*(Yabitz.config().dbparams))
    create_tables()
  end

  def self.setup_test_db()
    create_database(*(Yabitz.config().dbparams))
    create_tables()
  end

  def self.teardown_test_db()
    drop_database(*(Yabitz.config().dbparams))
  end

  def self.conn()
    Mysql.connect(*(Yabitz.config().dbparams))
  end

  def self.create_database(server, user, pass, db, port, sock, flg=nil)
    c = Mysql.connect(server, user, pass, nil, port, sock, flg)
    c.query("CREATE DATABASE #{db} DEFAULT CHARACTER SET 'utf8'")
    c.close()
  end

  def self.drop_database(server, user, pass, db, port, sock, flg=nil)
    c = Mysql.connect(server, user, pass, nil, port, sock, flg)
    c.query("DROP DATABASE IF EXISTS #{db}")
    c.close()
  end

  def self.create_tables()
    sqls = []
    sqls.push <<-EOSQL
CREATE TABLE oids (
id INT PRIMARY KEY NOT NULL AUTO_INCREMENT
) ENGINE=InnoDB
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE auth_info (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
valid       ENUM('0','1')   NOT NULL DEFAULT '1',
name        VARCHAR(64)     NOT NULL,
fullname    VARCHAR(64)     NOT NULL,
priv        VARCHAR(16)     DEFAULT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
INSERT INTO oids SET id=1
EOSQL

    sqls.push <<-EOSQL
INSERT INTO auth_info SET oid=0, valid='1', name='root', fullname='root', priv='ROOT', operated_by=0;
EOSQL
    sqls.push <<-EOSQL
INSERT INTO auth_info SET oid=1, valid='1', name='batchmaker', fullname='batchmaker', priv='ADMIN', operated_by=0
EOSQL
    sqls.push <<-EOSQL
CREATE TABLE auth_log (
id             INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
username       VARCHAR(64) NOT NULL,
msg            VARCHAR(16),
oid            INT,
sourceip       VARCHAR(39),
inserted_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE contents (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(64)     NOT NULL,
charging    VARCHAR(16)     DEFAULT NULL,
code        VARCHAR(16)     NOT NULL,
dept        INT             NOT NULL,
services    TEXT            DEFAULT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE services (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(64)     NOT NULL,
content     INT             NOT NULL,
mladdress   VARCHAR(256)    DEFAULT NULL,
urls        TEXT            DEFAULT NULL,
contact     INT             DEFAULT NULL,
notes       TEXT            DEFAULT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE hosts (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
service     INT             NOT NULL,
status      VARCHAR(16)     NOT NULL,
type        VARCHAR(16)     NOT NULL,
parent      INT             ,
children    TEXT            ,
rackunit    INT             ,
hwid        VARCHAR(16)     ,
hwinfo      INT             ,
memory      VARCHAR(64)     ,
disk        VARCHAR(64)     ,
os          VARCHAR(64)     ,
dnsnames    TEXT            ,
local_ipaddrs   TEXT        ,
global_ipaddrs  TEXT        ,
virtual_ipaddrs TEXT        ,
notes       TEXT            ,
tagchain    INT             ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE tagchains (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
host        INT             NOT NULL,
tagchain    TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0',
FULLTEXT INDEX tagchain_idx (tagchain)
) ENGINE=MyISAM charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE serviceurls (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
url         VARCHAR(1024)   NOT NULL,
services    TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE dnsnames (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
dnsname     VARCHAR(256)    NOT NULL,
hosts       TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE ipaddresses (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
address     VARCHAR(39)     NOT NULL,
version     VARCHAR(16)     DEFAULT 'IPv4',
hosts       TEXT            ,
holder      ENUM('0','1')   NOT NULL DEFAULT '0',
notes       TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE ipsegments (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
address     VARCHAR(39)     NOT NULL,
netmask     VARCHAR(11)     ,
version     VARCHAR(16)     DEFAULT 'IPv4',
area        VARCHAR(16)     DEFAULT 'local',
ongoing     ENUM('0','1')   NOT NULL DEFAULT '1',
notes       TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE rackunits (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
rackunit    VARCHAR(64)     NOT NULL,
dividing    VARCHAR(16)     DEFAULT 'FULL',
rack        INT             NOT NULL,
hosts       TEXT            ,
holder      ENUM('0','1')   NOT NULL DEFAULT '0',
notes       TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE racks (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
label       VARCHAR(64)     NOT NULL,
type        VARCHAR(16)     DEFAULT 'DH_1',
datacenter  VARCHAR(16)     DEFAULT 'DATAHOTEL',
ongoing     ENUM('0','1')   NOT NULL DEFAULT '1',
notes       TEXT            ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE contactmembers (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(64)     NOT NULL,
telno       VARCHAR(64)     ,
mail        VARCHAR(256)    ,
comment     TEXT            ,
badge       VARCHAR(16)     ,
position    VARCHAR(16)     ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE contacts (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
label       VARCHAR(64)     NOT NULL,
services    TEXT            ,
telno_daytime VARCHAR(64)   ,
mail_daytime  VARCHAR(256)  ,
telno_offtime VARCHAR(64)   ,
mail_offtime  VARCHAR(256)  ,
members       TEXT          ,
memo          TEXT          ,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE depts (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(64)     NOT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE hwinformations (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(64)     NOT NULL,
prior       ENUM('0','1')   NOT NULL DEFAULT '0',
units       VARCHAR(64)     NOT NULL,
calcunits   DECIMAL(4,2)    ,
virtualized ENUM('0','1')   NOT NULL DEFAULT '0',
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    sqls.push <<-EOSQL
CREATE TABLE osinformations (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(64)     NOT NULL,
prior       ENUM('0','1')   NOT NULL DEFAULT '0',
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL

    c = conn()
    sqls.each do |s|
      c.query(s)
    end
    c.close()
  end
end

if $PROGRAM_NAME == __FILE__
  Yabitz::Schema.main()
end
