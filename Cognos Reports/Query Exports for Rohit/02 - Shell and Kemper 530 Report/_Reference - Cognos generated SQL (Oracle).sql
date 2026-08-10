with "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDLNID", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDDRQJ">0 then "PRODDTA".JUL2DATE("F4211"."SDDRQJ") else NULL end  "SDDRQJ", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDDSC1", "F4211"."SDNXTR", "F4211"."SDLTTR", "F4211"."SDPRP4", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "F42140__CSR" as (
select "F42140"."CMAN8", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8"), "MAIN8" as (
select "F4211_Open_Sales_Orders"."SDKCOO" "Order_Company", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "Branch_Plant", trim(both
 from "F42140__CSR"."ABALPH") "CSR_Name", "F4211_Open_Sales_Orders"."SDDOCO" "Order_Number", "F4211_Open_Sales_Orders"."SDLNID"/1000 "Order_Line", "F4211_Open_Sales_Orders"."SDVR01" "Customer_PO", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "Customer_Name", trim(both
 from "F0101_Ship_To_Customer"."ABAC06") "Customer_Segmentation", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C_2nd_Item_Number", "F4211_Open_Sales_Orders"."SDLTTR" "Last_Status", "F4211_Open_Sales_Orders"."SDNXTR" "Next_Status", "F4211_Open_Sales_Orders"."SDTRDJ" "Order_Date", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "Primary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM1" "Primary_UOM", "F4211_Open_Sales_Orders"."SDDRQJ" "Requested_Date", "F4211_Open_Sales_Orders"."SDPDDJ" "Promised_Ship_Date", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "Secondary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM2" "Secondary_UOM", "F4211_Open_Sales_Orders"."SDPRP4" "MPF", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") "Description_1"
 from ("F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") LEFT OUTER JOIN "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8"
 where "F4211_Open_Sales_Orders"."SDNXTR" in ('525', '530', '535', '540', '545', '550') and "F4211_Open_Sales_Orders"."SDKCOO"='00010'
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), trim(both
 from "F42140__CSR"."ABALPH"), "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDLNID"/1000, "F4211_Open_Sales_Orders"."SDVR01", trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), trim(both
 from "F0101_Ship_To_Customer"."ABAC06"), trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), "F4211_Open_Sales_Orders"."SDLTTR", "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDDRQJ", "F4211_Open_Sales_Orders"."SDPDDJ", "F4211_Open_Sales_Orders"."SDUOM2", "F4211_Open_Sales_Orders"."SDPRP4", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1")), "ITEM9" as (
