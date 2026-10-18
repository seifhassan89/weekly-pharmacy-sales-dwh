# Weekly Pharmacy Sales Data Warehouse

**A SQL Server Data Engineering project focused on dimensional modeling, ETL development, and weekly sales analytics.**

This project implements a relational data warehouse that transforms transactional pharmacy order data into a structured analytical model. It enables weekly sales reporting across pharmacies through an automated, re-runnable ETL process and a simplified reporting view.

**Data Engineering Portfolio — Project 01**

## Overview

The primary objective is to answer a business question:

**How much revenue did each pharmacy generate each week, and how many delivered orders contributed to that revenue?**

The solution extracts data from an existing operational database (`OnlinePharmacyDB`), loads dimension tables, aggregates transactional sales data, and stores the results in a weekly sales fact table.

The resulting dataset supports consistent, pharmacy-level weekly reporting without requiring repeated aggregation of individual order items.

## Technology Stack

| Technology | Purpose |
|---|---|
| Microsoft SQL Server | Data warehouse storage and processing |
| T-SQL | Data extraction, transformation, and loading |
| SQL Server Management Studio (SSMS) | Database development and execution |
| Dimensional Modeling | Analytical data organization |
| Stored Procedures | ETL implementation |
| SQL Views | Reporting and semantic layer |

## Data Architecture

The solution follows a dimensional modeling approach using a weekly sales fact table and supporting dimensions.

```text
                 OnlinePharmacyDB
                (Operational Database)
                         |
                         v
                 Extract & Transform
                         |
                         v
                  Dimension Loading
                 /       |         \
                v        v          v
           DimDate  DimPharmacy  DimOrderStatus
                \        /          |
                 \      /       ETL Status Filter
                  v    v
           FactWeeklyPharmacySales
                         |
                         v
             vw_WeeklyPharmacySales
                         |
                         v
                Weekly Sales Reports
```

### Dimensional Model

| Table | Description |
|---|---|
| `DimDate` | Calendar information used to identify and analyze reporting periods |
| `DimPharmacy` | Pharmacy identifiers and descriptive attributes |
| `DimOrderStatus` | Reference data used to identify delivered orders during ETL |
| `FactWeeklyPharmacySales` | Aggregated weekly sales and delivered order counts |
| `vw_WeeklyPharmacySales` | Reporting view presenting pharmacy-level weekly metrics |

### Fact Table Grain

**One row represents one pharmacy during one calendar week.**

Weeks run from **Monday through Sunday**.

The fact table uses a composite primary key:

`(WeekStartDateKey, PharmacyKey)`

This guarantees that each pharmacy has at most one fact record per reporting week.

### Fact Measures

| Measure | Calculation |
|---|---|
| `TotalSales` | `SUM(Price * Quantity)` for delivered order items |
| `TotalOrders` | `COUNT(DISTINCT OrderId)` for delivered orders containing at least one item |
| `WeekStartDateKey` | Date dimension key representing the Monday of the order creation week |

**Business rules and assumptions**

- Only orders currently marked as `Delivered` are included.
- Sales are grouped by the week of `Orders.CreatedOn`, not the actual delivery date.
- Revenue excludes delivery fees and adjustments unless already reflected in the item prices.
- Order status changes may affect historical weekly totals during subsequent ETL runs.
- Orders without order items do not contribute to the measures.
- Source monetary values are aggregated without currency conversion.
- A pharmacy-week with no qualifying delivered order items is not stored in the fact table.

## ETL Pipeline

The ETL process is implemented using SQL Server stored procedures and follows three main stages.

**1. Extract**

Read transactional data from the operational database:

- Orders and order items
- Pharmacies
- Order status reference data

**2. Transform**

Apply business and aggregation rules:

- Identify delivered orders.
- Calculate the Monday start date for each order's creation week.
- Resolve pharmacy and date dimension keys.
- Aggregate sales by pharmacy and week.
- Count distinct delivered orders.

**3. Load**

Synchronize the data warehouse with the current source snapshot:

- Update existing dimension records.
- Insert new dimension records.
- Update existing weekly sales facts.
- Insert new pharmacy-week records.
- Remove outdated fact records that no longer qualify.

The fact-loading procedure stages the aggregated dataset once and uses it to synchronize the fact table.

**Loading strategy:** Full snapshot recalculation, rather than incremental Change Data Capture (CDC).

The ETL is designed for repeated, serial execution against a complete source dataset. It is not intended for partial source feeds.

## Repository Structure

```text
weekly-pharmacy-sales-dwh/
│
├── README.md
├── .gitignore
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_dimensions.sql
│   ├── 03_load_fact.sql
│   ├── 04_semantic_view.sql
│   └── 05_run_etl.sql
│
└── tests/
    └── quality_checks.sql
```

## Getting Started

### Prerequisites

