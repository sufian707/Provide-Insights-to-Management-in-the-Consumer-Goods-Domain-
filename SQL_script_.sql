SELECT * FROM dim_customer where customer like "%croma%" and market="India";
select s.date,s.product_code,p.product,p.variant,s.sold_quantity,g.gross_price,round(g.gross_price*s.sold_quantity,2) as total_gross_price
from fact_sales_monthly s
join dim_product p
on s.product_code=p.product_code
join fact_gross_price g 
on g.product_code=s.product_code and g.fiscal_year=get_fiscal_year(s.date)
 where
			customer_code="90002002" AND
            get_fiscal_year(date)=2021  
ORDER BY date asc;



select 
	s.date,sum(g.gross_price*s.sold_quantity) as monthly_sales
from fact_sales_monthly s
join fact_gross_price g 
on g.product_code=s.product_code and
g.fiscal_year=get_fiscal_year(s.date)
where customer_code=90002002
group by date ;
    
    
select
            get_fiscal_year(date) as fiscal_year,
            sum(round(sold_quantity*g.gross_price,2)) as yearly_sales
	from fact_sales_monthly s
	join fact_gross_price g
	on 
	    g.fiscal_year=get_fiscal_year(s.date) and
	    g.product_code=s.product_code
	where
	    customer_code=90002002
	group by get_fiscal_year(date)
	order by fiscal_year;
		
        
 -- Include pre-invoice deductions in Croma detailed report
	SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
    	    ON g.fiscal_year=get_fiscal_year(s.date)
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
	    s.customer_code=90002002 AND 
    	    get_fiscal_year(s.date)=2021     
	LIMIT 1000000;
       

-- Same report but all the customers
	SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
    	    ON g.fiscal_year=get_fiscal_year(s.date)
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
    	    get_fiscal_year(s.date)=2021     
	LIMIT 1000000;


-- creating dim_date and joining with this table and avoid using the function 'get_fiscal_year()' to reduce the amount of time taking to run the query
	SELECT 
    	    s.date, 
            s.customer_code,
            s.product_code, 
            p.product, p.variant, 
            s.sold_quantity, 
            g.gross_price as gross_price_per_item,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
            pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_date dt
        	ON dt.calendar_date = s.date
	JOIN dim_product p
        	ON s.product_code=p.product_code
	JOIN fact_gross_price g
    		ON g.fiscal_year=dt.fiscal_year
    		AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
        	ON pre.customer_code = s.customer_code AND
    		pre.fiscal_year=dt.fiscal_year
	WHERE 
    		dt.fiscal_year=2021     
	LIMIT 1500000;


-- Added the fiscal year in the fact_sales_monthly table itself
	SELECT 
    	    s.date, 
            s.customer_code,
            s.product_code, 
            p.product, p.variant, 
            s.sold_quantity, 
            g.gross_price as gross_price_per_item,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
            pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
        	ON s.product_code=p.product_code
	JOIN fact_gross_price g
    		ON g.fiscal_year=s.fiscal_year
    		AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
        	ON pre.customer_code = s.customer_code AND
    		pre.fiscal_year=s.fiscal_year
	WHERE 
    		s.fiscal_year=2021     
	LIMIT 1500000;


-- Get the net_invoice_sales amount using the CTE's
	WITH cte1 AS (
		SELECT 
    		    s.date, 
    		    s.customer_code,
    		    s.product_code, 
                    p.product, p.variant, 
                    s.sold_quantity, 
                    g.gross_price as gross_price_per_item,
                    ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
                    pre.pre_invoice_discount_pct
		FROM fact_sales_monthly s
		JOIN dim_product p
        		ON s.product_code=p.product_code
		JOIN fact_gross_price g
    			ON g.fiscal_year=s.fiscal_year
    			AND g.product_code=s.product_code
		JOIN fact_pre_invoice_deductions as pre
        		ON pre.customer_code = s.customer_code AND
    			pre.fiscal_year=s.fiscal_year
		WHERE 
    			s.fiscal_year=2021) 
	SELECT 
      	    *, 
    	    (gross_price_total-pre_invoice_discount_pct*gross_price_total) as net_invoice_sales
	FROM cte1
	LIMIT 1500000;



-- Now generate net_invoice_sales using the above created view "sales_preinv_discount"
	SELECT 
            *,
    	    (gross_price_total-pre_invoice_discount_pct*gross_price_total) as net_invoice_sales
	FROM sales_preinv_discount;

-- Create a report for net sales
    SELECT 
            *, 
    	    net_invoice_sales*(1-post_invoice_discount_pct) as net_sales
	FROM gdb0041.sales_postinv_discount;
    
    select * from net_sales;

-- Get top 5 market by net sales in fiscal year 2021
	SELECT 
    	    market, 
            round(sum(net_sales)/1000000,2) as net_sales_mln
	FROM gdb0041.net_sales
	where fiscal_year=2021
	group by market
	order by net_sales_mln desc
	limit 5;


