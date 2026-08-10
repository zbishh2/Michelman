select "T0"."C0" "C0", "T0"."C1" "C1", "T0"."C2" "C2", "T0"."C3" "C3", "T0"."C4" "C4", "T0"."C6" "C5", "T0"."C7" "C6", "T0"."C8" "C7", "T0"."C9" "C8", "T0"."C10" "C9", "T0"."C21" "C10", "T0"."C11" "C11", "T0"."C12" "C12", "T0"."C13" "C13", "T0"."C14" "C14", "T0"."C15" "C15", "T0"."C16" "C16", "T0"."C17" "C17", "T0"."C18" "C18", "T0"."C19" "C19", "T0"."C20" "C20", "T0"."C5" "C21", "T0"."C22" "C22", "T0"."C23" "C23"
 from (
select "T0"."C0" "C0", "T0"."C1" "C1", "T0"."C2" "C2", "T0"."C3" "C3", "T0"."C4" "C4", count("T0"."C3") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C9", "T0"."C10", "T0"."C11", "T0"."C12", "T0"."C13", "T0"."C14", "T0"."C15", "T0"."C16", "T0"."C17", "T0"."C18", "T0"."C19") "C5", "T0"."C5" "C6", "T0"."C6" "C7", "T0"."C7" "C8", "T0"."C8" "C9", "T0"."C9" "C10", "T0"."C10" "C11", "T0"."C11" "C12", "T0"."C12" "C13", "T0"."C13" "C14", "T0"."C14" "C15", "T0"."C15" "C16", "T0"."C16" "C17", "T0"."C17" "C18", "T0"."C18" "C19", "T0"."C19" "C20", case  when "T0"."C20"='5' then 4 when "T0"."C20"='4' then 4 when "T0"."C20"='6' then 3 else 2 end  "C21", sum(trim(both
 from "T0"."C21"/10000)) over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C9", "T0"."C10", "T0"."C11", "T0"."C12", "T0"."C13", "T0"."C14", "T0"."C15", "T0"."C16", "T0"."C17", "T0"."C18", "T0"."C19") "C22", sum(trim(both
 from "T0"."C22"/10000)) over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C9", "T0"."C10", "T0"."C11", "T0"."C12", "T0"."C13", "T0"."C14", "T0"."C15", "T0"."C16", "T0"."C17", "T0"."C18", "T0"."C19") "C23"
 from (
select "F4211_Open_Sales_Orders"."SDNXTR" "C0", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C1", "F4211_Open_Sales_Orders"."SDTRDJ" "C2", trim(both
 from "F4211_Open_Sales_Orders"."SDDOCO") "C3", trim(both
 from "F4211_Open_Sales_Orders"."SDLNID"/1000) "C4", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "C5", "F0101_Ship_To_Customer"."ABALPH" "C6", "F4211_Open_Sales_Orders"."SDPDDJ" "C7", (MOD( MOD( TO_NUMBER( TO_CHAR( "F4211_Open_Sales_Orders"."SDPDDJ", 'D' ) ) - TO_NUMBER( TO_CHAR( TO_DATE( '2003-01-06', 'YYYY-MM-DD' ), 'D' ) ) + 7, 7 ) + 1 - 1 + 7, 7 ) + 1) "C8", decode((MOD( MOD( TO_NUMBER( TO_CHAR( "F4211_Open_Sales_Orders"."SDPDDJ", 'D' ) ) - TO_NUMBER( TO_CHAR( TO_DATE( '2003-01-06', 'YYYY-MM-DD' ), 'D' ) ) + 7, 7 ) + 1 - 1 + 7, 7 ) + 1), '1', 'Monday', '2', 'Tuesday', '3', 'Wednesday', '4', 'Thursday', '5', 'Friday', '6', 'Saturday', '7', 'Sunday', 'ERROR') "C9", "F42140__CSR"."ABALPH" "C10", "F4211_Open_Sales_Orders"."SDLNTY" "C11", trim(both
 from "F4211_Open_Sales_Orders"."SDLOTN") "C12", "F0010_Order_Company"."CCNAME" "C13", "F0101_Sold_To_Customer"."ABALPH" "C14", trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") "C15", case  when trim(both
 from "F4211_Open_Sales_Orders"."SDLITM")='NEWITEMFG' or trim(both
 from "F4211_Open_Sales_Orders"."SDLITM")='NEWITEMPKG' then trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") else trim(both
 from "F4211_Open_Sales_Orders"."SDDSC1") end  "C16", sum(trim(both
 from "F4211_Open_Sales_Orders"."SDPQOR"/10000)) over (partition by trim(both
 from "F4211_Open_Sales_Orders"."SDLITM")) "C17", sum(trim(both
 from "F4211_Open_Sales_Orders"."SDPQOR"/10000)) over (partition by trim(both
 from "F4211_Open_Sales_Orders"."SDMCU")) "C18", "F4211_Open_Sales_Orders"."SDPRP4" "C19", (MOD( MOD( TO_NUMBER( TO_CHAR( sysdate, 'D' ) ) - TO_NUMBER( TO_CHAR( TO_DATE( '2003-01-06', 'YYYY-MM-DD' ), 'D' ) ) + 7, 7 ) + 1 - 1 + 7, 7 ) + 1) "C20", "F4211_Open_Sales_Orders"."SDUORG" "C21", "F4211_Open_Sales_Orders"."SDPQOR" "C22"
 from ((((
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDLNID", "F4211"."SDMCU", "F4211"."SDAN8", "F4211"."SDSHAN", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDLITM", "F4211"."SDLOTN", "F4211"."SDDSC1", "F4211"."SDLNTY", "F4211"."SDNXTR", "F4211"."SDPRP4", "F4211"."SDUORG", "F4211"."SDPQOR"
 from "PRODDTA"."F4211" "F4211") "F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Sold_To_Customer" on "F4211_Open_Sales_Orders"."SDAN8"="F0101_Sold_To_Customer"."ABAN8") INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") INNER JOIN "PRODDTA"."F0010" "F0010_Order_Company" on "F4211_Open_Sales_Orders"."SDKCOO"="F0010_Order_Company"."CCCO") LEFT OUTER JOIN (
select "F42140"."CMAN8", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8") "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8"
 where "F4211_Open_Sales_Orders"."SDNXTR" in ('525', '530', '535', '536', '537', '540', '545', '550') and "F4211_Open_Sales_Orders"."SDLNTY"='S' and trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") in ('161017CX-FD', '161017CX-OP', '161190PX-T2', '161190PX-T3', '171143PX-T2', '191245PX-T2', 'APT10', 'APT10-T2', 'APT11', 'APT11-T2', 'BPADA', 'BTDA', 'BYK3565', 'C2', 'CAN', 'CORNERB', 'CRTNCLEAR', 'CRTNDARK', 'CRTNWHITE', 'DMAEMA', 'DMEA', 'DPE3500-T2', 'EMA3065', 'FERSUL7W', 'GEN926', 'HP1432AT-OP', 'HP1632', 'HP1632-T2', 'HP1632-T2*OP10', 'IND139', 'KOH50', 'MD4020-C1', 'MD4020-C2', 'MD4020C-C2', 'MD4021', 'MD4021-C1', 'MD4021-C2', 'MD4021C-C2', 'MD4022', 'MD4022C-C2', 'MD4023', 'MD4023-C2', 'MD4023C-C2', 'MDU20-T2', 'MPD', 'MW40504', 'MW40504-C2', 'MW40514', 'MW40514-C2', 'NS41-PL', 'PEG1450', 'PEG1450.S', 'PERSD', 'PTMG', 'STODSO', 'TC275', 'THERMOT', 'THF', 'U1001-OP', 'U101-OP', 'U201-T2', 'U2022-OP', 'U2023-OP', 'U204-OP', 'U204-T2', 'U470-OP', 'U501B', 'U501B-OP', 'U501-OP', 'U502.E', 'U502-OP', 'U601-OP', 'U701-OP', 'UNYTE201', 'UNYTEC201-FD', 'WAH12MDI', 'WAV501', 'WD40', 'WD40-SP', 'WD40-UN', 'JS037-OP', 'HP401-OP', 'HSCF410-PL', 'UNYTEC201-FD') and (trim(both
 from "F4211_Open_Sales_Orders"."SDLOTN") is null or trim(both
 from "F4211_Open_Sales_Orders"."SDLOTN")=' ') and "F4211_Open_Sales_Orders"."SDPDDJ"<=sysdate+21 and trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") in ('CINC', 'CIN2', 'CIN4')) "T0") "T0"

