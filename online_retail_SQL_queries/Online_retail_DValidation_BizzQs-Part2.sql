

/* Part A – Data validation

First, we verify that SQL Server contains the same data as Python.

We'll check:

Total record count.
Missing values.
Duplicate records.
Minimum and maximum dates.
Negative and positive quantities.
Minimum and maximum prices.
Transaction classifications.   */

select
	count(*) as totalRecords,
	count(customerid) as populatedcustomerIDs,
	count(*) - count(customerid) as missingcustomerids
from online_retail;
SELECT TOP 10 *
FROM online_retail
ORDER BY InvoiceNo;
---Validation 2: Checking duplicate records
with duplicateGroups AS(


	select
		invoiceno,
		stockcode,
		description,
		quantity,
		invoicedate,
		unitprice,
		customerid,
		country,
		transaction_type,
		transaction_value,
		count(*) as occurence_count
	from online_retail
	group by
		invoiceno,
		stockcode,
		description,
		quantity,
		invoicedate,
		unitprice,
		customerid,
		country,
		transaction_type,
		transaction_value
	Having count(*) >1
)
select
	count(*) as duplicate_groups,
	sum(occurence_count) as records_in_duplicate_groups,
	sum(occurence_count - 1) as excess_duplicate_records
from DuplicateGroups;


----Validation 3: Checking the date range

select
	MIN(invoicedate) as earliest_transaction_date,
	MAX(invoicedate) as latest_tranaction_date,
	count(Distinct cast(invoicedate as date)) as unique_tranaction_dates
from online_retail;


----2. Validation 4 – Quantity distribution
-----------Business Questions:- How many transaction records represent positive sales, negative quantities and zero quantities?
/* In retail datasets:

Positive quantities generally represent goods sold.
Negative quantities can represent returns or cancellations.
Zero quantities may indicate unusual or adjustment records.

We shouldn't automatically assume every negative quantity is a return. We'll investigate transaction classifications separately.

*/

select
	count(case when quantity >0 then 1 End) as positive_quantity_records,
	count(case when quantity < 0 then 1 End) as negative_quantity_records,
	count(case when quantity = 0 then 1 End) as Zero_quantity_records,
	sum(quantity) as total_quantity
from online_retail;

----Validation 5 – Unit Price analysis

----Business or Management Question  :-  Management question

----Are there unusual prices in our retail transactions?

SELECT
    MIN(unitprice) AS minimum_unit_price,
    MAX(unitprice) AS maximum_unit_price,

    COUNT(CASE WHEN unitprice < 0 THEN 1 END) AS negative_price_records,

    COUNT(CASE WHEN unitprice = 0 THEN 1 END) AS zero_price_records,

    COUNT(CASE WHEN unitprice > 0 THEN 1 END) AS positive_price_records

FROM dbo.online_retail;


----Validation 6 – Transaction classification

/* ----- Business question

Does our transaction classification correctly distinguish regular transactions, cancellations and financial adjustments? */

select
	transaction_type,
	count(*) as total_records,
	sum(quantity) as total_quantity,
	sum(transaction_value) as total_transaction_value
from online_retail
group by transaction_type
order by total_transaction_value desc;


----  Validation 7 – Investigate negative unit prices
--- Business/data-quality question: What are the two records with negative unit prices, and do they explain the financial adjustments?

SELECT
    invoiceno,
    stockcode,
    description,
    quantity,
    unitprice,
    transaction_value,
    transaction_type
FROM dbo.online_retail
WHERE unitprice < 0
ORDER BY unitprice;

------      -----------     Next: Business Analysis – Sales Performance    ------------       ---------

---BQ 1 How much transaction value did the business generate, and how much remains after cancellation-related transactions and financial adjustments?

/* Key points
I would structure our analysis like this:

Overall business performance: What is the total transaction value?
Sales performance: How much value comes from regular transactions?
Cancellations and adjustments: How much value is being reversed or adjusted?
Sales trends: Is performance improving or declining month by month?
Business drivers: Which products, customers and countries contribute most? */

select
	invoiceno,
	quantity,
	unitprice,
	transaction_value,
	transaction_type
from online_retail
where transaction_type = 'Financial adjustment';



---BQ Is the business performing consistently, or is its performance improving or declining over time?