select distinct trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", "F4102_Item_Branch_Alias_WO"."IBANPL" "Planner"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "Main_w_Bulk12" as (
select "MAIN8"."Order_Company" "Order_Company", "MAIN8"."Branch_Plant" "Branch_Plant", "MAIN8"."CSR_Name" "CSR_Name", "MAIN8"."Order_Number" "Order_Number", "MAIN8"."Order_Line" "Order_Line", "MAIN8"."Customer_PO" "Customer_PO", "MAIN8"."Customer_Name" "Customer_Name", "MAIN8"."Customer_Segmentation" "Customer_Segmentation", "MAIN8"."C_2nd_Item_Number" "C_2nd_Item_Number", "MAIN8"."Last_Status" "Last_Status", "MAIN8"."Next_Status" "Next_Status", "MAIN8"."Order_Date" "Order_Date", sum("MAIN8"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "MAIN8"."Primary_UOM" "Primary_UOM", "MAIN8"."Requested_Date" "Requested_Date", "MAIN8"."Promised_Ship_Date" "Promised_Ship_Date", sum("MAIN8"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "MAIN8"."Secondary_UOM" "Secondary_UOM", "MAIN8"."MPF" "MPF", "MAIN8"."Description_1" "Description_1", "ITEM9"."Branch_Plant" "Branch_Plant1", "ITEM9"."Bulk_Item" "Bulk_Item", "ITEM9"."C_2nd_Item_Number" "C_2nd_Item_Number1", "ITEM9"."Planner" "Planner"
 from "MAIN8", "ITEM9"
 where "MAIN8"."Branch_Plant"="ITEM9"."Branch_Plant" and "MAIN8"."C_2nd_Item_Number"="ITEM9"."C_2nd_Item_Number"
 group by "MAIN8"."Order_Company", "MAIN8"."Branch_Plant", "MAIN8"."CSR_Name", "MAIN8"."Order_Number", "MAIN8"."Order_Line", "MAIN8"."Customer_PO", "MAIN8"."Customer_Name", "MAIN8"."Customer_Segmentation", "MAIN8"."C_2nd_Item_Number", "MAIN8"."Last_Status", "MAIN8"."Next_Status", "MAIN8"."Order_Date", "MAIN8"."Primary_UOM", "MAIN8"."Requested_Date", "MAIN8"."Promised_Ship_Date", "MAIN8"."Secondary_UOM", "MAIN8"."MPF", "MAIN8"."Description_1", "ITEM9"."Branch_Plant", "ITEM9"."Bulk_Item", "ITEM9"."C_2nd_Item_Number", "ITEM9"."Planner"), "F3312_Capacity_Pegging" as (
select "F3312"."CWCAPM", "F3312"."CWMCU", "F3312"."CWITM", "F3312"."CWMMCU", "F3312"."CWDRQJ" "CWDRQJ_ORIG", decode("F3312"."CWDRQJ", 0, NULL, 1, 'EARLY DATE 1', 2, 'EARLY DATE 2', TO_CHAR("PRODDTA".JUL2DATE("F3312"."CWDRQJ"), 'MM/DD/YYYY')) "CWDRQJ", "F3312"."CWTRQT"/10000 "CWTRQT", "F3312"."CWUORG"/10000 "CWUORG", "F3312"."CWDOCO", "F3312"."CWWMCU"
 from "PRODDTA"."F3312" "F3312"), "F3313_Capacity_Load_Table" as (
select "F3313"."CRCAPM", "F3313"."CRMCU", "F3313"."CRCQT", "F3313"."CRSTRT" "CRSTRT_ORIG", "F3313"."CRTRQT"/10000 "CRTRQT", "F3313"."CRWMCU"
 from "PRODDTA"."F3313" "F3313"), "Routing13" as (
select "T0"."C0" "Item_Branch", "T0"."C1" "C_2nd_Item_Number", "T0"."C2" "Work_Center", "T0"."C3" "Julian_Period_End_Date", "T0"."C4" "Period_End_Date", "T0"."C5" "Julian_Period_Date", "T0"."C6" "Transaction_Quantity", "T0"."C7" "Capacity_Type", "T0"."C8" "Capacity_Mode", "T0"."C9" "Work_Center1", "T0"."C1" "C_2nd_Item_Number1", "T0"."C10" "Item_Branch1", "T0"."C3" "Julian_Period_End_Date1", "T0"."C4" "Period_End_Date1", "T0"."C11" "Units", "T0"."C12" "Ordered_Quantity", "T0"."C13" "WO_Number"
 from (
select trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") "C0", trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") "C1", trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) "C2", "F3312_Capacity_Pegging"."CWDRQJ_ORIG" "C3", "F3312_Capacity_Pegging"."CWDRQJ" "C4", "F3313_Capacity_Load_Table"."CRSTRT_ORIG" "C5", "F3313_Capacity_Load_Table"."CRTRQT" "C6", "F3313_Capacity_Load_Table"."CRCQT" "C7", "F3312_Capacity_Pegging"."CWCAPM" "C8", trim(both
 from "F3312_Capacity_Pegging"."CWMCU") "C9", "F3312_Capacity_Pegging"."CWMMCU" "C10", sum("F3312_Capacity_Pegging"."CWTRQT") "C11", sum("F3312_Capacity_Pegging"."CWUORG") "C12", "F3312_Capacity_Pegging"."CWDOCO" "C13"
 from "F3312_Capacity_Pegging", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_CapPeg", "F3313_Capacity_Load_Table"
 where trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") in ('CINC', 'CIN2') and trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") not  like '%-%' and trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) in ('SREC23', 'SREC37', 'SREC48', 'SREC72', 'SREC130', 'SDMD', 'SPEC', 'SPREC', 'SECG', 'SE2', 'SCOLD', 'SPDMD', 'SPCOLD', 'SLAB', 'SRENAME', 'SREPACK', 'SHILDA', 'KLAB', 'KBB', 'KSB', 'KWG', 'KBOT', 'KREPACK', 'KRENAME') and to_date(1900000+decode("F3312_Capacity_Pegging"."CWDRQJ_ORIG", 0, 1, "F3312_Capacity_Pegging"."CWDRQJ_ORIG"), 'YYYYDDD')>(sysdate+30)+1 and "F3312_Capacity_Pegging"."CWDOCO"=0 and "F3312_Capacity_Pegging"."CWMCU"="F3313_Capacity_Load_Table"."CRMCU" and "F3312_Capacity_Pegging"."CWCAPM"="F3313_Capacity_Load_Table"."CRCAPM" and "F3312_Capacity_Pegging"."CWDRQJ_ORIG"="F3313_Capacity_Load_Table"."CRSTRT_ORIG" and "F3312_Capacity_Pegging"."CWWMCU"="F3313_Capacity_Load_Table"."CRWMCU" and "F3312_Capacity_Pegging"."CWITM"="F4102_Item_Branch_Alias_CapPeg"."IBITM" and "F3312_Capacity_Pegging"."CWWMCU"="F4102_Item_Branch_Alias_CapPeg"."IBMCU"
 group by trim(both
 from "F3312_Capacity_Pegging"."CWMMCU"), trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM"), trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")), "F3312_Capacity_Pegging"."CWDRQJ_ORIG", "F3312_Capacity_Pegging"."CWDRQJ", "F3313_Capacity_Load_Table"."CRSTRT_ORIG", "F3313_Capacity_Load_Table"."CRTRQT", "F3313_Capacity_Load_Table"."CRCQT", "F3312_Capacity_Pegging"."CWCAPM", trim(both
 from "F3312_Capacity_Pegging"."CWMCU"), "F3312_Capacity_Pegging"."CWMMCU", "F3312_Capacity_Pegging"."CWDOCO") "T0") 
select sum(case  when decode("Main_w_Bulk12"."Planner", '324363', 'Eric', '20444', 'Eric', '20445', 'Lance', '291740', 'Mark Tilley', '328907', 'Lance', '333530', 'Lance', '316775', 'Lance', '334927', 'Tammy', '290808', 'David Kramer', '335951', 'Lance', '300021', 'Tammy', '324287', 'Brent', 'ERROR')='ERROR' then 1 else 0 end ) "COUNT_ERROR"
 from "Main_w_Bulk12" FULL OUTER JOIN "Routing13" on "Main_w_Bulk12"."Bulk_Item"="Routing13"."C_2nd_Item_Number"
 where not "Main_w_Bulk12"."C_2nd_Item_Number" is null and "Main_w_Bulk12"."Next_Status"='530'
 having count(*)>0


with "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDLNID", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDDRQJ">0 then "PRODDTA".JUL2DATE("F4211"."SDDRQJ") else NULL end  "SDDRQJ", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDDSC1", "F4211"."SDNXTR", "F4211"."SDLTTR", "F4211"."SDPRP4", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "F42140__CSR" as (
select "F42140"."CMAN8", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8"), "MAIN8" as (
select "F4211_Open_Sales_Orders"."SDKCOO" "Order_Company", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "Branch_Plant", trim(both
 from "F42140__CSR"."ABALPH") "CSR_Name", "F4211_Open_Sales_Orders"."SDDOCO" "Order_Number", "F4211_Open_Sales_Orders"."SDLNID"/1000 "Order_Line", "F4211_Open_Sales_Orders"."SDVR01" "Customer_PO", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "Customer_Name", trim(both
 from "F0101_Ship_To_Customer"."ABAC06") "Customer_Segmentation", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C_2nd_Item_Number", "F4211_Open_Sales_Orders"."SDLTTR" "Last_Status", "F4211_Open_Sales_Orders"."SDNXTR" "Next_Status", "F4211_Open_Sales_Orders"."SDTRDJ" "Order_Date", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "Primary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM1" "Primary_UOM", "F4211_Open_Sales_Orders"."SDDRQJ" "Requested_Date", "F4211_Open_Sales_Orders"."SDPDDJ" "Promised_Ship_Date", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "Secondary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM2" "Secondary_UOM", "F4211_Open_Sales_Orders"."SDPRP4" "MPF", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") "Description_1"
 from ("F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") LEFT OUTER JOIN "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8"
 where "F4211_Open_Sales_Orders"."SDNXTR" in ('525', '530', '535', '540', '545', '550') and "F4211_Open_Sales_Orders"."SDKCOO"='00010'
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), trim(both
 from "F42140__CSR"."ABALPH"), "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDLNID"/1000, "F4211_Open_Sales_Orders"."SDVR01", trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), trim(both
 from "F0101_Ship_To_Customer"."ABAC06"), trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), "F4211_Open_Sales_Orders"."SDLTTR", "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDDRQJ", "F4211_Open_Sales_Orders"."SDPDDJ", "F4211_Open_Sales_Orders"."SDUOM2", "F4211_Open_Sales_Orders"."SDPRP4", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1")), "ITEM9" as (
