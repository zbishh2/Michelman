import json, subprocess, sys

B70 = '{ "161017CX","161190PX","171143PX","171228PX.E","181020CX.E","181136IX","181192IX","181193EU.E","191011CX","191026CX.E","191245PX","23409A","ABEX2525","APT10","APT11","DMAEMA","EMA3065","ET2012.E","ET2022.E","ET4075.E","ET440.E","FERSUL7W","HP1432AT","HP1632","MD4020","MD4020C","MD4020S","MD4021","MD4021C","MD4021S","MD4022","MD4022C","MD4023","MD4023C","MDU20","MDU2012.E","MDU2012B.E","MDU4075.E","MDU4075B.E","MDU440.E","MDU440B.E","MPEG2000","MW40504","MW40514","NP4LF","NP4LF.S","OMS","PUD1.E","STODSO","U1001","U101","U201","U2022","U2022EU.E","U2023","U204","U204EU.E","U470","U501","U501B","U502","U502.E","U502X1.E","U601","U701","U802","U802.E","WAV501","WD40","WD40T" }'
B47 = '{ "161017CX","161190PX","171143PX","171228PX.E","181193EU.E","191245PX","APT10","APT11","DMAEMA","EMA3065","FERSUL7W","HP1432AT","HP1632","MD4020","MD4020C","MD4021","MD4021C","MD4022C","MD4023","MD4023C","MDU2012.E","MDU2012B.E","MDU20","MDU4075.E","MDU4075B.E","MDU440.E","MDU440B.E","MW40504","MW40514","NP4LF.S","PUD1.E","STODSO","U1001","U101","U201","U2022","U204","U470","U501B","U501","U502.E","U502","U601","U701","U802.E","WAV501","WD40" }'

