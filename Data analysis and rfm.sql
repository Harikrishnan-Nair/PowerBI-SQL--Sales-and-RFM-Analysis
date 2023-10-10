SELECT * FROM sales_data.sales_data_sample;
-- Inspecting data 
select * from sales_data_sample;

/* Checking unique values */
select distinct status from sales_data_sample;
select distinct year_ID from sales_data_sample;
select distinct productline from sales_data_sample;
select distinct country from sales_data_sample;
select distinct dealsize from sales_data_sample;
select distinct territory from sales_data_sample;

-- Analysis 
-- grouping sales by productline

select productline, sum(sales) as revenue from sales_data_sample
group by productline
order by 2 desc ;

select year_id, sum(sales) as revenue from sales_data_sample
group by year_id
order by 2 desc ;

select dealsize, sum(sales) as revenue from sales_data_sample
group by dealsize
order by 2 desc;

-- what was the best month for sales in a specific year? How much was earned that month?
select sum(sales) Revenue,month_id,YEAR_ID, count(ordernumber ) frequency from sales_data_sample
group by YEAR_ID,month_id
order by revenue desc;

-- from above query analysis it seems November is best month, what product do they sell in November, probably Classic
select month_id,YEAR_ID,sum(sales) Revenue,PRODUCTLINE, count(ordernumber ) frequency from sales_data_sample
where MONTH_ID='11'
group by YEAR_ID,month_id,PRODUCTLINE
order by revenue desc;


-- who is the best customer (this could be answered by the rfm analysis method)
-- adding a new column order_date to the existing database
alter table sales_data_sample
add column order_date date;

-- updating the data in it to date datatype
update sales_data_sample
set order_date = str_to_date(orderdate, '%m/%d/%Y %H:%i');

-- addressing the actual problem 

-- Drop the table if it exists
DROP TABLE IF EXISTS rfm_temp;

-- Create the table and insert the query result into it
with rfm as  (	
    SELECT
        CUSTOMERNAME,
        SUM(sales) AS monetary_value,
        AVG(sales) AS avg_monetary_value,
        COUNT(ORDERNUMBER) AS frequency,
        MAX(order_date) AS last_order_date,
        (SELECT MAX(order_date) FROM sales_data_sample) AS max_order_date,
        DATEDIFF((SELECT MAX(order_date) FROM sales_data_sample), MAX(order_date)) AS recency
    FROM sales_data_sample
    GROUP BY customername
),
rfm_calc as
(
select r.*,
	ntile(4) over (order by recency desc) rfm_recency,
    ntile(4) over (order by frequency) rfm_frequency,
    ntile(4) over (order by monetary_value) rfm_monetary
from rfm r
),

new_cte as (
select c.*, rfm_recency+rfm_frequency+rfm_monetary as rfm_cell,
concat(rfm_recency, rfm_frequency, rfm_monetary) as rfm_cell_string
from rfm_calc c
)
select customername,rfm_recency, rfm_frequency, rfm_monetary,
case
	when rfm_cell_string in (111,112,121,122,123,132,211,114,141) then 'Lost customers' -- lost customer
    when rfm_cell_string in (133,134,143,244,334,343,344,144) then 'slipping away cannot loose' -- big spenders who havent purchased lately, slipping away
    when rfm_cell_string in (311,411,331,421,412) then 'new customers'
    when rfm_cell_string in (222,223,233,322,221,212) then 'potential churners'
    when rfm_cell_string in (323,333,321,422,332,432,232) then 'active'  -- customers who buy often and recently, but at low price points
    when rfm_cell_string in (433,434,443,444,423) then 'Loyal'
    end rfm_segment
from new_cte f;


-- what products are most often sold together?
select distinct s.ordernumber,
	(select group_concat(z.PRODUCTCODE separator ',') from sales_data_sample as z
where z.ordernumber = s.ordernumber) as concatnated_productcodes
from sales_data_sample s
where  s.ordernumber in
	(select ordernumber from 
		(select ordernumber, count(*) rn 
		from sales_data_sample
		where status='shipped'
		group by ordernumber) a
	where rn=3);

