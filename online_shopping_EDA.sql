/*
EDA
*/

--Calculate the total spend (online vs offline) by CUSTOMERS (We will want to know top 100 spend the most money)
SELECT
	DISTINCT 
	TOP 100
	CustomerID
	, ROUND(
		SUM(Online_Spend)
		, 2) AS total_online_spend
	, DENSE_RANK() OVER(ORDER BY SUM(Online_Spend) DESC) AS onlinespend_ranking
	, ROUND(
		SUM(Offline_Spend)
		, 2) AS total_offline_spend
	, DENSE_RANK() OVER(ORDER BY SUM(Offline_Spend) DESC) AS offlinespend_ranking
	, ROUND(
		(SUM(Offline_Spend)+SUM(Offline_Spend))
		, 2) AS Total_spend --calculate how mocuh they have spent in total
FROM FactTransactions
GROUP BY CustomerID
ORDER BY Total_spend DESC

/*
calculate the RFM (Recency, Frequency, Monetary) score of customers
*/
CREATE VIEW rfm_view AS
WITH base AS (
    SELECT 
        CustomerID,
        MAX(Transaction_Date) AS most_recently_purchased_date,
        DATEDIFF(DAY, MAX(Transaction_Date), '2019-12-31') AS recency_score, --Select the ending date of 2019 to calculate the difference between the latest date that the customers purchased vs the ending of the period
        COUNT(DISTINCT Transaction_ID) AS frequency_score,
        ROUND(
			SUM(online_spend + offline_spend)
			, 2) AS monetary_score
    FROM FactTransactions
    GROUP BY CustomerID
)
SELECT
    CustomerID,
    recency_score,
    frequency_score,
    monetary_score,
    NTILE(5) OVER(ORDER BY recency_score DESC) AS R,
    NTILE(5) OVER(ORDER BY frequency_score ASC) AS F,
    NTILE(5) OVER(ORDER BY monetary_score ASC) AS M
FROM base

-- View the distribution and summary of the RFM groups
WITH base AS (
    SELECT 
        CustomerID,
        MAX(Transaction_Date) AS most_recently_purchased_date,
        DATEDIFF(
			DAY
			, MAX(Transaction_Date)
			, '2019-12-31') AS recency_score, --Select the ending date of 2019 to calculate the difference between the latest date that the customers purchased vs the ending of the period
        COUNT(DISTINCT Transaction_ID) AS frequency_score,
        ROUND(
			SUM(online_spend + offline_spend)
			, 2) AS monetary_score
    FROM FactTransactions
    GROUP BY CustomerID
)
SELECT
	(R + F+ M)/3 AS RFM_group
	, COUNT(rfm_view.CustomerID) AS number_of_customer
	, ROUND(
		SUM(base.monetary_score)
		, 2) AS total_revenue
	, ROUND(
		SUM(base.monetary_score)/COUNT(rfm_view.CustomerID)
		, 2) AS avg_revenue_per_customer
FROM rfm_view
INNER JOIN 
	base
	ON base.CustomerID = rfm_view.CustomerID
GROUP BY (R + F+ M)/3
ORDER BY RFM_group 

--Who are the best customers?
SELECT *
FROM rfm_view
WHERE 
	R = 5
	AND F = 5
	AND M = 5

/*As we now know the RFM score of the customers, we would like to know the information of loyal customers
*/

WITH rfm_cal AS
	(SELECT 
		CustomerID
		,(R + F+ M)/3 AS avg_RFM_score
	FROM rfm_view 
	WHERE (R + F+ M)/3 >= 4)

SELECT
	DISTINCT 
	Location
	, Gender
	, COUNT(Gender) OVER(PARTITION BY Location) AS total_customers
	, ROUND(
		CAST(
		COUNT(Gender) OVER(PARTITION BY Location, Gender) AS float)
		/ 
		(COUNT(Gender) OVER(PARTITION BY Location)) 
	, 2)
	AS number_of_customers_by_gender
	,AVG(
		CAST(Tenure_Months AS FLOAT)/12
		) OVER(PARTITION BY Location, Gender) AS avg_tenure_years
FROM DimCustomer
WHERE CustomerID IN (SELECT CustomerID FROM rfm_cal)
ORDER BY total_customers DESC

/*Chicago is the leader and majority customers are female and they have the highest tenure years*
We can see that women purchased more than men*/

--At what time of the year customers will buy more?
ALTER TABLE FactTransactions
ADD Revenue float

UPDATE FactTransactions
SET Revenue = (Avg_Price*Quantity*(1-Discount_pct/100)) 
FROM FactTransactions ft
LEFT JOIN DimCoupon dc
	ON ft.Coupon_Code = dc.Coupon_code

SELECT
	MONTH(Transaction_Date) AS Month
	, COUNT(DISTINCT Transaction_ID) AS number_of_orders
	, ROUND(
		SUM(Revenue)
		, 2) AS value_of_orders
FROM FactTransactions
GROUP BY MONTH(Transaction_Date) 
ORDER BY value_of_orders DESC

/*can see that at the end of the year, people tend to buy more, maybe because of Chirstmas and BlackFriday*/


--top 5 product categories that generate the most revenue in each month
WITH monthlyrank AS
	(SELECT
		MONTH(Transaction_Date) AS Month
		, Product_Category
		, ROUND(
			SUM(Revenue)
			, 2) AS total_revenue
		, DENSE_RANK() OVER(PARTITION BY MONTH(Transaction_Date) ORDER BY SUM(Revenue) DESC) AS month_rank
	FROM FactTransactions ft
	LEFT JOIN DimProduct dp
		ON ft.Product_SKU = dp.Product_SKU
	GROUP BY Product_Category, MONTH(Transaction_Date))

SELECT 
	*
	, COUNT(Product_Category) OVER(PARTITION BY Product_Category) AS frequency_of_in_top_purchased
FROM monthlyrank
WHERE month_rank <= 5
ORDER BY Month, total_revenue DESC

--count how frequently customers using coupon
SELECT
	DISTINCT Coupon_Status
	, COUNT(Coupon_Status) OVER(PARTITION BY Coupon_Status) AS number_of_status
	, ROUND
		(
		CAST((COUNT(Coupon_Status) OVER(PARTITION BY Coupon_Status)) AS float) 
		/ COUNT(Coupon_Status) OVER() 
		, 2 
		) AS frequency_of_using_coupon
	, SUM(Revenue) OVER(PARTITION BY Coupon_Status) AS total_revenue
FROM FactTransactions
ORDER BY frequency_of_using_coupon

/*
As we can see, the rate of using coupon is only 30%, why is that? => the coupon code is applied to different product, some can be applied and some can not
*/
SELECT 
	Transaction_ID
	, Coupon_Status
	, Coupon_Code
	, Product_SKU
	, Revenue
FROM FactTransactions
WHERE Coupon_Status = 'Clicked'
OR Coupon_Status = 'Used'
ORDER BY Transaction_ID

--actually, most of the customers know or use the coupon code 
SELECT 
	COUNT(DISTINCT CustomerID) AS number_of_customers --find number_of_customers who knew about the coupon code
FROM FactTransactions 
WHERE Coupon_Status IN ('Used', 'Clicked')