select "F41021_Item_Location"."LILOTS", "F41021_Item_Location"."LIPQOH"/10000 - "F41021_Item_Location"."LIHCOM"/10000, "F4102_Item_Branch_Alias_WO"."IBLITM", "F4102_Item_Branch_Alias_WO"."IBMCU", "F41021_Item_Location"."LILOCN", "F41021_Item_Location"."LILOTN", "F554101_ITEM_TAG"."IMBULK", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")), "F41021_Item_Location"."LIPQOH", "F41021_Item_Location"."LIHCOM", "F41021_Item_Location"."LIPCOM", "F41021_Item_Location"."LIFCOM"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F41021" "F41021_Item_Location", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where "F4102_Item_Branch_Alias_WO"."IBMCU"="F41021_Item_Location"."LIMCU" and "F4102_Item_Branch_Alias_WO"."IBITM"="F41021_Item_Location"."LIITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM" and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") in ('CINC', 'CIN2', 'CIN4') and "F41021_Item_Location"."LIPQOH"/10000>0

select "T0"."C0" "C0", "T0"."C2" "C1", "T0"."C3" "C2", "T0"."C4" "C3", "T0"."C5" "C4", "T0"."C6" "C5", "T0"."C7" "C6", "T0"."C8" "C7", "T0"."C10" "C8", "T0"."C9" "C9", "T0"."C1" "C10", "T0"."C11" "C11"
 from (
select "T0"."C0" "C0", count("T0"."C0") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8") "C1", "T0"."C6" "C2", "T0"."C1" "C3", "T0"."C2" "C4", "T0"."C3" "C5", "T0"."C4" "C6", "T0"."C5" "C7", "T0"."C7" "C8", "T0"."C8" "C9", case  when "T0"."C9"='5' then 5 when "T0"."C9"='4' then 5 when "T0"."C9"='6' then 4 else 3 end  "C10", sum("T0"."C10"/10000) over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8") "C11"
 from (
select trim(both
 from "F4801_Work_Order"."WADOCO") "C0", trim(both
 from "F4801_Work_Order"."WAMMCU") "C1", case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end  "C2", case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end  "C3", "F4801_Work_Order"."WASRST" "C4", trim(both
 from "F554101_ITEM_TAG"."IMBULK") "C5", trim(both
 from "F4801_Work_Order"."WALITM") "C6", trim(both
 from "F4801_Work_Order"."WALOTN") "C7", sum("F4801_Work_Order"."WAUORG"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WALITM")) "C8", (MOD( MOD( TO_NUMBER( TO_CHAR( sysdate, 'D' ) ) - TO_NUMBER( TO_CHAR( TO_DATE( '2003-01-06', 'YYYY-MM-DD' ), 'D' ) ) + 7, 7 ) + 1 - 1 + 7, 7 ) + 1) "C9", "F4801_Work_Order"."WAUORG" "C10"
 from "PRODDTA"."F4801" "F4801_Work_Order", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO"
 where "F4801_Work_Order"."WASRST" in ('20', '30', '32', '35', '40', '45', '50', '90') and "F4801_Work_Order"."WAUORG"/10000>0 and case  when ("F4801_Work_Order"."WADRQJ">0) then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end <=sysdate+31 and trim(both
 from "F4801_Work_Order"."WAMMCU") in ('CINC', 'CIN2', 'CIN4') and "F4801_Work_Order"."WAITM"="F4102_Item_Branch_Alias_WO"."IBITM" and "F4801_Work_Order"."WAMMCU"="F4102_Item_Branch_Alias_WO"."IBMCU" and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM") "T0") "T0"