files = {
'11_forecast_lines.dax': ('''// Forecast rows for the 70 CM bulk items, requested date in the Cognos window (first of current month .. end of month(today+450)),
// every decode column carried so RELOAD_KEY / TABLE_TYPE equivalents can be identified locally.
EVALUATE
VAR B = %(B70)s
RETURN
SELECTCOLUMNS(
    FILTER(
        FactForecast,
        TRIM(RELATED('Item Branch'[Item Bulk])) IN B
            && FactForecast[RequestedDate] >= DATE(2026,8,1)
            && FactForecast[RequestedDate] <= DATE(2027,11,30)
    ),
    "Company", FactForecast[Company],
    "BusinessUnit", FactForecast[BusinessUnit],
    "IBBranch", RELATED('Item Branch'[Business Unit]),
    "BUDim", RELATED('Business Unit'[Business Unit]),
    "GlobalBulk", FactForecast[Global Bulk],
    "Bulk", FactForecast[Bulk Item],
    "IBGlobalBulk", RELATED('Item Branch'[Item Global Bulk]),
    "IBBulk", RELATED('Item Branch'[Item Bulk]),
    "Item2nd", FactForecast[ItemNum2nd],
    "IBItem2nd", RELATED('Item Branch'[Item Num 2nd]),
    "Desc1", RELATED('Item Branch'[Item Num 2nd Desc]),
    "Desc2", RELATED('Item Branch'[Description 2]),
    "ReqDate", FactForecast[RequestedDate],
    "TM", RELATED('Territory Manager'[Mailing Name]),
    "ForecastType", FactForecast[ForecastType],
    "ForecastTypeDesc", FactForecast[ForecastTypeDesc],
    "RevisedFlag", FactForecast[RevisedFlag],
    "Bypass", FactForecast[BypassForcingYN],
    "DWSource", FactForecast[DWSource],
    "OrderType", FactForecast[OrderType],
    "QtyForecast", FactForecast[QuantityForecast],
    "QtyFcLB", FactForecast[QuantityForecastLB],
    "QtyFcKG", FactForecast[QuantityForecastKG],
    "CFLB", FactForecast[ConversionFactorLB],
    "CFKG", FactForecast[ConversionFactorKG],
    "UOMPrimary", FactForecast[UOM Primary],
    "AddressNum", FactForecast[AddressNum],
    "AddrName", RELATED('Address'[Address Name]),
    "GlobalParentDesc", RELATED('Address'[Global Parent Desc]),
    "Chemist", RELATED('Item Branch'[Chemist Name]),
    "UpdatedDate", FactForecast[UpdatedDate]
)
''', "Probe R22 E", "Company:string,BusinessUnit:string,IBBranch:string,BUDim:string,GlobalBulk:string,Bulk:string,IBGlobalBulk:string,IBBulk:string,Item2nd:string,IBItem2nd:string,Desc1:string,Desc2:string,ReqDate:dateTime,TM:string,ForecastType:string,ForecastTypeDesc:string,RevisedFlag:string,Bypass:string,DWSource:int64,OrderType:string,QtyForecast:double,QtyFcLB:double,QtyFcKG:double,CFLB:double,CFKG:double,UOMPrimary:string,AddressNum:int64,AddrName:string,GlobalParentDesc:string,Chemist:string,UpdatedDate:dateTime"),

'12_wo_lines.dax': ('''// Work Order Parts List rows whose component item is a CM bulk item, with the WO header and the parent item via Work Order Detail.
EVALUATE
VAR B = %(B70)s
VAR P =
    ADDCOLUMNS(
        FILTER(
            'Work Order Parts List',
            TRIM(RELATED('Item Branch'[Item Bulk])) IN B
                && ('Work Order Parts List'[QuantityOrdered] > 0 || 'Work Order Parts List'[QuantityShipped] > 0 || 'Work Order Parts List'[QuantityTransaction] > 0)
                && (RELATED('Work Order'[Start Date]) >= DATE(2020,1,1) || RELATED('Work Order'[Completed Date]) >= DATE(2020,1,1))
        ),
        "@pib", LOOKUPVALUE('Work Order Detail'[ItemBranchSKey], 'Work Order Detail'[WorkOrderSKey], 'Work Order Parts List'[WorkOrderSKey]),
        "@pbr", LOOKUPVALUE('Work Order Detail'[BranchSKey], 'Work Order Detail'[WorkOrderSKey], 'Work Order Parts List'[WorkOrderSKey])
    )
RETURN
SELECTCOLUMNS(
    P,
    "WONum", RELATED('Work Order'[Work Order Num]),
    "WOType", RELATED('Work Order'[Work Order Type]),
    "StartDate", RELATED('Work Order'[Start Date]),
    "CompletedDate", RELATED('Work Order'[Completed Date]),
    "WOStatus", RELATED('Work Order'[Work Order Status]),
    "ParentItem2nd", RELATED('Work Order'[Parent Item Num 2nd]),
    "ParentBranch", LOOKUPVALUE(Branch[Branch Plant], Branch[BranchSKey], [@pbr]),
    "ParentGlobalBulk", LOOKUPVALUE('Item Branch'[Item Global Bulk], 'Item Branch'[ItemBranchSKey], [@pib]),
    "ParentBulk", LOOKUPVALUE('Item Branch'[Item Bulk], 'Item Branch'[ItemBranchSKey], [@pib]),
    "ParentIBItem2nd", LOOKUPVALUE('Item Branch'[Item Num 2nd], 'Item Branch'[ItemBranchSKey], [@pib]),
    "PLBranch", RELATED(Branch[Branch Plant]),
    "PLBusinessUnit", 'Work Order Parts List'[BusinessUnit],
    "CompItem2nd", 'Work Order Parts List'[Component Item Num 2nd],
    "CompIBItem2nd", RELATED('Item Branch'[Item Num 2nd]),
    "CompGlobalBulk", RELATED('Item Branch'[Item Global Bulk]),
    "CompBulk", RELATED('Item Branch'[Item Bulk]),
    "CompStockType", RELATED('Item Branch'[Stocking Type]),
    "UOM", 'Work Order Parts List'[UOM],
    "QtyOrdered", 'Work Order Parts List'[QuantityOrdered],
    "QtyShipped", 'Work Order Parts List'[QuantityShipped],
    "QtyTransaction", 'Work Order Parts List'[QuantityTransaction],
    "PLCompletion", 'Work Order Parts List'[Completion Date],
    "CompLineNum", 'Work Order Parts List'[Component Line Num],
    "CompType", 'Work Order Parts List'[Component Type],
    "LineType", 'Work Order Parts List'[Line Type]
)
''', "Probe R22 F", "WONum:int64,WOType:string,StartDate:dateTime,CompletedDate:dateTime,WOStatus:string,ParentItem2nd:string,ParentBranch:string,ParentGlobalBulk:string,ParentBulk:string,ParentIBItem2nd:string,PLBranch:string,PLBusinessUnit:string,CompItem2nd:string,CompIBItem2nd:string,CompGlobalBulk:string,CompBulk:string,CompStockType:string,UOM:string,QtyOrdered:double,QtyShipped:double,QtyTransaction:double,PLCompletion:dateTime,CompLineNum:int64,CompType:string,LineType:string"),

'13_bom_lines.dax': ('''// Bill Of Material Expanded rows: M bills, effective thru >= today, component bulk in the CM list; all levels and branches carried.
EVALUATE
VAR B = %(B70)s
RETURN
SELECTCOLUMNS(
    FILTER(
        'Bill Of Material Expanded',
        TRIM(RELATED('Item Branch'[Item Bulk])) IN B
            && 'Bill Of Material Expanded'[Type Bill of Material] = "M"
            && 'Bill Of Material Expanded'[BOM Effective Thru Date] >= TODAY()
    ),
    "ParentBranch", 'Bill Of Material Expanded'[Parent Branch],
    "CompBranch", 'Bill Of Material Expanded'[Component Branch],
    "ParentItem", 'Bill Of Material Expanded'[Parent Item],
    "InterimItem", 'Bill Of Material Expanded'[Interim Item],
    "IsInterim", 'Bill Of Material Expanded'[Is Interim Item],
    "CompItem2nd", 'Bill Of Material Expanded'[Component Item Num 2nd],
    "Item2nd", 'Bill Of Material Expanded'[Item Num 2nd],
    "CompIBItem2nd", RELATED('Item Branch'[Item Num 2nd]),
    "CompBulk", RELATED('Item Branch'[Item Bulk]),
    "CompGlobalBulk", RELATED('Item Branch'[Item Global Bulk]),
    "Level", 'Bill Of Material Expanded'[Component BOM Level],
    "CompQty", 'Bill Of Material Expanded'[ComponentQuantity],
    "OrigQty", 'Bill Of Material Expanded'[OriginalQuantity],
    "ParentQty", 'Bill Of Material Expanded'[ParentQuantity],
    "ChildUOM", 'Bill Of Material Expanded'[Child UOM],
    "EffFrom", 'Bill Of Material Expanded'[BOM Effective From Date],
    "EffThru", 'Bill Of Material Expanded'[BOM Effective Thru Date],
    "CalDate", 'Bill Of Material Expanded'[CalendarDate]
)
''', "Probe R22 G", "ParentBranch:string,CompBranch:string,ParentItem:string,InterimItem:string,IsInterim:boolean,CompItem2nd:string,Item2nd:string,CompIBItem2nd:string,CompBulk:string,CompGlobalBulk:string,Level:int64,CompQty:double,OrigQty:double,ParentQty:double,ChildUOM:string,EffFrom:dateTime,EffThru:dateTime,CalDate:dateTime"),

'14_item_details.dax': ('''// Item Branch rows for the 47-item list, branch not containing LAB.
EVALUATE
VAR B = %(B47)s
RETURN
SELECTCOLUMNS(
    FILTER(
        'Item Branch',
        TRIM('Item Branch'[Item Bulk]) IN B
            && NOT CONTAINSSTRING('Item Branch'[Business Unit], "LAB")
    ),
    "Branch", 'Item Branch'[Business Unit],
    "GlobalBulk", 'Item Branch'[Item Global Bulk],
    "Bulk", 'Item Branch'[Item Bulk],
    "Item2nd", 'Item Branch'[Item Num 2nd],
    "StockType", 'Item Branch'[Stocking Type],
    "MPF", 'Item Branch'[Master Planning Family],
    "LeadTimeLevel", 'Item Branch'[Lead time Level],
    "LeadTimeMFG", 'Item Branch'[Lead Time MFG_BP],
    "PlanningCode", 'Item Branch'[Planning Code],
    "PTF", 'Item Branch'[Planning Time Fence Days],
    "SafetyStock", 'Item Branch'[SafetyStock],
    "SafetyStockSAFE", 'Item Branch'[Safety Stock SAFE],
    "ShelfLife", 'Item Branch'[Shelf Life Days],
    "SupplierNum", 'Item Branch'[Branch Supplier Num],
    "SupplierName", 'Item Branch'[Branch Supplier Name],
    "PlannerNum", 'Item Branch'[Planner Num],
    "PlannerName", 'Item Branch'[Planner Name],
    "Planner", 'Item Branch'[Planner],
    "BuyerNum", 'Item Branch'[Buyer Num],
    "BuyerName", 'Item Branch'[Buyer Name],
    "ActiveFlag", 'Item Branch'[Active Flag Status],
    "Partition", 'Item Branch'[Partition],
    "SRC01", 'Item Branch'[Sales Reporting Code 01],
    "SRC01Desc", 'Item Branch'[Sales Reporting Code 01 Desc],
    "SRC03", 'Item Branch'[Sales Reporting Code 03],
    "SRC03Desc", 'Item Branch'[Sales Reporting Code 03 Desc],
    "SRC04", 'Item Branch'[Sales Reporting Code 04],
    "SRC04Desc", 'Item Branch'[Sales Reporting Code 04 Desc],
    "StockTypeDesc", 'Item Branch'[Stocking Type Desc],
    "MPFDesc", 'Item Branch'[Master Planning Family Desc]
)
''', "Probe R22 H", "Branch:string,GlobalBulk:string,Bulk:string,Item2nd:string,StockType:string,MPF:string,LeadTimeLevel:int64,LeadTimeMFG:int64,PlanningCode:string,PTF:int64,SafetyStock:double,SafetyStockSAFE:double,ShelfLife:int64,SupplierNum:int64,SupplierName:string,PlannerNum:int64,PlannerName:string,Planner:string,BuyerNum:int64,BuyerName:string,ActiveFlag:string,Partition:int64,SRC01:string,SRC01Desc:string,SRC03:string,SRC03Desc:string,SRC04:string,SRC04Desc:string,StockTypeDesc:string,MPFDesc:string"),
}

for n, (t, tbl, cols) in files.items():
    open(n, 'w', encoding='utf-8').write(t % {'B70': B70, 'B47': B47})
    out = subprocess.run([sys.executable, 'mk_probe_def.py', n, tbl, cols], capture_output=True, text=True, check=True).stdout
    open(n.split('_')[0] + '.json', 'w', encoding='utf-8').write(out)
    print(n, tbl, len(out))
