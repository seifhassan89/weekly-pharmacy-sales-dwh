/* Read-only SQL data quality checks. Run AFTER 05_run_etl.sql. */
USE WeeklySalesPharmacyDWH;
GO
-- 1: No duplicated pharmacy/week combinations (also enforced by PK).
IF EXISTS (
    SELECT 1 FROM dbo.FactWeeklyPharmacySales
    GROUP BY PharmacyKey, WeekStartDateKey HAVING COUNT(*) > 1
) THROW 51001, 'Duplicate pharmacy-week detected.', 1;

-- 2: Fact references resolve to a Monday date.
IF EXISTS (
    SELECT 1 FROM dbo.FactWeeklyPharmacySales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.WeekStartDateKey
    WHERE ((DATEDIFF(DAY, '19000101', d.FullDate) % 7 + 7) % 7) <> 0
) THROW 51002, 'Fact week start is not a Monday.', 1;

-- 3: No negative order counts.
IF EXISTS (SELECT 1 FROM dbo.FactWeeklyPharmacySales WHERE TotalOrders < 0)
    THROW 51003, 'Negative total orders detected.', 1;

-- 4: Lookup integrity (important because duplicates inflate sales).
IF EXISTS (SELECT 1 FROM dbo.DimOrderStatus GROUP BY OrderStateTypeId HAVING COUNT(*) > 1)
    THROW 51004, 'Duplicate status lookup.', 1;
IF EXISTS (SELECT 1 FROM dbo.DimPharmacy GROUP BY PharmacyBisKey HAVING COUNT(*) > 1)
    THROW 51005, 'Duplicate pharmacy lookup.', 1;

PRINT 'Basic DWH data quality checks passed.';
-- Manual integration scenarios to test against a disposable source DB:
-- A) Two delivered orders for one pharmacy/week -> one fact row, TotalOrders=2.
-- B) Same order has two items -> TotalOrders=1; sales = sum of both items.
-- C) Re-run ETL unchanged -> same row count and totals.
-- D) Change one item price -> total changes after re-run.
-- E) Change all delivered orders of one pharmacy/week to Canceled -> fact row removed.
-- F) Add a new pharmacy/week -> new fact row appears.
GO
