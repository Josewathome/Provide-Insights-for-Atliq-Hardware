-- 1. List of markets where "Atliq Exclusive" operates in the APAC region
SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';


-- 2.  Percentage of unique product increase in 2021 vs. 2020
WITH UniqueProductCounts AS (
    SELECT
        EXTRACT(YEAR FROM date) AS sales_year,
        COUNT(DISTINCT product_code) AS unique_products
    FROM
        fact_sales_monthly
    GROUP BY
        EXTRACT(YEAR FROM date)
)
SELECT
    UP_2020.unique_products AS unique_products_2020,
    UP_2021.unique_products AS unique_products_2021,
    ROUND(((UP_2021.unique_products - UP_2020.unique_products) * 100.0) / UP_2020.unique_products, 2) AS percentage_chg
FROM
    (SELECT unique_products FROM UniqueProductCounts WHERE sales_year = 2020) AS UP_2020
JOIN
    (SELECT unique_products FROM UniqueProductCounts WHERE sales_year = 2021) AS UP_2021
ON
    1 = 1;


-- 3.  Unique product counts for each segment, sorted in descending order
SELECT
    segment,
    COUNT(DISTINCT product_code) AS product_count
FROM
    dim_product
GROUP BY
    segment
ORDER BY
    product_count DESC;


-- 4. Segment with the most increase in unique products in 2021 vs. 2020
WITH UniqueProducts2020 AS (
    SELECT
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS unique_products_2020
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    WHERE
       fsm.fiscal_year = 2020
    GROUP BY
        dp.segment
),
UniqueProducts2021 AS (
    SELECT
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS unique_products_2021
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    WHERE
        fsm.fiscal_year = 2021
    GROUP BY
        dp.segment
)
SELECT
    spc.segment,
    spc.unique_products_2020 AS product_count_2020,
    fup.unique_products_2021 AS product_count_2021,
    (fup.unique_products_2021 - spc.unique_products_2020) AS difference,
    ROUND(((fup.unique_products_2021 - spc.unique_products_2020) * 100.0) / (spc.unique_products_2020 + fup.unique_products_2021), 0) AS percentage
FROM
    UniqueProducts2020 spc
JOIN
    UniqueProducts2021 fup ON spc.segment = fup.segment

ORDER BY
    difference DESC;

-- 5. Products with the highest and lowest manufacturing costs
SELECT
    fm.product_code,
    dp.product,
    fm.manufacturing_cost
FROM
    fact_manufacturing_cost fm
JOIN
    dim_product dp ON fm.product_code = dp.product_code
WHERE
    fm.manufacturing_cost = (
        SELECT MAX(manufacturing_cost)
        FROM fact_manufacturing_cost
    )
    OR
    fm.manufacturing_cost = (
        SELECT MIN(manufacturing_cost)
        FROM fact_manufacturing_cost
    );

-- 6. Top 5 customers with the highest average pre_invoice_discount_pct in 2021 (Indian market)
WITH IndianCustomers AS (
    SELECT
        dc.customer_code,
        dc.customer,
        AVG(fpd.pre_invoice_discount_pct) AS average_discount_percentage
    FROM
        fact_pre_invoice_deductions fpd
	join
		dim_customer dc  on fpd.customer_code = dc.customer_code
	where 
		fpd.fiscal_year = 2021
        and dc.market ='India'
	group by
		dc.customer_code, dc.customer
)
select
	customer_code,
    customer,
    ROUND(average_discount_percentage, 2) AS average_discount_percentage
FROM 
	IndianCustomers
order by
	average_discount_percentage DESC
limit 5;

-- 7. Gross sales amount for "Atliq Exclusive" customer by month
SELECT
    EXTRACT(MONTH FROM fsm.date) AS Month,
    EXTRACT(YEAR FROM fsm.date) AS Year,
    SUM(fgp.gross_price * fsm.sold_quantity) AS "Gross Sales Amount"
FROM
    fact_sales_monthly fsm
