/* Weekly Pharmacy Sales | 05 - Run AFTER scripts 01 through 04 */
USE WeeklySalesPharmacyDWH;
GO
EXEC dbo.usp_Load_DimDate @StartDate = '2020-01-01', @EndDate = '2030-12-31';
EXEC dbo.usp_Load_DimPharmacy;
EXEC dbo.usp_Load_DimOrderStatus;
EXEC dbo.usp_Load_FactWeeklyPharmacySales;
GO
SELECT * FROM dbo.vw_WeeklyPharmacySales ORDER BY WeekStart, Pharmacy;
GO
