SELECT
    @@SERVERNAME AS ServerName,
    SERVERPROPERTY('InstanceName') AS InstanceName,
    DB_NAME() AS CurrentDatabase;


    Create Table  online_retail
    (
        invoiceno VARCHAR(20),
        stockcode VARCHAR(20),
        description NVARCHAR(255),
        quantity INT,
        invoicedate DATETIME2,
        unitprice decimal(12,2),
        customerid INT NULL,
        country NVARCHAR(100),
        transaction_type VARCHAR(50),
        transaction_value decimal(14,2)
    );

    select count(*) as total_records from online_retail;

    SELECT TOP 10 *
FROM dbo.online_retail;