-- find out customer wise net sales percentage contribution 
	with cte1 as (
		select 
                    customer, 
                    round(sum(net_sales)/1000000,2) as net_sales_mln
        	from net_sales s
        	join dim_customer c
                    on s.customer_code=c.customer_code
        	where s.fiscal_year=2021
        	group by customer)
	select 
            *,
            net_sales_mln*100/sum(net_sales_mln) over() as pct_net_sales
	from cte1
	order by net_sales_mln desc;

-- Find customer wise net sales distibution per region for FY 2021
	with cte1 as (
		select 
        	    c.customer,
                    c.region,
                    round(sum(net_sales)/1000000,2) as net_sales_mln
                from gdb0041.net_sales n
                join dim_customer c
                    on n.customer_code=c.customer_code
		where fiscal_year=2021
		group by c.customer, c.region)
	select
             *,
             net_sales_mln*100/sum(net_sales_mln) over (partition by region) as pct_share_region
	from cte1
	order by region, pct_share_region desc;

	-- Find out top 3 products from each division by total quantity sold in a given year
	with cte1 as 
		(select
                     p.division,
                     p.product,
                     sum(sold_quantity) as total_qty
                from fact_sales_monthly s
                join dim_product p
                      on p.product_code=s.product_code
                where fiscal_year=2021
                group by p.product),
           cte2 as 
	        (select 
                     *,
                     dense_rank() over (partition by division order by total_qty desc) as drnk
                from cte1)
	select * from cte2 where drnk<=3;
    
    SET sql_mode = '';
    
    
    
    -- Retrieve the top 2 markets in every region by their gross sales amount in FY=2021. 
    with cte1 as (
		select
			c.market,
			c.region,
			round(sum(gross_price_total)/1000000,2) as gross_sales_mln
			from gross_sales s
			join dim_customer c
			on c.customer_code=s.customer_code
			where fiscal_year=2021
			group by market
			order by gross_sales_mln desc
		),
		cte2 as (
			select *,
			dense_rank() over(partition by region order by gross_sales_mln desc) as drnk
			from cte1
		)
	select * from cte2 where drnk<=2;
		
        
        
        -- Create fact_act_est table
	drop table if exists fact_act_est;

	create table fact_act_est
	(
        	select 
                    s.date as date,
                    s.fiscal_year as fiscal_year,
                    s.product_code as product_code,
                    s.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
                    fact_sales_monthly s
        	left join fact_forecast_monthly f 
        	using (date, customer_code, product_code)
	)
	union
	(
        	select 
                    f.date as date,
                    f.fiscal_year as fiscal_year,
                    f.product_code as product_code,
                    f.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
		    fact_forecast_monthly  f
        	left join fact_sales_monthly s 
        	using (date, customer_code, product_code)
	);

SET SQL_SAFE_UPDATES = 0;
update fact_act_est
	set sold_quantity = 0
	where sold_quantity is null;

	update fact_act_est
	set forecast_quantity = 0
	where forecast_quantity is null;

drop table if exists forecast_accuracy_2021;
create temporary table forecast_accuracy_2021
with forecast_err_table as (
        select
                s.customer_code as customer_code,
                c.customer as customer_name,
                c.market as market,
                sum(s.sold_quantity) as total_sold_qty,
                sum(s.forecast_quantity) as total_forecast_qty,
                sum(s.forecast_quantity-s.sold_quantity) as net_error,
                round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
        from fact_act_est s
        join dim_customer c
        on s.customer_code = c.customer_code
        where s.fiscal_year=2021
        group by customer_code
)
select 
        *,
    if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
from 
	forecast_err_table
order by forecast_accuracy desc;

drop table if exists forecast_accuracy_2020;
create temporary table forecast_accuracy_2020
with forecast_err_table as (
        select
                s.customer_code as customer_code,
                c.customer as customer_name,
                c.market as market,
                sum(s.sold_quantity) as total_sold_qty,
                sum(s.forecast_quantity) as total_forecast_qty,
                sum(s.forecast_quantity-s.sold_quantity) as net_error,
                round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
        from fact_act_est s
        join dim_customer c
        on s.customer_code = c.customer_code
        where s.fiscal_year=2020
        group by customer_code
)
select 
        *,
    if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
from 
	forecast_err_table
order by forecast_accuracy desc;

select 
	f_2020.customer_code,
	f_2020.customer_name,
	f_2020.market,
	f_2020.forecast_accuracy as forecast_acc_2020,
	f_2021.forecast_accuracy as forecast_acc_2021
from forecast_accuracy_2020 f_2020
join forecast_accuracy_2021 f_2021
on f_2020.customer_code = f_2021.customer_code 
where f_2021.forecast_accuracy < f_2020.forecast_accuracy
order by forecast_acc_2020 desc;

