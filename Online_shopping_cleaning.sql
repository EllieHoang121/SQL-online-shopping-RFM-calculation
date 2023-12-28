USE project

-- take a look at the dataset
SELECT 
	COLUMN_NAME
	, IS_NULLABLE
	, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'online_shopping'

/*
Create Dim tables to reduce the size of the dataset (star schema)
Create Dim_customer
*/
SELECT DISTINCT 
	CustomerID
	, Gender
	, Location
	, Tenure_Months
INTO DimCustomer
FROM online_shopping
ORDER BY CustomerID

SELECT * 
FROM DimCustomer

--check the data integrity (null values or incorrect syntax values)
SELECT 
	Gender
	, COUNT(Gender)
FROM DimCustomer
GROUP BY Gender

SELECT 
	Location
	, COUNT(Location)
FROM DimCustomer
GROUP BY Location

/*
Create DimProduct
*/
SELECT DISTINCT 
	Product_SKU
	, Product_Description
	, Product_Category
INTO DimProduct
FROM online_shopping
ORDER BY Product_SKU

--check the data integrity (null values or incorrect syntax values)
SELECT 
	Product_Description
	, COUNT(Product_Description)
FROM DimProduct
GROUP BY Product_Description

SELECT 
	Product_Category
	, COUNT(Product_Category)
FROM DimProduct
GROUP BY Product_Category

/*
Create DimCoupon
*/
SELECT DISTINCT 
	Coupon_code
	, Discount_pct
INTO DimCoupon
FROM online_shopping
ORDER BY Coupon_Code
 
SELECT *
FROM DimCoupon

/*
Create FactTransaction which contains all transaction values
*/
SELECT
	Transaction_ID
	, Transaction_Date
	, CustomerID
	, Product_SKU
	, Quantity
	, Coupon_Status
	, Coupon_Code
	, Avg_Price
	, Delivery_Charges
	, Online_Spend
	, Offline_Spend 
INTO FactTransactions
FROM online_shopping
ORDER BY Transaction_Date

--Round the Avg__Price and Delivery_Charges into 2 decimal places
UPDATE FactTransactions
SET Avg_Price = ROUND(Avg_Price, 2)
	, Delivery_Charges = ROUND(Delivery_Charges, 2)
	, Online_Spend = ROUND(Online_Spend, 2)
	, Offline_Spend = ROUND(Offline_Spend, 2)