/* We'll analyse monthly transaction value, compare periods, and identify trends.
This is where an analyst starts moving beyond reporting numbers and explaining business performance. */


------Analysis 1 – How is the business performing month by month? (Are our sales growing, declining, or fluctuating throughout the year?)
with tt_types as (

	select
		DATEFROMPARTS(
			year(invoicedate),
			month(invoicedate),
			1) AS sales_month,
		count(*) as total_records,

		sum(case WHEN transaction_type ='Regular'
			THEN transaction_value  ELSE 0
			END) as Regular_transaction_value,
		sum(case WHEN transaction_type ='Cancellation-related'
			THEN transaction_value  ELSE 0
			END) as Cancellationvalue,

		sum(case WHEN transaction_type ='Financial adjustment'
			THEN transaction_value  ELSE 0
			END) as Financial_adjustments

	from online_retail
	Group by 
		Year(invoicedate),
		month(invoicedate)
)
select *,
	(Regular_transaction_value + cancellationvalue + Financial_adjustments) as Net_transaction_value
from tt_types
order by sales_month;


---BQ --- Which products contributed most to November's transaction value, and how does that compare with August?
----
---   One important analytical decision: We should initially compare regular transactions only,
----keeping cancellation-related transactions and financial adjustments separate. 
----This ensures we're comparing like with like.

---creating surrogate key

alter table online_retail
ADD SalesLineKey BIGINT IDENTITY(1,1) NOT NULL;

alter table online_retail
add constraint PK_online_retail
PRIMARY KEY (SalesLineKey);


select TOP (10)
	SalesLineKey,
	invoiceno,
	stockcode,
	quantity,
	unitprice
from online_retail
order by SalesLineKey;

select * from online_retail;

SELECT
    COUNT(*) AS total_records,
    COUNT(SalesLineKey) AS populated_keys,
    COUNT(DISTINCT SalesLineKey) AS unique_keys
FROM dbo.online_retail;

/* -----    Business Analysis – Product Performance
Analysis 2: Which products drove the growth between August and November? */

--- BQ ---Regular transaction value increased from approximately £746,779 in August to £1,503,867 in November.



SELECT
    stockcode,
    description,

    -- August performance
    SUM(CASE
        WHEN MONTH(invoicedate) = 8
        THEN quantity ELSE 0
    END) AS august_quantity,

    SUM(CASE
        WHEN MONTH(invoicedate) = 8
        THEN transaction_value ELSE 0
    END) AS august_value,

    -- November performance
    SUM(CASE
        WHEN MONTH(invoicedate) = 11
        THEN quantity ELSE 0
    END) AS november_quantity,

    SUM(CASE
        WHEN MONTH(invoicedate) = 11
        THEN transaction_value ELSE 0
    END) AS november_value,

    -- Differences: November minus August
    SUM(CASE
        WHEN MONTH(invoicedate) = 11
        THEN quantity ELSE 0
    END)
    -
    SUM(CASE
        WHEN MONTH(invoicedate) = 8
        THEN quantity ELSE 0
    END) AS quantity_difference,

    SUM(CASE
        WHEN MONTH(invoicedate) = 11
        THEN transaction_value ELSE 0
    END)
    -
    SUM(CASE
        WHEN MONTH(invoicedate) = 8
        THEN transaction_value ELSE 0
    END) AS value_difference

FROM dbo.online_retail

WHERE
    invoicedate >= '2011-08-01'
    AND invoicedate < '2011-12-01'
    AND MONTH(invoicedate) IN (8, 11)
    AND transaction_type = 'Regular'

GROUP BY
    stockcode,
    description

ORDER BY
    value_difference DESC;


	----------   Analysis 3 – Country performance analysis --------------

	--- BQ ---- Which countries contributed most to the business's transaction value, and where did growth occur between August and November 2011?


