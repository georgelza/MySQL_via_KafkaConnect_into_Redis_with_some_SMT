-- MySQL initialization script for Debezium
-- Fixed version with proper database creation

-- ⚠️ FIX: Create database BEFORE using it
CREATE DATABASE IF NOT EXISTS tokenise;


SET GLOBAL time_zone = '+2:00';
SET GLOBAL binlog_expire_logs_seconds = 60000;

-- Create user with proper host specification
CREATE USER IF NOT EXISTS 'tokenuser'@'%' IDENTIFIED BY 'tokenpw';

-- Grant ALL required Debezium privileges
-- SELECT: Read table data
-- SHOW DATABASES: List databases
-- REPLICATION SLAVE: Read binlog events
-- REPLICATION CLIENT: Check binlog position
-- RELOAD: Flush tables during snapshot
-- LOCK TABLES: Lock tables during snapshot

GRANT SELECT, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT, RELOAD, LOCK TABLES ON *.* TO 'tokenuser'@'%';
FLUSH PRIVILEGES;

-- Now use the database
USE tokenise;

-- Create test table
DROP TABLE IF EXISTS tokenise.`JNL_ACQ`;

CREATE TABLE IF NOT EXISTS tokenise.`JNL_ACQ` (
  `acqJnlSeqNumber`             bigint NOT NULL AUTO_INCREMENT,
  `accountId1`                  varchar(28) DEFAULT NULL,
  `accountId2`                  varchar(28) DEFAULT NULL,
  `acquirerCountryCode`         decimal(3,0) DEFAULT NULL,
  `acquirerId`                  varchar(11) NOT NULL DEFAULT '',
  `acquiringInstId`             varchar(11) DEFAULT NULL,
  `additionalDataPrivate`       varchar(255) DEFAULT NULL,
  `additionalRespData`          varchar(99) DEFAULT NULL,
  `amtCredits`                  char(16) DEFAULT NULL,
  `amtDebits`                   char(16) DEFAULT NULL,
  `bankId`                      char(11) NOT NULL DEFAULT '',
  `banknetRefNumber`            varchar(9) DEFAULT NULL,
  `businessDate`                char(8) DEFAULT NULL,
  `captureDate`                 char(4) DEFAULT NULL,
  `cardNumber`                  char(19) NOT NULL DEFAULT '',
  `tkcardNumber`                char(19) NOT NULL DEFAULT '',
  `cardTypeId`                  varchar(6) DEFAULT NULL,
  `currencyCode`                decimal(3,0) DEFAULT NULL,
  `discountAmt`                 decimal(12,0) DEFAULT NULL,
  `endDateTime`                 bigint NOT NULL DEFAULT '0',
  `expirationDate`              varchar(4) DEFAULT NULL,
  `issuerApplicationData`       varchar(64) DEFAULT NULL,
  `issuingIIC`                  varchar(14) DEFAULT NULL,
  `processingCode`              char(6) DEFAULT NULL,
  `retrievRefNumber`            varchar(12) DEFAULT NULL,
  `MTI`                         decimal(4,0) DEFAULT NULL,
  `memberPrivateData`           varchar(999) DEFAULT NULL,
  `networkData`                 varchar(49) DEFAULT NULL,
  `networkDataTraceID`          varchar(15) DEFAULT NULL,
  `originTransLocalDate`        char(4) DEFAULT NULL,
  `originTransLocalTime`        char(6) DEFAULT NULL,
  `requestedAmt`                decimal(12,0) DEFAULT NULL,
  `terminalId`                  varchar(16) DEFAULT NULL,
  `transDateTime`               varchar(20) DEFAULT NULL,
  `transLocalDate`              char(4) NOT NULL DEFAULT '',
  `transLocalTime`              char(6) NOT NULL DEFAULT '',
  PRIMARY KEY (`acqJnlSeqNumber`),
  KEY `TH_IDX` (`captureDate`),
  KEY `AC_IDX` (`transLocalDate`,`transLocalTime`,`retrievRefNumber`,`MTI`,`acquirerId`,`terminalId`),
  KEY `transDateTime` (`transDateTime`)
) ENGINE=InnoDB AUTO_INCREMENT=4691850412 DEFAULT CHARSET=latin1;

-- Verification queries
SELECT 'Setup completed successfully' AS Status;
SHOW DATABASES LIKE 'tokenise';
SHOW TABLES FROM tokenise;
SHOW GRANTS FOR 'tokenuser'@'%';