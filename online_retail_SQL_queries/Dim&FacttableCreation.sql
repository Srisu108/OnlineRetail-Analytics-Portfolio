_--


----------------   4. Before creating tables: validate our dimension candidates ----------------------------



---- Task 1 – Product uniqueness ------


select
	stockcode,
	count(Distinct description) as description_count
from online_retail
group by stockcode
having count(Distinct description) > 1
order by description_count DESC;

---------   Task 2 – Customer uniqueness   -----------------

select
	count(*) as total_records,
	count(Distinct customerid) as unique_customers,
	count( DISTINCT Case
		WHEN customerid  is NULL THEN NULL
		ELSE customerid
	END) as identified_customers
from online_retail;


---------   Task 3 – Country profiling -------------------------------

SELECT
    country,
    COUNT(*) AS transaction_records,
    COUNT(DISTINCT invoiceno) AS total_invoices
FROM dbo.online_retail
GROUP BY country
ORDER BY transaction_records DESC;


---- Next investigation Product dimension table


SELECT
    stockcode,
    description,
    COUNT(*) AS transaction_records
FROM dbo.online_retail
WHERE stockcode IN ('20713', '23084', '21830')
GROUP BY
    stockcode,
    description
ORDER BY
    stockcode,
    transaction_records DESC;




WITH ProductDescriptionFrequency AS
(
    SELECT
        stockcode,
        description,
        COUNT(*) AS description_count,

        ROW_NUMBER() OVER
        (
            PARTITION BY stockcode
            ORDER BY COUNT(*) DESC
        ) AS description_rank

    FROM dbo.online_retail

    WHERE description IS NOT NULL

    GROUP BY
        stockcode,
        description
)

SELECT
    COUNT(*) AS total_stockcodes,

    COUNT(CASE
        WHEN description_rank = 1 THEN 1
    END) AS stockcodes_with_primary_description,

    COUNT(CASE
        WHEN description_rank > 1 THEN 1
    END) AS additional_description_records

FROM ProductDescriptionFrequency;



----- 2. Let's get the correct product statistics -----
WITH ProductDescriptionFrequency AS
(
    SELECT
        stockcode,
        description,
        COUNT(*) AS description_count
    FROM dbo.online_retail
    WHERE description IS NOT NULL
    GROUP BY
        stockcode,
        description
),
ProductSummary AS
(
    SELECT
        stockcode,
        COUNT(*) AS distinct_descriptions
    FROM ProductDescriptionFrequency
    GROUP BY stockcode
)

SELECT
    (SELECT COUNT(DISTINCT stockcode)
     FROM dbo.online_retail) AS total_unique_stockcodes,

    COUNT(*) AS stockcodes_with_descriptions,

    COUNT(CASE
        WHEN distinct_descriptions = 1 THEN 1
    END) AS stockcodes_with_one_description,

    COUNT(CASE
        WHEN distinct_descriptions > 1 THEN 1
    END) AS stockcodes_with_multiple_descriptions,

    SUM(CASE
        WHEN distinct_descriptions > 1
        THEN distinct_descriptions - 1
        ELSE 0
    END) AS additional_description_variants

FROM ProductSummary;


SELECT
    COUNT(*) AS total_records,
    COUNT(stockcode) AS populated_stockcodes,
    COUNT(DISTINCT stockcode) AS unique_stockcodes,
    COUNT(*) - COUNT(stockcode) AS missing_stockcodes
FROM dbo.online_retail;


SELECT
    stockcode,
    COUNT(*) AS transaction_records
FROM dbo.online_retail
WHERE stockcode IS NULL
GROUP BY stockcode;


SELECT
    COUNT(DISTINCT stockcode) AS sql_distinct_count,

    COUNT(DISTINCT
        CONVERT(VARBINARY(20), stockcode)
    ) AS exact_binary_distinct_count

FROM dbo.online_retail;


SELECT
    stockcode COLLATE Latin1_General_100_BIN2 AS stockcode,
    COUNT(*) AS record_count
FROM dbo.online_retail
GROUP BY
    stockcode COLLATE Latin1_General_100_BIN2
ORDER BY
    stockcode;


    --------    Step 2 – Populate DimProduct ----------


WITH ExactValues AS
(
    SELECT DISTINCT
        stockcode,
        CONVERT(VARBINARY(20), stockcode) AS stockcode_bytes
    FROM dbo.online_retail
)
SELECT
    a.stockcode AS stockcode_1,
    b.stockcode AS stockcode_2
FROM ExactValues a
INNER JOIN ExactValues b
    ON a.stockcode = b.stockcode
   AND a.stockcode_bytes < b.stockcode_bytes
