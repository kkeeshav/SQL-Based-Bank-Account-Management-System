# SQL-Based Bank Account Management System

A comprehensive MySQL-based application for managing bank customer accounts, transactions, and core operations using robust stored procedures and normalized database design

## Project Overview

This system simulates a modern banking backend with secure, atomic management of customer accounts. Features include deposits, withdrawals, transfer operations, detailed logging, error handling, and built-in reporting through SQL views and stored procedures. ACID properties are rigorously enforced to ensure data integrity and reliability.

## Objectives

Automate and centralize core banking operations with SQL stored procedures for deposit, withdrawal, and fund transfer.
Maintain accurate, real-time account balances using transaction blocks and locking mechanisms.
Ensure security via salted password hashing and secure authentication table structures.
Provide audit trails for all financial and admin operations, supporting regulatory compliance.
Empower administrators to define rules for overdraft and daily limits at a per-account or type level.

## Features

Highly normalized schema supporting joint accounts, employee roles, credit/debit cards, loans, EMI schedules, notifications, and customer support tickets.
Secure authentication with salted hashes and multi-factor questions.
Error-proof operations with centralized logging and robust exception handling.
Pre-built views for live reporting and compliance.

## System Components

**Entity Tables:** Customer, Account, Employee.
**Junction Tables:** CustomerAccount for joint ownership.
**Lookup Tables:** AccountType, AccountStatusType, TransactionType.
**Security Tables:** UserLogin, UserSecurityQuestion, UserSecurityAnswer.
**Operational Tables:** TransactionLog, OverDraftLog, FailedTransactionLog.
**Policy Tables:** OverdraftPolicy, DailyTransactionLimit.
**Other:** CreditCard, Loan, Rewards, Notifications, CustomerSupportTickets.

## Installation

1. Install a MySQL server (version 8+ recommended).
2. Run the SQL script SQL-Based-Bank-Account-Management-System.sql to set up the full schema, including all tables, views, and sample data.
3. Populate initial records or use included sample data for testing.

## Usage

Invoke stored procedures for secure, validated banking operations:

**Add Customer and Account:** sp_add_customer_with_account (creates customer, primary account, links ownership, accepts initial deposit).
**Deposit Funds:** sp_deposit (ensures atomic update and logs transaction).
**Withdraw Funds:** sp_withdraw (validates overdraft and daily limits, logs transaction, records overdraft events if applicable).
**Transfer Funds:** sp_transfer_funds (atomic transfer between accounts, checks limits and sufficiency).

Predefined SQL views provide real-time reporting, such as overdraft lists, customer balances above thresholds, and account summary counts.

## Inputs/Outputs

**Inputs:**

Customer, account-opening details, transaction parameters, security/authentication credentials, administrative rule updates.

**Outputs:**

Data records, updated balances, audit logs, error messages on failed operations, reporting statements via views or monthly statement procedure.

## Error Handling & Logging

Every stored procedure includes robust validation and try-catch blocks, logging errors and input parameters to the FailedTransactionLog for future diagnostics and auditing.
Success and failure logs help resolve customer disputes and regulatory investigations efficiently.

## Extensibility

Potential future enhancements include:

REST API layer for integration with UIs/mobile apps.
Role-Based Access Control (RBAC) for secure privilege management.
Automated audits using database triggers to monitor sensitive changes.

## Authors
Chandra Shekhar
Keshav Yadav