select distinct trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", "F4102_Item_Branch_Alias_WO"."IBANPL" "Planner"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "Main_w_Bulk12" as (
select "MAIN8"."Order_Company" "Order_Company", "MAIN8"."Branch_Plant" "Branch_Plant", "MAIN8"."CSR_Name" "CSR_Name", "MAIN8"."Order_Number" "Order_Number", "MAIN8"."Order_Line" "Order_Line", "MAIN8"."Customer_PO" "Customer_PO", "MAIN8"."Customer_Name" "Customer_Name", "MAIN8"."Customer_Segmentation" "Customer_Segmentation", "MAIN8"."C_2nd_Item_Number" "C_2nd_Item_Number", "MAIN8"."Last_Status" "Last_Status", "MAIN8"."Next_Status" "Next_Status", "MAIN8"."Order_Date" "Order_Date", sum("MAIN8"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "MAIN8"."Primary_UOM" "Primary_UOM", "MAIN8"."Requested_Date" "Requested_Date", "MAIN8"."Promised_Ship_Date" "Promised_Ship_Date", sum("MAIN8"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "MAIN8"."Secondary_UOM" "Secondary_UOM", "MAIN8"."MPF" "MPF", "MAIN8"."Description_1" "Description_1", "ITEM9"."Branch_Plant" "Branch_Plant1", "ITEM9"."Bulk_Item" "Bulk_Item", "ITEM9"."C_2nd_Item_Number" "C_2nd_Item_Number1", "ITEM9"."Planner" "Planner"
 from "MAIN8", "ITEM9"
 where "MAIN8"."Branch_Plant"="ITEM9"."Branch_Plant" and "MAIN8"."C_2nd_Item_Number"="ITEM9"."C_2nd_Item_Number"
 group by "MAIN8"."Order_Company", "MAIN8"."Branch_Plant", "MAIN8"."CSR_Name", "MAIN8"."Order_Number", "MAIN8"."Order_Line", "MAIN8"."Customer_PO", "MAIN8"."Customer_Name", "MAIN8"."Customer_Segmentation", "MAIN8"."C_2nd_Item_Number", "MAIN8"."Last_Status", "MAIN8"."Next_Status", "MAIN8"."Order_Date", "MAIN8"."Primary_UOM", "MAIN8"."Requested_Date", "MAIN8"."Promised_Ship_Date", "MAIN8"."Secondary_UOM", "MAIN8"."MPF", "MAIN8"."Description_1", "ITEM9"."Branch_Plant", "ITEM9"."Bulk_Item", "ITEM9"."C_2nd_Item_Number", "ITEM9"."Planner"), "F3312_Capacity_Pegging" as (
select "F3312"."CWCAPM", "F3312"."CWMCU", "F3312"."CWITM", "F3312"."CWMMCU", "F3312"."CWDRQJ" "CWDRQJ_ORIG", decode("F3312"."CWDRQJ", 0, NULL, 1, 'EARLY DATE 1', 2, 'EARLY DATE 2', TO_CHAR("PRODDTA".JUL2DATE("F3312"."CWDRQJ"), 'MM/DD/YYYY')) "CWDRQJ", "F3312"."CWTRQT"/10000 "CWTRQT", "F3312"."CWUORG"/10000 "CWUORG", "F3312"."CWDOCO", "F3312"."CWWMCU"
 from "PRODDTA"."F3312" "F3312"), "F3313_Capacity_Load_Table" as (
select "F3313"."CRCAPM", "F3313"."CRMCU", "F3313"."CRCQT", "F3313"."CRSTRT" "CRSTRT_ORIG", "F3313"."CRTRQT"/10000 "CRTRQT", "F3313"."CRWMCU"
 from "PRODDTA"."F3313" "F3313"), "Routing13" as (
select "T0"."C0" "Item_Branch", "T0"."C1" "C_2nd_Item_Number", "T0"."C2" "Work_Center", "T0"."C3" "Julian_Period_End_Date", "T0"."C4" "Period_End_Date", "T0"."C5" "Julian_Period_Date", "T0"."C6" "Transaction_Quantity", "T0"."C7" "Capacity_Type", "T0"."C8" "Capacity_Mode", "T0"."C9" "Work_Center1", "T0"."C1" "C_2nd_Item_Number1", "T0"."C10" "Item_Branch1", "T0"."C3" "Julian_Period_End_Date1", "T0"."C4" "Period_End_Date1", "T0"."C11" "Units", "T0"."C12" "Ordered_Quantity", "T0"."C13" "WO_Number"
 from (
select trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") "C0", trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") "C1", trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) "C2", "F3312_Capacity_Pegging"."CWDRQJ_ORIG" "C3", "F3312_Capacity_Pegging"."CWDRQJ" "C4", "F3313_Capacity_Load_Table"."CRSTRT_ORIG" "C5", "F3313_Capacity_Load_Table"."CRTRQT" "C6", "F3313_Capacity_Load_Table"."CRCQT" "C7", "F3312_Capacity_Pegging"."CWCAPM" "C8", trim(both
 from "F3312_Capacity_Pegging"."CWMCU") "C9", "F3312_Capacity_Pegging"."CWMMCU" "C10", sum("F3312_Capacity_Pegging"."CWTRQT") "C11", sum("F3312_Capacity_Pegging"."CWUORG") "C12", "F3312_Capacity_Pegging"."CWDOCO" "C13"
 from "F3312_Capacity_Pegging", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_CapPeg", "F3313_Capacity_Load_Table"
 where trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") in ('CINC', 'CIN2') and trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") not  like '%-%' and trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) in ('SREC23', 'SREC37', 'SREC48', 'SREC72', 'SREC130', 'SDMD', 'SPEC', 'SPREC', 'SECG', 'SE2', 'SCOLD', 'SPDMD', 'SPCOLD', 'SLAB', 'SRENAME', 'SREPACK', 'SHILDA', 'KLAB', 'KBB', 'KSB', 'KWG', 'KBOT', 'KREPACK', 'KRENAME') and to_date(1900000+decode("F3312_Capacity_Pegging"."CWDRQJ_ORIG", 0, 1, "F3312_Capacity_Pegging"."CWDRQJ_ORIG"), 'YYYYDDD')>(sysdate+30)+1 and "F3312_Capacity_Pegging"."CWDOCO"=0 and "F3312_Capacity_Pegging"."CWMCU"="F3313_Capacity_Load_Table"."CRMCU" and "F3312_Capacity_Pegging"."CWCAPM"="F3313_Capacity_Load_Table"."CRCAPM" and "F3312_Capacity_Pegging"."CWDRQJ_ORIG"="F3313_Capacity_Load_Table"."CRSTRT_ORIG" and "F3312_Capacity_Pegging"."CWWMCU"="F3313_Capacity_Load_Table"."CRWMCU" and "F3312_Capacity_Pegging"."CWITM"="F4102_Item_Branch_Alias_CapPeg"."IBITM" and "F3312_Capacity_Pegging"."CWWMCU"="F4102_Item_Branch_Alias_CapPeg"."IBMCU"
 group by trim(both
 from "F3312_Capacity_Pegging"."CWMMCU"), trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM"), trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")), "F3312_Capacity_Pegging"."CWDRQJ_ORIG", "F3312_Capacity_Pegging"."CWDRQJ", "F3313_Capacity_Load_Table"."CRSTRT_ORIG", "F3313_Capacity_Load_Table"."CRTRQT", "F3313_Capacity_Load_Table"."CRCQT", "F3312_Capacity_Pegging"."CWCAPM", trim(both
 from "F3312_Capacity_Pegging"."CWMCU"), "F3312_Capacity_Pegging"."CWMMCU", "F3312_Capacity_Pegging"."CWDOCO") "T0") 