ORDER BY
    a.stockcode;


SELECT
    COUNT(DISTINCT stockcode) AS default_collation_count,
    COUNT(DISTINCT
        stockcode COLLATE Latin1_General_100_BIN2
    ) AS case_sensitive_count,
    COUNT(DISTINCT
        CONVERT(VARBINARY(20), stockcode)
    ) AS exact_binary_count
FROM dbo.online_retail;



------------------------------               Step 1 – Create the DimProduct table                   -----------------------------------------

Create table DimProduct
(
    ProductKey INT IDENTITY(1,1) NOT NULL,
    StockCode VARCHAR(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ProductDescription NVARCHAR(255) NULL,

    CONSTRAINT PK_DIMProduct
        PRIMARY KEY (ProductKey),
    CONSTRAINT UQ_DimProduct_StockCode
        UNIQUE (StockCode)
);


With DescriptionFrequency as (

select
    stockcode COLLATE Latin1_General_100_BIN2 AS StockCode,
    description COLLATE Latin1_General_100_BIN2
            AS Description,
    count(*) as DescriptionFrequency
from online_retail
Group by
    stockcode COLLATE Latin1_General_100_BIN2,
    description COLLATE Latin1_General_100_BIN2
),
RankedDescriptions as
(
    select
        stockcode,
        description,
        DescriptionFrequency,
        ROW_NUMBER() OVER
        (
            Partition by stockcode 
            order by
                case
                    WHEN NULLIF(LTRIM(RTRIM(Description)),'') IS NULL
                    THEN 1
                    ELSE 0
                END,
                DescriptionFrequency DESC,
                Description ASC 
        ) AS rn
    from DescriptionFrequency
)

INSERT INTO  DimProduct
(
    stockcode,
    ProductDescription
)
select
    stockcode,
    description
from RankedDescriptions
WHERE rn = 1;


------------   Step 3 – Validate the dimension ====-----

select
    count(*) as totalProducts,
    count(Distinct productKey) as UniqueProductKeys,
    count(Distinct stockcode collate latin1_General_100_BIN2)
        AS UniqueStockCodes,
    count(ProductDescription) As productsWithDescription,
    count(*) - count(ProductDescription) AS ProductWithourDescription
from dimProduct;



-----------------   3. One final data-quality check

SELECT
    COUNT(DISTINCT
        o.stockcode COLLATE Latin1_General_100_BIN2
    ) AS ProductsWithoutMeaningfulDescription
FROM dbo.online_retail o
WHERE Exists
(
    SELECT 1
    FROM dbo.DimProduct p
    WHERE ProductDescription IS NULL
        AND p.ProductDescription = o.stockcode Collate Latin1_General_100_BIN2
);


SELECT TOP 20
    p.StockCode,
    p.ProductDescription,
    COUNT(o.stockcode) AS StagingRecords
FROM dbo.DimProduct AS p
LEFT JOIN dbo.online_retail AS o
    ON p.StockCode =
       o.stockcode COLLATE Latin1_General_100_BIN2
WHERE p.ProductDescription IS NULL
GROUP BY
    p.StockCode,
    p.ProductDescription
ORDER BY p.StockCode;

SELECT
    COUNT(*) AS ProductsWithoutDescription
FROM dbo.DimProduct
WHERE ProductDescription IS NULL;


SELECT
    COUNT(DISTINCT p.StockCode) AS MatchedProducts,
    COUNT(o.stockcode) AS MatchingStagingRecords
FROM dbo.DimProduct p
INNER JOIN dbo.online_retail o
    ON p.StockCode COLLATE Latin1_General_100_BIN2 =
       o.stockcode COLLATE Latin1_General_100_BIN2
WHERE p.ProductDescription IS NULL;

/*    Today's task: Complete dimensional modelling

Our current position:

DimProduct – Created.
DimCustomer – Next.
DimCountry – Pending.
DimDate – Pending.
FactSales – Pending.
Relationships and validation – Pending.   */


-------------------------------------------------------- Step 1: Create DimCustomer ----------------------------------


Create Table DimCustomer

(
    CustomerKey INT IDENTITY(1,1) NOT NULL,
    CustomerId INT NULL,

    Constraint PK_Dimcustomer
        PRIMARY KEY (CustomerKey),
    Constraint UQ_DimCustomer_Customer_ID
        UNIQUE(CustomerID)
);


------ ---------------------      Step 2: Populate DimCustomer ------------

    --insert into unknown customer
INSERT INTO DimCustomer (CustomerID)
VALUES (NULL);

----Insert into Identified cusotmers

INSERT INTO DimCustomer(CustomerId)
Select DISTINCT CustomerID
From online_retail
WHERE customerid IS NOT NULL;


----------------------------     Step 3: Validate --------------

select
    count(*) as total_customers,
    count(CustomerID) as IdentifiedCustomers,
    count(*) - count(CustomerID) as unknown_customers
From DimCustomer;


--------------------------------------------------------------------     Next task: Create DimCountry ------------------------------------------------------------------

-----------------      Step 1 – Check source data

select * from online_retail;

select
    count(*) as totalRecords,
    count(country) as Populatedcountries,
    count(DISTINCT country) as UniqueCountries,
    count(*) - Count(country) as MissingCountries
from online_retail;


-----------------      Step 2 – Create  dimension


create table DimCountry

(
    CountryKey INT Identity(1,1) NOT NULL,
    CountryName NVARCHAR(100) NOT NULL,

    Constraint PK_DimCountry
        PRIMARY KEY (CountryKey),
    
    Constraint UQ_Dimcountry_Country_Name
        Unique (CountryName)

);


-----------------      Step 3 – Populate it


Insert INTO DimCountry(CountryName)
select DISTINCT
    Country
From online_retail
WHERE Country IS NOT NULL;

-----------------      Step 4 – Vadilate

SELECT
    COUNT(*) AS TotalCountries,
    COUNT(DISTINCT CountryKey) AS UniqueCountryKeys,
    COUNT(DISTINCT CountryName) AS UniqueCountryNames
FROM dbo.DimCountry;



--------------------------------------------------------------------     Next task: Create DimDate ------------------------------------------------------------------


SELECT
    MIN(CAST(invoicedate AS DATE)) AS EarliestDate,
    MAX(CAST(invoicedate AS DATE)) AS LatestDate
FROM dbo.online_retail;


-----------------      Step 1 – Create the table

Create table DimDate
(
    DateKey INT NOT NULL Primary Key,
    FullDate DATE NOT NULL UNIQUE,
    [Year] INT NOT NULL,
    QtrNum INT NOT NULL,
    QtrName VARCHAR(2) NOT NULL,
    [Month] INT NOT NULL,
    MonthName VARCHAR(20) NOT NULL,
    WeekNum INT NOT NULL,
    [Day] INT NOT NULL,
    WeekDayNum INT NOT NULL

);


-----------------      Step 2 – Populate the table

DECLARE @StartDate DATE = '2010-12-01';
DECLARE @EndDate DATE = '2011-12-09';

WITH DateCalendar AS
(
    SELECT @StartDate AS CalendarDate

    UNION ALL

    SELECT DATEADD(DAY, 1, CalendarDate)
    FROM DateCalendar
    WHERE CalendarDate < @EndDate
)
INSERT INTO dbo.DimDate
(
    DateKey, FullDate, [Year], QtrNum, QtrName,
    [Month], MonthName, WeekNum, [Day], WeekDayNum
)
SELECT
    YEAR(CalendarDate) * 10000
        + MONTH(CalendarDate) * 100
        + DAY(CalendarDate),

    CalendarDate,
    YEAR(CalendarDate),
    DATEPART(QUARTER, CalendarDate),
    CONCAT('Q', DATEPART(QUARTER, CalendarDate)),
    MONTH(CalendarDate),
    DATENAME(MONTH, CalendarDate),
    DATEPART(ISO_WEEK, CalendarDate),
    DAY(CalendarDate),
    (DATEDIFF(DAY, '19000101', CalendarDate) % 7) + 1
FROM DateCalendar
OPTION (MAXRECURSION 0);


-----------------      Step 3 – Validation

SELECT
    COUNT(*) AS TotalDates,
    COUNT(DISTINCT DateKey) AS UniqueDateKeys,
    MIN(FullDate) AS EarliestDate,
    MAX(FullDate) AS LatestDate
FROM dbo.DimDate;



--------------------------------------------------------------------     Next task: Create FactSales   ------------------------------------------------------------------


-----------------      Step 1 – Understand FactSales
/*
Think of it this way:

Dimension tables describe the business: products, customers, countries and dates.
FactSales stores the actual transactions: quantity, unit price and transaction value. */

-----------------      Step 2 – Check dimension mapping Query ---   VERY IMPORTANT BELOW CREATING FACTS SALES



select
    count(*) as Totalrecords,

    sum(CASE
        WHEN p.productKey is NULL
        THEN 1 ELSE 0 END) AS MissingProducts,

    sum(CASE
        WHEN c.CustomerKey is NULL
        THEN 1 ELSE 0 END) AS MissingCustomers,


    sum(CASE
        WHEN co.CountryKey is NULL
        THEN 1 ELSE 0 END) AS MissingCountries,

    sum(CASE
        WHEN d.DateKey is NULL
        THEN 1 ELSE 0 END) AS MissingDates

from online_retail as o

LEFT JOIN DimProduct p
    ON o.stockcode collate Latin1_General_100_BIN2 = p.StockCode

LEFT JOIN DimCustomer c
    ON o.customerid = c.customerId
    OR(o.customerid IS NULL AND c.customerid is NULL)

LEFT JOIN DimCountry AS co
    ON o.country = co.countryName

LEFt JOIN DimDate as d
    ON CAST(o.invoicedate AS DATE) = d.FullDate;
    

    -----------------      Step 1 – Create FactSales ------------------------------------------------------

    Create Table FactSales

    (
        SalesLineKey BigINT NOT NULL,
        Invoiceno VARCHAR(20) NOT NULL,

        DATEKEY INT NOT NULL,
        PRODUCTKEY INT NOT NULL,    
        CustomerKey INT NOT NULL,
        CountryKey INT Not NUll,


        Quantity INT NOT NULL,
        UnitPrice Decimal(12,2) NOT NULL,
        TransactionValue Decimal(14,2) NOT NULL,
        Transaction_type VARCHAR(50) NOT NULL,

        OriginalDescription NVARCHAR(255) NULL,

        CONSTRAINT PK_FactSales
            PRIMARY KEY (SalesLineKey),

        Constraint FK_FactSales_DimDate
            Foreign KEY (DateKey)
            REFERENCES DimDate(DateKey),

        Constraint FK_FactSales_DimProduct
            Foreign Key (ProductKey)
            References DimProduct(ProductKey),

        Constraint FK_FactSales_DimCustomer
            Foreign Key (CustomerKey)
            References DimCustomer(CustomerKey),

        Constraint Fk_Factsales_dimCountry
            Foreign Key (CountryKey)
            References DimCountry(CountryKey)

    );


        -----------------      Step 1 – Insert data into FactSales ------------------------------------------------------


        INSERT INTO dbo.FactSales
(
    SalesLineKey,
    InvoiceNo,
    DateKey,
    ProductKey,
    CustomerKey,
    CountryKey,
    Quantity,
    UnitPrice,
    TransactionValue,
    Transaction_Type,
    OriginalDescription
)
SELECT
    o.SalesLineKey,
    o.invoiceno,
    d.DateKey,
    p.ProductKey,
    c.CustomerKey,
    co.CountryKey,
    o.quantity,
    o.unitprice,
    o.transaction_value,
    o.transaction_type,
    o.description

FROM dbo.online_retail AS o

INNER JOIN dbo.DimDate AS d
    ON CAST(o.invoicedate AS DATE) = d.FullDate

INNER JOIN dbo.DimProduct AS p
    ON o.stockcode COLLATE Latin1_General_100_BIN2 = p.StockCode

INNER JOIN dbo.DimCustomer AS c
    ON (
        o.customerid = c.CustomerID
        OR (o.customerid IS NULL AND c.CustomerID IS NULL)
    )

INNER JOIN dbo.DimCountry AS co
    ON o.country = co.CountryName;



-------------------         Step 3 – Validate the insertion       -------------------------------------------

SELECT
    COUNT(*) AS TotalFactRecords,
    COUNT(DISTINCT SalesLineKey) AS UniqueSalesLines,
    SUM(TransactionValue) AS TotalTransactionValue,
    SUM(Quantity) AS TotalQuantity
FROM dbo.FactSales;

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'FactSales';

Exec sp_rename
    'Factsales.Transaction_type',
    'TransactionType',
    'COLUMN';


---------------------------------------------------------------------------------------        Next: Final integrity validation -------------------------------------------------------------------------------------


SELECT
    COUNT(*) AS TotalRecords,
    COUNT(DISTINCT SalesLineKey) AS UniqueSalesLines,
    COUNT(DISTINCT ProductKey) AS Products,
    COUNT(DISTINCT CustomerKey) AS Customers,
    COUNT(DISTINCT CountryKey) AS Countries,
    COUNT(DISTINCT DateKey) AS TransactionDates
FROM dbo.FactSales;



-----------------------------------------------------------                     2. Next: Final reconciliation  ---------------------------------------------------------



SELECT
    'Staging' AS TableName,
    COUNT(*) AS TotalRecords,
    SUM(transaction_value) AS TotalValue,
    SUM(quantity) AS TotalQuantity
FROM dbo.online_retail

UNION ALL

SELECT
    'FactSales',
    COUNT(*),
    SUM(TransactionValue),
    SUM(Quantity)
FROM dbo.FactSales;


select Top 100 * from FactSales;

select Top 100 * from DimProduct;

select Top 100 * from online_retail;

 