- Microsoft SQL Server 2016 SP1 or later, supporting the required T-SQL features.
- SQL Server Management Studio (SSMS) or `sqlcmd`.
- An accessible operational database named `OnlinePharmacyDB`.
- Appropriate database creation and source read permissions.

The source database must provide the following tables:

| Source Table | Required Columns |
|---|---|
| `Orders` | `Id`, `PharmacyKey`, `OrderStateTypeId`, `CreatedOn` |
| `OrderItems` | `OrderId`, `Price`, `Quantity` |
| `Pharmacies` | `Id`, `Key`, `CreatedOn`, `TestFlag` |
| `OrderStateTypes` | `Id`, `OrderStateTypeId`, `StateName` |

The repository does not include source business data.

### Installation and Execution

**Step 1 — Clone the repository**

```bash
git clone https://github.com/<your-username>/weekly-pharmacy-sales-dwh.git
cd weekly-pharmacy-sales-dwh
```

Replace `<your-username>` with your GitHub username.

**Step 2 — Review the source database**

Ensure that `OnlinePharmacyDB` exists on the SQL Server instance and matches the expected schema.

**Step 3 — Execute SQL scripts in order**

| Order | Script | Purpose |
|---|---|---|
| 1 | `01_schema.sql` | Create the data warehouse schema |
| 2 | `02_load_dimensions.sql` | Create dimension loading procedures |
| 3 | `03_load_fact.sql` | Create the weekly fact loading procedure |
| 4 | `04_semantic_view.sql` | Create the reporting view |
| 5 | `05_run_etl.sql` | Execute the ETL workflow |

**Step 4 — Query the reporting view**

```sql
USE WeeklySalesPharmacyDWH;
GO

SELECT
    Pharmacy,
    WeekStart,
    WeekEnd,
    TotalOrders,
    TotalSales
FROM dbo.vw_WeeklyPharmacySales
ORDER BY WeekStart, Pharmacy;
```

The reporting view excludes pharmacies marked as test records.

## Data Quality and Validation

A separate validation script is provided at:

`tests/quality_checks.sql`

The checks cover:

- Fact table grain uniqueness.
- Valid Monday week-start dates.
- Dimension key uniqueness.
- Referential integrity between fact and dimension tables.
- Basic consistency of stored data.

**Recommended integration test scenarios**

| Scenario | Expected Behavior |
|---|---|
| Order with multiple items | Revenue includes all items; order counted once |
| Repeated ETL execution | No duplicated pharmacy-week records |
| Order price change | Weekly revenue recalculated |
| New delivered order | Corresponding pharmacy-week updated or inserted |
| Last delivered order no longer qualifies | Outdated pharmacy-week removed |

These checks support validation but do not replace executing the project against a SQL Server database containing representative source data.

## Design Decisions and Limitations

The implementation intentionally prioritizes clarity and core Data Engineering concepts over production-scale complexity.

**Dimensional keys**

The project uses source-derived integer pharmacy IDs rather than independently generated surrogate identity values.

**Weekly aggregation**

Actual week-start dates are used to identify reporting periods, avoiding ambiguity around week numbers and calendar-year boundaries.

**Full snapshot loading**

A full recalculation simplifies synchronization and handles changes to previously delivered orders. However, it introduces unnecessary processing for unchanged historical data.

**Calendar coverage**

The date dimension initially covers 2020–2030 and must be extended if operational data falls outside that range.

**Operational limitations**

The solution assumes a complete, consistent source dataset and serial ETL execution. Production deployment would require additional attention to performance, observability, data reconciliation, and orchestration.

## Data Architecture & Dimensional Model

![ETL Architecture & Star Schema](docs/images/Weekly%20Pharmacy%20Sales%20ETL%20and%20Star%20Schema.png)

## Sample Output

![Weekly Sales Results](docs/images/weekly-sales-results.png)

## Future Enhancements

Potential improvements include:

- Incremental loading using change tracking or CDC.
- Scheduled pipeline orchestration.
- ETL monitoring and structured execution logs.
- Source-to-warehouse reconciliation tests.
- Extended business metrics and reporting.
- Automated integration testing.
- Power BI dashboards for weekly revenue trends.

These are future opportunities and are not part of the current implementation.

## Learning Outcomes

This project demonstrates foundational Data Engineering concepts:

- Dimensional modeling and fact table grain
- Star schema design
- Business and surrogate key lookups
- SQL-based ETL development
- Aggregate measures and analytical reporting
- Re-runnable data loading
- Data quality and consistency validation
- Technical documentation and reproducible workflows

---

**Project Type:** Data Engineering Course Assignment  
**Portfolio:** Data Engineering — Project 01  
**Author:** Seif Hassan

*This is an educational project intended to demonstrate foundational Data Engineering practices. It has not been presented as a production-hardened data warehouse.*