select "Main_w_Bulk12"."Promised_Ship_Date" "Promised_Ship_Date", "Main_w_Bulk12"."Requested_Date" "Requested_Date", "Main_w_Bulk12"."Branch_Plant" "Branch_Plant", "Main_w_Bulk12"."Customer_Name" "Customer_Name", "Main_w_Bulk12"."Customer_Segmentation" "Customer_Segmentation", "Main_w_Bulk12"."Order_Number" "Order_Number", "Main_w_Bulk12"."Order_Line" "Order_Line", "Main_w_Bulk12"."Bulk_Item" "Bulk_Item", "Main_w_Bulk12"."C_2nd_Item_Number" "C_2nd_Item_Number", decode("Main_w_Bulk12"."C_2nd_Item_Number", 'NEWITEMFG', "Main_w_Bulk12"."Description_1", 'NEWITEMPKG', "Main_w_Bulk12"."Description_1", ' ') "DESCRIPTION", decode("Main_w_Bulk12"."Planner", '324363', 'Eric', '20444', 'Eric', '20445', 'Lance', '291740', 'Mark Tilley', '328907', 'Lance', '333530', 'Lance', '316775', 'Lance', '334927', 'Tammy', '290808', 'David Kramer', '335951', 'Lance', '300021', 'Tammy', '324287', 'Brent', 'ERROR') "NEW_OWNER", "Main_w_Bulk12"."Planner" "Planner", "Main_w_Bulk12"."Next_Status" "Next_Status", avg("Main_w_Bulk12"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "Main_w_Bulk12"."Primary_UOM" "Primary_UOM", avg("Main_w_Bulk12"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "Main_w_Bulk12"."Secondary_UOM" "Secondary_UOM", "Main_w_Bulk12"."Order_Date" "Order_Date", "Main_w_Bulk12"."CSR_Name" "CSR_Name", "Routing13"."Work_Center" "Work_Center", "Main_w_Bulk12"."MPF" "MPF"
 from "Main_w_Bulk12" FULL OUTER JOIN "Routing13" on "Main_w_Bulk12"."Bulk_Item"="Routing13"."C_2nd_Item_Number"
 where not "Main_w_Bulk12"."C_2nd_Item_Number" is null and "Main_w_Bulk12"."Next_Status"='530'
 group by "Main_w_Bulk12"."Branch_Plant", "Main_w_Bulk12"."CSR_Name", "Main_w_Bulk12"."Order_Number", "Main_w_Bulk12"."Order_Line", "Main_w_Bulk12"."Customer_Name", "Main_w_Bulk12"."Customer_Segmentation", "Main_w_Bulk12"."C_2nd_Item_Number", "Main_w_Bulk12"."Next_Status", "Main_w_Bulk12"."Primary_UOM", "Main_w_Bulk12"."Secondary_UOM", "Main_w_Bulk12"."Order_Date", "Main_w_Bulk12"."Requested_Date", "Main_w_Bulk12"."Promised_Ship_Date", "Main_w_Bulk12"."MPF", "Main_w_Bulk12"."Bulk_Item", "Routing13"."Work_Center", "Main_w_Bulk12"."Planner", decode("Main_w_Bulk12"."Planner", '324363', 'Eric', '20444', 'Eric', '20445', 'Lance', '291740', 'Mark Tilley', '328907', 'Lance', '333530', 'Lance', '316775', 'Lance', '334927', 'Tammy', '290808', 'David Kramer', '335951', 'Lance', '300021', 'Tammy', '324287', 'Brent', 'ERROR'), decode("Main_w_Bulk12"."C_2nd_Item_Number", 'NEWITEMFG', "Main_w_Bulk12"."Description_1", 'NEWITEMPKG', "Main_w_Bulk12"."Description_1", ' ')
 order by "Bulk_Item" asc nulls last, "Promised_Ship_Date" asc nulls last, "Order_Number" asc nulls last, "Order_Line" asc nulls last, "NEW_OWNER" asc nulls last


with "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDLNID", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDDRQJ">0 then "PRODDTA".JUL2DATE("F4211"."SDDRQJ") else NULL end  "SDDRQJ", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDDSC1", "F4211"."SDNXTR", "F4211"."SDLTTR", "F4211"."SDPRP4", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "F42140__CSR" as (
select "F42140"."CMAN8", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8"), "MAIN8" as (
select "F4211_Open_Sales_Orders"."SDKCOO" "Order_Company", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "Branch_Plant", trim(both
 from "F42140__CSR"."ABALPH") "CSR_Name", "F4211_Open_Sales_Orders"."SDDOCO" "Order_Number", "F4211_Open_Sales_Orders"."SDLNID"/1000 "Order_Line", "F4211_Open_Sales_Orders"."SDVR01" "Customer_PO", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "Customer_Name", trim(both
 from "F0101_Ship_To_Customer"."ABAC06") "Customer_Segmentation", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C_2nd_Item_Number", "F4211_Open_Sales_Orders"."SDLTTR" "Last_Status", "F4211_Open_Sales_Orders"."SDNXTR" "Next_Status", "F4211_Open_Sales_Orders"."SDTRDJ" "Order_Date", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "Primary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM1" "Primary_UOM", "F4211_Open_Sales_Orders"."SDDRQJ" "Requested_Date", "F4211_Open_Sales_Orders"."SDPDDJ" "Promised_Ship_Date", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "Secondary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM2" "Secondary_UOM", "F4211_Open_Sales_Orders"."SDPRP4" "MPF", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") "Description_1"
 from ("F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") LEFT OUTER JOIN "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8"
 where "F4211_Open_Sales_Orders"."SDNXTR" in ('525', '530', '535', '540', '545', '550') and "F4211_Open_Sales_Orders"."SDKCOO"='00010'
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), trim(both
 from "F42140__CSR"."ABALPH"), "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDLNID"/1000, "F4211_Open_Sales_Orders"."SDVR01", trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), trim(both
 from "F0101_Ship_To_Customer"."ABAC06"), trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), "F4211_Open_Sales_Orders"."SDLTTR", "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDDRQJ", "F4211_Open_Sales_Orders"."SDPDDJ", "F4211_Open_Sales_Orders"."SDUOM2", "F4211_Open_Sales_Orders"."SDPRP4", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1")), "ITEM9" as (
