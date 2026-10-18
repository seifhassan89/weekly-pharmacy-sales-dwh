/* Weekly Pharmacy Sales | 03 - Fact ETL
   Grain: one row per pharmacy per Monday-starting week.
   Metric: SUM(OrderItems.Price * Quantity) for orders currently Delivered.
   Time basis: Orders.CreatedOn (NOT actual delivery date).
   Full refresh of derived pharmacy-week rows; stale rows are removed.
*/
USE WeeklySalesPharmacyDWH;
GO
CREATE OR ALTER PROCEDURE dbo.usp_Load_FactWeeklyPharmacySales
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Refuse an incomplete lookup rather than silently dropping sales rows.
    IF EXISTS (
        SELECT 1 FROM OnlinePharmacyDB.dbo.Orders AS o
        JOIN OnlinePharmacyDB.dbo.OrderItems AS oi ON oi.OrderId = o.Id
        LEFT JOIN dbo.DimOrderStatus AS s ON s.OrderStateTypeId = o.OrderStateTypeId
        WHERE s.OrderStateTypeId IS NULL
    ) THROW 50010, 'Order status dimension is missing a source order status.', 1;

    IF EXISTS (
        SELECT 1 FROM OnlinePharmacyDB.dbo.Orders AS o
        JOIN OnlinePharmacyDB.dbo.OrderItems AS oi ON oi.OrderId = o.Id
        JOIN dbo.DimOrderStatus AS s ON s.OrderStateTypeId = o.OrderStateTypeId
        LEFT JOIN dbo.DimPharmacy AS p ON p.PharmacyBisKey = o.PharmacyKey
        WHERE s.StateName = N'Delivered' AND p.PharmacyKey IS NULL
    ) THROW 50011, 'Pharmacy dimension is missing a delivered order pharmacy.', 1;

    IF EXISTS (
        SELECT 1 FROM OnlinePharmacyDB.dbo.Orders AS o
        JOIN OnlinePharmacyDB.dbo.OrderItems AS oi ON oi.OrderId = o.Id
        JOIN dbo.DimOrderStatus AS s ON s.OrderStateTypeId = o.OrderStateTypeId
        LEFT JOIN dbo.DimDate AS d
          ON d.FullDate = DATEADD(DAY, -((DATEDIFF(DAY, '19000101', CAST(o.CreatedOn AS DATE)) % 7 + 7) % 7), CAST(o.CreatedOn AS DATE))
        WHERE s.StateName = N'Delivered' AND d.DateKey IS NULL
    ) THROW 50012, 'Date dimension is missing a delivered order week start.', 1;

    -- Stage exactly one row per (pharmacy, week) before updating the fact.
    SELECT
        d.DateKey AS WeekStartDateKey,
        p.PharmacyKey,
        COUNT(DISTINCT o.Id) AS TotalOrders,
        CAST(SUM(CAST(oi.Price AS DECIMAL(28,4)) * CAST(oi.Quantity AS DECIMAL(18,4))) AS DECIMAL(38,2)) AS TotalSales
    INTO #WeeklySales
    FROM OnlinePharmacyDB.dbo.Orders AS o
    JOIN OnlinePharmacyDB.dbo.OrderItems AS oi ON oi.OrderId = o.Id
    JOIN dbo.DimOrderStatus AS s ON s.OrderStateTypeId = o.OrderStateTypeId
    JOIN dbo.DimPharmacy AS p ON p.PharmacyBisKey = o.PharmacyKey
    JOIN dbo.DimDate AS d
      ON d.FullDate = DATEADD(DAY, -((DATEDIFF(DAY, '19000101', CAST(o.CreatedOn AS DATE)) % 7 + 7) % 7), CAST(o.CreatedOn AS DATE))
    WHERE s.StateName = N'Delivered'
    GROUP BY d.DateKey, p.PharmacyKey;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE f
           SET f.TotalSales = w.TotalSales,
               f.TotalOrders = w.TotalOrders
        FROM dbo.FactWeeklyPharmacySales AS f
        JOIN #WeeklySales AS w ON w.WeekStartDateKey = f.WeekStartDateKey
                              AND w.PharmacyKey = f.PharmacyKey
        WHERE f.TotalSales <> w.TotalSales OR f.TotalOrders <> w.TotalOrders;

        INSERT dbo.FactWeeklyPharmacySales (WeekStartDateKey, PharmacyKey, TotalOrders, TotalSales)
        SELECT w.WeekStartDateKey, w.PharmacyKey, w.TotalOrders, w.TotalSales
        FROM #WeeklySales AS w
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.FactWeeklyPharmacySales AS f WITH (UPDLOCK, HOLDLOCK)
            WHERE f.WeekStartDateKey = w.WeekStartDateKey AND f.PharmacyKey = w.PharmacyKey
        );

        -- Remove pharmacy-weeks that no longer contain any qualifying Delivered orders.
        DELETE f
        FROM dbo.FactWeeklyPharmacySales AS f
        WHERE NOT EXISTS (
            SELECT 1 FROM #WeeklySales AS w
            WHERE w.WeekStartDateKey = f.WeekStartDateKey AND w.PharmacyKey = f.PharmacyKey
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
