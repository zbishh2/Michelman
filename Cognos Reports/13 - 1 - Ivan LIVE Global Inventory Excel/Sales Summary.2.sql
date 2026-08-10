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
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDDCTO", "F4211"."SDLNID", "F4211"."SDSFXO", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDLOTN", "F4211"."SDNXTR", "F4211"."SDLTTR", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "Sales5" as (
select "T0"."C0" "Order_Company", "T0"."C1" "Branch_Plant", "T0"."C2" "Order_Number", "T0"."C3" "Order_Line", "T0"."C4" "Customer_PO", "T0"."C5" "C_2nd_Item_Number", "T0"."C6" "Lot_Number", "T0"."C7" "Hold_Orders_Code", "T0"."C8" "Last_Status", "T0"."C9" "Next_Status", "T0"."C10" "Primary_Quantity_Ordered", "T0"."C11" "Primary_UOM", "T0"."C12" "Order_Date", "T0"."C13" "Promised_Ship_Date", "T0"."C13" "Scheduled_Pick_Date", "T0"."C14" "Secondary_Quantity_Ordered", "T0"."C15" "Secondary_UOM", "T0"."C16" "Customer_Code", "T0"."C17" "Customer_Name", "T0"."C18" "Order_Type"
 from (
select "F4211_Open_Sales_Orders"."SDKCOO" "C0", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "C1", "F4211_Open_Sales_Orders"."SDDOCO" "C2", "F4211_Open_Sales_Orders"."SDLNID"/1000 "C3", trim(both
 from "F4211_Open_Sales_Orders"."SDVR01") "C4", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C5", trim(both
 from "F4211_Open_Sales_Orders"."SDLOTN") "C6", "F4201_Order_Header"."SHHOLD" "C7", "F4211_Open_Sales_Orders"."SDLTTR" "C8", "F4211_Open_Sales_Orders"."SDNXTR" "C9", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "C10", "F4211_Open_Sales_Orders"."SDUOM1" "C11", "F4211_Open_Sales_Orders"."SDTRDJ" "C12", "F4211_Open_Sales_Orders"."SDPDDJ" "C13", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "C14", "F4211_Open_Sales_Orders"."SDUOM2" "C15", "F0101_Ship_To_Customer"."ABAN8" "C16", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "C17", "F4211_Open_Sales_Orders"."SDDCTO" "C18"
 from "F4211_Open_Sales_Orders", "PRODDTA"."F4201" "F4201_Order_Header", "PRODDTA"."F0101" "F0101_Ship_To_Customer"
 where "F4211_Open_Sales_Orders"."SDPQOR"/10000>0 and "F4211_Open_Sales_Orders"."SDNXTR" not  in ('620', '999') and "F4211_Open_Sales_Orders"."SDDCTO" not  in ('ST') and "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8" and "F4211_Open_Sales_Orders"."SDKCOO"="F4201_Order_Header"."SHKCOO" and "F4211_Open_Sales_Orders"."SDDOCO"="F4201_Order_Header"."SHDOCO" and "F4211_Open_Sales_Orders"."SDDCTO"="F4201_Order_Header"."SHDCTO" and "F4211_Open_Sales_Orders"."SDSFXO"="F4201_Order_Header"."SHSFXO"
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDLNID"/1000, trim(both
 from "F4211_Open_Sales_Orders"."SDVR01"), trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), trim(both
 from "F4211_Open_Sales_Orders"."SDLOTN"), "F4201_Order_Header"."SHHOLD", "F4211_Open_Sales_Orders"."SDLTTR", "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDPDDJ", "F4211_Open_Sales_Orders"."SDUOM2", "F0101_Ship_To_Customer"."ABAN8", trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), "F4211_Open_Sales_Orders"."SDDCTO") "T0") 
select "Sales5"."Order_Company" "Order_Company", "Sales5"."Branch_Plant" "Branch_Plant", "Item6"."Global_Bulk_Item" "Global_Bulk_Item", "Item6"."Bulk_Item" "Bulk_Item", "Sales5"."C_2nd_Item_Number" "C_2nd_Item_Number", "Sales5"."Order_Number" "Order_Number", "Sales5"."Order_Line" "Order_Line", "Sales5"."Customer_PO" "Customer_PO", "Sales5"."Lot_Number" "Lot_Number", "Sales5"."Hold_Orders_Code" "Hold_Orders_Code", "Sales5"."Last_Status" "Last_Status", "Sales5"."Next_Status" "Next_Status", sum("Sales5"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "Sales5"."Primary_UOM" "Primary_UOM", sum("Sales5"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "Sales5"."Secondary_UOM" "Secondary_UOM", "Sales5"."Order_Date" "Order_Date", "Sales5"."Promised_Ship_Date" "Promised_Ship_Date", "Sales5"."Scheduled_Pick_Date" "Scheduled_Pick_Date", "Sales5"."Customer_Code" "Customer_Code", "Sales5"."Customer_Name" "Customer_Name", "Sales5"."Order_Type" "Order_Type", "Item6"."C_2nd_Item_Number" "C_2nd_Item_Number1"
 from "Item6" LEFT OUTER JOIN "Sales5" on "Item6"."Branch_Plant"="Sales5"."Branch_Plant" and "Item6"."C_2nd_Item_Number"="Sales5"."C_2nd_Item_Number"
 where "Sales5"."Branch_Plant"="Item6"."Branch_Plant" and "Sales5"."C_2nd_Item_Number"="Item6"."C_2nd_Item_Number"
 group by "Sales5"."Order_Company", "Sales5"."Branch_Plant", "Sales5"."Order_Number", "Sales5"."Order_Line", "Sales5"."Customer_PO", "Sales5"."C_2nd_Item_Number", "Sales5"."Lot_Number", "Sales5"."Hold_Orders_Code", "Sales5"."Last_Status", "Sales5"."Next_Status", "Sales5"."Primary_UOM", "Sales5"."Order_Date", "Sales5"."Promised_Ship_Date", "Sales5"."Scheduled_Pick_Date", "Sales5"."Secondary_UOM", "Sales5"."Customer_Code", "Sales5"."Customer_Name", "Sales5"."Order_Type", "Item6"."Global_Bulk_Item", "Item6"."Bulk_Item", "Item6"."C_2nd_Item_Number"
 order by "Global_Bulk_Item" asc nulls last, "Bulk_Item" asc nulls last, "C_2nd_Item_Number1" asc nulls last, "Promised_Ship_Date" asc nulls last



