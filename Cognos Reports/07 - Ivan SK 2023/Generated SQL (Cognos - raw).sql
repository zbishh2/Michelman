SK 2023




select decode(trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")), 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'India', 'SHAN', 'China', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'ERROR') "REGION", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMGBLK")) "Global_Bulk_Item", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", "F4102_Item_Branch_Alias_WO"."IBSTKT" "Stock_Type", trim(both
 from "F41021_Item_Location"."LILOTN") "Lot_Number", trim(both
 from "F41021_Item_Location"."LILOCN") "Location", "F41021_Item_Location"."LILOTS" "Status", sum("F41021_Item_Location"."LIPQOH"/10000) "Quantity_On_Hand", sum("F41021_Item_Location"."LIHCOM"/10000) "Hard_Commit", "F4101_Item_Master"."IMUOM1" "Primary_UOM", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBPRP4") "Master_Planning_Family", to_date(sysdate) "NOW", case  when min("F4101_Item_Master"."IMUOM1")='KG' then sum("F41021_Item_Location"."LIPQOH"/10000) when min("F4101_Item_Master"."IMUOM1")='LB' then sum(("F41021_Item_Location"."LIPQOH"/10000))*0.453593 when min("F4101_Item_Master"."IMUOM1")='EA' then sum(("F41021_Item_Location"."LIPQOH"/10000))*20 else 100000 end  "OH_KG", case  when min("F4101_Item_Master"."IMUOM1")='LB' then sum("F41021_Item_Location"."LIPQOH"/10000) when min("F4101_Item_Master"."IMUOM1")='KG' then sum(("F41021_Item_Location"."LIPQOH"/10000))/0.453593 when min("F4101_Item_Master"."IMUOM1")='EA' then sum(("F41021_Item_Location"."LIPQOH"/10000))*44 else 100000 end  "OH_LB"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F41021" "F41021_Item_Location", "PRODDTA"."F4101" "F4101_Item_Master"
 where trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4') and "F41021_Item_Location"."LIPQOH"/10000>0 and trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) in ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S', 'DPI8600.E', 'PH00007E.E', '201250PX.E', 'DPI8200.E', 'MF4915.E', 'MFHS1130.E', 'MFP1857.E', 'MP3000.E', 'MP48525R.E', 'MP4932.E', 'MP498340R.E', 'PH00017E.E', 'MFP1853R.E', 'MP498345P.E', 'MP4983RHSA.E', '201081CX', '241083PX.S', '241088PX.S', '241089PX.S', '241199PX.S', '241252PX.S', '251095NX.S', '251142PX.S', '251144PX.S', '251194NX.S', '251268PX.S', 'MF1204.S', 'MF1306D.S', 'MF1406.S', 'MFHS1881.S', 'MFP1853R.S', 'MFP1883.S', 'MP4982SC.S', 'MP498340R.S', 'MP498345N.S', 'MP4983R.S', 'MP4983RHS.S', 'PH00017E.S', 'PI8545.S', '241253PX.S', '241168PX', '241201FX', 'DP040', 'DPI8600', 'HSCF280', 'ILP040', 'KHI205', 'KHI340', 'MED310', 'MED800', 'MFHS168', 'MFHS268', 'MFP1853R', 'MP04422R', 'MP3000', 'MP48525R', 'MP498340D', 'MP498340R', 'MP498345N', 'MP4983RHS', 'MT242AF', 'PA845H', 'PH00015E', 'PH00017E', 'UBD211', 'UBD268', 'UTS610', '251379PX.E', 'MFP1883.E', 'MP4983RAM.E', 'PH00001A.E', '251095NX.E', '251194NX.E', 'MD7900.E', 'MP4983R.E', '251246NX.E', '251095NX', '251194NX', '261044NX', '261074NX', '605000007', 'MFP1883', 'MP4983R', 'MP4983RN', 'RM108', 'UPR420', '221247PX.E', 'MP2960.E', '221247PX', '231093FX', 'MP2960') and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM" and "F4102_Item_Branch_Alias_WO"."IBITM"="F41021_Item_Location"."LIITM" and "F4102_Item_Branch_Alias_WO"."IBMCU"="F41021_Item_Location"."LIMCU"
 group by trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")), trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMGBLK")), trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")), trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")), trim(both
 from "F41021_Item_Location"."LILOCN"), trim(both
 from "F41021_Item_Location"."LILOTN"), "F41021_Item_Location"."LILOTS", "F4101_Item_Master"."IMUOM1", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBPRP4"), decode(trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")), 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'India', 'SHAN', 'China', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'ERROR'), "F4102_Item_Branch_Alias_WO"."IBSTKT"
 order by "Global_Bulk_Item" asc nulls last, "Bulk_Item" asc nulls last, "C_2nd_Item_Number" asc nulls last





