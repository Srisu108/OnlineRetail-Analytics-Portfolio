SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT COUNT(*) AS TotalRecords
FROM dbo.online_retail;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;


SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    COUNT(CASE WHEN quantity > 0 THEN 1 END) AS positive_quantity_records,
    COUNT(CASE WHEN quantity < 0 THEN 1 END) AS negative_quantity_records,
    COUNT(CASE WHEN quantity = 0 THEN 1 END) AS zero_quantity_records,
    SUM(quantity) AS total_quantity
FROM dbo.online_retail;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;