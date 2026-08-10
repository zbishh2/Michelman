with "F4801_Work_Order" as (
select "F4801"."WADOCO", "F4801"."WAMMCU", "F4801"."WASRST", case  when "F4801"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801"."WATRDJ") else NULL end  "WATRDJ", case  when "F4801"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801"."WASTRT") else NULL end  "WASTRT", case  when "F4801"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801"."WASTRX") else NULL end  "WASTRX", "F4801"."WAITM", "F4801"."WALITM", "F4801"."WAUORG", "F4801"."WASOQS", "F4801"."WAUOM"
 from "PRODDTA"."F4801" "F4801"), "F3111_Work_Order_Parts" as (
select "F3111"."WMDOCO", "F3111"."WMCPIL", "F3111"."WMCMCU", case  when "F3111"."WMDRQJ">0 then "PRODDTA".JUL2DATE("F3111"."WMDRQJ") else NULL end  "WMDRQJ", "F3111"."WMUORG", "F3111"."WMTRQT", "F3111"."WMUM"
 from "PRODDTA"."F3111" "F3111") 
select "T0"."C0" "Branch_Plant", "T0"."C1" "Global_Bulk_Item", "T0"."C2" "Bulk_Item", "T0"."C3" "C_2nd_Item_Number", "T0"."C4" "WO_Number", "T0"."C5" "WO_Status", "T0"."C6" "Order_Date", "T0"."C7" "Start_Date", "T0"."C8" "Completed_Date", first_value("T0"."C9") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C10") "Quantity_Requested", first_value("T0"."C11") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C10") "Quantity_Completed", "T0"."C10" "Unit_of_Measure", "T0"."C12" "Component_Branch", "T0"."C13" "Component_2nd_Item_Number", "T0"."C14" "Ordered_Quantity", "T0"."C15" "Issued_Quantity", "T0"."C16" "Component_UOM", "T0"."C17" "Requested_Date"
 from (
select "T0"."C0" "C0", "T0"."C1" "C1", "T0"."C2" "C2", "T0"."C3" "C3", "T0"."C4" "C4", "T0"."C5" "C5", "T0"."C6" "C6", "T0"."C7" "C7", "T0"."C8" "C8", sum("T0"."C9") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C11")/nullif(sum("T0"."C10") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C11"), 0) "C9", "T0"."C11" "C10", sum("T0"."C16") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C11")/nullif(sum("T0"."C17") over (partition by "T0"."C0", "T0"."C1", "T0"."C2", "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C11"), 0) "C11", "T0"."C12" "C12", "T0"."C13" "C13", "T0"."C18" "C14", "T0"."C19" "C15", "T0"."C14" "C16", "T0"."C15" "C17"
 from (
select trim(both
 from "F4801_Work_Order"."WAMMCU") "C0", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "C1", "F554101_ITEM_TAG"."IMBULK" "C2", trim(both
 from "F4801_Work_Order"."WALITM") "C3", "F4801_Work_Order"."WADOCO" "C4", "F4801_Work_Order"."WASRST" "C5", "F4801_Work_Order"."WATRDJ" "C6", "F4801_Work_Order"."WASTRT" "C7", "F4801_Work_Order"."WASTRX" "C8", sum("F4801_Work_Order"."WAUORG"/10000) "C9", count("F4801_Work_Order"."WAUORG"/10000) "C10", "F4801_Work_Order"."WAUOM" "C11", "F3111_Work_Order_Parts"."WMCMCU" "C12", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL") "C13", "F3111_Work_Order_Parts"."WMUM" "C14", "F3111_Work_Order_Parts"."WMDRQJ" "C15", sum("F4801_Work_Order"."WASOQS"/10000) "C16", count("F4801_Work_Order"."WASOQS"/10000) "C17", sum("F3111_Work_Order_Parts"."WMUORG"/10000) "C18", sum("F3111_Work_Order_Parts"."WMTRQT"/10000) "C19", avg("F4801_Work_Order"."WASOQS"/10000) "C20"
 from "F4801_Work_Order", "PRODDTA"."F554101" "F554101_ITEM_TAG", "F3111_Work_Order_Parts", "PRODDTA"."F4101" "F4101_Item_Master", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO"
 where "F4801_Work_Order"."WASRST" not  in ('95', '96', '97', '98', '99', 'MM', 'CD') and "F4801_Work_Order"."WASTRT">=to_date(sysdate) - 30 and "F3111_Work_Order_Parts"."WMUORG"/10000+"F3111_Work_Order_Parts"."WMTRQT"/10000>0 and "F4801_Work_Order"."WADOCO"="F3111_Work_Order_Parts"."WMDOCO" and "F4801_Work_Order"."WAITM"="F4102_Item_Branch_Alias_WO"."IBITM" and "F4801_Work_Order"."WAMMCU"="F4102_Item_Branch_Alias_WO"."IBMCU" and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"
 group by trim(both
 from "F4801_Work_Order"."WAMMCU"), trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WADOCO", "F4801_Work_Order"."WASRST", "F4801_Work_Order"."WATRDJ", "F4801_Work_Order"."WASTRT", "F4801_Work_Order"."WASTRX", "F4801_Work_Order"."WAUOM", "F3111_Work_Order_Parts"."WMCMCU", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", "F3111_Work_Order_Parts"."WMDRQJ"
 having avg("F4801_Work_Order"."WASOQS"/10000)=0) "T0") "T0"
 order by "Global_Bulk_Item" asc nulls last, "Bulk_Item" asc nulls last, "C_2nd_Item_Number" asc nulls last, "Start_Date" asc nulls last