select "T0"."C0" "C0", "T0"."C3" "C1", "T0"."C4" "C2", "T0"."C5" "C3", "T0"."C6" "C4", "T0"."C7" "C5", "T0"."C8" "C6", "T0"."C9" "C7", "T0"."C10" "C8", "T0"."C11" "C9", "T0"."C13" "C10", "T0"."C14" "C11", "T0"."C15" "C12", "T0"."C12" "C13", "T0"."C1" "C14", "T0"."C2" "C15", min("T0"."C8") over (partition by "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C9", "T0"."C10", "T0"."C14", "T0"."C15", "T0"."C0") "C16", min("T0"."C15") over (partition by "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C9", "T0"."C10", "T0"."C14", "T0"."C15", "T0"."C0") "C17", "T0"."C16" "C18", "T0"."C17" "C19", "T0"."C18" "C20", min("T0"."C13") over (partition by "T0"."C3", "T0"."C4", "T0"."C5", "T0"."C6", "T0"."C7", "T0"."C8", "T0"."C9", "T0"."C10", "T0"."C14", "T0"."C15", "T0"."C0") "C21", "T0"."C19" "C22"
 from (
select decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR') "C0", sum("F4801_Work_Order"."WASOQS"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C1", count("F4801_Work_Order"."WASOQS"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C2", trim(both
 from "F4801_Work_Order"."WAMMCU") "C3", "F4801_Work_Order"."WADOCO" "C4", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "C5", "F554101_ITEM_TAG"."IMBULK" "C6", trim(both
 from "F4801_Work_Order"."WALITM") "C7", "F4801_Work_Order"."WASRST" "C8", case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end  "C9", case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end  "C10", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end  "C11", case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end  "C12", "F4801_Work_Order"."WAUOM" "C13", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL") "C14", "F3111_Work_Order_Parts"."WMUM" "C15", sum("F3111_Work_Order_Parts"."WMTRQT"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C16", sum("F4801_Work_Order"."WAUORG"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C17", count("F4801_Work_Order"."WAUORG"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C18", sum("F3111_Work_Order_Parts"."WMUORG"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C19", avg("F4801_Work_Order"."WAUORG"/10000) over (partition by trim(both
 from "F4801_Work_Order"."WAMMCU"), "F4801_Work_Order"."WADOCO", trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), "F554101_ITEM_TAG"."IMBULK", trim(both
 from "F4801_Work_Order"."WALITM"), "F4801_Work_Order"."WASRST", case  when "F4801_Work_Order"."WATRDJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WATRDJ") else NULL end , case  when "F4801_Work_Order"."WASTRT">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end , case  when "F4801_Work_Order"."WADRQJ">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WADRQJ") else NULL end , case  when "F4801_Work_Order"."WASTRX">0 then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRX") else NULL end , "F4801_Work_Order"."WAUOM", trim(both
 from "F3111_Work_Order_Parts"."WMCPIL"), "F3111_Work_Order_Parts"."WMUM", decode(trim(both
 from "F4801_Work_Order"."WAMMCU"), 'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')) "C20"
 from "PRODDTA"."F4801" "F4801_Work_Order", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F3111" "F3111_Work_Order_Parts", "PRODDTA"."F4101" "F4101_Item_Master", "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO"
 where trim(both
 from "F3111_Work_Order_Parts"."WMCPIL") in ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S') and "F3111_Work_Order_Parts"."WMTRQT"/10000+"F3111_Work_Order_Parts"."WMUORG"/10000>0 and case  when ("F4801_Work_Order"."WASTRT">0) then "PRODDTA".JUL2DATE("F4801_Work_Order"."WASTRT") else NULL end >=DATE '2026-03-01' and trim(both
 from "F4801_Work_Order"."WALITM") not  like '%-%' and "F4801_Work_Order"."WAUOM" in ('LB', 'KG') and "F4801_Work_Order"."WASRST" not  in ('MM') and "F4801_Work_Order"."WADOCO"="F3111_Work_Order_Parts"."WMDOCO" and "F4801_Work_Order"."WAITM"="F4102_Item_Branch_Alias_WO"."IBITM" and "F4801_Work_Order"."WAMMCU"="F4102_Item_Branch_Alias_WO"."IBMCU" and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM") "T0"
 where "T0"."C20">0




