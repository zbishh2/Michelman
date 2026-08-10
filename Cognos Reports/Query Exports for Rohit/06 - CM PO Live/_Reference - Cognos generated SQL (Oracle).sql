with "F4311_Purchase_Order_Details" as (
select "F4311"."PDMCU", case  when "F4311"."PDPDDJ">0 then "PRODDTA".JUL2DATE("F4311"."PDPDDJ") else NULL end  "PDPDDJ", "F4311"."PDUOPN"
 from "PRODDTA"."F4311" "F4311") 
select distinct decode(trim(both
 from "F4311_Purchase_Order_Details"."PDMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'OTHER') "REGION"
 from "F4311_Purchase_Order_Details"
 where "F4311_Purchase_Order_Details"."PDUOPN"/10000>0 and "F4311_Purchase_Order_Details"."PDPDDJ">=to_date(sysdate) - 90
 order by "REGION" asc nulls last




with "Item_Branch6" as (
select distinct trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") "Branch_Plant", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "Global_Bulk_Item", trim(both
 from "F554101_ITEM_TAG"."IMBULK") "Bulk_Item", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM") "C_2nd_Item_Number"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "F4311_Purchase_Order_Details" as (
select "F4311"."PDKCOO", "F4311"."PDDOCO", "F4311"."PDDCTO", "F4311"."PDLNID", "F4311"."PDMCU", "F4311"."PDAN8", case  when "F4311"."PDDRQJ">0 then "PRODDTA".JUL2DATE("F4311"."PDDRQJ") else NULL end  "PDDRQJ", case  when "F4311"."PDPDDJ">0 then "PRODDTA".JUL2DATE("F4311"."PDPDDJ") else NULL end  "PDPDDJ", "F4311"."PDVR02", "F4311"."PDLITM", "F4311"."PDNXTR", "F4311"."PDLTTR", "F4311"."PDPDP3", "F4311"."PDUOPN", "F4311"."PDPQOR", "F4311"."PDSQOR"
 from "PRODDTA"."F4311" "F4311"), "Purchase_Orders5" as (
select "F4311_Purchase_Order_Details"."PDKCOO" "Company", "F4311_Purchase_Order_Details"."PDDOCO" "Purchase_Order_Number", "F4311_Purchase_Order_Details"."PDDCTO" "Purchase_Order_Type", "F4311_Purchase_Order_Details"."PDLNID"/1000 "Line_Number", trim(both
 from "F4311_Purchase_Order_Details"."PDMCU") "Branch_Plant", "F4311_Purchase_Order_Details"."PDDRQJ" "Requested_Date", "F4311_Purchase_Order_Details"."PDVR02" "Reference_2", "F4311_Purchase_Order_Details"."PDPDP3" "Reporting_Code_3", trim(both
 from "F4311_Purchase_Order_Details"."PDLITM") "C_2nd_Item_Number", sum("F4311_Purchase_Order_Details"."PDSQOR"/10000) "Secondary_Quantity", sum("F4311_Purchase_Order_Details"."PDPQOR"/10000) "Primary_Quantity", "F4311_Purchase_Order_Details"."PDLTTR" "Last_Status", "F4311_Purchase_Order_Details"."PDNXTR" "Next_Status", "F4311_Purchase_Order_Details"."PDPDDJ" "Promised_Date", sum("F4311_Purchase_Order_Details"."PDUOPN"/10000) "Open_Quantity", sum("F4311_Purchase_Order_Details"."PDAN8") "Vendor_Code", trim(both
 from "F0101_Vendor_Alias_Work_Order"."ABALPH") "Vendor_Name", decode(trim(both
 from "F4311_Purchase_Order_Details"."PDMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'OTHER') "REGION"
 from "F4311_Purchase_Order_Details", "PRODDTA"."F0101" "F0101_Vendor_Alias_Work_Order"
 where "F4311_Purchase_Order_Details"."PDUOPN"/10000>0 and "F4311_Purchase_Order_Details"."PDPDDJ">=to_date(sysdate) - 90 and "F4311_Purchase_Order_Details"."PDAN8"="F0101_Vendor_Alias_Work_Order"."ABAN8"
 group by "F4311_Purchase_Order_Details"."PDKCOO", "F4311_Purchase_Order_Details"."PDDOCO", "F4311_Purchase_Order_Details"."PDDCTO", "F4311_Purchase_Order_Details"."PDLNID"/1000, trim(both
 from "F4311_Purchase_Order_Details"."PDMCU"), "F4311_Purchase_Order_Details"."PDDRQJ", "F4311_Purchase_Order_Details"."PDVR02", "F4311_Purchase_Order_Details"."PDPDP3", trim(both
 from "F4311_Purchase_Order_Details"."PDLITM"), "F4311_Purchase_Order_Details"."PDLTTR", "F4311_Purchase_Order_Details"."PDNXTR", "F4311_Purchase_Order_Details"."PDPDDJ", trim(both
 from "F0101_Vendor_Alias_Work_Order"."ABALPH"), decode(trim(both
 from "F4311_Purchase_Order_Details"."PDMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'OTHER')) 
select "Purchase_Orders5"."Company" "Company", "Purchase_Orders5"."Branch_Plant" "Branch_Plant", "Purchase_Orders5"."Purchase_Order_Number" "Purchase_Order_Number", "Purchase_Orders5"."Line_Number" "Line_Number", "Item_Branch6"."Bulk_Item" "Bulk_Item", "Purchase_Orders5"."C_2nd_Item_Number" "C_2nd_Item_Number", sum("Purchase_Orders5"."Primary_Quantity") "Primary_Quantity", sum("Purchase_Orders5"."Open_Quantity") "Open_Quantity", sum("Purchase_Orders5"."Secondary_Quantity") "Secondary_Quantity", "Purchase_Orders5"."Next_Status" "Next_Status", "Purchase_Orders5"."Requested_Date" "Requested_Date", "Purchase_Orders5"."Promised_Date" "Promised_Date", "Purchase_Orders5"."Vendor_Name" "Vendor_Name"
 from "Item_Branch6" LEFT OUTER JOIN "Purchase_Orders5" on "Item_Branch6"."Branch_Plant"="Purchase_Orders5"."Branch_Plant" and "Item_Branch6"."C_2nd_Item_Number"="Purchase_Orders5"."C_2nd_Item_Number"
 where "Purchase_Orders5"."Branch_Plant"="Item_Branch6"."Branch_Plant" and "Purchase_Orders5"."C_2nd_Item_Number"="Item_Branch6"."C_2nd_Item_Number" and "Item_Branch6"."Bulk_Item" in ('161017CX', '161190PX', '171143PX', '171228PX.E', '181020CX.E', '181136IX', '181192IX', '181193EU.E', '191011CX', '191026CX.E', '191245PX', '23409A', 'ABEX2525', 'APT10', 'APT11', 'DMAEMA', 'EMA3065', 'ET2012.E', 'ET2022.E', 'ET4075.E', 'ET440.E', 'FERSUL7W', 'HP1432AT', 'HP1632', 'MD4020', 'MD4020C', 'MD4020S', 'MD4021', 'MD4021C', 'MD4021S', 'MD4022', 'MD4022C', 'MD4023', 'MD4023C', 'MDU20', 'MDU2012.E', 'MDU2012B.E', 'MDU4075.E', 'MDU4075B.E', 'MDU440.E', 'MDU440B.E', 'MPEG2000', 'MW40504', 'MW40514', 'NP4LF', 'NP4LF.S', 'OMS', 'PUD1.E', 'STODSO', 'U1001', 'U101', 'U201', 'U2022', 'U2022EU.E', 'U2023', 'U204', 'U204EU.E', 'U470', 'U501', 'U501B', 'U502', 'U502.E', 'U502X1.E', 'U601', 'U701', 'U802', 'U802.E', 'WAV501', 'WD40', 'WD40T', 'DPE3500', 'JS037', 'HP401', 'HSCF410', 'UNYTEC201')
 group by "Purchase_Orders5"."Company", "Purchase_Orders5"."Purchase_Order_Number", "Purchase_Orders5"."Line_Number", "Purchase_Orders5"."Branch_Plant", "Purchase_Orders5"."Requested_Date", "Purchase_Orders5"."C_2nd_Item_Number", "Purchase_Orders5"."Next_Status", "Purchase_Orders5"."Promised_Date", "Purchase_Orders5"."Vendor_Name", "Item_Branch6"."Bulk_Item"
 order by "Promised_Date" asc nulls last