select distinct trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", "F4102_Item_Branch_Alias_WO"."IBANPL" "Planner"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "Main_w_Bulk12" as (
select "MAIN8"."Order_Company" "Order_Company", "MAIN8"."Branch_Plant" "Branch_Plant", "MAIN8"."CSR_Name" "CSR_Name", "MAIN8"."Order_Number" "Order_Number", "MAIN8"."Order_Line" "Order_Line", "MAIN8"."Customer_PO" "Customer_PO", "MAIN8"."Customer_Name" "Customer_Name", "MAIN8"."Customer_Segmentation" "Customer_Segmentation", "MAIN8"."C_2nd_Item_Number" "C_2nd_Item_Number", "MAIN8"."Last_Status" "Last_Status", "MAIN8"."Next_Status" "Next_Status", "MAIN8"."Order_Date" "Order_Date", sum("MAIN8"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "MAIN8"."Primary_UOM" "Primary_UOM", "MAIN8"."Requested_Date" "Requested_Date", "MAIN8"."Promised_Ship_Date" "Promised_Ship_Date", sum("MAIN8"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "MAIN8"."Secondary_UOM" "Secondary_UOM", "MAIN8"."MPF" "MPF", "MAIN8"."Description_1" "Description_1", "ITEM9"."Branch_Plant" "Branch_Plant1", "ITEM9"."Bulk_Item" "Bulk_Item", "ITEM9"."C_2nd_Item_Number" "C_2nd_Item_Number1", "ITEM9"."Planner" "Planner"
 from "MAIN8", "ITEM9"
 where "MAIN8"."Branch_Plant"="ITEM9"."Branch_Plant" and "MAIN8"."C_2nd_Item_Number"="ITEM9"."C_2nd_Item_Number"
 group by "MAIN8"."Order_Company", "MAIN8"."Branch_Plant", "MAIN8"."CSR_Name", "MAIN8"."Order_Number", "MAIN8"."Order_Line", "MAIN8"."Customer_PO", "MAIN8"."Customer_Name", "MAIN8"."Customer_Segmentation", "MAIN8"."C_2nd_Item_Number", "MAIN8"."Last_Status", "MAIN8"."Next_Status", "MAIN8"."Order_Date", "MAIN8"."Primary_UOM", "MAIN8"."Requested_Date", "MAIN8"."Promised_Ship_Date", "MAIN8"."Secondary_UOM", "MAIN8"."MPF", "MAIN8"."Description_1", "ITEM9"."Branch_Plant", "ITEM9"."Bulk_Item", "ITEM9"."C_2nd_Item_Number", "ITEM9"."Planner"), "F3312_Capacity_Pegging" as (
select "F3312"."CWCAPM", "F3312"."CWMCU", "F3312"."CWITM", "F3312"."CWMMCU", "F3312"."CWDRQJ" "CWDRQJ_ORIG", decode("F3312"."CWDRQJ", 0, NULL, 1, 'EARLY DATE 1', 2, 'EARLY DATE 2', TO_CHAR("PRODDTA".JUL2DATE("F3312"."CWDRQJ"), 'MM/DD/YYYY')) "CWDRQJ", "F3312"."CWTRQT"/10000 "CWTRQT", "F3312"."CWUORG"/10000 "CWUORG", "F3312"."CWDOCO", "F3312"."CWWMCU"
 from "PRODDTA"."F3312" "F3312"), "F3313_Capacity_Load_Table" as (
select "F3313"."CRCAPM", "F3313"."CRMCU", "F3313"."CRCQT", "F3313"."CRSTRT" "CRSTRT_ORIG", "F3313"."CRTRQT"/10000 "CRTRQT", "F3313"."CRWMCU"
 from "PRODDTA"."F3313" "F3313"), "Routing13" as (
select "T0"."C0" "Item_Branch", "T0"."C1" "C_2nd_Item_Number", "T0"."C2" "Work_Center", "T0"."C3" "Julian_Period_End_Date", "T0"."C4" "Period_End_Date", "T0"."C5" "Julian_Period_Date", "T0"."C6" "Transaction_Quantity", "T0"."C7" "Capacity_Type", "T0"."C8" "Capacity_Mode", "T0"."C9" "Work_Center1", "T0"."C1" "C_2nd_Item_Number1", "T0"."C10" "Item_Branch1", "T0"."C3" "Julian_Period_End_Date1", "T0"."C4" "Period_End_Date1", "T0"."C11" "Units", "T0"."C12" "Ordered_Quantity", "T0"."C13" "WO_Number"
 from (
select trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") "C0", trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") "C1", trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) "C2", "F3312_Capacity_Pegging"."CWDRQJ_ORIG" "C3", "F3312_Capacity_Pegging"."CWDRQJ" "C4", "F3313_Capacity_Load_Table"."CRSTRT_ORIG" "C5", "F3313_Capacity_Load_Table"."CRTRQT" "C6", "F3313_Capacity_Load_Table"."CRCQT" "C7", "F3312_Capacity_Pegging"."CWCAPM" "C8", trim(both
 from "F3312_Capacity_Pegging"."CWMCU") "C9", "F3312_Capacity_Pegging"."CWMMCU" "C10", sum("F3312_Capacity_Pegging"."CWTRQT") "C11", sum("F3312_Capacity_Pegging"."CWUORG") "C12", "F3312_Capacity_Pegging"."CWDOCO" "C13"
 from "F3312_Capacity_Pegging", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_CapPeg", "F3313_Capacity_Load_Table"
 where trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") in ('CINC', 'CIN2') and trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") not  like '%-%' and trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) in ('SREC23', 'SREC37', 'SREC48', 'SREC72', 'SREC130', 'SDMD', 'SPEC', 'SPREC', 'SECG', 'SE2', 'SCOLD', 'SPDMD', 'SPCOLD', 'SLAB', 'SRENAME', 'SREPACK', 'SHILDA', 'KLAB', 'KBB', 'KSB', 'KWG', 'KBOT', 'KREPACK', 'KRENAME') and to_date(1900000+decode("F3312_Capacity_Pegging"."CWDRQJ_ORIG", 0, 1, "F3312_Capacity_Pegging"."CWDRQJ_ORIG"), 'YYYYDDD')>(sysdate+30)+1 and "F3312_Capacity_Pegging"."CWDOCO"=0 and "F3312_Capacity_Pegging"."CWMCU"="F3313_Capacity_Load_Table"."CRMCU" and "F3312_Capacity_Pegging"."CWCAPM"="F3313_Capacity_Load_Table"."CRCAPM" and "F3312_Capacity_Pegging"."CWDRQJ_ORIG"="F3313_Capacity_Load_Table"."CRSTRT_ORIG" and "F3312_Capacity_Pegging"."CWWMCU"="F3313_Capacity_Load_Table"."CRWMCU" and "F3312_Capacity_Pegging"."CWITM"="F4102_Item_Branch_Alias_CapPeg"."IBITM" and "F3312_Capacity_Pegging"."CWWMCU"="F4102_Item_Branch_Alias_CapPeg"."IBMCU"
 group by trim(both
 from "F3312_Capacity_Pegging"."CWMMCU"), trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM"), trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")), "F3312_Capacity_Pegging"."CWDRQJ_ORIG", "F3312_Capacity_Pegging"."CWDRQJ", "F3313_Capacity_Load_Table"."CRSTRT_ORIG", "F3313_Capacity_Load_Table"."CRTRQT", "F3313_Capacity_Load_Table"."CRCQT", "F3312_Capacity_Pegging"."CWCAPM", trim(both
 from "F3312_Capacity_Pegging"."CWMCU"), "F3312_Capacity_Pegging"."CWMMCU", "F3312_Capacity_Pegging"."CWDOCO") "T0") 
