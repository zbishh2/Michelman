select distinct decode(trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'BPIP', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'Americas') "REGION"
 from "PRODDTA"."F4211" "F4211_Open_Sales_Orders"
 where "F4211_Open_Sales_Orders"."SDNXTR" not  in ('999')
 order by "REGION" asc nulls last




with "Item_Branch7" as (
select distinct trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") "Branch_Plant", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "Global_Bulk_Item", trim(both
 from "F554101_ITEM_TAG"."IMBULK") "Bulk_Item", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM") "C_2nd_Item_Number"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDDCTO", "F4211"."SDLNID", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDDRQJ">0 then "PRODDTA".JUL2DATE("F4211"."SDDRQJ") else NULL end  "SDDRQJ", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDNXTR", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "F4211_F0006_join_to_F42140" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDDCTO", "F4211"."SDLNID", "F4211"."SDSHAN", case  when NVL(trim(both
 from "F0006"."MCRP01"), '-') is null  then  null  else NVL(trim(both
 from "F0006"."MCRP01"), '-') || 'GTM' end  "CMRTYPE"
 from "PRODDTA"."F4211" "F4211" LEFT OUTER JOIN "PRODDTA"."F0006" "F0006" on "F4211"."SDEMCU"="F0006"."MCMCU"), "Sales_Orders6" as (
select "F4211_Open_Sales_Orders"."SDKCOO" "Order_Company", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "Branch_Plant", "F4211_Open_Sales_Orders"."SDDOCO" "Order_Number", "F4211_Open_Sales_Orders"."SDLNID"/1000 "Order_Line", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C_2nd_Item_Number", "F4211_Open_Sales_Orders"."SDNXTR" "Next_Status", "F4211_Open_Sales_Orders"."SDTRDJ" "Order_Date", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "Primary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM1" "Primary_UOM", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "Secondary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM2" "Secondary_UOM", "F4211_Open_Sales_Orders"."SDDRQJ" "Requested_Date", "F4211_Open_Sales_Orders"."SDPDDJ" "Promised_Ship_Date", trim(both
 from decode("F0101_Sales_Rep"."ABALPH", NULL, 'Unassigned', "F0101_Sales_Rep"."ABALPH")) "TM_Name", trim(both
 from "F4211_Open_Sales_Orders"."SDVR01") "Customer_PO", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "Customer_Name", decode(trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'BPIP', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'Americas') "REGION"
 from (("F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") LEFT OUTER JOIN "F4211_F0006_join_to_F42140" on "F4211_Open_Sales_Orders"."SDKCOO"="F4211_F0006_join_to_F42140"."SDKCOO" and "F4211_Open_Sales_Orders"."SDDOCO"="F4211_F0006_join_to_F42140"."SDDOCO" and "F4211_Open_Sales_Orders"."SDDCTO"="F4211_F0006_join_to_F42140"."SDDCTO" and "F4211_Open_Sales_Orders"."SDLNID"="F4211_F0006_join_to_F42140"."SDLNID") LEFT OUTER JOIN ("PRODDTA"."F42140" "F42140_Sales_Rep" INNER JOIN "PRODDTA"."F0101" "F0101_Sales_Rep" on "F42140_Sales_Rep"."CMSLSM"="F0101_Sales_Rep"."ABAN8") on "F4211_F0006_join_to_F42140"."SDSHAN"="F42140_Sales_Rep"."CMAN8" and "F4211_F0006_join_to_F42140"."CMRTYPE"="F42140_Sales_Rep"."CMRTYPE"
 where "F4211_Open_Sales_Orders"."SDNXTR" not  in ('999')
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDLNID"/1000, trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDUOM2", "F4211_Open_Sales_Orders"."SDDRQJ", "F4211_Open_Sales_Orders"."SDPDDJ", trim(both
 from decode("F0101_Sales_Rep"."ABALPH", NULL, 'Unassigned', "F0101_Sales_Rep"."ABALPH")), trim(both
 from "F4211_Open_Sales_Orders"."SDVR01"), trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), decode(trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'BPIP', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'Americas')) 
