/* Weekly Pharmacy Sales | 04 - Reporting layer */
USE WeeklySalesPharmacyDWH;
GO
CREATE OR ALTER VIEW dbo.vw_WeeklyPharmacySales
AS
SELECT
    p.PharmacyBisKey AS Pharmacy,
    d.FullDate AS WeekStart,
    DATEADD(DAY, 6, d.FullDate) AS WeekEnd,
    f.TotalOrders,
    f.TotalSales
FROM dbo.FactWeeklyPharmacySales AS f
JOIN dbo.DimPharmacy AS p ON p.PharmacyKey = f.PharmacyKey
JOIN dbo.DimDate AS d ON d.DateKey = f.WeekStartDateKey
WHERE p.TestFlag = 0;
GO