select sum(case  when decode("Main_w_Bulk12"."Planner", '324363', 'Eric', '20444', 'Eric', '20445', 'Lance', '291740', 'Mark Tilley', '328907', 'Lance', '333530', 'Lance', '316775', 'Lance', '334927', 'Tammy', '290808', 'David Kramer', '335951', 'Lance', '300021', 'Tammy', '324287', 'Brent', 'ERROR')='ERROR' then 1 else 0 end ) "COUNT_ERROR"
 from "Main_w_Bulk12" FULL OUTER JOIN "Routing13" on "Main_w_Bulk12"."Bulk_Item"="Routing13"."C_2nd_Item_Number"
 where not "Main_w_Bulk12"."C_2nd_Item_Number" is null
 having count(*)>0



with "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDLNID", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDDRQJ">0 then "PRODDTA".JUL2DATE("F4211"."SDDRQJ") else NULL end  "SDDRQJ", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDDSC1", "F4211"."SDNXTR", "F4211"."SDLTTR", "F4211"."SDPRP4", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "F42140__CSR" as (
select "F42140"."CMAN8", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8"), "MAIN8" as (
select "F4211_Open_Sales_Orders"."SDKCOO" "Order_Company", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "Branch_Plant", trim(both
 from "F42140__CSR"."ABALPH") "CSR_Name", "F4211_Open_Sales_Orders"."SDDOCO" "Order_Number", "F4211_Open_Sales_Orders"."SDLNID"/1000 "Order_Line", "F4211_Open_Sales_Orders"."SDVR01" "Customer_PO", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "Customer_Name", trim(both
 from "F0101_Ship_To_Customer"."ABAC06") "Customer_Segmentation", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C_2nd_Item_Number", "F4211_Open_Sales_Orders"."SDLTTR" "Last_Status", "F4211_Open_Sales_Orders"."SDNXTR" "Next_Status", "F4211_Open_Sales_Orders"."SDTRDJ" "Order_Date", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "Primary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM1" "Primary_UOM", "F4211_Open_Sales_Orders"."SDDRQJ" "Requested_Date", "F4211_Open_Sales_Orders"."SDPDDJ" "Promised_Ship_Date", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "Secondary_Quantity_Ordered", "F4211_Open_Sales_Orders"."SDUOM2" "Secondary_UOM", "F4211_Open_Sales_Orders"."SDPRP4" "MPF", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") "Description_1"
 from ("F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") LEFT OUTER JOIN "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8"
 where "F4211_Open_Sales_Orders"."SDNXTR" in ('525', '530', '535', '540', '545', '550') and "F4211_Open_Sales_Orders"."SDKCOO"='00010'
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), trim(both
 from "F42140__CSR"."ABALPH"), "F4211_Open_Sales_Orders"."SDDOCO", "F4211_Open_Sales_Orders"."SDLNID"/1000, "F4211_Open_Sales_Orders"."SDVR01", trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), trim(both
 from "F0101_Ship_To_Customer"."ABAC06"), trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), "F4211_Open_Sales_Orders"."SDLTTR", "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDDRQJ", "F4211_Open_Sales_Orders"."SDPDDJ", "F4211_Open_Sales_Orders"."SDUOM2", "F4211_Open_Sales_Orders"."SDPRP4", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1")), "ITEM9" as (
