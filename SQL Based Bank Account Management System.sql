DROP DATABASE IF EXISTS BankDB;
CREATE DATABASE BankDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE BankDB;

-- Disabling foreign key checks to drop tables safely
SET FOREIGN_KEY_CHECKS = 0;

-- Drop existing procedure in dependency order
DROP PROCEDURE IF EXISTS sp_deposit;
DROP PROCEDURE IF EXISTS sp_withdraw;
DROP PROCEDURE IF EXISTS sp_transfer_funds;
DROP PROCEDURE IF EXISTS sp_add_customer_with_account;
DROP PROCEDURE IF EXISTS sp_credit_monthly_interest;
DROP PROCEDURE IF EXISTS sp_generate_monthly_statement;

DROP VIEW IF EXISTS V_Customers_Overdraft;
DROP VIEW IF EXISTS V_Account_UserCredentials;
DROP VIEW IF EXISTS V_AccountCounts_ByCustomer;
DROP VIEW IF EXISTS V_Customers_TotalBalance_GT5000;
DROP VIEW IF EXISTS V_Customers_Checking_ON;

-- Drop tables (order-insensitive because FK checks disabled)
DROP TABLE IF EXISTS RewardTransactions;
DROP TABLE IF EXISTS Rewards;
DROP TABLE IF EXISTS CustomerSupportTickets;
DROP TABLE IF EXISTS Notifications;
DROP TABLE IF EXISTS FailedTransactionLog;
DROP TABLE IF EXISTS TransactionSubType;
DROP TABLE IF EXISTS TransactionLog;
DROP TABLE IF EXISTS TransactionType;
DROP TABLE IF EXISTS OverDraftLog;
DROP TABLE IF EXISTS OverdraftPolicy;
DROP TABLE IF EXISTS DailyTransactionLimit;
DROP TABLE IF EXISTS EMI_Schedule;
DROP TABLE IF EXISTS Loan;
DROP TABLE IF EXISTS CreditCard;
DROP TABLE IF EXISTS Account;
DROP TABLE IF EXISTS AccountType;
DROP TABLE IF EXISTS AccountStatusType;
DROP TABLE IF EXISTS SavingsInterestRate;
DROP TABLE IF EXISTS LoginAccount;
DROP TABLE IF EXISTS UserSecurityAnswer;
DROP TABLE IF EXISTS UserSecurityQuestion;
DROP TABLE IF EXISTS UserLogin;
DROP TABLE IF EXISTS Employee;
DROP TABLE IF EXISTS CustomerAccount;
DROP TABLE IF EXISTS Phone;
DROP TABLE IF EXISTS Address;
DROP TABLE IF EXISTS Customer;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- Creating tables
CREATE TABLE AccountType (
  AccountTypeID INT PRIMARY KEY AUTO_INCREMENT,
  AccountTypeDescription VARCHAR(50) NOT NULL UNIQUE,
  Notes VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE AccountStatusType (
  AccountStatusTypeID INT PRIMARY KEY AUTO_INCREMENT,
  AccountStatusDescription VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE SavingsInterestRate (
  SavingsInterestRateID INT PRIMARY KEY AUTO_INCREMENT,
  InterestRate DECIMAL(6,4) NOT NULL,
  Description VARCHAR(100),
  CONSTRAINT chk_interest_range CHECK (InterestRate > 0 AND InterestRate < 1)
) ENGINE=InnoDB;

-- Employee table
CREATE TABLE Employee (
  EmployeeID INT PRIMARY KEY AUTO_INCREMENT,
  FirstName VARCHAR(60) NOT NULL,
  MiddleInitial CHAR(1),
  LastName VARCHAR(60) NOT NULL,
  IsManager BOOLEAN NOT NULL DEFAULT FALSE,
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Customer, addresses, phones (multiple addresses/phones per customer)
CREATE TABLE Customer (
  CustomerID INT PRIMARY KEY AUTO_INCREMENT,
  FirstName VARCHAR(60) NOT NULL,
  MiddleInitial CHAR(1),
  LastName VARCHAR(60) NOT NULL,
  DateOfBirth DATE,
  Nationality VARCHAR(60),
  KYCStatus ENUM('Pending','Verified','Rejected') NOT NULL DEFAULT 'Pending',
  Email VARCHAR(150),
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE Address (
  AddressID INT PRIMARY KEY AUTO_INCREMENT,
  CustomerID INT NOT NULL,
  AddressType ENUM('Home','Work','Other') NOT NULL DEFAULT 'Home',
  AddressLine1 VARCHAR(200) NOT NULL,
  AddressLine2 VARCHAR(200),
  City VARCHAR(100),
  Province VARCHAR(50),
  PostalCode VARCHAR(20),
  Country VARCHAR(50) DEFAULT 'Canada',
  IsPrimary BOOLEAN NOT NULL DEFAULT FALSE,
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_addr_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Phone (
  PhoneID INT PRIMARY KEY AUTO_INCREMENT,
  CustomerID INT NOT NULL,
  PhoneNumber VARCHAR(30) NOT NULL,
  PhoneType ENUM('Mobile','Home','Work','Other') NOT NULL DEFAULT 'Mobile',
  IsPrimary BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_phone_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Main account table (references lookup tables) with extended columns
CREATE TABLE Account (
  AccountID INT PRIMARY KEY AUTO_INCREMENT,
  CurrentBalance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  AccountTypeID INT NOT NULL,
  AccountStatusTypeID INT NOT NULL,
  SavingsInterestRateID INT NULL,
  AccountManagerID INT NULL,
  CurrencyCode CHAR(3) DEFAULT 'CAD',
  AccountOpenedDate DATE NOT NULL DEFAULT (CURRENT_DATE()),
  AccountClosedDate DATE NULL,
  AccountOpenReason VARCHAR(255),
  AccountCloseReason VARCHAR(255),
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_acct_type FOREIGN KEY (AccountTypeID) REFERENCES AccountType(AccountTypeID),
  CONSTRAINT fk_acct_status FOREIGN KEY (AccountStatusTypeID) REFERENCES AccountStatusType(AccountStatusTypeID),
  CONSTRAINT fk_acct_rate FOREIGN KEY (SavingsInterestRateID) REFERENCES SavingsInterestRate(SavingsInterestRateID),
  CONSTRAINT fk_acct_manager FOREIGN KEY (AccountManagerID) REFERENCES Employee(EmployeeID)
) ENGINE=InnoDB;

-- CustomerAccount becomes the junction with ownership percentage allowing joint accounts
CREATE TABLE CustomerAccount (
  CustomerID INT NOT NULL,
  AccountID INT NOT NULL,
  OwnershipPercentage DECIMAL(5,2) NOT NULL DEFAULT 100.00,
  OwnershipStartDate DATE NOT NULL DEFAULT (CURRENT_DATE()),
  PRIMARY KEY (CustomerID, AccountID),
  CONSTRAINT fk_ca_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE,
  CONSTRAINT fk_ca_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE CASCADE,
  CONSTRAINT chk_ownership_percentage CHECK (OwnershipPercentage > 0 AND OwnershipPercentage <= 100)
) ENGINE=InnoDB;



-- User/login tables
CREATE TABLE UserLogin (
  UserLoginID INT PRIMARY KEY AUTO_INCREMENT,
  Username VARCHAR(100) NOT NULL UNIQUE,
  PasswordSalt VARBINARY(32) NOT NULL,
  PasswordHash VARBINARY(64) NOT NULL,
  IsActive BOOLEAN NOT NULL DEFAULT TRUE,
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE LoginAccount (
  UserLoginID INT NOT NULL,
  AccountID INT NOT NULL,
  Role ENUM('Owner','Viewer','Teller','Manager','Admin') NOT NULL DEFAULT 'Owner',
  PRIMARY KEY (UserLoginID, AccountID),
  CONSTRAINT fk_la_user FOREIGN KEY (UserLoginID) REFERENCES UserLogin(UserLoginID) ON DELETE CASCADE,
  CONSTRAINT fk_la_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE UserSecurityQuestion (
  QuestionID INT PRIMARY KEY AUTO_INCREMENT,
  QuestionText VARCHAR(250) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE UserSecurityAnswer (
  AnswerID INT PRIMARY KEY AUTO_INCREMENT,
  UserLoginID INT NOT NULL,
  QuestionID INT NOT NULL,
  AnswerSalt VARBINARY(32) NOT NULL,
  AnswerHash VARBINARY(64) NOT NULL,
  CONSTRAINT fk_usa_user FOREIGN KEY (UserLoginID) REFERENCES UserLogin(UserLoginID) ON DELETE CASCADE,
  CONSTRAINT fk_usa_question FOREIGN KEY (QuestionID) REFERENCES UserSecurityQuestion(QuestionID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Transaction types and subtypes
CREATE TABLE TransactionType (
  TransactionTypeID INT PRIMARY KEY AUTO_INCREMENT,
  Name VARCHAR(50) NOT NULL UNIQUE,
  Description VARCHAR(250),
  Fee DECIMAL(12,2) DEFAULT 0.00
) ENGINE=InnoDB;

CREATE TABLE TransactionSubType (
  TransactionSubTypeID INT PRIMARY KEY AUTO_INCREMENT,
  TransactionTypeID INT NOT NULL,
  SubTypeName VARCHAR(80) NOT NULL,
  Description VARCHAR(255),
  CONSTRAINT fk_tsub_type FOREIGN KEY (TransactionTypeID) REFERENCES TransactionType(TransactionTypeID)
) ENGINE=InnoDB;

-- Overdraft Policy and limits
CREATE TABLE OverdraftPolicy (
  PolicyID INT PRIMARY KEY AUTO_INCREMENT,
  AccountTypeID INT NULL,
  MaxOverdraftAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  OverdraftFee DECIMAL(12,2) DEFAULT 0.00,
  CONSTRAINT fk_od_policy_accttype FOREIGN KEY (AccountTypeID) REFERENCES AccountType(AccountTypeID)
) ENGINE=InnoDB;

CREATE TABLE DailyTransactionLimit (
  LimitID INT PRIMARY KEY AUTO_INCREMENT,
  AccountID INT NULL,
  AccountTypeID INT NULL,
  MaxDailyWithdrawal DECIMAL(18,2) DEFAULT 0.00,
  MaxDailyTransfer DECIMAL(18,2) DEFAULT 0.00,
  CONSTRAINT fk_dtl_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE CASCADE,
  CONSTRAINT fk_dtl_accttype FOREIGN KEY (AccountTypeID) REFERENCES AccountType(AccountTypeID)
) ENGINE=InnoDB;


-- Transaction log (partitioned by YEAR(TransactionDate) for performance - adjust partitions for your deployment)
CREATE TABLE TransactionLog (
   TransactionID BIGINT PRIMARY KEY AUTO_INCREMENT,
   TransactionDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
   TransactionTypeID INT NOT NULL,
   TransactionSubTypeID INT NULL,
   Amount DECIMAL(18,2) NOT NULL,
   BalanceBefore DECIMAL(18,2) NOT NULL,
   BalanceAfter DECIMAL(18,2) NOT NULL,
   AccountID INT NOT NULL,
   CustomerID INT NULL,
   EmployeeID INT NULL,
   UserLoginID INT NULL,
   IsRecurring BOOLEAN NOT NULL DEFAULT FALSE,
   CurrencyCode CHAR(3) NOT NULL DEFAULT 'CAD',
   TransactionMetadata JSON NULL,
   Notes VARCHAR(500),
   Failed BOOLEAN NOT NULL DEFAULT FALSE,
   ErrorMessage VARCHAR(500),
   CONSTRAINT fk_tl_type FOREIGN KEY (TransactionTypeID) REFERENCES TransactionType(TransactionTypeID),
   CONSTRAINT fk_tl_subtype FOREIGN KEY (TransactionSubTypeID) REFERENCES TransactionSubType(TransactionSubTypeID),
   CONSTRAINT fk_tl_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID),
   CONSTRAINT fk_tl_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
   CONSTRAINT fk_tl_employee FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID),
   CONSTRAINT fk_tl_user FOREIGN KEY (UserLoginID) REFERENCES UserLogin(UserLoginID)
) ENGINE=InnoDB;


-- OverDraftLog (allow multiple overdraft events per account)
CREATE TABLE OverDraftLog (
  OverDraftLogID INT PRIMARY KEY AUTO_INCREMENT,
  AccountID INT NOT NULL,
  OverDraftDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  OverDraftAmount DECIMAL(18,2) NOT NULL,
  OverDraftTransactionJSON JSON,
  CONSTRAINT fk_od_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID)
) ENGINE=InnoDB;

-- Failed transaction log (structured for errors)
CREATE TABLE FailedTransactionLog (
  FailedLogID BIGINT PRIMARY KEY AUTO_INCREMENT,
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ProcedureName VARCHAR(128),
  Params JSON,
  ErrorMessage TEXT,
  ErrorCode VARCHAR(20)
) ENGINE=InnoDB;

-- Notifications table for alerts
CREATE TABLE Notifications (
  NotificationID BIGINT PRIMARY KEY AUTO_INCREMENT,
  CustomerID INT NULL,
  AccountID INT NULL,
  Type ENUM('LowBalance','LargeTransaction','KYC','Other') NOT NULL,
  Message VARCHAR(500) NOT NULL,
  IsRead BOOLEAN NOT NULL DEFAULT FALSE,
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notif_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE SET NULL,
  CONSTRAINT fk_notif_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Rewards and offers
CREATE TABLE Rewards (
  RewardID INT PRIMARY KEY AUTO_INCREMENT,
  CustomerID INT NOT NULL,
  Points INT NOT NULL DEFAULT 0,
  UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_rewards_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE RewardTransactions (
  RewardTxnID BIGINT PRIMARY KEY AUTO_INCREMENT,
  RewardID INT NOT NULL,
  TransactionID BIGINT NULL,
  PointsDelta INT NOT NULL,
  Reason VARCHAR(255),
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_rtxn_reward FOREIGN KEY (RewardID) REFERENCES Rewards(RewardID) ON DELETE CASCADE,
  CONSTRAINT fk_rtxn_txn FOREIGN KEY (TransactionID) REFERENCES TransactionLog(TransactionID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Customer support tickets
CREATE TABLE CustomerSupportTickets (
  TicketID BIGINT PRIMARY KEY AUTO_INCREMENT,
  CustomerID INT NOT NULL,
  AccountID INT NULL,
  CreatedByEmployeeID INT NULL,
  Subject VARCHAR(255),
  Description TEXT,
  Status ENUM('Open','InProgress','Resolved','Closed') NOT NULL DEFAULT 'Open',
  CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ClosedAt DATETIME NULL,
  CONSTRAINT fk_ticket_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE,
  CONSTRAINT fk_ticket_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE SET NULL,
  CONSTRAINT fk_ticket_employee FOREIGN KEY (CreatedByEmployeeID) REFERENCES Employee(EmployeeID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Loan, EMI schedule, credit card
CREATE TABLE Loan (
  LoanID BIGINT PRIMARY KEY AUTO_INCREMENT,
  AccountID INT NOT NULL,
  Principal DECIMAL(18,2) NOT NULL,
  InterestRate DECIMAL(6,4) NOT NULL,
  TermMonths INT NOT NULL,
  StartDate DATE NOT NULL,
  EndDate DATE NOT NULL,
  Status ENUM('Applied','Approved','Active','Closed','Defaulted') NOT NULL DEFAULT 'Applied',
  CONSTRAINT fk_loan_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID)
) ENGINE=InnoDB;

CREATE TABLE EMI_Schedule (
  EMIScheduleID BIGINT PRIMARY KEY AUTO_INCREMENT,
  LoanID BIGINT NOT NULL,
  DueDate DATE NOT NULL,
  PrincipalComponent DECIMAL(18,2),
  InterestComponent DECIMAL(18,2),
  TotalAmount DECIMAL(18,2),
  Paid BOOLEAN NOT NULL DEFAULT FALSE,
  PaidDate DATE NULL,
  CONSTRAINT fk_emi_loan FOREIGN KEY (LoanID) REFERENCES Loan(LoanID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE CreditCard (
  CreditCardID BIGINT PRIMARY KEY AUTO_INCREMENT,
  AccountID INT NOT NULL,
  CardNumber VARBINARY(16) NOT NULL, -- ideally tokenized/encrypted
  ExpiryMonth INT,
  ExpiryYear INT,
  CreditLimit DECIMAL(18,2) DEFAULT 0.00,
  AvailableCredit DECIMAL(18,2) DEFAULT 0.00,
  Status ENUM('Active','Blocked','Cancelled') DEFAULT 'Active',
  CONSTRAINT fk_cc_account FOREIGN KEY (AccountID) REFERENCES Account(AccountID)
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_account_type ON Account(AccountTypeID);
CREATE INDEX idx_account_status ON Account(AccountStatusTypeID);
CREATE INDEX idx_customer_email ON Customer(Email);
CREATE INDEX idx_userlogin_username ON UserLogin(Username);
CREATE INDEX idx_transaction_account_date ON TransactionLog(AccountID, TransactionDate);
CREATE INDEX idx_transaction_type ON TransactionLog(TransactionTypeID);
CREATE INDEX idx_transaction_customer ON TransactionLog(CustomerID);

-- Inserting lookup data (using INSERT IGNORE to avoid duplicate key errors on re-run)
INSERT IGNORE INTO AccountType (AccountTypeDescription, Notes) VALUES
('Checking','Standard transactional account'),
('Savings','Interest-bearing retail savings'),
('FixedDeposit','Term deposit with fixed tenure'),
('LoanAccount','Loan ledger account'),
('CreditCard','Revolving credit card');

INSERT IGNORE INTO AccountStatusType (AccountStatusDescription) VALUES ('Active'), ('Closed'), ('Dormant'), ('Frozen');

INSERT IGNORE INTO SavingsInterestRate (InterestRate, Description) VALUES
(0.0100, 'Basic'), (0.0250, 'Standard'), (0.0350, 'Premium'), (0.0050, 'Promo'), (0.0500, 'VIP');

INSERT IGNORE INTO TransactionType (Name, Description, Fee) VALUES
('Deposit','Deposit to account',0.00),
('Withdrawal','Cash withdrawal',0.00),
('Transfer','Account-to-account transfer',0.00),
('Interest','Interest credit',0.00),
('Fee','Service fee',2.50),
('LoanPayment','Loan EMI payment',0.00),
('CardPayment','Credit card payment',0.00);

-- Add some subtypes
INSERT IGNORE INTO TransactionSubType (TransactionTypeID, SubTypeName, Description)
SELECT * FROM (
  SELECT t.TransactionTypeID, 'ATM', 'ATM cash withdrawal'
  FROM TransactionType t WHERE t.Name = 'Withdrawal' LIMIT 1
) AS a
UNION ALL
SELECT * FROM (
  SELECT t.TransactionTypeID, 'Online', 'Online banking'
  FROM TransactionType t WHERE t.Name = 'Transfer' LIMIT 1
) AS b
UNION ALL
SELECT * FROM (
  SELECT t.TransactionTypeID, 'Cheque', 'Cheque payment'
  FROM TransactionType t WHERE t.Name = 'Withdrawal' LIMIT 1
) AS c
UNION ALL
SELECT * FROM (
  SELECT t.TransactionTypeID, 'POS', 'Point-of-sale payment'
  FROM TransactionType t WHERE t.Name = 'Withdrawal' LIMIT 1
) AS d;



-- Sample accounts & customers (5) - using the enhanced schema
INSERT INTO Customer (FirstName, MiddleInitial, LastName, DateOfBirth, Nationality, KYCStatus, Email)
VALUES
('Ravi','K','Sharma','1989-05-12','Indian','Verified','ravi.sharma@example.com'),
('Aisha','L','Singh','1992-09-03','Indian','Verified','aisha.singh@example.com'),
('Michael','T','Brown','1980-02-20','Canadian','Verified','m.brown@example.com'),
('Sara',NULL,'Lee','1995-07-15','Canadian','Verified','sara.lee@example.com'),
('Carlos','D','Garcia','1978-11-03','Canadian','Verified','carlos.g@example.com');

INSERT INTO Address (CustomerID, AddressType, AddressLine1, City, Province, PostalCode, Country, IsPrimary)
VALUES
(1,'Home','123 MG Road','Bangalore','Karnataka','560001','India',TRUE),
(2,'Home','55 Park Street','Kolkata','West Bengal','700016','India',TRUE),
(3,'Home','200 Anna Salai','Chennai','Tamil Nadu','600002','India',TRUE),
(4,'Home','78 Brigade Road','Bangalore','Karnataka','560025','India',TRUE),
(5,'Home','9 Connaught Place','Delhi','Delhi','110001','India',TRUE);

INSERT INTO Phone (CustomerID, PhoneNumber, PhoneType, IsPrimary)
VALUES
(1,'+91-9876543210','Mobile',TRUE),
(2,'+91-9123456789','Mobile',TRUE),
(3,'+91-9988776655','Mobile',TRUE),
(4,'+91-9567894321','Mobile',TRUE),
(5,'+91-9000123456','Mobile',TRUE);


-- Sample accounts
INSERT INTO Account (CurrentBalance, AccountTypeID, AccountStatusTypeID, SavingsInterestRateID, CurrencyCode)
VALUES
(4500.00, (SELECT AccountTypeID FROM AccountType WHERE AccountTypeDescription='Checking' LIMIT 1), (SELECT AccountStatusTypeID FROM AccountStatusType WHERE AccountStatusDescription='Active' LIMIT 1), NULL, 'CAD'),
(12000.50, (SELECT AccountTypeID FROM AccountType WHERE AccountTypeDescription='Savings' LIMIT 1), (SELECT AccountStatusTypeID FROM AccountStatusType WHERE AccountStatusDescription='Active' LIMIT 1), (SELECT SavingsInterestRateID FROM SavingsInterestRate WHERE Description='Standard' LIMIT 1), 'CAD'),
(300.00, (SELECT AccountTypeID FROM AccountType WHERE AccountTypeDescription='Checking' LIMIT 1), (SELECT AccountStatusTypeID FROM AccountStatusType WHERE AccountStatusDescription='Active' LIMIT 1), NULL, 'CAD'),
(8000.75, (SELECT AccountTypeID FROM AccountType WHERE AccountTypeDescription='Savings' LIMIT 1), (SELECT AccountStatusTypeID FROM AccountStatusType WHERE AccountStatusDescription='Active' LIMIT 1), (SELECT SavingsInterestRateID FROM SavingsInterestRate WHERE Description='Premium' LIMIT 1), 'CAD'),
(-150.00, (SELECT AccountTypeID FROM AccountType WHERE AccountTypeDescription='Checking' LIMIT 1), (SELECT AccountStatusTypeID FROM AccountStatusType WHERE AccountStatusDescription='Active' LIMIT 1), NULL, 'CAD');

-- Map some customers to accounts (ownership percentage supports joint accounts)
INSERT IGNORE INTO CustomerAccount (CustomerID, AccountID, OwnershipPercentage)
VALUES
(1, 1, 100.00),
(2, 2, 100.00),
(3, 3, 100.00),
(4, 4, 100.00),
(5, 5, 100.00);

-- Insert into Employee
INSERT INTO Employee (FirstName, MiddleInitial, LastName, IsManager) VALUES 
('Alice', 'M', 'Johnson', TRUE),
('Bob', NULL, 'Brown', FALSE),
('Carol', 'A', 'Davis', FALSE),
('David', 'J', 'Martinez', TRUE),
('Ella', NULL, 'Wilson', FALSE);

-- Insert into UserLogin (Note: PasswordSalt and PasswordHash are sample hex bytes)
INSERT INTO UserLogin (Username, PasswordSalt, PasswordHash) VALUES 
('user1', x'1234567890abcdef1234567890abcdef', x'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
('user2', x'abcdef1234567890abcdef1234567890', x'1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
('user3', x'11111111111111111111111111111111', x'2222222222222222222222222222222222222222222222222222222222222222'),
('user4', x'33333333333333333333333333333333', x'4444444444444444444444444444444444444444444444444444444444444444'),
('user5', x'55555555555555555555555555555555', x'6666666666666666666666666666666666666666666666666666666666666666');

-- Insert into LoginAccount
INSERT INTO LoginAccount (UserLoginID, AccountID, Role) VALUES 
(1, 1, 'Owner'),
(2, 2, 'Viewer'),
(3, 3, 'Teller'),
(4, 4, 'Manager'),
(5, 5, 'Admin');

-- Insert into UserSecurityQuestion
INSERT INTO UserSecurityQuestion (QuestionText) VALUES 
('What is your mother''s maiden name?'),
('What was the name of your first pet?'),
('What city were you born in?'),
('What is your favorite book?'),
('What was the model of your first car?');

-- Insert into UserSecurityAnswer (sample salts and hashes)
INSERT INTO UserSecurityAnswer (UserLoginID, QuestionID, AnswerSalt, AnswerHash) VALUES 
(1, 1, x'1234', x'5678'),
(2, 2, x'abcd', x'ef01'),
(3, 3, x'4321', x'8765'),
(4, 4, x'dcba', x'10fe'),
(5, 5, x'5678', x'1234');

-- Insert into TransactionLog 
INSERT INTO TransactionLog (TransactionTypeID, TransactionSubTypeID, Amount, BalanceBefore, BalanceAfter, AccountID, CustomerID, EmployeeID, UserLoginID, IsRecurring, CurrencyCode, Notes, Failed) VALUES 
(1, 1, 150.00, 1000.00, 1150.00, 1, 1, 1, 1, FALSE, 'CAD', 'Deposit', FALSE),
(2, 2, 50.00, 1150.00, 1100.00, 2, 2, 2, 2, FALSE, 'CAD', 'Withdrawal', FALSE),
(3, 3, 200.00, 1100.00, 900.00, 3, 3, 3, 3, TRUE, 'CAD', 'Bill Payment', FALSE),
(4, 4, 500.00, 900.00, 400.00, 4, 4, 4, 4, FALSE, 'CAD', 'Transfer', FALSE);
-- (5, 5, 100.00, 400.00, 500.00, 5, 5, 5, 5, FALSE, 'CAD', 'Refund', FALSE);

-- Insert into OverDraftLog
INSERT INTO OverDraftLog (AccountID, OverDraftAmount, OverDraftTransactionJSON) VALUES
(1, 100.00, '{"transaction":"TXN1001", "amount":100.00}'),
(2, 50.00, '{"transaction":"TXN1002", "amount":50.00}'),
(3, 200.00, '{"transaction":"TXN1003", "amount":200.00}'),
(4, 300.00, '{"transaction":"TXN1004", "amount":300.00}'),
(5, 400.00, '{"transaction":"TXN1005", "amount":400.00}');


-- Views (create or replace to allow re-run)
CREATE OR REPLACE VIEW V_Customers_Checking_ON AS
SELECT DISTINCT c.CustomerID, c.FirstName, c.LastName, a.CurrencyCode, addr.City, addr.Province, c.Email
FROM Customer c
JOIN CustomerAccount ca ON c.CustomerID = ca.CustomerID
JOIN Account a ON ca.AccountID = a.AccountID
JOIN AccountType t ON a.AccountTypeID = t.AccountTypeID
LEFT JOIN Address addr ON addr.CustomerID = c.CustomerID AND addr.IsPrimary = TRUE
WHERE t.AccountTypeDescription = 'Checking' AND addr.Province = 'ON';

CREATE OR REPLACE VIEW V_Customers_TotalBalance_GT5000 AS
SELECT c.CustomerID, c.FirstName, c.LastName,
       SUM(a.CurrentBalance + IFNULL(a.CurrentBalance * s.InterestRate, 0)) AS TotalWithInterest
FROM Customer c
JOIN CustomerAccount ca ON c.CustomerID = ca.CustomerID
JOIN Account a ON ca.AccountID = a.AccountID
LEFT JOIN SavingsInterestRate s ON a.SavingsInterestRateID = s.SavingsInterestRateID
GROUP BY c.CustomerID, c.FirstName, c.LastName
HAVING SUM(a.CurrentBalance + IFNULL(a.CurrentBalance * s.InterestRate, 0)) > 5000;

CREATE OR REPLACE VIEW V_AccountCounts_ByCustomer AS
SELECT c.CustomerID, c.FirstName, c.LastName,
       SUM(CASE WHEN t.AccountTypeDescription = 'Checking' THEN 1 ELSE 0 END) AS CheckingCount,
       SUM(CASE WHEN t.AccountTypeDescription = 'Savings' THEN 1 ELSE 0 END) AS SavingsCount,
       SUM(CASE WHEN t.AccountTypeDescription = 'FixedDeposit' THEN 1 ELSE 0 END) AS FixedDepositCount
FROM Customer c
JOIN CustomerAccount ca ON c.CustomerID = ca.CustomerID
JOIN Account a ON ca.AccountID = a.AccountID
JOIN AccountType t ON a.AccountTypeID = t.AccountTypeID
GROUP BY c.CustomerID, c.FirstName, c.LastName;

CREATE OR REPLACE VIEW V_Account_UserCredentials AS
SELECT a.AccountID,
       ul.UserLoginID,
       ul.Username,
       '****' AS PasswordMasked
FROM Account a
JOIN LoginAccount la ON a.AccountID = la.AccountID
JOIN UserLogin ul ON la.UserLoginID = ul.UserLoginID;

CREATE OR REPLACE VIEW V_Customers_Overdraft AS
SELECT c.CustomerID, c.FirstName, c.LastName, o.OverDraftAmount, o.OverDraftDate
FROM Customer c
JOIN CustomerAccount ca ON c.CustomerID = ca.CustomerID
JOIN OverDraftLog o ON ca.AccountID = o.AccountID;

-- Stored procedures: use delimiter for multi-statement bodies
DELIMITER $$


CREATE PROCEDURE insert_failed_log(IN p_procedure VARCHAR(128), IN p_params JSON, IN p_err TEXT, IN p_code VARCHAR(20))
BEGIN
  INSERT INTO FailedTransactionLog (ProcedureName, Params, ErrorMessage, ErrorCode)
  VALUES (p_procedure, p_params, p_err, p_code);
END$$

/*
  sp_deposit: deposit money into an account
  IN p_account_id, IN p_amount, IN p_userlogin_id
  Behavior:
    - Locks account row FOR UPDATE
    - Updates balance
    - Inserts TransactionLog row (TransactionType='Deposit')
    - Error handling logs to FailedTransactionLog
*/
CREATE PROCEDURE sp_deposit(
    IN p_account_id INT,
    IN p_amount DECIMAL(18,2),
    IN p_userlogin_id INT
)
BEGIN
    DECLARE v_balance_before DECIMAL(18,2);
    DECLARE v_balance_after DECIMAL(18,2);
    DECLARE v_ttype_id INT;
    DECLARE v_err TEXT DEFAULT NULL;
    DECLARE v_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT, v_code = MYSQL_ERRNO;
        CALL insert_failed_log(
            'sp_deposit',
            JSON_OBJECT('account', p_account_id, 'amount', p_amount, 'user', p_userlogin_id),
            v_err,
            v_code
        );
        ROLLBACK;
        SET v_msg = CONCAT('Deposit failed: ', v_err);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Deposit amount must be greater than zero';
    END IF;

    START TRANSACTION;
        SELECT CurrentBalance INTO v_balance_before
        FROM Account
        WHERE AccountID = p_account_id
        FOR UPDATE;

        IF v_balance_before IS NULL THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Account not found for deposit';
        END IF;

        SET v_balance_after = v_balance_before + p_amount;

        UPDATE Account
        SET CurrentBalance = v_balance_after
        WHERE AccountID = p_account_id;

        SELECT TransactionTypeID INTO v_ttype_id
        FROM TransactionType
        WHERE Name = 'Deposit'
        LIMIT 1;

        INSERT INTO TransactionLog (
            TransactionTypeID,
            Amount,
            BalanceBefore,
            BalanceAfter,
            AccountID,
            UserLoginID,
            Notes,
            CurrencyCode
        )
        VALUES (
            v_ttype_id,
            p_amount,
            v_balance_before,
            v_balance_after,
            p_account_id,
            p_userlogin_id,
            'Deposit',
            (SELECT CurrencyCode FROM Account WHERE AccountID = p_account_id)
        );
    COMMIT;
END;


/*
  sp_withdraw: withdraw money from an account with extra validation
  IN p_account_id, IN p_amount, IN p_userlogin_id
  - Check daily limits and overdraft policies
  - On failure, log to FailedTransactionLog
*/
CREATE PROCEDURE sp_withdraw(
    IN p_account_id INT,
    IN p_amount DECIMAL(18,2),
    IN p_userlogin_id INT
)
BEGIN
    DECLARE v_balance_before DECIMAL(18,2);
    DECLARE v_balance_after DECIMAL(18,2);
    DECLARE v_ttype_id INT;
    DECLARE v_max_daily_withdraw DECIMAL(18,2) DEFAULT NULL;
    DECLARE v_withdraw_today DECIMAL(18,2) DEFAULT 0.00;
    DECLARE v_policy_amt DECIMAL(18,2) DEFAULT 0.00;
    DECLARE v_err TEXT DEFAULT NULL;
    DECLARE v_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_msg TEXT;
    DECLARE v_acct_type INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT, v_code = MYSQL_ERRNO;
        CALL insert_failed_log(
            'sp_withdraw',
            JSON_OBJECT('account', p_account_id, 'amount', p_amount, 'user', p_userlogin_id),
            v_err,
            v_code
        );
        ROLLBACK;
        SET v_msg = CONCAT('Withdrawal failed: ', v_err);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Withdrawal amount must be greater than zero';
    END IF;

    START TRANSACTION;
        -- lock account
        SELECT CurrentBalance, AccountTypeID INTO v_balance_before, v_acct_type
        FROM Account
        WHERE AccountID = p_account_id
        FOR UPDATE;

        IF v_balance_before IS NULL THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Account not found for withdrawal';
        END IF;

        -- check daily withdrawal limit
        SELECT d.MaxDailyWithdrawal INTO v_max_daily_withdraw
        FROM DailyTransactionLimit d
        WHERE d.AccountID = p_account_id
        LIMIT 1;

        IF v_max_daily_withdraw IS NULL THEN
            SELECT d2.MaxDailyWithdrawal INTO v_max_daily_withdraw
            FROM DailyTransactionLimit d2
            WHERE d2.AccountTypeID = v_acct_type
            LIMIT 1;
        END IF;

        -- calculate today's withdrawn amount
        SELECT COALESCE(SUM(ABS(Amount)), 0.00) INTO v_withdraw_today
        FROM TransactionLog
        WHERE AccountID = p_account_id
          AND TransactionTypeID = (SELECT TransactionTypeID FROM TransactionType WHERE Name='Withdrawal' LIMIT 1)
          AND DATE(TransactionDate) = CURRENT_DATE();

        IF v_max_daily_withdraw IS NOT NULL AND (v_withdraw_today + p_amount) > v_max_daily_withdraw THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Daily withdrawal limit exceeded';
        END IF;

        -- Overdraft policy
        SELECT COALESCE(op.MaxOverdraftAmount, 0.00) INTO v_policy_amt
        FROM OverdraftPolicy op
        LEFT JOIN Account a ON a.AccountID = p_account_id
        WHERE op.AccountTypeID = a.AccountTypeID
        LIMIT 1;

        IF v_balance_before + v_policy_amt < p_amount THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient funds and overdraft limit reached';
        END IF;

        SET v_balance_after = v_balance_before - p_amount;

        UPDATE Account
        SET CurrentBalance = v_balance_after
        WHERE AccountID = p_account_id;

        SELECT TransactionTypeID INTO v_ttype_id
        FROM TransactionType
        WHERE Name = 'Withdrawal'
        LIMIT 1;

        INSERT INTO TransactionLog (
            TransactionTypeID,
            Amount,
            BalanceBefore,
            BalanceAfter,
            AccountID,
            UserLoginID,
            Notes,
            CurrencyCode
        )
        VALUES (
            v_ttype_id,
            -p_amount,
            v_balance_before,
            v_balance_after,
            p_account_id,
            p_userlogin_id,
            'Withdrawal',
            (SELECT CurrencyCode FROM Account WHERE AccountID = p_account_id)
        );

        -- If balance negative and overdraft used
        IF v_balance_after < 0 THEN
            INSERT INTO OverDraftLog (AccountID, OverDraftAmount, OverDraftTransactionJSON)
            VALUES (
                p_account_id,
                ABS(v_balance_after),
                JSON_OBJECT('by_user', p_userlogin_id, 'amount', p_amount, 'when', NOW())
            );
        END IF;
    COMMIT;
END$$


/*
  sp_transfer_funds: transfer between accounts atomically with error handling & daily limits
  IN p_from_account, IN p_to_account, IN p_amount, IN p_userlogin_id
*/
CREATE PROCEDURE sp_transfer_funds(
    IN p_from_account INT,
    IN p_to_account INT,
    IN p_amount DECIMAL(18,2),
    IN p_userlogin_id INT
)
BEGIN
    DECLARE v_balance_from DECIMAL(18,2);
    DECLARE v_balance_to DECIMAL(18,2);
    DECLARE v_new_from DECIMAL(18,2);
    DECLARE v_new_to DECIMAL(18,2);
    DECLARE v_t_transfer INT;
    DECLARE v_err TEXT DEFAULT NULL;
    DECLARE v_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_msg TEXT;
    DECLARE v_max_daily_transfer DECIMAL(18,2) DEFAULT NULL;
    DECLARE v_transfer_today DECIMAL(18,2) DEFAULT 0.00;
    DECLARE v_policy_amt DECIMAL(18,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT, v_code = MYSQL_ERRNO;
        CALL insert_failed_log(
            'sp_transfer_funds',
            JSON_OBJECT('from', p_from_account, 'to', p_to_account, 'amount', p_amount, 'user', p_userlogin_id),
            v_err,
            v_code
        );
        ROLLBACK;
        SET v_msg = CONCAT('Transfer failed: ', v_err);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transfer amount must be greater than zero';
    END IF;

    IF p_from_account = p_to_account THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot transfer to same account';
    END IF;

    START TRANSACTION;
        -- Lock rows in consistent order
        IF p_from_account < p_to_account THEN
            SELECT CurrentBalance INTO v_balance_from FROM Account WHERE AccountID = p_from_account FOR UPDATE;
            SELECT CurrentBalance INTO v_balance_to   FROM Account WHERE AccountID = p_to_account FOR UPDATE;
        ELSE
            SELECT CurrentBalance INTO v_balance_to   FROM Account WHERE AccountID = p_to_account FOR UPDATE;
            SELECT CurrentBalance INTO v_balance_from FROM Account WHERE AccountID = p_from_account FOR UPDATE;
        END IF;

        IF v_balance_from IS NULL OR v_balance_to IS NULL THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'One or both accounts not found for transfer';
        END IF;

        -- check daily transfer limit for source account
        SELECT d.MaxDailyTransfer INTO v_max_daily_transfer
        FROM DailyTransactionLimit d
        WHERE d.AccountID = p_from_account
        LIMIT 1;

        IF v_max_daily_transfer IS NULL THEN
            SELECT d2.MaxDailyTransfer INTO v_max_daily_transfer
            FROM DailyTransactionLimit d2
            JOIN Account a ON a.AccountTypeID = d2.AccountTypeID
            WHERE a.AccountID = p_from_account
            LIMIT 1;
        END IF;

        SELECT COALESCE(SUM(ABS(Amount)),0.00) INTO v_transfer_today
        FROM TransactionLog
        WHERE AccountID = p_from_account
          AND TransactionTypeID = (SELECT TransactionTypeID FROM TransactionType WHERE Name='Transfer' LIMIT 1)
          AND DATE(TransactionDate) = CURRENT_DATE();

        IF v_max_daily_transfer IS NOT NULL AND (v_transfer_today + p_amount) > v_max_daily_transfer THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Daily transfer limit exceeded for source account';
        END IF;

        -- check funds + overdraft
        SELECT COALESCE(op.MaxOverdraftAmount,0.00) INTO v_policy_amt
        FROM OverdraftPolicy op
        JOIN Account af ON af.AccountTypeID = op.AccountTypeID
        WHERE af.AccountID = p_from_account
        LIMIT 1;

        IF v_balance_from + v_policy_amt < p_amount THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds in source account';
        END IF;

        SET v_new_from = v_balance_from - p_amount;
        SET v_new_to   = v_balance_to + p_amount;

        UPDATE Account SET CurrentBalance = v_new_from WHERE AccountID = p_from_account;
        UPDATE Account SET CurrentBalance = v_new_to   WHERE AccountID = p_to_account;

        SELECT TransactionTypeID INTO v_t_transfer FROM TransactionType WHERE Name = 'Transfer' LIMIT 1;

        -- Log debit for from_account
        INSERT INTO TransactionLog (
            TransactionTypeID, Amount, BalanceBefore, BalanceAfter, AccountID, UserLoginID, Notes, CurrencyCode
        ) VALUES (
            v_t_transfer, -p_amount, v_balance_from, v_new_from, p_from_account, p_userlogin_id,
            CONCAT('Transfer to account ', p_to_account),
            (SELECT CurrencyCode FROM Account WHERE AccountID = p_from_account)
        );

        -- Log credit for to_account
        INSERT INTO TransactionLog (
            TransactionTypeID, Amount, BalanceBefore, BalanceAfter, AccountID, UserLoginID, Notes, CurrencyCode
        ) VALUES (
            v_t_transfer, p_amount, v_balance_to, v_new_to, p_to_account, p_userlogin_id,
            CONCAT('Transfer from account ', p_from_account),
            (SELECT CurrencyCode FROM Account WHERE AccountID = p_to_account)
        );

        -- If source account negative after transfer
        IF v_new_from < 0 THEN
            INSERT INTO OverDraftLog (AccountID, OverDraftAmount, OverDraftTransactionJSON)
            VALUES (
                p_from_account,
                ABS(v_new_from),
                JSON_OBJECT('by_user', p_userlogin_id, 'amount', p_amount, 'when', NOW())
            );
        END IF;
    COMMIT;
END$$

/*
  sp_add_customer_with_account:
    - Creates customer, account, link, initial deposit
    - Returns p_CustomerID and p_AccountID (OUT params)
    - Enhanced: accepts OwnershipPercentage for primary owner if provided (defaults 100)
*/
CREATE PROCEDURE sp_add_customer_with_account(
  IN p_FirstName VARCHAR(60),
  IN p_LastName VARCHAR(60),
  IN p_Email VARCHAR(150),
  IN p_Province VARCHAR(20),
  IN p_InitialDeposit DECIMAL(18,2),
  IN p_AccountTypeID INT,
  IN p_OwnershipPercentage DECIMAL(5,2),  -- removed DEFAULT here
  OUT p_CustomerID INT,
  OUT p_AccountID INT
)
BEGIN
  DECLARE v_account_status_active INT;
  DECLARE v_t_deposit INT;
  DECLARE v_balance_after DECIMAL(18,2);

  -- set default if parameter is NULL
  IF p_OwnershipPercentage IS NULL THEN
    SET p_OwnershipPercentage = 100.00;
  END IF;

  IF p_FirstName IS NULL OR p_LastName IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'First and Last name are required';
  END IF;

  START TRANSACTION;
    INSERT INTO Customer (FirstName, LastName, Email)
    VALUES (p_FirstName, p_LastName, p_Email);

    SET p_CustomerID = LAST_INSERT_ID();

    -- get Active status id
    SELECT AccountStatusTypeID INTO v_account_status_active
    FROM AccountStatusType
    WHERE AccountStatusDescription = 'Active'
    LIMIT 1;

    IF v_account_status_active IS NULL THEN
      SELECT AccountStatusTypeID INTO v_account_status_active FROM AccountStatusType LIMIT 1;
    END IF;

    INSERT INTO Account (CurrentBalance, AccountTypeID, AccountStatusTypeID)
    VALUES (0.00, p_AccountTypeID, v_account_status_active);

    SET p_AccountID = LAST_INSERT_ID();

    -- link customer to account with ownership percentage
    INSERT INTO CustomerAccount (CustomerID, AccountID, OwnershipPercentage)
    VALUES (p_CustomerID, p_AccountID, p_OwnershipPercentage);

    -- If initial deposit provided, perform deposit (manual insert and update)
    IF p_InitialDeposit IS NOT NULL AND p_InitialDeposit > 0 THEN
      SELECT CurrentBalance INTO v_balance_after FROM Account WHERE AccountID = p_AccountID FOR UPDATE;
      SET v_balance_after = v_balance_after + p_InitialDeposit;
      UPDATE Account SET CurrentBalance = v_balance_after WHERE AccountID = p_AccountID;

      SELECT TransactionTypeID INTO v_t_deposit FROM TransactionType WHERE Name = 'Deposit' LIMIT 1;

      INSERT INTO TransactionLog (TransactionTypeID, Amount, BalanceBefore, BalanceAfter, AccountID, CustomerID, Notes, CurrencyCode)
      VALUES (v_t_deposit, p_InitialDeposit, v_balance_after - p_InitialDeposit, v_balance_after, p_AccountID, p_CustomerID, 'Initial deposit', (SELECT CurrencyCode FROM Account WHERE AccountID = p_AccountID));
    END IF;

  COMMIT;
END$$


/*
  sp_credit_monthly_interest:
  - Scans savings accounts and credits interest monthly
  - PARAMETERS: p_process_date (DATE) - interest applied for month containing date
*/
CREATE PROCEDURE sp_credit_monthly_interest(IN p_process_date DATE)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_acct INT;
  DECLARE v_balance DECIMAL(18,2);
  DECLARE v_rate DECIMAL(6,4);
  DECLARE v_interest DECIMAL(18,4);
  DECLARE v_t_interest INT;

  DECLARE cur_accounts CURSOR FOR
    SELECT a.AccountID, a.CurrentBalance, s.InterestRate
    FROM Account a
    JOIN AccountType t ON a.AccountTypeID = t.AccountTypeID
    LEFT JOIN SavingsInterestRate s ON a.SavingsInterestRateID = s.SavingsInterestRateID
    WHERE t.AccountTypeDescription = 'Savings' AND a.AccountStatusTypeID = (SELECT AccountStatusTypeID FROM AccountStatusType WHERE AccountStatusDescription='Active' LIMIT 1);

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  SELECT TransactionTypeID INTO v_t_interest FROM TransactionType WHERE Name = 'Interest' LIMIT 1;

  OPEN cur_accounts;
  read_loop: LOOP
    FETCH cur_accounts INTO v_acct, v_balance, v_rate;
    IF done = 1 THEN
      LEAVE read_loop;
    END IF;

    IF v_rate IS NULL OR v_rate <= 0 THEN
      ITERATE read_loop;
    END IF;

    -- simple monthly interest = balance * (rate / 12)
    SET v_interest = ROUND(v_balance * (v_rate / 12), 2);

    IF v_interest <> 0 THEN
      UPDATE Account SET CurrentBalance = CurrentBalance + v_interest WHERE AccountID = v_acct;
      INSERT INTO TransactionLog (TransactionTypeID, Amount, BalanceBefore, BalanceAfter, AccountID, Notes, CurrencyCode)
      VALUES (v_t_interest, v_interest, v_balance, v_balance + v_interest, v_acct, CONCAT('Monthly interest for ', DATE_FORMAT(p_process_date, '%Y-%m')), (SELECT CurrencyCode FROM Account WHERE AccountID = v_acct));
    END IF;

  END LOOP;
  CLOSE cur_accounts;
END$$

/*
  sp_generate_monthly_statement:
  - IN p_account_id, IN p_year INT, IN p_month INT
  - Returns a resultset summarizing debits/credits and the transactions for that month
*/
CREATE PROCEDURE sp_generate_monthly_statement(IN p_account_id INT, IN p_year INT, IN p_month INT)
BEGIN
  -- header summary
  SELECT a.AccountID, a.CurrencyCode, a.CurrentBalance
  FROM Account a WHERE a.AccountID = p_account_id;

  -- summary totals
  SELECT
    SUM(CASE WHEN Amount < 0 THEN Amount ELSE 0 END) AS TotalDebits,
    SUM(CASE WHEN Amount > 0 THEN Amount ELSE 0 END) AS TotalCredits,
    COUNT(*) AS TransactionCount
  FROM TransactionLog
  WHERE AccountID = p_account_id
    AND YEAR(TransactionDate) = p_year
    AND MONTH(TransactionDate) = p_month;

  -- full transactions list
  SELECT TransactionID, TransactionDate, TransactionTypeID, TransactionSubTypeID, Amount, BalanceBefore, BalanceAfter, Notes, TransactionMetadata
  FROM TransactionLog
  WHERE AccountID = p_account_id
    AND YEAR(TransactionDate) = p_year
    AND MONTH(TransactionDate) = p_month
  ORDER BY TransactionDate ASC;
END$$

DELIMITER ;

-- Core selects for sanity checks
SELECT * FROM AccountType;
SELECT * FROM AccountStatusType;
SELECT * FROM SavingsInterestRate;
 SELECT * FROM Account;
SELECT * FROM Customer;
SELECT * FROM CustomerAccount;
SELECT * FROM Employee;
SELECT * FROM UserLogin;
SELECT * FROM LoginAccount;
SELECT * FROM UserSecurityQuestion;
SELECT * FROM UserSecurityAnswer;
SELECT * FROM TransactionType;
SELECT * FROM TransactionLog;
SELECT * FROM OverDraftLog;

-- Sample: create a simple overdraft policy and daily limits
INSERT IGNORE INTO OverdraftPolicy (AccountTypeID, MaxOverdraftAmount, OverdraftFee)
SELECT AccountTypeID, 500.00, 25.00 FROM AccountType WHERE AccountTypeDescription='Checking' LIMIT 1;

INSERT IGNORE INTO DailyTransactionLimit (AccountTypeID, MaxDailyWithdrawal, MaxDailyTransfer)
SELECT AccountTypeID, 2000.00, 5000.00 FROM AccountType WHERE AccountTypeDescription='Checking' LIMIT 1;

-- Create a rewards row for sample customer
INSERT IGNORE INTO Rewards (CustomerID, Points) VALUES (1, 100), (2, 150);

