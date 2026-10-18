/*
  OPTIONAL DEMO ONLY — run on a disposable SQL Server instance.
  The warehouse ETL expects a source database named OnlinePharmacyDB.
  Safety: abort if that database already exists; never modify real source data.
*/
USE master;
GO
IF DB_ID(N'OnlinePharmacyDB') IS NOT NULL
    THROW 52000, 'OnlinePharmacyDB already exists. STOP: use a fresh disposable SQL Server instance for this demo.', 1;
GO
CREATE DATABASE OnlinePharmacyDB;
GO
USE OnlinePharmacyDB;
GO
EXEC sys.sp_addextendedproperty
    @name=N'WeeklyPharmacyDemoOnly', @value=N'Synthetic training data - safe to test';
GO
CREATE TABLE dbo.Pharmacies (
    Id INT NOT NULL PRIMARY KEY,
    [Key] NVARCHAR(200) NOT NULL UNIQUE,
    CreatedOn DATETIME NOT NULL,
    TestFlag BIT NOT NULL
);
CREATE TABLE dbo.OrderStateTypes (
    Id INT NOT NULL PRIMARY KEY,
    OrderStateTypeId INT NOT NULL UNIQUE,
    StateName NVARCHAR(200) NOT NULL
);
CREATE TABLE dbo.Orders (
    Id INT NOT NULL PRIMARY KEY,
    PharmacyKey NVARCHAR(200) NOT NULL,
    OrderStateTypeId INT NOT NULL,
    CreatedOn DATETIME NOT NULL,
    CONSTRAINT FK_Demo_Orders_Pharmacy FOREIGN KEY (PharmacyKey) REFERENCES dbo.Pharmacies([Key]),
    CONSTRAINT FK_Demo_Orders_Status FOREIGN KEY (OrderStateTypeId) REFERENCES dbo.OrderStateTypes(OrderStateTypeId)
);
CREATE TABLE dbo.OrderItems (
    Id INT NOT NULL PRIMARY KEY,
    OrderId INT NOT NULL,
    Price DECIMAL(18,2) NOT NULL,
    Quantity INT NOT NULL,
    CONSTRAINT FK_Demo_OrderItems_Order FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id)
);
GO
INSERT dbo.Pharmacies (Id, [Key], CreatedOn, TestFlag) VALUES
(101, N'PHARMACY-A', '2024-01-01', 0),
(102, N'PHARMACY-B', '2024-01-01', 0),
(103, N'PHARMACY-TEST', '2024-01-01', 1);
INSERT dbo.OrderStateTypes (Id, OrderStateTypeId, StateName) VALUES
(1, 10, N'Created'), (2, 20, N'Delivered'), (3, 30, N'Canceled');
INSERT dbo.Orders (Id, PharmacyKey, OrderStateTypeId, CreatedOn) VALUES
(1001, N'PHARMACY-A', 20, '2024-03-04T09:00:00'),
(1002, N'PHARMACY-A', 20, '2024-03-06T12:00:00'),
(1003, N'PHARMACY-B', 20, '2024-03-08T10:00:00'),
(1004, N'PHARMACY-A', 20, '2024-03-11T08:00:00'),
(1005, N'PHARMACY-A', 30, '2024-03-05T15:00:00'),
(1006, N'PHARMACY-B', 20, '2024-03-12T11:00:00'),
(1007, N'PHARMACY-TEST', 20, '2024-03-04T11:00:00');
INSERT dbo.OrderItems (Id, OrderId, Price, Quantity) VALUES
(1, 1001, 100.00, 2), (2, 1001, 50.00, 1), -- one order: 250.00
(3, 1002, 75.00, 1),                          -- pharmacy A, week 1: 325.00 / 2 orders
(4, 1003, 40.00, 3),                          -- pharmacy B, week 1: 120.00 / 1 order
(5, 1004, 10.00, 2),                          -- pharmacy A, week 2: 20.00 / 1 order
(6, 1005, 999.00, 1),                         -- canceled: excluded
(7, 1006, 60.00, 1),                          -- pharmacy B, week 2: 60.00 / 1 order
(8, 1007, 5.00, 1);                           -- test pharmacy: loaded but hidden by view
GO
PRINT 'Sample operational database created. Now run sql/01_schema.sql through sql/05_run_etl.sql.';
GO