SELECT Top 3
    country,

    -- August performance
    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN transaction_value ELSE 0
    END) AS august_value,

    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN quantity ELSE 0
    END) AS august_quantity,

    COUNT(DISTINCT CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN customerid
    END) AS august_customers,

    -- November performance
    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN transaction_value ELSE 0
    END) AS november_value,

    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN quantity ELSE 0
    END) AS november_quantity,

    COUNT(DISTINCT CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN customerid
    END) AS november_customers,

    -- Value difference
    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN transaction_value ELSE 0
    END)
    -
    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN transaction_value ELSE 0
    END) AS value_difference,

    -- Percentage growth
    CAST(
        (
            SUM(CASE
                WHEN invoicedate >= '2011-11-01'
                 AND invoicedate < '2011-12-01'
                THEN transaction_value ELSE 0
            END)
            -
            SUM(CASE
                WHEN invoicedate >= '2011-08-01'
                 AND invoicedate < '2011-09-01'
                THEN transaction_value ELSE 0
            END)
        ) * 100.0
        /
        NULLIF(
            SUM(CASE
                WHEN invoicedate >= '2011-08-01'
                 AND invoicedate < '2011-09-01'
                THEN transaction_value ELSE 0
            END), 0
        )
        AS DECIMAL(10,2)
    ) AS growth_percentage

FROM dbo.online_retail

WHERE
    invoicedate >= '2011-08-01'
    AND invoicedate < '2011-12-01'
    AND MONTH(invoicedate) IN (8, 11)
    AND transaction_type = 'Regular'

GROUP BY
    country

ORDER BY
    value_difference DESC;


------------------------------------    4. Next analysis – Customer performance          -------------------------------------------

---- Management question: Are more customers purchasing, or are existing customers spending more?

------------------------------------------------

SELECT 
    customerid,

    COUNT(DISTINCT CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN invoiceno
    END) AS august_orders,

    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN transaction_value ELSE 0
    END) AS august_value,

    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN quantity ELSE 0
    END) AS august_quantity,

    COUNT(DISTINCT CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN invoiceno
    END) AS november_orders,

    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN transaction_value ELSE 0
    END) AS november_value,

    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN quantity ELSE 0
    END) AS november_quantity

FROM dbo.online_retail

WHERE
    country = 'United Kingdom'
    AND transaction_type = 'Regular'
    AND invoicedate >= '2011-08-01'
    AND invoicedate < '2011-12-01'
    AND MONTH(invoicedate) IN (8, 11)
    AND customerid IS NOT NULL

GROUP BY
    customerid

ORDER BY
    november_value DESC;

    ---------------    Next analysis: Customer segmentation -----------

----    Management question: Did the UK business grow because it acquired new customers or because existing customers purchased more?

with customerPerformance as
(


select
    customerid,
    MAX(case
        WHEN Month(invoicedate) = 8
        THEN 1 ELSE 0
    END) AS august_active,

    Max(case
        WHEN Month(invoicedate) =11
        THEN 1 ELSE 0
    END) AS November_active,

    sum(case
        WHEN Month(invoicedate) = 8
        THEN transaction_value ELSE 0
    END) As August_value,

    sum(case
        WHEN Month(invoicedate) = 11
        THEN transaction_value ELSE 0
    END) As November_value

From online_retail
WHERE
    country = 'United Kingdom'
    AND transaction_type = 'Regular'
    AND customerid is not NULL
    AND Month(invoicedate) IN (8,11)
    
Group by 
    customerid

)

select
    case
        WHEN august_active = 1 AND November_active = 1
            THEN 'Retained'
        WHEN august_active =0 AND november_active = 1
            THEN 'New in November'
        WHEN august_active = 1 AND november_active = 0
            THEN 'NOT active in November'
    END as customer_segement,
    
    count(*) as total_customers,

    sum(august_value) as august_value,
    sum(november_value) as November_value,
    sum(November_value - August_value) as value_difference

From customerPerformance

Group by
    
    case
        WHEN august_active = 1 AND November_active = 1
            THEN 'Retained'
        WHEN august_active =0 AND november_active = 1
            THEN 'New in November'
        WHEN august_active = 1 AND november_active = 0
            THEN 'NOT active in November'
    END

Order by total_customers DEsc;
    
-------    3. Next task: Investigate missing CustomerIDs


SELECT
    CASE
        WHEN Month(invoicedate) =8
        THEN 'August 2011'

        WHEN Month(invoicedate) = 11
        THEN 'November 2011'
    END AS sales_month,

    COUNT(*) AS total_records,

    COUNT(DISTINCT invoiceno) AS total_invoices,

    SUM(quantity) AS total_quantity,

    SUM(transaction_value) AS total_transaction_value

