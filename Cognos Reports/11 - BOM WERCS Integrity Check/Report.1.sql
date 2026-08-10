
select "T0"."C0" "C0", "T0"."C1" "C1", "T0"."C2" "C2", "T0"."C3" "C3", "T0"."C4" "C4", "T0"."C5" "C5", "T0"."C6" "C6", "T0"."C7" "C7", "T0"."C8" "C8", count(distinct "T0"."C9") over () "C9"
 from (
select "T0"."C0" "C0", "T0"."C1" "C1", sum("T0"."C2") over (partition by "T0"."C0", "T0"."C1") "C2", "T0"."C3" "C3", "T0"."C4" "C4", "T0"."C2" "C5", "T0"."C5" "C6", "T0"."C6" "C7", "T0"."C7" "C8", "T0"."C8" "C9", sum("T0"."C7") over (partition by "T0"."C0") "C10"
 from (
select "JDE4"."Parent_Second_Item_Number" "C0", "JDE4"."Branch_Plant" "C1", sum("JDE4"."Quantity") "C2", "WERCS5"."Parent_2nd_Item_Number" "C3", "JDE4"."C_2nd_Item_Number" "C4", "WERCS5"."Percent" "C5", "WERCS5"."Component_2nd_item_Number" "C6", sum(abs("JDE4"."Quantity" - nvl("WERCS5"."Percent", 0))) "C7", min("JDE4"."Parent_Second_Item_Number") "C8"
 from (
select "ITEM"."ITEM_NUMBER_2ND" "Parent_Second_Item_Number", "ITEM_ALIAS_COMP"."ITEM_NUMBER_2ND" "C_2nd_Item_Number", "BILL_OF_MATERIAL"."FIXED_OR_VARIABLE_QUANTITY" "Fixed_or_Variable_Quantity", sum(round("BILL_OF_MATERIAL"."QUANTITY"*100,4)) "Quantity", "ITEM"."STOCK_TYPE_CODE" "Stock_Type_Code", "BILL_OF_MATERIAL"."BRANCH_PLANT" "Branch_Plant"
 from ("DW_LEGACY"."ORGANIZATION" "ORGANIZATION_ALIAS" INNER JOIN "DW_LEGACY"."ITEM" "ITEM" on "ORGANIZATION_ALIAS"."ORGANIZATION_DIM_ID"="ITEM"."BRANCH_PLANT") LEFT OUTER JOIN ("DW_LEGACY"."ITEM" "ITEM_ALIAS_COMP" INNER JOIN "DW_LEGACY"."BILL_OF_MATERIAL" "BILL_OF_MATERIAL" on "ITEM_ALIAS_COMP"."ITEM_SID"="BILL_OF_MATERIAL"."BILL_OF_MATERIAL__ITEM_SID") on "ITEM"."ITEM_SID"="BILL_OF_MATERIAL"."BILL_OF_MATERIAL_KIT__IT_SID"
 where "ITEM"."STOCK_TYPE_CODE"=N'M' and "BILL_OF_MATERIAL"."TYPE_OF_BILL"=N'M' and "ORGANIZATION_ALIAS"."BRANCH_TYPE"<>N'LAB'
 group by "ITEM"."ITEM_NUMBER_2ND", "ITEM_ALIAS_COMP"."ITEM_NUMBER_2ND", "BILL_OF_MATERIAL"."FIXED_OR_VARIABLE_QUANTITY", "ITEM"."STOCK_TYPE_CODE", "BILL_OF_MATERIAL"."BRANCH_PLANT") "JDE4" LEFT OUTER JOIN (
select sum(round("BILL_OF_MATERIAL_WERCS"."PERCENT",4)) "Percent", "BILL_OF_MATERIAL_WERCS"."ITEM_NUMBER_2ND_COMPONENT" "Component_2nd_item_Number", "BILL_OF_MATERIAL_WERCS"."ITEM_NUMBER_2ND_PARENT" "Parent_2nd_Item_Number"
 from "DW_LEGACY"."BILL_OF_MATERIAL_WERCS" "BILL_OF_MATERIAL_WERCS"
 group by "BILL_OF_MATERIAL_WERCS"."ITEM_NUMBER_2ND_COMPONENT", "BILL_OF_MATERIAL_WERCS"."ITEM_NUMBER_2ND_PARENT") "WERCS5" on "JDE4"."Parent_Second_Item_Number"="WERCS5"."Parent_2nd_Item_Number" and "JDE4"."C_2nd_Item_Number"="WERCS5"."Component_2nd_item_Number"
 group by "JDE4"."Parent_Second_Item_Number", "JDE4"."C_2nd_Item_Number", "WERCS5"."Percent", "WERCS5"."Component_2nd_item_Number", "WERCS5"."Parent_2nd_Item_Number", "JDE4"."Branch_Plant") "T0") "T0"
 where "T0"."C10"<>0



