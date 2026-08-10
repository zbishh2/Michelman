with "F4801_Work_Order" as (
select "F4801"."WADOCO", "F4801"."WAMMCU", "F4801"."WASRST", case  when "F4801"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801"."WATRDJ") else NULL end  "WATRDJ", case  when "F4801"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801"."WASTRT") else NULL end  "WASTRT", case  when "F4801"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801"."WASTRX") else NULL end  "WASTRX", "F4801"."WAITM", "F4801"."WALITM", "F4801"."WAUORG", "F4801"."WASOQS", "F4801"."WAUOM"
 from "PRODDTA"."F4801" "F4801") 
select "T0"."C0" "Branch_Plant", "T0"."C1" "Global_Bulk_Item", "T0"."C2" "Bulk_Item", "T0"."C3" "C_2nd_Item_Number", "T0"."C4" "WO_Number", "T0"."C5" "WO_Status", "T0"."C6" "Order_Date", "T0"."C7" "Start_Date", "T0"."C8" "Completed_Date", first_value("T0"."C9") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C10") "Quantity_Requested", first_value("T0"."C11") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C10") "Quantity_Completed", "T0"."C10" "Unit_of_Measure"
 from (
select trim(both
 from "F4801_Work_Order"."WAMMCU") "C0", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "C1", "F554101_ITEM_TAG"."IMBULK" "C2", trim(both
 from "F4801_Work_Order"."WALITM") "C3", "F4801_Work_Order"."WADOCO" "C4", "F4801_Work_Order"."WASRST" "C5", "F4801_Work_Order"."WATRDJ" "C6", "F4801_Work_Order"."WASTRT" "C7", "F4801_Work_Order"."WASTRX" "C8", avg("F4801_Work_Order"."WAUORG"/10000) "C9", "F4801_Work_Order"."WAUOM" "C10", avg("F4801_Work_Order"."WASOQS"/10000) "C11"
 from "F4801_Work_Order", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO"
 where "F4801_Work_Order"."WASRST" not  in ('95', '96', '97', '98', '99', 'MM', 'CD') and "F4801_Work_Order"."WASTRT">=to_date(sysdate) - 30 and "F4801_Work_Order"."WAITM"="F4102_Item_Branch_Alias_WO"."IBITM" and "F4801_Work_Order"."WAMMCU"="F4102_Item_Branch_Alias_WO"."IBMCU" and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"
 group by trim(both
 from "F4801_Work_Order"."WAMMCU"), trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WADOCO", "F4801_Work_Order"."WASRST", "F4801_Work_Order"."WATRDJ", "F4801_Work_Order"."WASTRT", "F4801_Work_Order"."WASTRX", "F4801_Work_Order"."WAUOM"
 having avg("F4801_Work_Order"."WASOQS"/10000)=0) "T0"
 order by "Global_Bulk_Item" asc nulls last, "Bulk_Item" asc nulls last, "C_2nd_Item_Number" asc nulls last, "Start_Date" asc nulls last