with "Item_Information8" as (
select distinct trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) "Branch_Plant", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMGBLK")) "Global_Bulk_Item", trim(both
 from trim(both
 from "F554101_ITEM_TAG"."IMBULK")) "Bulk_Item", trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM")) "C_2nd_Item_Number", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBPRP4") "Master_Planning_Family", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBSTKT") "Stock_Type"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where trim(both
 from trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU")) in ('SING', 'SNG4', 'MUM3', 'SHAN', 'AUBA', 'AUB2') and trim(both
 from "F4102_Item_Branch_Alias_WO"."IBSTKT") not  in ('I', 'O') and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"), "F4211_Open_Sales_Orders" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDDCTO", "F4211"."SDLNID", "F4211"."SDSFXO", "F4211"."SDMCU", "F4211"."SDSHAN", case  when "F4211"."SDDRQJ">0 then "PRODDTA".JUL2DATE("F4211"."SDDRQJ") else NULL end  "SDDRQJ", case  when "F4211"."SDTRDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDTRDJ") else NULL end  "SDTRDJ", case  when "F4211"."SDPDDJ">0 then "PRODDTA".JUL2DATE("F4211"."SDPDDJ") else NULL end  "SDPDDJ", "F4211"."SDVR01", "F4211"."SDLITM", "F4211"."SDLNTY", "F4211"."SDNXTR", "F4211"."SDLTTR", "F4211"."SDEMCU", "F4211"."SDUOM1", "F4211"."SDPQOR", "F4211"."SDUOM2", "F4211"."SDSQOR"
 from "PRODDTA"."F4211" "F4211"), "F4211_F0006_join_to_F42140" as (
select "F4211"."SDKCOO", "F4211"."SDDOCO", "F4211"."SDDCTO", "F4211"."SDLNID", "F4211"."SDSHAN", case  when NVL(trim(both
 from "F0006"."MCRP01"), '-') is null  then  null  else NVL(trim(both
 from "F0006"."MCRP01"), '-') || 'GTM' end  "CMRTYPE"
 from "PRODDTA"."F4211" "F4211" LEFT OUTER JOIN "PRODDTA"."F0006" "F0006" on "F4211"."SDEMCU"="F0006"."MCMCU"), "F42140__CSR" as (
select "F42140"."CMAN8", "F0101"."ABALPH"
 from "PRODDTA"."F42140" "F42140", "PRODDTA"."F0101" "F0101"
 where "F42140"."CMRTYPE"='CSR' and "F42140"."CMSLSM"="F0101"."ABAN8"), "Sales_Orders7" as (
select "T0"."C0" "Order_Company", "T0"."C1" "Customer_Code", "T0"."C2" "Customer_Name", "T0"."C3" "Customer_Segmentation", "T0"."C4" "Global_Parent", "T0"."C5" "Country_Name", "T0"."C6" "Branch_Plant", "T0"."C7" "Order_Number", "T0"."C8" "C_2nd_Item_Number", "T0"."C9" "Next_Status", "T0"."C10" "Last_Status", "T0"."C11" "Line_Type", "T0"."C12" "Primary_Quantity_Ordered", "T0"."C13" "Primary_UOM", "T0"."C14" "Secondary_Quantity_Ordered", "T0"."C15" "Secondary_UOM", "T0"."C16" "Order_Date", "T0"."C17" "Requested_Date", "T0"."C18" "Promised_Ship_Date", "T0"."C18" "Scheduled_Pick_Date", "T0"."C19" "Rev_Bus_Unit", "T0"."C20" "TM_Name", "T0"."C21" "Customer_PO", "T0"."C22" "Hold_Orders_Code", "T0"."C23" "CSR_Name"
 from (
select "F4211_Open_Sales_Orders"."SDKCOO" "C0", trim(both
 from "F0101_Ship_To_Customer"."ABAN8") "C1", trim(both
 from "F0101_Ship_To_Customer"."ABALPH") "C2", "F0101_Ship_To_Customer"."ABAC06" "C3", trim(both
 from "F0101_Ship_To_Customer"."ABAN86") "C4", trim(both
 from "T3"."DRDL01") "C5", trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") "C6", "F4211_Open_Sales_Orders"."SDDOCO" "C7", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM") "C8", "F4211_Open_Sales_Orders"."SDNXTR" "C9", "F4211_Open_Sales_Orders"."SDLTTR" "C10", "F4211_Open_Sales_Orders"."SDLNTY" "C11", sum("F4211_Open_Sales_Orders"."SDPQOR"/10000) "C12", "F4211_Open_Sales_Orders"."SDUOM1" "C13", sum("F4211_Open_Sales_Orders"."SDSQOR"/10000) "C14", "F4211_Open_Sales_Orders"."SDUOM2" "C15", "F4211_Open_Sales_Orders"."SDTRDJ" "C16", "F4211_Open_Sales_Orders"."SDDRQJ" "C17", "F4211_Open_Sales_Orders"."SDPDDJ" "C18", "F4211_Open_Sales_Orders"."SDEMCU" "C19", trim(both
 from decode("F0101_Sales_Rep"."ABALPH", NULL, 'Unassigned', "F0101_Sales_Rep"."ABALPH")) "C20", trim(both
 from "F4211_Open_Sales_Orders"."SDVR01") "C21", "F4201_Order_Header"."SHHOLD" "C22", trim(both
 from "F42140__CSR"."ABALPH") "C23"
 from (((((("F4211_Open_Sales_Orders" INNER JOIN "PRODDTA"."F0101" "F0101_Ship_To_Customer" on "F4211_Open_Sales_Orders"."SDSHAN"="F0101_Ship_To_Customer"."ABAN8") INNER JOIN "PRODDTA"."F0116" "F0116_Ship_To_Address" on "F0101_Ship_To_Customer"."ABAN8"="F0116_Ship_To_Address"."ALAN8") INNER JOIN "PRODDTA"."F4201" "F4201_Order_Header" on "F4211_Open_Sales_Orders"."SDKCOO"="F4201_Order_Header"."SHKCOO" and "F4211_Open_Sales_Orders"."SDDOCO"="F4201_Order_Header"."SHDOCO" and "F4211_Open_Sales_Orders"."SDDCTO"="F4201_Order_Header"."SHDCTO" and "F4211_Open_Sales_Orders"."SDSFXO"="F4201_Order_Header"."SHSFXO") LEFT OUTER JOIN "F4211_F0006_join_to_F42140" on "F4211_Open_Sales_Orders"."SDKCOO"="F4211_F0006_join_to_F42140"."SDKCOO" and "F4211_Open_Sales_Orders"."SDDOCO"="F4211_F0006_join_to_F42140"."SDDOCO" and "F4211_Open_Sales_Orders"."SDDCTO"="F4211_F0006_join_to_F42140"."SDDCTO" and "F4211_Open_Sales_Orders"."SDLNID"="F4211_F0006_join_to_F42140"."SDLNID") LEFT OUTER JOIN ("PRODDTA"."F42140" "F42140_Sales_Rep" INNER JOIN "PRODDTA"."F0101" "F0101_Sales_Rep" on "F42140_Sales_Rep"."CMSLSM"="F0101_Sales_Rep"."ABAN8") on "F4211_F0006_join_to_F42140"."SDSHAN"="F42140_Sales_Rep"."CMAN8" and "F4211_F0006_join_to_F42140"."CMRTYPE"="F42140_Sales_Rep"."CMRTYPE") LEFT OUTER JOIN "F42140__CSR" on "F4211_Open_Sales_Orders"."SDSHAN"="F42140__CSR"."CMAN8") LEFT OUTER JOIN "PRODCTL"."F0005" "T3" on trim(both
 from "F0116_Ship_To_Address"."ALCTR")=trim(both
 from "T3"."DRKY") and '00  '="T3"."DRSY" and 'CN'="T3"."DRRT"
 where "F4211_Open_Sales_Orders"."SDLNTY"='S' and "F4211_Open_Sales_Orders"."SDPQOR"/10000>0 and "F4211_Open_Sales_Orders"."SDNXTR" not  in ('570', '580', '620', '999') and trim(both
 from "F4211_Open_Sales_Orders"."SDMCU") in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4', 'BARC', 'CIND', 'CINR')
 group by "F4211_Open_Sales_Orders"."SDKCOO", trim(both
 from "F0101_Ship_To_Customer"."ABAN8"), trim(both
 from "F0101_Ship_To_Customer"."ABALPH"), "F0101_Ship_To_Customer"."ABAC06", trim(both
 from "F0101_Ship_To_Customer"."ABAN86"), trim(both
 from "T3"."DRDL01"), trim(both
 from "F4211_Open_Sales_Orders"."SDMCU"), "F4211_Open_Sales_Orders"."SDDOCO", trim(both
 from "F4211_Open_Sales_Orders"."SDLITM"), "F4211_Open_Sales_Orders"."SDNXTR", "F4211_Open_Sales_Orders"."SDLTTR", "F4211_Open_Sales_Orders"."SDLNTY", "F4211_Open_Sales_Orders"."SDUOM1", "F4211_Open_Sales_Orders"."SDUOM2", "F4211_Open_Sales_Orders"."SDTRDJ", "F4211_Open_Sales_Orders"."SDDRQJ", "F4211_Open_Sales_Orders"."SDPDDJ", "F4211_Open_Sales_Orders"."SDEMCU", trim(both
 from decode("F0101_Sales_Rep"."ABALPH", NULL, 'Unassigned', "F0101_Sales_Rep"."ABALPH")), trim(both
 from "F4211_Open_Sales_Orders"."SDVR01"), "F4201_Order_Header"."SHHOLD", trim(both
 from "F42140__CSR"."ABALPH")) "T0") 