select distinct trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", "F4102_Item_Branch_Alias_WO"."IBANPL" "Planner"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "Main_w_Bulk12" as (
select "MAIN8"."Order_Company" "Order_Company", "MAIN8"."Branch_Plant" "Branch_Plant", "MAIN8"."CSR_Name" "CSR_Name", "MAIN8"."Order_Number" "Order_Number", "MAIN8"."Order_Line" "Order_Line", "MAIN8"."Customer_PO" "Customer_PO", "MAIN8"."Customer_Name" "Customer_Name", "MAIN8"."Customer_Segmentation" "Customer_Segmentation", "MAIN8"."C_2nd_Item_Number" "C_2nd_Item_Number", "MAIN8"."Last_Status" "Last_Status", "MAIN8"."Next_Status" "Next_Status", "MAIN8"."Order_Date" "Order_Date", sum("MAIN8"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "MAIN8"."Primary_UOM" "Primary_UOM", "MAIN8"."Requested_Date" "Requested_Date", "MAIN8"."Promised_Ship_Date" "Promised_Ship_Date", sum("MAIN8"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "MAIN8"."Secondary_UOM" "Secondary_UOM", "MAIN8"."MPF" "MPF", "MAIN8"."Description_1" "Description_1", "ITEM9"."Branch_Plant" "Branch_Plant1", "ITEM9"."Bulk_Item" "Bulk_Item", "ITEM9"."C_2nd_Item_Number" "C_2nd_Item_Number1", "ITEM9"."Planner" "Planner"
 from "MAIN8", "ITEM9"
 where "MAIN8"."Branch_Plant"="ITEM9"."Branch_Plant" and "MAIN8"."C_2nd_Item_Number"="ITEM9"."C_2nd_Item_Number"
 group by "MAIN8"."Order_Company", "MAIN8"."Branch_Plant", "MAIN8"."CSR_Name", "MAIN8"."Order_Number", "MAIN8"."Order_Line", "MAIN8"."Customer_PO", "MAIN8"."Customer_Name", "MAIN8"."Customer_Segmentation", "MAIN8"."C_2nd_Item_Number", "MAIN8"."Last_Status", "MAIN8"."Next_Status", "MAIN8"."Order_Date", "MAIN8"."Primary_UOM", "MAIN8"."Requested_Date", "MAIN8"."Promised_Ship_Date", "MAIN8"."Secondary_UOM", "MAIN8"."MPF", "MAIN8"."Description_1", "ITEM9"."Branch_Plant", "ITEM9"."Bulk_Item", "ITEM9"."C_2nd_Item_Number", "ITEM9"."Planner"), "F3312_Capacity_Pegging" as (
select "F3312"."CWCAPM", "F3312"."CWMCU", "F3312"."CWITM", "F3312"."CWMMCU", "F3312"."CWDRQJ" "CWDRQJ_ORIG", decode("F3312"."CWDRQJ", 0, NULL, 1, 'EARLY DATE 1', 2, 'EARLY DATE 2', TO_CHAR("PRODDTA".JUL2DATE("F3312"."CWDRQJ"), 'MM/DD/YYYY')) "CWDRQJ", "F3312"."CWTRQT"/10000 "CWTRQT", "F3312"."CWUORG"/10000 "CWUORG", "F3312"."CWDOCO", "F3312"."CWWMCU"
 from "PRODDTA"."F3312" "F3312"), "F3313_Capacity_Load_Table" as (
select "F3313"."CRCAPM", "F3313"."CRMCU", "F3313"."CRCQT", "F3313"."CRSTRT" "CRSTRT_ORIG", "F3313"."CRTRQT"/10000 "CRTRQT", "F3313"."CRWMCU"
 from "PRODDTA"."F3313" "F3313"), "Routing13" as (
select "T0"."C0" "Item_Branch", "T0"."C1" "C_2nd_Item_Number", "T0"."C2" "Work_Center", "T0"."C3" "Julian_Period_End_Date", "T0"."C4" "Period_End_Date", "T0"."C5" "Julian_Period_Date", "T0"."C6" "Transaction_Quantity", "T0"."C7" "Capacity_Type", "T0"."C8" "Capacity_Mode", "T0"."C9" "Work_Center1", "T0"."C1" "C_2nd_Item_Number1", "T0"."C10" "Item_Branch1", "T0"."C3" "Julian_Period_End_Date1", "T0"."C4" "Period_End_Date1", "T0"."C11" "Units", "T0"."C12" "Ordered_Quantity", "T0"."C13" "WO_Number"
 from (
select trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") "C0", trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") "C1", trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) "C2", "F3312_Capacity_Pegging"."CWDRQJ_ORIG" "C3", "F3312_Capacity_Pegging"."CWDRQJ" "C4", "F3313_Capacity_Load_Table"."CRSTRT_ORIG" "C5", "F3313_Capacity_Load_Table"."CRTRQT" "C6", "F3313_Capacity_Load_Table"."CRCQT" "C7", "F3312_Capacity_Pegging"."CWCAPM" "C8", trim(both
 from "F3312_Capacity_Pegging"."CWMCU") "C9", "F3312_Capacity_Pegging"."CWMMCU" "C10", sum("F3312_Capacity_Pegging"."CWTRQT") "C11", sum("F3312_Capacity_Pegging"."CWUORG") "C12", "F3312_Capacity_Pegging"."CWDOCO" "C13"
 from "F3312_Capacity_Pegging", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_CapPeg", "F3313_Capacity_Load_Table"
 where trim(both
 from "F3312_Capacity_Pegging"."CWMMCU") in ('CINC', 'CIN2') and trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM") not  like '%-%' and trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")) in ('SREC23', 'SREC37', 'SREC48', 'SREC72', 'SREC130', 'SDMD', 'SPEC', 'SPREC', 'SECG', 'SE2', 'SCOLD', 'SPDMD', 'SPCOLD', 'SLAB', 'SRENAME', 'SREPACK', 'SHILDA', 'KLAB', 'KBB', 'KSB', 'KWG', 'KBOT', 'KREPACK', 'KRENAME') and to_date(1900000+decode("F3312_Capacity_Pegging"."CWDRQJ_ORIG", 0, 1, "F3312_Capacity_Pegging"."CWDRQJ_ORIG"), 'YYYYDDD')>(sysdate+30)+1 and "F3312_Capacity_Pegging"."CWDOCO"=0 and "F3312_Capacity_Pegging"."CWMCU"="F3313_Capacity_Load_Table"."CRMCU" and "F3312_Capacity_Pegging"."CWCAPM"="F3313_Capacity_Load_Table"."CRCAPM" and "F3312_Capacity_Pegging"."CWDRQJ_ORIG"="F3313_Capacity_Load_Table"."CRSTRT_ORIG" and "F3312_Capacity_Pegging"."CWWMCU"="F3313_Capacity_Load_Table"."CRWMCU" and "F3312_Capacity_Pegging"."CWITM"="F4102_Item_Branch_Alias_CapPeg"."IBITM" and "F3312_Capacity_Pegging"."CWWMCU"="F4102_Item_Branch_Alias_CapPeg"."IBMCU"
 group by trim(both
 from "F3312_Capacity_Pegging"."CWMMCU"), trim(both
 from "F4102_Item_Branch_Alias_CapPeg"."IBLITM"), trim(both
 from trim(both
 from "F3312_Capacity_Pegging"."CWMCU")), "F3312_Capacity_Pegging"."CWDRQJ_ORIG", "F3312_Capacity_Pegging"."CWDRQJ", "F3313_Capacity_Load_Table"."CRSTRT_ORIG", "F3313_Capacity_Load_Table"."CRTRQT", "F3313_Capacity_Load_Table"."CRCQT", "F3312_Capacity_Pegging"."CWCAPM", trim(both
 from "F3312_Capacity_Pegging"."CWMCU"), "F3312_Capacity_Pegging"."CWMMCU", "F3312_Capacity_Pegging"."CWDOCO") "T0") 
