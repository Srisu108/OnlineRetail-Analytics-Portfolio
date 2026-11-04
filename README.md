# Online Retail Analytics Portfolio

An end-to-end retail analytics project using the UCI Online Retail dataset. It demonstrates data profiling, Python data cleaning, SQL Server dimensional modelling and business analysis, and Power BI reporting.

## Objectives
- Profile and assess transactional data quality.
- Clean and validate data with Python and pandas.
- Load data into SQL Server and build a star schema.
- Analyse sales, orders, products, countries and customer activity with SQL.
- Build an interactive Power BI report with DAX measures.
- Practise Power BI Service publishing, gateway configuration, refresh and workspace access.

## Dataset
**Source:** [UCI Machine Learning Repository – Online Retail](https://archive.ics.uci.edu/dataset/352/online+retail)

The source dataset contains transactions from a UK-based online retailer between 1 December 2010 and 9 December 2011. It originally contains 541,909 rows and eight columns: `InvoiceNo`, `StockCode`, `Description`, `Quantity`, `InvoiceDate`, `UnitPrice`, `CustomerID` and `Country`.

The cleaned working dataset contains **536,641 rows** after removal of **5,268 exact duplicate occurrences**. The cleaned CSV is included for reproducibility. Review the dataset source terms before reuse.

## Workflow

### 1. Profiling and data quality
Reviewed row counts, data types, date coverage, distinct values, missing values, duplicate rows, cancellations, negative quantities and zero/negative prices. The raw source was preserved separately from the cleaned working data.

### 2. Python and pandas
Removed exact duplicate occurrences, standardised column names and data types, retained missing customer identifiers and descriptions, added a project-defined transaction classification, and calculated line-level `transaction_value = quantity * unitprice`. The cleaned data was saved as `online_retail.csv`.

### 3. SQL Server and dimensional modelling
The cleaned data was loaded into SQL Server database `OnlineRetailDB`. The star schema consists of:
- `FactSales`
- `DimDate`
- `DimProduct`
- `DimCustomer`
- `DimCountry`

**Fact grain:** one row per retained transaction line. Missing CustomerID values map to an unknown customer dimension member.

### 4. SQL business analysis
The SQL work covers monthly performance, product performance, country performance, customer activity/segmentation, order performance and product mix comparisons.

### 5. Power BI
Report pages:
- Executive Overview
- Sales & Order Performance
- Product Performance
- Country Performance
- Customer Analysis

The semantic model uses the star schema and measures for transaction value, regular transaction value, cancellation value, quantity, invoice count, average order value, cancellation rate, identified customers and product count.

### 6. Power BI Service
Practised publishing, gateway configuration and SQL Server mapping, manual and scheduled refresh, workspace roles (Viewer and Contributor), and the distinction between workspace access and semantic-model Build permission.

## Selected findings
- November was the strongest month in the monthly comparison.
- December 2011 is incomplete because the source ends on 9 December 2011.
- The UK represented approximately 95.66% of the overall increase in regular transaction value between August and November in the analysed comparison.
- UK regular order volume increased approximately 110.28% and transaction value approximately 121.57% between August and November.
- Missing CustomerID transactions are material and cannot be assigned to identified-customer segments.
- “New in November” means active in November but not in the August comparison period; it does not prove a product launch or a customer's lifetime first purchase.

These are dataset-derived observations, not causal explanations.

## Repository structure
```text
OnlineRetail-Analytics-Portfolio/
├── 01_raw_data_profiling.ipynb
├── OnlineRetail_Raw_Analysis.xlsx
├── online_retail.csv
├── online_retail.pbix
├── online_retail_SQL_queries/
│   ├── Dim&FacttableCreation.sql
│   ├── Online_retail table creation -part1.sql
│   ├── Online_retail_DValidation_BizzQs-Part2.sql
│   └── Testing SQL performance .sql
├── docs/
│   ├── three existing project note documents
│   └── Project_Learning_Notes.docx
└── .gitignore
```

## Tools
Excel; Python; pandas; Jupyter Notebook; SQL Server; T-SQL; Power BI Desktop; Power BI Service; Git; GitHub.

## How to explore
1. Review `01_raw_data_profiling.ipynb`.
2. Review SQL scripts in `online_retail_SQL_queries/`.
3. Open `online_retail.pbix` in Power BI Desktop.
4. Read supporting notes in `docs/`.

The SQL scripts assume SQL Server. Update server/database references for your environment before execution. Configure the Power BI data source connection when opening the PBIX in another environment.

## Analytical caveats
- `transaction_value` is quantity multiplied by unit price; it is not independently verified accounting revenue.
- Negative quantities and values are retained as source transaction history.
- Transaction classification is a project-defined analytical classification based on invoice prefixes and source values.
- Missing CustomerID values remain unknown; they are not reconstructed.
- December 2011 is a partial month.
- “New in comparison period” does not mean newly launched or newly acquired.

## Author
Created as a hands-on Data Analyst portfolio project demonstrating an end-to-end analytics workflow.