select "Sales_Orders7"."Order_Company" "Order_Company", "Sales_Orders7"."Customer_Code" "Customer_Code", "Sales_Orders7"."Customer_Name" "Customer_Name", "Sales_Orders7"."Customer_Segmentation" "Customer_Segmentation", "Sales_Orders7"."Global_Parent" "Global_Parent", "Sales_Orders7"."Country_Name" "Country_Name", "Sales_Orders7"."Branch_Plant" "Branch_Plant", "Sales_Orders7"."Order_Number" "Order_Number", "Sales_Orders7"."Hold_Orders_Code" "Hold_Orders_Code", "Item_Information8"."Global_Bulk_Item" "Global_Bulk_Item", "Item_Information8"."Bulk_Item" "Bulk_Item", "Sales_Orders7"."C_2nd_Item_Number" "C_2nd_Item_Number", "Sales_Orders7"."Next_Status" "Next_Status", "Sales_Orders7"."Last_Status" "Last_Status", case  when min("Sales_Orders7"."Primary_UOM")='LB' then sum("Sales_Orders7"."Primary_Quantity_Ordered")*0.453593 when min("Sales_Orders7"."Primary_UOM")='KG' then sum("Sales_Orders7"."Primary_Quantity_Ordered") when min("Sales_Orders7"."Primary_UOM")='EA' then sum("Sales_Orders7"."Primary_Quantity_Ordered")*20 else 1000000 end  "ORDER_KGs", case  when min("Sales_Orders7"."Primary_UOM")='LB' then sum("Sales_Orders7"."Primary_Quantity_Ordered") when min("Sales_Orders7"."Primary_UOM")='KG' then sum("Sales_Orders7"."Primary_Quantity_Ordered")/0.453593 when min("Sales_Orders7"."Primary_UOM")='EA' then sum("Sales_Orders7"."Primary_Quantity_Ordered")*44 else 1000000 end  "ORDER_LBs", sum("Sales_Orders7"."Primary_Quantity_Ordered") "Primary_Quantity_Ordered", "Sales_Orders7"."Primary_UOM" "Primary_UOM", sum("Sales_Orders7"."Secondary_Quantity_Ordered") "Secondary_Quantity_Ordered", "Sales_Orders7"."Secondary_UOM" "Secondary_UOM", "Sales_Orders7"."Order_Date" "Order_Date", "Sales_Orders7"."Requested_Date" "Requested_Date", "Sales_Orders7"."Promised_Ship_Date" "Promised_Ship_Date", "Sales_Orders7"."Scheduled_Pick_Date" "Scheduled_Pick_Date", "Sales_Orders7"."CSR_Name" "CSR_Name", "Sales_Orders7"."TM_Name" "TM_Name", "Sales_Orders7"."Customer_PO" "Customer_PO", "Item_Information8"."Master_Planning_Family" "Master_Planning_Family", "Item_Information8"."Stock_Type" "Stock_Type"
 from "Item_Information8" LEFT OUTER JOIN "Sales_Orders7" on "Item_Information8"."Branch_Plant"="Sales_Orders7"."Branch_Plant" and "Item_Information8"."C_2nd_Item_Number"="Sales_Orders7"."C_2nd_Item_Number"
 where "Sales_Orders7"."Branch_Plant"="Item_Information8"."Branch_Plant" and "Sales_Orders7"."C_2nd_Item_Number"="Item_Information8"."C_2nd_Item_Number" and "Item_Information8"."Bulk_Item" in ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S', 'DPI8600.E', 'PH00007E.E', '201250PX.E', 'DPI8200.E', 'MF4915.E', 'MFHS1130.E', 'MFP1857.E', 'MP3000.E', 'MP48525R.E', 'MP4932.E', 'MP498340R.E', 'PH00017E.E', 'MFP1853R.E', 'MP498345P.E', 'MP4983RHSA.E', '201081CX', '241083PX.S', '241088PX.S', '241089PX.S', '241199PX.S', '241252PX.S', '251095NX.S', '251142PX.S', '251144PX.S', '251194NX.S', '251268PX.S', 'MF1204.S', 'MF1306D.S', 'MF1406.S', 'MFHS1881.S', 'MFP1853R.S', 'MFP1883.S', 'MP4982SC.S', 'MP498340R.S', 'MP498345N.S', 'MP4983R.S', 'MP4983RHS.S', 'PH00017E.S', 'PI8545.S', '241253PX.S', '241168PX', '241201FX', 'DP040', 'DPI8600', 'HSCF280', 'ILP040', 'KHI205', 'KHI340', 'MED310', 'MED800', 'MFHS168', 'MFHS268', 'MFP1853R', 'MP04422R', 'MP3000', 'MP48525R', 'MP498340D', 'MP498340R', 'MP498345N', 'MP4983RHS', 'MT242AF', 'PA845H', 'PH00015E', 'PH00017E', 'UBD211', 'UBD268', 'UTS610', '251379PX.E', 'MFP1883.E', 'MP4983RAM.E', 'PH00001A.E', '251095NX.E', '251194NX.E', 'MD7900.E', 'MP4983R.E', '251246NX.E', '251095NX', '251194NX', '261044NX', '261074NX', '605000007', 'MFP1883', 'MP4983R', 'MP4983RN', 'RM108', 'UPR420', '221247PX.E', 'MP2960.E', '221247PX', '231093FX', 'MP2960')
 group by "Sales_Orders7"."Order_Company", "Sales_Orders7"."Customer_Code", "Sales_Orders7"."Customer_Name", "Sales_Orders7"."Customer_Segmentation", "Sales_Orders7"."Global_Parent", "Sales_Orders7"."Country_Name", "Sales_Orders7"."Hold_Orders_Code", "Sales_Orders7"."Branch_Plant", "Sales_Orders7"."Order_Number", "Sales_Orders7"."C_2nd_Item_Number", "Sales_Orders7"."Next_Status", "Sales_Orders7"."Last_Status", "Sales_Orders7"."Primary_UOM", "Sales_Orders7"."Secondary_UOM", "Sales_Orders7"."Requested_Date", "Sales_Orders7"."Promised_Ship_Date", "Sales_Orders7"."Scheduled_Pick_Date", "Sales_Orders7"."TM_Name", "Sales_Orders7"."CSR_Name", "Sales_Orders7"."Order_Date", "Sales_Orders7"."Customer_PO", "Item_Information8"."Global_Bulk_Item", "Item_Information8"."Bulk_Item", "Item_Information8"."Master_Planning_Family", "Item_Information8"."Stock_Type"
 order by "Order_Company" asc nulls last, "Global_Bulk_Item" asc nulls last, "Bulk_Item" asc nulls last, "Scheduled_Pick_Date" asc nulls last




