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
  `additionalAmt`               varchar(15) DEFAULT NULL,
  `additionalDataPrivate`       varchar(255) DEFAULT NULL,
  `additionalRespData`          varchar(99) DEFAULT NULL,
  `AECalcData`                  char(6) DEFAULT NULL,
  `AIP`                         char(4) DEFAULT NULL,
  `amtCredits`                  char(16) DEFAULT NULL,
  `amtDebits`                   char(16) DEFAULT NULL,
  `applicationCryptogram`       varchar(16) DEFAULT NULL,
  `applicationId`               varchar(32) DEFAULT NULL,
  `ATC`                         char(4) DEFAULT NULL,
  `auditNumber`                 decimal(6,0) DEFAULT NULL,
  `authenticationElement`       varchar(8) DEFAULT NULL,
  `authId`                      varchar(8) DEFAULT NULL,
  `authNumberLen`               char(1) DEFAULT NULL,
  `B24AdditionalData`           varchar(1024) DEFAULT NULL,
  `B24AuthorizationId`          varchar(23) DEFAULT NULL,
  `B24BatchShiftData`           varchar(12) DEFAULT NULL,
  `B24CardIssuerRespData`       varchar(22) DEFAULT NULL,
  `B24DepositCreditAmt`         varchar(27) DEFAULT NULL,
  `B24DepositoryType`           varchar(4) DEFAULT NULL,
  `B24InvoiceData`              varchar(23) DEFAULT NULL,
  `B24OriginatorCode`           char(1) DEFAULT NULL,
  `B24PINOffset`                varchar(19) DEFAULT NULL,
  `B24PreauthChargeback`        varchar(41) DEFAULT NULL,
  `B24ProductIndicator`         char(2) DEFAULT NULL,
  `B24ReleaseNumber`            char(2) DEFAULT NULL,
  `B24ResponderCode`            char(1) DEFAULT NULL,
  `B24SettlementData`           varchar(15) DEFAULT NULL,
  `B24Status`                   char(3) DEFAULT NULL,
  `B24TerminalData`             varchar(19) DEFAULT NULL,
  `bankId`                      char(11) NOT NULL DEFAULT '',
  `BICISOMsgId`                 char(4) DEFAULT NULL,
  `businessDate`                char(8) DEFAULT NULL,
  `captureDate`                 char(4) DEFAULT NULL,
  `captureDateOrigin`           varchar(14) DEFAULT NULL,
  `captureinitiator`            varchar(12) DEFAULT NULL,
  `cardAcceptorId`              varchar(15) DEFAULT NULL,
  `cardAcceptorNameLoc`         varchar(40) DEFAULT NULL,
  `cardAppliType`               char(1) DEFAULT NULL,
  `cardNumber`                  char(19) NOT NULL DEFAULT '',
  `cardTypeId`                  varchar(6) DEFAULT NULL,
  `chipProcessingResult`        decimal(2,0) DEFAULT NULL,
  `currencyCode`                decimal(3,0) DEFAULT NULL,
  `CVMResults`                  varchar(6) DEFAULT NULL,
  `endDateTime`                 bigint NOT NULL DEFAULT '0',
  `expirationDate`              varchar(4) DEFAULT NULL,
  `issuerApplicationData`       varchar(64) DEFAULT NULL,
  `issuingIIC`                  varchar(14) DEFAULT NULL,
  `MCC`                         decimal(4,0) DEFAULT NULL,
  `MTI`                         decimal(4,0) DEFAULT NULL,
  `netSettlementAmt`            char(17) DEFAULT NULL,
  `networkManageCode`           char(3) DEFAULT NULL,
  `numberAuthorizations`        char(10) DEFAULT NULL,
  `numberCredits`               char(10) DEFAULT NULL,
  `numberDebits`                char(10) DEFAULT NULL,
  `numberInquiries`             char(10) DEFAULT NULL,
  `numberTransfer`              char(10) DEFAULT NULL,
  `operationType`               char(3) NOT NULL DEFAULT '',
  `originalDataElements`        char(42) DEFAULT NULL,
  `originId`                    varchar(11) DEFAULT NULL,
  `originMTI`                   decimal(4,0) DEFAULT NULL,
  `originTransLocalDate`        char(4) DEFAULT NULL,
  `originTransLocalTime`        char(6) DEFAULT NULL,
  `POSConditionCode`            char(2) DEFAULT NULL,
  `POSEntryMode`                decimal(3,0) DEFAULT NULL,
  `processingCode`              char(6) DEFAULT NULL,
  `reachedSiteName`             varchar(12) DEFAULT NULL,
  `receivingIIC`                varchar(24) DEFAULT NULL,
  `replacementAmt`              char(42) DEFAULT NULL,
  `requesterAppliId`            varchar(40) DEFAULT NULL,
  `responseCode`                char(6) DEFAULT NULL,
  `resultCode`                  int DEFAULT NULL,
  `resultVector`                varchar(75) DEFAULT NULL,
  `retrievRefNumber`            varchar(12) DEFAULT NULL,
  `retrievRefNumberOrigin`      varchar(12) DEFAULT NULL,
  `reversalAmtCredits`          char(16) DEFAULT NULL,
  `reversalAmtDebits`           char(16) DEFAULT NULL,
  `reversalNumberCredits`       char(10) DEFAULT NULL,
  `reversalNumberDebits`        char(10) DEFAULT NULL,
  `reversalNumberTransfer`      char(10) DEFAULT NULL,
  `RTCBeneficiaryBranchCode`    decimal(6,0) DEFAULT NULL,
  `securityInformation`         varchar(96) DEFAULT NULL,
  `sequencePAN`                 char(3) DEFAULT NULL,
  `serverAppliId`               varchar(40) DEFAULT NULL,
  `settleCurrencyCode`          char(3) DEFAULT NULL,
  `settlementCode`              char(1) DEFAULT NULL,
  `settlementDate`              char(4) DEFAULT NULL,
  `settlementIIC`               varchar(11) DEFAULT NULL,
  `standinInd`                  char(1) DEFAULT NULL,
  `startDateTime`               bigint NOT NULL DEFAULT '0',
  `terminalCapabilities`        varchar(6) DEFAULT NULL,
  `terminalCountryCode`         decimal(3,0) DEFAULT NULL,
  `terminalId`                  varchar(16) DEFAULT NULL,
  `terminalTransDate`           varchar(6) DEFAULT NULL,
  `transactionAmt`              decimal(12,0) DEFAULT NULL,
  `transactionType`             decimal(2,0) DEFAULT NULL,
  `transCurrencyCode`           decimal(3,0) DEFAULT NULL,
  `transDateTime`               varchar(20) DEFAULT NULL,
  `transLocalDate`              char(4) NOT NULL DEFAULT '',
  `transLocalTime`              char(6) NOT NULL DEFAULT '',
  `transmitDateTime`            varchar(20) DEFAULT NULL,
  `transOrigin`                 char(1) DEFAULT NULL,
  `transRefNumber`              varchar(20) DEFAULT NULL,
  `TVR`                         char(10) DEFAULT NULL,
  `unpredictableNumber`         varchar(8) DEFAULT NULL,
  `adviceResponseCode`          char(2) DEFAULT NULL,
  `mainDest`                    varchar(11) DEFAULT NULL,
  `serviceCode`                 char(3) DEFAULT NULL,
  `forwardingInstId`            varchar(11) DEFAULT NULL,
  `msgId`                       char(4) DEFAULT NULL,
  `networkData`                 varchar(49) DEFAULT NULL,
  `availableBalance`            varchar(12) DEFAULT NULL,
  `dueAmount`                   varchar(12) DEFAULT NULL,
  `ledgerBalance`               varchar(12) DEFAULT NULL,
  `visaCpsAtmTi`                varchar(16) DEFAULT NULL,
  `reversalInd`                 varchar(1) DEFAULT NULL,
  `UPIPINEntryMode`             varchar(1) DEFAULT NULL,
  `BICISOPOSEntryMode`          decimal(4,0) DEFAULT NULL,
  `transactionFeeAmt`           varchar(9) DEFAULT NULL,
  `requestedAmt`                decimal(12,0) DEFAULT NULL,
  `MCAdditionalMerchantData`    varchar(49) DEFAULT NULL,
  `MCAssignedID`                varchar(9) DEFAULT NULL,
  `MCProductId`                 varchar(3) DEFAULT NULL,
  `addressVerifRequest`         varchar(2) DEFAULT NULL,
  `banknetRefNumber`            varchar(9) DEFAULT NULL,
  `elecCommIndicators`          varchar(7) DEFAULT NULL,
  `networkDataTraceID`          varchar(15) DEFAULT NULL,
  `paymentInitiationChannel`    varchar(2) DEFAULT NULL,
  `discountAmt`                 decimal(12,0) DEFAULT NULL,
  `discountDesc`                varchar(20) DEFAULT NULL,
  `discountPaymentDesc`         varchar(20) DEFAULT NULL,
  `memberPrivateData`           varchar(999) DEFAULT NULL,
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