select "Main_w_Bulk12"."Promised_Ship_Date" "Promised_Ship_Date", "Main_w_Bulk12"."Requested_Date" "Requested_Date", "Main_w_Bulk12"."Branch_Plant" "Branch_Plant", "Main_w_Bulk12"."Customer_Name" "Customer_Name", "Main_w_Bulk12"."Customer_Segmentation" "Customer_Segmentation", "Main_w_Bulk12"."Order_Number" "Order_Number", "Main_w_Bulk12"."Order_Line" "Order_Line", "Main_w_Bulk12"."Bulk_Item" "Bulk_Item", "Main_w_Bulk12"."C_2nd_Item_Number" "C_2nd_Item_Number", decode("Main_w_Bulk12"."C_2nd_Item_Number", 'NEWITEMFG', "Main_w_Bulk12"."Description_1", 'NEWITEMPKG', "Main_w_Bulk12"."Description_1", ' ') "DESCRIPTION", decode("Main_w_Bulk12"."Planner", '324363', 'Eric', '20444', 'Eric', '20445', 'Lance', '291740', 'Mark Tilley', '328907', 'Lance', '333530', 'Lance', '316775', 'Lance', '334927', 'Tammy', '290808', 'David Kramer', '335951', 'Lance', '300021', 'Tammy', '324287', 'Brent', 'ERROR') "NEW_OWNER", "Main_w_Bulk12"."Next_Status" "Next_Status", avg("Main_w_Bulk12"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "Main_w_Bulk12"."Primary_UOM" "Primary_UOM", avg("Main_w_Bulk12"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "Main_w_Bulk12"."Secondary_UOM" "Secondary_UOM", "Main_w_Bulk12"."Order_Date" "Order_Date", "Main_w_Bulk12"."CSR_Name" "CSR_Name", "Routing13"."Work_Center" "Work_Center", "Main_w_Bulk12"."MPF" "MPF"
 from "Main_w_Bulk12" FULL OUTER JOIN "Routing13" on "Main_w_Bulk12"."Bulk_Item"="Routing13"."C_2nd_Item_Number"
 where not "Main_w_Bulk12"."C_2nd_Item_Number" is null
 group by "Main_w_Bulk12"."Branch_Plant", "Main_w_Bulk12"."CSR_Name", "Main_w_Bulk12"."Order_Number", "Main_w_Bulk12"."Order_Line", "Main_w_Bulk12"."Customer_Name", "Main_w_Bulk12"."Customer_Segmentation", "Main_w_Bulk12"."C_2nd_Item_Number", "Main_w_Bulk12"."Next_Status", "Main_w_Bulk12"."Primary_UOM", "Main_w_Bulk12"."Secondary_UOM", "Main_w_Bulk12"."Order_Date", "Main_w_Bulk12"."Requested_Date", "Main_w_Bulk12"."Promised_Ship_Date", "Main_w_Bulk12"."MPF", "Main_w_Bulk12"."Bulk_Item", "Routing13"."Work_Center", decode("Main_w_Bulk12"."Planner", '324363', 'Eric', '20444', 'Eric', '20445', 'Lance', '291740', 'Mark Tilley', '328907', 'Lance', '333530', 'Lance', '316775', 'Lance', '334927', 'Tammy', '290808', 'David Kramer', '335951', 'Lance', '300021', 'Tammy', '324287', 'Brent', 'ERROR'), decode("Main_w_Bulk12"."C_2nd_Item_Number", 'NEWITEMFG', "Main_w_Bulk12"."Description_1", 'NEWITEMPKG', "Main_w_Bulk12"."Description_1", ' ')
 order by "Bulk_Item" asc nulls last, "Promised_Ship_Date" asc nulls last, "Order_Number" asc nulls last, "Order_Line" asc nulls last, "NEW_OWNER" asc nulls last