select decode(trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'AUBA', 'EMEA', 'AUB2', 'EMEA', 'SING', 'PacRim', 'SNG4', 'PacRim', 'MUM3', 'India', 'SHAN', 'China') "REGION", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") "Branch_Plant", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "Global_Bulk_Item", trim(both
 from "F554101_ITEM_TAG"."IMBULK") "Bulk_Item", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM") "C_2nd_Item_Number", trim(both
 from "F41021_Item_Location"."LILOCN") "Location", trim(both
 from "F41021_Item_Location"."LILOTN") "Lot_Number", trim(both
 from "F41021_Item_Location"."LILOTS") "Status", "F4101_Item_Master"."IMUOM1" "Primary_UOM", sum("F41021_Item_Location"."LIPQOH"/10000) "Quantity_On_Hand", case  when min("F4101_Item_Master"."IMUOM1")='LB' then sum("F41021_Item_Location"."LIPQOH"/10000) when min("F4101_Item_Master"."IMUOM1")='KG' then sum(("F41021_Item_Location"."LIPQOH"/10000))/0.453593 when min("F4101_Item_Master"."IMUOM1")='EA' then sum(("F41021_Item_Location"."LIPQOH"/10000))*40 else 0 end  "LB"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F41021" "F41021_Item_Location", "PRODDTA"."F4101" "F4101_Item_Master"
 where (trim(both
 from "F41021_Item_Location"."LILOTS") is null or trim(both
 from "F41021_Item_Location"."LILOTS") in ('T', 'B', 'Q', 'H')) and trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4') and trim(both
 from "F554101_ITEM_TAG"."IMBULK") in ('251194NX.E', 'DPI8200.E', '201250PX.E', '251095NX.E', 'DPI8600.E', 'DP040', '251194NX', 'DPI8600', '251095NX', '251194NX.S', 'PR5985', 'PR5985.E', 'PR5985.S') and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM" and "F4102_Item_Branch_Alias_WO"."IBITM"="F41021_Item_Location"."LIITM" and "F4102_Item_Branch_Alias_WO"."IBMCU"="F41021_Item_Location"."LIMCU"
 group by decode(trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'AUBA', 'EMEA', 'AUB2', 'EMEA', 'SING', 'PacRim', 'SNG4', 'PacRim', 'MUM3', 'India', 'SHAN', 'China'), trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU"), trim(both
 from "F554101_ITEM_TAG"."IMGBLK"), trim(both
 from "F554101_ITEM_TAG"."IMBULK"), trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM"), trim(both
 from "F41021_Item_Location"."LILOCN"), trim(both
 from "F41021_Item_Location"."LILOTN"), trim(both
 from "F41021_Item_Location"."LILOTS"), "F4101_Item_Master"."IMUOM1"
 order by "Global_Bulk_Item" asc nulls last, "Bulk_Item" asc nulls last, "C_2nd_Item_Number" asc nulls last