select "Sales_Orders6"."Order_Company" "Order_Company", "Sales_Orders6"."Branch_Plant" "Branch_Plant", "Sales_Orders6"."Order_Number" "Order_Number", "Sales_Orders6"."Order_Line" "Order_Line", "Sales_Orders6"."Customer_PO" "Customer_PO", "Sales_Orders6"."Order_Date" "Order_Date", "Sales_Orders6"."Requested_Date" "Requested_Date", "Sales_Orders6"."Promised_Ship_Date" "Promised_Ship_Date", "Sales_Orders6"."C_2nd_Item_Number" "C_2nd_Item_Number", "Sales_Orders6"."Next_Status" "Next_Status", sum("Sales_Orders6"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "Sales_Orders6"."Primary_UOM" "Primary_UOM", sum("Sales_Orders6"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "Sales_Orders6"."Secondary_UOM" "Secondary_UOM", "Sales_Orders6"."Customer_Name" "Customer_Name", "Sales_Orders6"."TM_Name" "TM_Name"
 from "Item_Branch7" LEFT OUTER JOIN "Sales_Orders6" on "Item_Branch7"."C_2nd_Item_Number"="Sales_Orders6"."C_2nd_Item_Number" and "Item_Branch7"."Branch_Plant"="Sales_Orders6"."Branch_Plant"
 where "Sales_Orders6"."Branch_Plant"="Item_Branch7"."Branch_Plant" and "Sales_Orders6"."C_2nd_Item_Number"="Item_Branch7"."C_2nd_Item_Number" and "Item_Branch7"."Bulk_Item" in ('161017CX', '161190PX', '171143PX', '171228PX.E', '181020CX.E', '181136IX', '181192IX', '181193EU.E', '191011CX', '191026CX.E', '191245PX', '23409A', 'ABEX2525', 'APT10', 'APT11', 'DMAEMA', 'EMA3065', 'ET2012.E', 'ET2022.E', 'ET4075.E', 'ET440.E', 'FERSUL7W', 'HP1432AT', 'HP1632', 'MD4020', 'MD4020C', 'MD4020S', 'MD4021', 'MD4021C', 'MD4021S', 'MD4022', 'MD4022C', 'MD4023', 'MD4023C', 'MDU20', 'MDU2012.E', 'MDU2012B.E', 'MDU4075.E', 'MDU4075B.E', 'MDU440.E', 'MDU440B.E', 'MPEG2000', 'MW40504', 'MW40514', 'NP4LF', 'NP4LF.S', 'OMS', 'PUD1.E', 'STODSO', 'U1001', 'U101', 'U201', 'U2022', 'U2022EU.E', 'U2023', 'U204', 'U204EU.E', 'U470', 'U501', 'U501B', 'U502', 'U502.E', 'U502X1.E', 'U601', 'U701', 'U802', 'U802.E', 'WAV501', 'WD40', 'WD40T', 'DPE3500', 'DPE3500.E', 'JS037', 'HP401', 'HSCF410', 'UNYTEC201')
 group by "Sales_Orders6"."Order_Company", "Sales_Orders6"."Branch_Plant", "Sales_Orders6"."Order_Number", "Sales_Orders6"."Order_Line", "Sales_Orders6"."C_2nd_Item_Number", "Sales_Orders6"."Next_Status", "Sales_Orders6"."Order_Date", "Sales_Orders6"."Primary_UOM", "Sales_Orders6"."Secondary_UOM", "Sales_Orders6"."Requested_Date", "Sales_Orders6"."Promised_Ship_Date", "Sales_Orders6"."TM_Name", "Sales_Orders6"."Customer_PO", "Sales_Orders6"."Customer_Name"
 order by "Promised_Ship_Date" asc nulls last, "Order_Number" asc nulls last, "Order_Line" asc nulls last
