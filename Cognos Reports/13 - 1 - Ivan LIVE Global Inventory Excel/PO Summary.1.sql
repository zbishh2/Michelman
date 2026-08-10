with "Item6" as (
select distinct trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMGBLK")) "Global_Bulk_Item", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", "F4102_Item_Branch_Alias_WO"."IBPRP1" "Commodity_Class", "F4102_Item_Branch_Alias_WO"."IBPRP2" "Sub_Class", "F4102_Item_Branch_Alias_WO"."IBPRP4" "Master_Planning_Family", "F4102_Item_Branch_Alias_WO"."IBGLPT" "GL_Category", "F4102_Item_Branch_Alias_WO"."IBVEND" "Primary_Supplier", "F4102_Item_Branch_Alias_WO"."IBSAFE"/10000 "Safety_Stock", "F4102_Item_Branch_Alias_WO"."IBLTLV" "Leadtime_Level", "F4101_Item_Master"."IMUOM1" "Primary_UOM", "F4101_Item_Master"."IMUOM2" "Secondary_UOM"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "F4311_Purchase_Order_Details" as (
select "F4311"."PDKCOO", "F4311"."PDDOCO", "F4311"."PDDCTO", "F4311"."PDMCU", "F4311"."PDAN8", case  when "F4311"."PDDRQJ">0 then "PRODDTA".JUL2DATE("F4311"."PDDRQJ") else NULL end  "PDDRQJ", case  when "F4311"."PDPDDJ">0 then "PRODDTA".JUL2DATE("F4311"."PDPDDJ") else NULL end  "PDPDDJ", "F4311"."PDVR02", "F4311"."PDLITM", "F4311"."PDNXTR", "F4311"."PDLTTR", "F4311"."PDPDP3", "F4311"."PDUOPN", "F4311"."PDPQOR", "F4311"."PDSQOR", NVL(trim(both
 from "F4311"."PDUNCD"), '-') "PDUNCD"
 from "PRODDTA"."F4311" "F4311"), "Purchase_Orders5" as (
select "F4311_Purchase_Order_Details"."PDKCOO" "Company", trim(both
 from "F4311_Purchase_Order_Details"."PDMCU") "Branch_Plant", trim(both
 from "F4311_Purchase_Order_Details"."PDLITM") "C_2nd_Item_Number", "F4311_Purchase_Order_Details"."PDDOCO" "Purchase_Order_Number", "F4311_Purchase_Order_Details"."PDDCTO" "Purchase_Order_Type", "F4311_Purchase_Order_Details"."PDDRQJ" "Requested_Date", "F4311_Purchase_Order_Details"."PDVR02" "Reference_2", "F4311_Purchase_Order_Details"."PDPDP3" "Reporting_Code_3", sum("F4311_Purchase_Order_Details"."PDUOPN"/10000) "Open_Quantity", sum("F4311_Purchase_Order_Details"."PDPQOR"/10000) "Primary_Quantity", sum("F4311_Purchase_Order_Details"."PDSQOR"/10000) "Secondary_Quantity", "F4311_Purchase_Order_Details"."PDLTTR" "Last_Status", "F4311_Purchase_Order_Details"."PDNXTR" "Next_Status", "F4311_Purchase_Order_Details"."PDPDDJ" "Promised_Date", sum("F4311_Purchase_Order_Details"."PDAN8") "Vendor_Code", trim(both
 from "F0101_Vendor_Alias_Work_Order"."ABALPH") "Vendor_Name", "F4311_Purchase_Order_Details"."PDUNCD" "Freeze_Code_Flag"
 from "F4311_Purchase_Order_Details", "PRODDTA"."F0101" "F0101_Vendor_Alias_Work_Order"
 where "F4311_Purchase_Order_Details"."PDPDDJ">=to_date(sysdate) - 365 and "F4311_Purchase_Order_Details"."PDDCTO"=N'OP' and "F4311_Purchase_Order_Details"."PDAN8"="F0101_Vendor_Alias_Work_Order"."ABAN8"
 group by "F4311_Purchase_Order_Details"."PDKCOO", trim(both
 from "F4311_Purchase_Order_Details"."PDMCU"), trim(both
 from "F4311_Purchase_Order_Details"."PDLITM"), "F4311_Purchase_Order_Details"."PDDOCO", "F4311_Purchase_Order_Details"."PDDCTO", "F4311_Purchase_Order_Details"."PDDRQJ", "F4311_Purchase_Order_Details"."PDVR02", "F4311_Purchase_Order_Details"."PDPDP3", "F4311_Purchase_Order_Details"."PDLTTR", "F4311_Purchase_Order_Details"."PDNXTR", "F4311_Purchase_Order_Details"."PDPDDJ", trim(both
 from "F0101_Vendor_Alias_Work_Order"."ABALPH"), "F4311_Purchase_Order_Details"."PDUNCD") 
select "Purchase_Orders5"."Company" "Company", "Purchase_Orders5"."Branch_Plant" "Branch_Plant", "Purchase_Orders5"."C_2nd_Item_Number" "C_2nd_Item_Number", "Purchase_Orders5"."Purchase_Order_Number" "Purchase_Order_Number", "Purchase_Orders5"."Reference_2" "Reference_2", "Purchase_Orders5"."Reporting_Code_3" "Reporting_Code_3", sum("Purchase_Orders5"."Open_Quantity") "Open_Quantity", sum("Purchase_Orders5"."Primary_Quantity") "Primary_Quantity", "Item6"."Primary_UOM" "Primary_UOM", sum("Purchase_Orders5"."Secondary_Quantity") "Secondary_Quantity", "Item6"."Secondary_UOM" "Secondary_UOM", "Purchase_Orders5"."Last_Status" "Last_Status", "Purchase_Orders5"."Next_Status" "Next_Status", "Purchase_Orders5"."Requested_Date" "Requested_Date", "Purchase_Orders5"."Promised_Date" "Promised_Date", sum("Purchase_Orders5"."Vendor_Code") "Vendor_Code", "Purchase_Orders5"."Vendor_Name" "Vendor_Name", "Purchase_Orders5"."Freeze_Code_Flag" "Freeze_Code_Flag", "Item6"."Branch_Plant" "Branch_Plant1", "Item6"."Global_Bulk_Item" "Global_Bulk_Item", "Item6"."Bulk_Item" "Bulk_Item", "Item6"."C_2nd_Item_Number" "C_2nd_Item_Number1", "Item6"."Commodity_Class" "Commodity_Class", "Item6"."Sub_Class" "Sub_Class", "Item6"."Master_Planning_Family" "Master_Planning_Family", "Item6"."GL_Category" "GL_Category", "Item6"."Primary_Supplier" "Primary_Supplier", "Item6"."Safety_Stock" "Safety_Stock", "Item6"."Leadtime_Level" "Leadtime_Level"
 from "Item6" LEFT OUTER JOIN "Purchase_Orders5" on "Item6"."Branch_Plant"="Purchase_Orders5"."Branch_Plant" and "Item6"."C_2nd_Item_Number"="Purchase_Orders5"."C_2nd_Item_Number"
 where "Purchase_Orders5"."Branch_Plant"="Item6"."Branch_Plant" and "Purchase_Orders5"."C_2nd_Item_Number"="Item6"."C_2nd_Item_Number"
 group by "Purchase_Orders5"."Company", "Purchase_Orders5"."Branch_Plant", "Purchase_Orders5"."C_2nd_Item_Number", "Purchase_Orders5"."Purchase_Order_Number", "Purchase_Orders5"."Requested_Date", "Purchase_Orders5"."Reference_2", "Purchase_Orders5"."Reporting_Code_3", "Purchase_Orders5"."Last_Status", "Purchase_Orders5"."Next_Status", "Purchase_Orders5"."Promised_Date", "Purchase_Orders5"."Vendor_Name", "Purchase_Orders5"."Freeze_Code_Flag", "Item6"."Branch_Plant", "Item6"."Global_Bulk_Item", "Item6"."Bulk_Item", "Item6"."C_2nd_Item_Number", "Item6"."Commodity_Class", "Item6"."Sub_Class", "Item6"."Master_Planning_Family", "Item6"."GL_Category", "Item6"."Primary_Supplier", "Item6"."Safety_Stock", "Item6"."Leadtime_Level", "Item6"."Primary_UOM", "Item6"."Secondary_UOM"