select distinct decode(trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU"), 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'AUBA', 'EMEA', 'AUB2', 'EMEA', 'SING', 'PacRim', 'SNG4', 'PacRim', 'MUM3', 'India', 'SHAN', 'China') "REGION", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") "Branch_Plant", trim(both
 from "F554101_ITEM_TAG"."IMGBLK") "Global_Bulk_Item", trim(both
 from "F554101_ITEM_TAG"."IMBULK") "Bulk_Item", trim(both
 from "F4102_Item_Branch_Alias_WO"."IBLITM") "C_2nd_Item_Number", "F4101_Item_Master"."IMUOM1" "Primary_UOM", "F4102_Item_Branch_Alias_WO"."IBSAFE"/10000 "Safety_Stock", case  when "F4101_Item_Master"."IMUOM1"='LB' then "F4102_Item_Branch_Alias_WO"."IBSAFE"/10000 when "F4101_Item_Master"."IMUOM1"='KG' then ("F4102_Item_Branch_Alias_WO"."IBSAFE"/10000)/0.453593 when "F4101_Item_Master"."IMUOM1"='EA' then ("F4102_Item_Branch_Alias_WO"."IBSAFE"/10000)*40 else 0 end  "LB_Safety_Stock"
 from "PRODDTA"."F4102" "F4102_Item_Branch_Alias_WO", "PRODDTA"."F554101" "F554101_ITEM_TAG", "PRODDTA"."F4101" "F4101_Item_Master"
 where trim(both
 from "F4102_Item_Branch_Alias_WO"."IBMCU") in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4') and trim(both
 from "F554101_ITEM_TAG"."IMBULK") in ('251194NX', 'DPI8200', '201250PX', '251095NX', 'DPI8600', 'DP040', '251194NX.E', 'DPI8200.E', '201250PX.E', '251095NX.E', 'DPI8600.E', 'DP040.E', '251194NX.S', 'DPI8200.S', '201250PX.S', '251095NX.S', 'DPI8600.S', 'DP040.S', 'PR5985', 'PR5985.E', 'PR5985.S') and "F4102_Item_Branch_Alias_WO"."IBITM"="F4101_Item_Master"."IMITM" and "F4101_Item_Master"."IMITM"="F554101_ITEM_TAG"."IMITM"
 order by "REGION" asc nulls last
