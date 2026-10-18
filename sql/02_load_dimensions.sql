/* Weekly Pharmacy Sales | 02 - Dimension ETL */
USE WeeklySalesPharmacyDWH;
GO
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimDate
    @StartDate DATE = '2020-01-01',
    @EndDate DATE = '2030-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    IF @StartDate > @EndDate THROW 50001, 'Start date must not be after end date.', 1;
    DECLARE @Date DATE = @StartDate;
    WHILE @Date <= @EndDate
    BEGIN
        INSERT INTO dbo.DimDate
            (DateKey, FullDate, DayOfMonth, DayName, WeekOfYear,
             MonthNumber, MonthName, [Quarter], [Year], IsWeekend)
        SELECT CONVERT(INT, CONVERT(CHAR(8), @Date, 112)),
               @Date, DAY(@Date), DATENAME(WEEKDAY, @Date), DATEPART(ISO_WEEK, @Date),
               MONTH(@Date), DATENAME(MONTH, @Date), DATEPART(QUARTER, @Date), YEAR(@Date),
               CASE WHEN ((DATEDIFF(DAY, '19000106', @Date) % 7 + 7) % 7) IN (0, 6)
                    THEN 1 ELSE 0 END
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate WHERE FullDate = @Date);
        SET @Date = DATEADD(DAY, 1, @Date);
    END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPharmacy
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE d
           SET d.PharmacyBisKey = s.[Key], d.CreatedOn = s.CreatedOn, d.TestFlag = s.TestFlag
        FROM dbo.DimPharmacy AS d
        JOIN OnlinePharmacyDB.dbo.Pharmacies AS s ON d.PharmacyKey = s.Id
        WHERE d.PharmacyBisKey <> s.[Key]
           OR d.CreatedOn <> s.CreatedOn OR d.TestFlag <> s.TestFlag;

        INSERT dbo.DimPharmacy (PharmacyKey, PharmacyBisKey, CreatedOn, TestFlag)
        SELECT s.Id, s.[Key], s.CreatedOn, s.TestFlag
        FROM OnlinePharmacyDB.dbo.Pharmacies AS s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DimPharmacy AS d WHERE d.PharmacyKey = s.Id);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimOrderStatus
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE d
           SET d.OrderStateTypeId = s.OrderStateTypeId, d.StateName = s.StateName
        FROM dbo.DimOrderStatus AS d
        JOIN OnlinePharmacyDB.dbo.OrderStateTypes AS s ON d.OrderStatusKey = s.Id
        WHERE d.OrderStateTypeId <> s.OrderStateTypeId OR d.StateName <> s.StateName;

        INSERT dbo.DimOrderStatus (OrderStatusKey, OrderStateTypeId, StateName)
        SELECT s.Id, s.OrderStateTypeId, s.StateName
        FROM OnlinePharmacyDB.dbo.OrderStateTypes AS s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DimOrderStatus AS d WHERE d.OrderStatusKey = s.Id);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
