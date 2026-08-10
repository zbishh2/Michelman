-- Report 16 - LTL report over 20k lbs
-- Query object: "Report"  (main F4211 open-orders query; Cognos SQL name "Report7")
-- Source: Cognos "Generated SQL.txt" (live popup, 2026-07-15) SELECT #1.
-- Byte-identical to the workbook-captured "OLD report code" (LTL.0.sql) -> this is
-- the DEPLOYED logic that runs today. LTL.0.sql is the reference copy; this
-- standard-named file is authoritative for the build.
--
-- Grain = order line (GROUP BY includes SDLNID/1000). The >20,000 filter is
-- applied PER ROW in the WHERE (pre-aggregation), so the SUM is cosmetic at this
-- grain. (Lilly's rewrite moves it to HAVING SUM(...) - a behavior change; see BUILD.md.)

select "Report7"."Order_Number" "c0", "Report7"."Order_Type" "c1", "Report7"."Carrier_AB_Number" "c2", "Report7"."Carrier_Name" "c3", "Report7"."CSR_Name" "c4", "Report7"."Primary_UOM" "c5", "Report7"."Next_Status" "c6", "Report7"."Customer_Name" "c7", "Report7"."Order_Line" "c8", "Report7"."Scheduled_Pick_Date" "c9", "Report7"."Primary_Quantity_Ordered" "c10", "Report7"."c13" "c11", "Report7"."CSR_AB_Number" "c12"
 from (
select "T0"."C0" "Order_Company", "T0"."C1" "Order_Number", "T0"."C2" "Order_Type", "T0"."C3" "Carrier_AB_Number", "T0"."C4" "Carrier_Name", "T0"."C5" "CSR_Name", "T0"."C6" "Primary_Quantity_Ordered", "T0"."C7" "Primary_UOM", "T0"."C8" "Next_Status", "T0"."C9" "Customer_Name", "T0"."C10" "Order_Line", "T0"."C11" "Scheduled_Pick_Date", "T0"."C6" "c13", "T0"."C12" "CSR_AB_Number"
 from (
select "F4211_Open_Sales_Orders"."SDKCOO" "C0", "F4211_Open_Sales_Orders"."SDDOCO" "C1", "F4211_Open_Sales_Orders"."SDDCTO" "C2", "F4211_Open_Sales_Orders"."SDCARS" "C3", "F0101_Carrier"."ABALPH" "C4", "F42140__CSR"."ABALPH" "C5", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "C6", "F4211_Open_Sales_Orders"."SDUOM1" "C7", "F4211_Open_Sales_Orders"."SDNXTR" "C8", "F0101_Ship_To_Customer"."ABALPH" "C9", "F4211_Open_Sales_Orders"."SDLNID"/1000 "C10", "F4211_Open_Sales_Orders"."SDPDDJ" "C11", "F42140__CSR"."CMSLSM" "C12"
 from (((
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDDCTO", "F4211"."SDLNID", "F4211"."SDSHAN", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDNXTR", "F4211"."SDCARS", "F4211"."SDUOM1", "F4211"."SDPQOR"
 from "PRODDTA"."F4211" "F4211") "F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") LEFT OUTER JOIN (
select "F42140"."CMAN8", "F42140"."CMSLSM", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8") "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8") LEFT OUTER JOIN "PRODDTA"."F0101" "F0101_Carrier" on "F4211_Open_Sales_Orders"."SDCARS"="F0101_Carrier"."ABAN8"
 where "F4211_Open_Sales_Orders"."SDKCOO" in ('00010') and "F4211_Open_Sales_Orders"."SDDCTO" in ('S4', 'S5', 'SZ', 'SC', 'ST') and "F4211_Open_Sales_Orders"."SDNXTR" in ('560', '550', '545', '540', '535', '530', '525') and "F4211_Open_Sales_Orders"."SDCARS" not  in ('293371', '29671', '288676', '26185', '293492', '98725', '301322', '195487', '136656', '293919', '304977', '309791', '301333', '309741', '27710', '26171', '283919', '26175', '301761', '292099', '309757', '316502') and "F4211_Open_Sales_Orders"."SDPQOR"/10000>20000 and "F4211_Open_Sales_Orders"."SDCARS"<>308636
 group by "F4211_Open_Sales_Orders"."SDKCOO", "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDDCTO", "F4211_Open_Sales_Orders"."SDCARS", "F0101_Carrier"."ABALPH", "F42140__CSR"."ABALPH", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDNXTR", "F0101_Ship_To_Customer"."ABALPH", "F4211_Open_Sales_Orders"."SDLNID"/1000, "F4211_Open_Sales_Orders"."SDPDDJ", "F42140__CSR"."CMSLSM") "T0") "Report7"
 order by "c12" asc nulls last