JOIN
    fact_gross_price fgp ON fsm.product_code = fgp.product_code
JOIN
    dim_customer dc ON fsm.customer_code = dc.customer_code
WHERE
    dc.customer = 'Atliq Exclusive'
GROUP BY
    EXTRACT(MONTH FROM fsm.date), EXTRACT(YEAR FROM fsm.date)
ORDER BY
    EXTRACT(YEAR FROM fsm.date), EXTRACT(MONTH FROM fsm.date);


-- 8. Quarter in 2020 with the maximum total_sold_quantity
WITH MonthlySales AS (
    SELECT
        EXTRACT(MONTH FROM fsm.date) AS Month,
        EXTRACT(QUARTER FROM fsm.date) AS Quarter,
        SUM(fsm.sold_quantity) AS total_sold_quantity
    FROM
        fact_sales_monthly fsm
    WHERE
        EXTRACT(YEAR FROM fsm.date) = 2020
    GROUP BY
        EXTRACT(MONTH FROM fsm.date), EXTRACT(QUARTER FROM fsm.date)
)
SELECT
    Quarter AS "Quarter",
    SUM(total_sold_quantity) AS "total_sold_quantity"
FROM
    MonthlySales
GROUP BY
    Quarter
ORDER BY
    SUM(total_sold_quantity) DESC
LIMIT 1;

-- 9. Channel with the highest gross sales in fiscal year 2021
WITH GrossSalesByChannel AS (
    SELECT
        dc.channel,
        SUM(fgp.gross_price * fsm.sold_quantity) AS gross_sales_mln
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_customer dc ON fsm.customer_code = dc.customer_code
    JOIN
        fact_gross_price fgp ON fsm.product_code = fgp.product_code
    WHERE
        EXTRACT(YEAR FROM fsm.date) = 2021
    GROUP BY
        dc.channel
),
TotalGrossSales AS (
    SELECT
        SUM(fgp.gross_price * fsm.sold_quantity) AS total_gross_sales
    FROM
        fact_sales_monthly fsm
    JOIN
        fact_gross_price fgp ON fsm.product_code = fgp.product_code
    WHERE
        EXTRACT(YEAR FROM fsm.date) = 2021
)
SELECT
    channel,
    gross_sales_mln,
    ROUND((gross_sales_mln / total_gross_sales) * 100, 2) AS percentage
FROM
    GrossSalesByChannel
CROSS JOIN
    TotalGrossSales
ORDER BY
    gross_sales_mln DESC;

-- 10. Top 3 products in each division with high total_sold_quantity in fiscal year 2021
WITH RankedProducts AS (
    SELECT
        dp.division,
        fsm.product_code,
        dp.product,
        SUM(fsm.sold_quantity) AS total_sold_quantity,
        RANK() OVER(PARTITION BY dp.division ORDER BY SUM(fsm.sold_quantity) DESC) AS rank_order
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    WHERE
        EXTRACT(YEAR FROM fsm.date) = 2021
    GROUP BY
        dp.division, fsm.product_code, dp.product
)
SELECT
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM
    RankedProducts
WHERE
    rank_order <= 3
ORDER BY
    division, rank_order;

-- 11. Yearly report for coroma customers
SELECT
    EXTRACT(YEAR FROM fsm.date) AS fiscal_year,
    SUM(fgp.gross_price * fsm.sold_quantity) / 1000000 AS yearly_gross_sales
FROM
    fact_sales_monthly fsm
JOIN
    dim_customer dc ON fsm.customer_code = dc.customer_code
JOIN
    fact_gross_price fgp ON fsm.product_code = fgp.product_code
WHERE
    dc.customer = 'croma'
GROUP BY
    EXTRACT(YEAR FROM fsm.date)
ORDER BY
    fiscal_year;

-- 12. number of unique products sold per year
select
	
        fiscal_year,
	
        COUNT(DISTINCT product_code) as unique_product_count

    from gdb023.fact_sales_monthly 

    Group by fiscal_year;