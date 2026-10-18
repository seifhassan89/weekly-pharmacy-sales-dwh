/* Weekly Pharmacy Sales | 01 - Schema
   Run in SSMS or sqlcmd. Requires access to OnlinePharmacyDB on the same server.
*/
IF DB_ID(N'WeeklySalesPharmacyDWH') IS NULL
    CREATE DATABASE WeeklySalesPharmacyDWH;
GO
USE WeeklySalesPharmacyDWH;
GO
IF OBJECT_ID(N'dbo.DimDate', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDate (
        DateKey INT NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
        FullDate DATE NOT NULL CONSTRAINT UQ_DimDate_FullDate UNIQUE,
        DayOfMonth TINYINT NOT NULL,
        DayName NVARCHAR(20) NOT NULL,
        WeekOfYear TINYINT NOT NULL,
        MonthNumber TINYINT NOT NULL,
        MonthName NVARCHAR(20) NOT NULL,
        [Quarter] TINYINT NOT NULL,
        [Year] SMALLINT NOT NULL,
        IsWeekend BIT NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.DimPharmacy', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimPharmacy (
        PharmacyKey INT NOT NULL CONSTRAINT PK_DimPharmacy PRIMARY KEY,
        PharmacyBisKey NVARCHAR(200) NOT NULL CONSTRAINT UQ_DimPharmacy_BusinessKey UNIQUE,
        CreatedOn DATETIME NOT NULL,
        TestFlag BIT NOT NULL CONSTRAINT DF_DimPharmacy_TestFlag DEFAULT (0)
    );
END;
GO
IF OBJECT_ID(N'dbo.DimOrderStatus', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimOrderStatus (
        OrderStatusKey INT NOT NULL CONSTRAINT PK_DimOrderStatus PRIMARY KEY,
        OrderStateTypeId INT NOT NULL CONSTRAINT UQ_DimOrderStatus_TypeId UNIQUE,
        StateName NVARCHAR(200) NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.FactWeeklyPharmacySales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactWeeklyPharmacySales (
        WeekStartDateKey INT NOT NULL,
        PharmacyKey INT NOT NULL,
        TotalOrders INT NOT NULL,
        TotalSales DECIMAL(38,2) NOT NULL,
        CONSTRAINT PK_FactWeeklyPharmacySales PRIMARY KEY (WeekStartDateKey, PharmacyKey),
        CONSTRAINT FK_FactWeeklyPharmacySales_Date FOREIGN KEY (WeekStartDateKey) REFERENCES dbo.DimDate(DateKey),
        CONSTRAINT FK_FactWeeklyPharmacySales_Pharmacy FOREIGN KEY (PharmacyKey) REFERENCES dbo.DimPharmacy(PharmacyKey),
        CONSTRAINT CK_FactWeeklyPharmacySales_TotalOrders CHECK (TotalOrders >= 0)
    );
END;
GO