FROM dbo.online_retail

WHERE
    country = 'United Kingdom'
    AND transaction_type = 'Regular'
    AND customerid IS NULL
    AND MONTH(invoicedate) IN (8, 11)

GROUP BY
    CASE
        WHEN Month(invoicedate) =8
        THEN 'August 2011'

        WHEN Month(invoicedate) = 11
        THEN 'November 2011'
    END;


    ------   3. Next analysis – Order performance ---
    ----   BQ ---Did the business grow because it received more orders, or because the average order value increased?

    select
        case
            When Month(invoicedate) = 8
            THEN 'August 2011'
            ELSE 'November 2011'
        END As sales_month,


        count(Distinct invoiceno) as total_orders,
        sum(quantity) as total_quantity,
        sum(transaction_value) as total_value,

        cast(
            sum(transaction_value) * 1.0
            /nullif(count(distinct invoiceno),0)
            AS DECIMAL(10,2)
        ) as Average_order_value,
        
        cast(
            sum(quantity)*1.0
            /NULLIF(count(distinct invoiceno),0)
            AS decimal(10,2)
        ) as Average_quantity_per_order

    from online_retail

    Where
        country = 'United Kingdom'
        AND transaction_type = 'Regular'
        AND Month(invoicedate) in (8,11)

    Group by
        case
            WHEN Month(invoicedate) = 8
            THEN 'August 2011' ELSE
            'November 2011'
        END

    ORDER BY 
        sales_month;



    ---------    5. Next analysis: Did the product mix change?

   ------ Management question: Which products contributed most to the increase in UK transaction value between August and November?
   with productperformance as (

   SELECT
    stockcode,
    description,

    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN quantity
        ELSE 0
    END) AS august_quantity,

    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN transaction_value
        ELSE 0
    END) AS august_value,

    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN quantity
        ELSE 0
    END) AS november_quantity,

    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN transaction_value
        ELSE 0
    END) AS november_value,

    SUM(CASE
        WHEN invoicedate >= '2011-11-01'
         AND invoicedate < '2011-12-01'
        THEN transaction_value
        ELSE 0
    END)
    -
    SUM(CASE
        WHEN invoicedate >= '2011-08-01'
         AND invoicedate < '2011-09-01'
        THEN transaction_value
        ELSE 0
    END) AS value_difference,

    CASE
    WHEN
        SUM(CASE
            WHEN invoicedate >= '2011-08-01'
             AND invoicedate < '2011-09-01'
            THEN transaction_value ELSE 0
        END) = 0
        AND
        SUM(CASE
            WHEN invoicedate >= '2011-11-01'
             AND invoicedate < '2011-12-01'
            THEN transaction_value ELSE 0
        END) > 0
    THEN 'New in November'

    WHEN
        SUM(CASE
            WHEN invoicedate >= '2011-08-01'
             AND invoicedate < '2011-09-01'
            THEN transaction_value ELSE 0
        END) > 0
        AND
        SUM(CASE
            WHEN invoicedate >= '2011-11-01'
             AND invoicedate < '2011-12-01'
            THEN transaction_value ELSE 0
        END) = 0
    THEN 'Not active in November'

    WHEN
        SUM(CASE
            WHEN invoicedate >= '2011-08-01'
             AND invoicedate < '2011-09-01'
            THEN transaction_value ELSE 0
        END) > 0
        AND
        SUM(CASE
            WHEN invoicedate >= '2011-11-01'
             AND invoicedate < '2011-12-01'
            THEN transaction_value ELSE 0
        END) > 0
    THEN 'Active in both months'

    ELSE 'No transaction value'
END AS product_segment

FROM dbo.online_retail

WHERE
    country = 'United Kingdom'
    AND transaction_type = 'Regular'
    AND invoicedate >= '2011-08-01'
    AND invoicedate < '2011-12-01'
    AND MONTH(invoicedate) IN (8, 11)

GROUP BY
    stockcode,
    description
)
select 
    product_segment,
    count(*) as total_products,
    sum(august_value) as august_value,
    sum(november_value) as November_value,
    sum(value_difference) as value_difference
from productperformance
group by product_segment 
order by value_difference;


------     4. Next step: Classify product performance -----------

