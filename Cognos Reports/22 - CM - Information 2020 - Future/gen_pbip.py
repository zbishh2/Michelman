# One-shot generator for the report-22 PBIP (TMDL + PBIR) and the shipped <Table>.m files.
# The generated PBIP is the source of truth once written; rerunning this REPLACES the whole
# "22 - CM - Information 2020 - Future (SSAS Import)" folder from the queries and column lists
# below, discarding any edit made directly to the PBIP. The commented masters
# (<Table>.commented.m) are maintained by hand beside it.
import os, json, uuid, shutil, re

ROOT = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\22 - CM - Information 2020 - Future"
OUT = os.path.join(ROOT, "22 - CM - Information 2020 - Future (SSAS Import)")
NAME = "CM - Information 2020 - Future"
SM = os.path.join(OUT, NAME + ".SemanticModel")
RP = os.path.join(OUT, NAME + ".Report")
R19 = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\19 - 1 - Inventory - Safety Stock and Order Size\19 - Safety Stock and Order Size (SSAS Import)\Safety Stock and Order Size.Report"
DAVE = os.path.join(ROOT, r"Daves PBIP\CM - Information 2020 - Future_7_27_26.Report")
LOGO = "Michelman_logo-resize_3008774386659023596.png"

B70 = ["161017CX","161190PX","171143PX","171228PX.E","181020CX.E","181136IX","181192IX","181193EU.E","191011CX","191026CX.E","191245PX","23409A","ABEX2525","APT10","APT11","DMAEMA","EMA3065","ET2012.E","ET2022.E","ET4075.E","ET440.E","FERSUL7W","HP1432AT","HP1632","MD4020","MD4020C","MD4020S","MD4021","MD4021C","MD4021S","MD4022","MD4022C","MD4023","MD4023C","MDU20","MDU2012.E","MDU2012B.E","MDU4075.E","MDU4075B.E","MDU440.E","MDU440B.E","MPEG2000","MW40504","MW40514","NP4LF","NP4LF.S","OMS","PUD1.E","STODSO","U1001","U101","U201","U2022","U2022EU.E","U2023","U204","U204EU.E","U470","U501","U501B","U502","U502.E","U502X1.E","U601","U701","U802","U802.E","WAV501","WD40","WD40T"]
B47 = ["161017CX","161190PX","171143PX","171228PX.E","181193EU.E","191245PX","APT10","APT11","DMAEMA","EMA3065","FERSUL7W","HP1432AT","HP1632","MD4020","MD4020C","MD4021","MD4021C","MD4022C","MD4023","MD4023C","MDU20","MDU2012.E","MDU2012B.E","MDU4075.E","MDU4075B.E","MDU440.E","MDU440B.E","MW40504","MW40514","NP4LF.S","PUD1.E","STODSO","U1001","U101","U201","U2022","U204","U470","U501","U501B","U502","U502.E","U601","U701","U802.E","WAV501","WD40"]
assert len(B70) == 70 and len(set(B70)) == 70 and len(B47) == 47 and set(B47) <= set(B70)
VENDORS = [292788, 324808, 328211, 322114, 331380, 317501, 327516, 292774, 301843, 328143, 322976, 326444, 324962, 327267, 326095]

def daxlist(items): return "{ " + ", ".join('"%s"' % i for i in items) + " }"
def sqllist(items): return ", ".join("N'%s'" % i for i in items)

def tag(*parts): return str(uuid.uuid5(uuid.NAMESPACE_URL, "r22/" + "/".join(parts)))
def vid(*parts): return uuid.uuid5(uuid.NAMESPACE_URL, "r22vis/" + "/".join(parts)).hex[:20]

# ----------------------------------------------------------------------------- native queries
DAX = {}
DAX["Receipts"] = """EVALUATE
VAR Vendors = { %s }
VAR Receipts =
    FILTER (
        'Purchase Order Receiver',
        'Purchase Order Receiver'[Match Record Type] = "1"
            && 'Purchase Order Receiver'[Address Num PO] IN Vendors
            && 'Purchase Order Receiver'[Received Date] >= DATE ( 2020, 1, 1 )
            && RELATED ( 'Item Branch'[Item Num 2nd] ) <> "??????"
    )
RETURN
    SELECTCOLUMNS (
        Receipts,
        "Global Bulk Item", RELATED ( 'Item Branch'[Item Num Global Bulk] ),
        "Bulk Item", RELATED ( 'Item Branch'[Item Num Bulk] ),
        "2nd Item Number", RELATED ( 'Item Branch'[Item Num 2nd] ),
        "Vendor Name", IF ( TRIM ( RELATED ( Supplier[Supplier Name] ) ) = "", LOOKUPVALUE ( 'Address'[Address Name], 'Address'[Address Num], 'Purchase Order Receiver'[Address Num PO] ), RELATED ( Supplier[Supplier Name] ) ),
        "Vendor ID", 'Purchase Order Receiver'[Address Num PO],
        "Received Quantity (Line)", IF ( 'Purchase Order Receiver'[UOM Primary] = "LB", 'Purchase Order Receiver'[QuantityReceivedLB], IF ( 'Purchase Order Receiver'[UOM Primary] = "KG", 'Purchase Order Receiver'[QuantityReceivedKG], 'Purchase Order Receiver'[QuantityReceived] ) ),
        "Received Quantity LBs (Line)", 'Purchase Order Receiver'[QuantityReceivedLB],
        "Received Quantity KGs (Line)", 'Purchase Order Receiver'[QuantityReceivedKG],
        "Receipt Transaction Type", 'Purchase Order Receiver'[Document Type],
        "Receipt Transaction Date", 'Purchase Order Receiver'[Received Date],
        "Order Type", 'Purchase Order Receiver'[Order Type],
        "Document Number", 'Purchase Order Receiver'[Document Num],
        "Line Number", 'Purchase Order Receiver'[Line Num],
        "Document Type", 'Purchase Order Receiver'[Document Type],
        "Amount Received (Line)", 'Purchase Order Receiver'[AmountReceived],
        "Amount Received USD (Line)", 'Purchase Order Receiver'[AmountReceivedUSD],
        "Amount Received EUR (Line)", 'Purchase Order Receiver'[AmountReceivedEUR],
        "Date", 'Purchase Order Receiver'[Received Date],
        "Year", YEAR ( 'Purchase Order Receiver'[Received Date] ),
        "Month", MONTH ( 'Purchase Order Receiver'[Received Date] )
    )""" % ", ".join(str(v) for v in VENDORS)

DAX["Shipments"] = """EVALUATE
VAR Bulks = %s
VAR Lines =
    FILTER (
        Sales,
        TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks
            && Sales[Promised Shipment Date] >= DATE ( 2020, 1, 1 )
            && Sales[Cancelled_Flag] = 0
            && NOT Sales[Order Type] IN { "SB", "SR" }
    )
RETURN
    SELECTCOLUMNS (
        Lines,
        "Order Company", Sales[Order Company],
        "Branch Plant", TRIM ( Sales[BusinessUnit] ),
        "Order Number", Sales[Order Num],
        "Line Number", Sales[Line Num],
        "Open Indicator", Sales[Open Order Flag],
        "Global Bulk Item", RELATED ( 'Item Branch'[Item Global Bulk] ),
        "Bulk Item", RELATED ( 'Item Branch'[Item Bulk] ),
        "2nd Item Number", Sales[Item Num 2nd],
        "Description 1", Sales[Description 1],
        "Description 2", Sales[Description 2],
        "Freight Handling Code", Sales[Freight Handling Code],
        "Next Status", Sales[Status Code Next],
        "Order Net Amount USD (Line)", Sales[AmountOrderNetUSD],
        "Order Net Amount EUR (Line)", Sales[AmountOrderNetEUR],
        "Ordered Quantity LBs (Line)", Sales[QuantityOrderedLB],
        "Ordered Quantity KGs (Line)", Sales[QuantityOrderedKG],
        "Revenue Business Unit", RELATED ( 'Revenue Business Unit'[RBU] ),
        "TM Name", RELATED ( 'Territory Manager'[Mailing Name] ),
        "Customer Name", RELATED ( 'Customer Ship To'[Customer Ship To Name] ),
        "Country Name", RELATED ( 'Customer Ship To'[Country Desc] ),
        "Global Parent Name", RELATED ( Customer[Global Parent Name] ),
        "Date", Sales[Promised Shipment Date],
        "Year", YEAR ( Sales[Promised Shipment Date] ),
        "Month", MONTH ( Sales[Promised Shipment Date] ),
        "Chemist Name", RELATED ( 'Item Branch'[Chemist Name] )
    )""" % daxlist(B70)

DAX["Forecast"] = """EVALUATE
VAR Bulks = %s
VAR WindowStart = DATE ( YEAR ( TODAY () ), MONTH ( TODAY () ), 1 )
VAR WindowEnd = EOMONTH ( TODAY () + 450, 0 )
VAR Forecasts =
    FILTER (
        FactForecast,
        TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks
            && FactForecast[RequestedDate] >= WindowStart
            && FactForecast[RequestedDate] <= WindowEnd
            && FactForecast[QuantityForecast] > 0
    )
RETURN
    SELECTCOLUMNS (
        Forecasts,
        "Company Code", FactForecast[Company],
        "Branch Plant", TRIM ( FactForecast[BusinessUnit] ),
        "Global Bulk Item", FactForecast[Global Bulk],
        "Bulk Item", FactForecast[Bulk Item],
        "2nd Item Number", FactForecast[ItemNum2nd],
        "Item Description 1", RELATED ( 'Item Branch'[Item Num 2nd Desc] ),
        "Item Description 2", RELATED ( 'Item Branch'[Description 2] ),
        "Requested Date", FactForecast[RequestedDate],
        "Current Forecast (Line)", FactForecast[QuantityForecast],
        "Primary UOM", FactForecast[UOM Primary],
        "Current Forecast LB (Line)", FactForecast[QuantityForecastLB],
        "Current Forecast KG (Line)", FactForecast[QuantityForecastKG],
        "Date", FactForecast[RequestedDate],
        "Year", YEAR ( FactForecast[RequestedDate] ),
        "Month", MONTH ( FactForecast[RequestedDate] ),
        "Customer Code", FactForecast[AddressNum],
        "Customer Name", RELATED ( 'Address'[Address Name] ),
        "Global Parent Name", RELATED ( 'Address'[Global Parent Desc] ),
        "Chemist Name", RELATED ( 'Item Branch'[Chemist Name] )
    )""" % daxlist(B70)

DAX["Work Orders"] = """EVALUATE
VAR Bulks = %s
VAR PartsLines =
    ADDCOLUMNS (
        FILTER (
            'Work Order Parts List',
            TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks
                && 'Work Order Parts List'[QuantityOrdered] + 'Work Order Parts List'[QuantityTransaction] > 0
                && ( RELATED ( 'Work Order'[Start Date] ) >= DATE ( 2020, 1, 1 ) || RELATED ( 'Work Order'[Completed Date] ) >= DATE ( 2020, 1, 1 ) )
                && RELATED ( 'Work Order'[Work Order Type] ) = "WO"
        ),
        "@ParentItemBranchSKey", LOOKUPVALUE ( 'Work Order Detail'[ItemBranchSKey], 'Work Order Detail'[WorkOrderSKey], 'Work Order Parts List'[WorkOrderSKey] ),
        "@ParentBranchSKey", LOOKUPVALUE ( 'Work Order Detail'[BranchSKey], 'Work Order Detail'[WorkOrderSKey], 'Work Order Parts List'[WorkOrderSKey] ),
        "@CompletionDate", IF ( RELATED ( 'Work Order'[Completed Date] ) <= DATE ( 1900, 12, 31 ), BLANK (), RELATED ( 'Work Order'[Completed Date] ) )
    )
RETURN
    SELECTCOLUMNS (
        PartsLines,
        "Branch Plant", LOOKUPVALUE ( Branch[Branch Plant], Branch[BranchSKey], [@ParentBranchSKey] ),
        "Global Bulk Item", LOOKUPVALUE ( 'Item Branch'[Item Global Bulk], 'Item Branch'[ItemBranchSKey], [@ParentItemBranchSKey] ),
        "Bulk Item", LOOKUPVALUE ( 'Item Branch'[Item Bulk], 'Item Branch'[ItemBranchSKey], [@ParentItemBranchSKey] ),
        "2nd Item Number", RELATED ( 'Work Order'[Parent Item Num 2nd] ),
        "WO Number", RELATED ( 'Work Order'[Work Order Num] ),
        "Start Date", RELATED ( 'Work Order'[Start Date] ),
        "Completion Date", [@CompletionDate],
        "Year", YEAR ( [@CompletionDate] ),
        "Month", MONTH ( [@CompletionDate] ),
        "WO Status", RELATED ( 'Work Order'[Work Order Status] ),
        "Component Branch Plant", TRIM ( 'Work Order Parts List'[BusinessUnit] ),
        "Component 2nd Item Number", 'Work Order Parts List'[Component Item Num 2nd],
        "Component UOM", 'Work Order Parts List'[UOM],
        "Issued Quantity (Line)", 'Work Order Parts List'[QuantityTransaction],
        "Quantity Ordered (Line)", 'Work Order Parts List'[QuantityOrdered],
        "Component Global Bulk Item", RELATED ( 'Item Branch'[Item Global Bulk] ),
        "Component Bulk Item", RELATED ( 'Item Branch'[Item Bulk] ),
        "Component Item 2nd Item Number", RELATED ( 'Item Branch'[Item Num 2nd] ),
        "Stock Type Code", RELATED ( 'Item Branch'[Stocking Type] )
    )""" % daxlist(B70)

DAX["Item Details"] = """EVALUATE
VAR Bulks = %s
VAR ItemBranches =
    FILTER (
        'Item Branch',
        TRIM ( 'Item Branch'[Item Bulk] ) IN Bulks
            && TRIM ( 'Item Branch'[Business Unit] ) <> ""
            && NOT CONTAINSSTRING ( 'Item Branch'[Business Unit], "LAB" )
    )
RETURN
    SELECTCOLUMNS (
        ItemBranches,
        "Branch Plant", TRIM ( 'Item Branch'[Business Unit] ),
        "Global Bulk Item", 'Item Branch'[Item Global Bulk],
        "Bulk Item", 'Item Branch'[Item Bulk],
        "2nd Item Number", 'Item Branch'[Item Num 2nd],
        "Stock Type Code", 'Item Branch'[Stocking Type],
        "Master Planning Family", 'Item Branch'[Master Planning Family],
        "Lead Time Level", 'Item Branch'[Lead time Level],
        "Lead Time Order to Ship", 'Item Branch'[Lead Time MFG_BP],
        "Planning Code", 'Item Branch'[Planning Code],
        "Planning Time Fence Days", 'Item Branch'[Planning Time Fence Days],
        "Safety Stock", IF ( ISBLANK ( 'Item Branch'[SafetyStock] ), 0, 'Item Branch'[SafetyStock] ),
        "Shelf Life Days", 'Item Branch'[Shelf Life Days],
        "Supplier Number", 'Item Branch'[Branch Supplier Num],
        "Supplier Name", 'Item Branch'[Branch Supplier Name],
        "Planner Number", 'Item Branch'[Planner Num],
        "Planner Name", 'Item Branch'[Planner Name],
        "Buyer Number", 'Item Branch'[Buyer Num],
        "Buyer Name", 'Item Branch'[Buyer Name]
    )""" % daxlist(B47)

SQL_BOM = """SET NOCOUNT ON;
SELECT
    LTRIM(RTRIM(b.Branch))                      AS [Branch Plant],
    LTRIM(RTRIM(pib.ItemNum2nd))                AS [Parent Second Item Number],
    LTRIM(RTRIM(ib.ItemNum2nd))                 AS [2nd Item Number],
    LTRIM(RTRIM(ib.ItemBulk))                   AS [Bulk Item],
    LTRIM(RTRIM(ib.ItemGlobalBulk))             AS [Global Bulk Item],
    b.QuantityStandardRequired / 100.0          AS [Quantity (Line)]
FROM BIQL.DimBillOfMaterial b
JOIN BIQL.DimItemBranch ib
    ON ib.ItemBranchSKey = b.ComponentItemBranchSKey
LEFT JOIN BIQL.DimItemBranch pib
    ON pib.ItemBranchSKey = b.ParentItemBranchSKey
WHERE b.TypeBillofMaterial = N'M'
  AND b.EffectiveThruDate >= CAST(GETDATE() AS date)
  AND LTRIM(RTRIM(ib.ItemBulk)) IN (%s)
  AND LTRIM(RTRIM(b.Branch)) NOT IN (N'LABO', N'LABS', N'LABA')""" % sqllist(B70)

SQL_TM = """SET NOCOUNT ON;
SELECT
    [Customer Code],
    [TM Name],
    [TM Role]
FROM (
    SELECT
        m.[Ship To CC]                          AS [Customer Code],
        LTRIM(RTRIM(t.[Mailing Name]))          AS [TM Name],
        LTRIM(RTRIM(m.Role))                    AS [TM Role],
        ROW_NUMBER() OVER (
            PARTITION BY m.[Ship To CC]
            ORDER BY CASE m.Role WHEN N'FCGTM' THEN 1 ELSE 2 END, m.CommissionLineNum
        )                                       AS rn
    FROM BIQL.TbTM_Max_Assignment m
    JOIN BIQL.TbTerritoryManager t
        ON t.TerritoryManagerSKey = m.TerritoryManagerSKey
    WHERE m.Role IN (N'FCGTM', N'CSGTM')
) x
WHERE rn = 1"""

def m_ssas(dax):
    return '''let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
%s
"
        ]
    ),
    Data = Table.TransformColumnNames(
        Raw,
        each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]")
            then Text.Middle(_, 1, Text.Length(_) - 2)
            else _
    )
in
    Data''' % dax.replace('"', '""')

def m_edw(sql):
    return '''let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
%s
",
        null,
        [EnableFolding = false]
    )
in
    Data''' % sql.replace('"', '""')

M_LAST = '''let
    UtcNowZ = DateTimeZone.FixedUtcNow(),
    UtcNow  = DateTime.From(DateTimeZone.RemoveZone(UtcNowZ)),
    Yr      = Date.Year(UtcNow),
    NthSunday = (yr as number, mth as number, n as number) as date =>
        let
            first      = #date(yr, mth, 1),
            offsetDays = Number.Mod(7 - Date.DayOfWeek(first, Day.Sunday), 7)
        in
            Date.AddDays(first, offsetDays + 7 * (n - 1)),
    DstStartUtc = #datetime(Yr, 3,  Date.Day(NthSunday(Yr, 3,  2)), 7, 0, 0),
    DstEndUtc   = #datetime(Yr, 11, Date.Day(NthSunday(Yr, 11, 1)), 6, 0, 0),
    OffsetHours = if UtcNow >= DstStartUtc and UtcNow < DstEndUtc then -4 else -5,
    EasternNow  = DateTime.From(DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNowZ, OffsetHours))),
    Output = #table(
        type table [ #"Last Refreshed" = datetime, #"Time Zone" = text ],
        { { EasternNow, if OffsetHours = -4 then "EDT" else "EST" } }
    )
in
    Output'''

M = {t: m_ssas(DAX[t]) for t in DAX}
M["BOM"] = m_edw(SQL_BOM)
M["TM Assignment"] = m_edw(SQL_TM)
M["Last Refreshed"] = M_LAST

# ----------------------------------------------------------------------------- model columns
DATEFMT = "MMM d, yyyy"
N0 = "#,##0"
def C(name, dtype, fmt=None, hidden=False, desc=None, expr=None):
    return dict(name=name, dtype=dtype, fmt=fmt, hidden=hidden, desc=desc, expr=expr)
def MEAS(name, col, desc=None, fmt=N0):
    return dict(name=name, col=col, desc=desc, fmt=fmt)

TABLES = {}
TABLES["Receipts"] = dict(
    desc="Purchase-order receipt lines for the 15 CM vendors, SSASPROD / BIQLTabular 'Purchase Order Receiver'.",
    cols=[
        C("Global Bulk Item", "string"),
        C("Bulk Item", "string", desc="'-' where the item branch carries no bulk item, which is how Cognos renders it."),
        C("2nd Item Number", "string"),
        C("Vendor Name", "string", desc="Supplier name; falls back to the address book name when the receipt's supplier key is unresolved."),
        C("Vendor ID", "int64", "0", desc="PO address number. Identifier - never aggregate."),
        C("Received Quantity (Line)", "double", N0, True, "Line-grain input to [Received Quantity]: the quantity in the item's primary UOM (LB or KG line, otherwise transaction)."),
        C("Received Quantity LBs (Line)", "double", N0, True, "Line-grain input to [Received Quantity LBs]."),
        C("Received Quantity KGs (Line)", "double", N0, True, "Line-grain input to [Received Quantity KGs]."),
        C("Receipt Transaction Type", "string", desc="JDE document type (OV receipt / OW return)."),
        C("Receipt Transaction Date", "dateTime", DATEFMT, desc="Received date."),
        C("Order Type", "string"),
        C("Document Number", "int64", "0", desc="Identifier - never aggregate."),
        C("Line Number", "double", desc="Identifier - never aggregate."),
        C("Document Type", "string"),
        C("Amount Received (Line)", "double", N0, True, "Line-grain input to [Amount Received], transaction currency."),
        C("Amount Received USD (Line)", "double", N0, True, "Line-grain input to [Amount Received USD], at the JDE transaction rate."),
        C("Amount Received EUR (Line)", "double", N0, True, "Line-grain input to [Amount Received EUR], at the JDE transaction rate."),
        C("Date", "dateTime", DATEFMT, desc="Received date."),
        C("Year", "int64", "0"),
        C("Month", "int64", "0"),
    ],
    measures=[
        MEAS("Received Quantity", "Received Quantity (Line)", "SUM of the primary-UOM received quantity."),
        MEAS("Received Quantity LBs", "Received Quantity LBs (Line)"),
        MEAS("Received Quantity KGs", "Received Quantity KGs (Line)"),
        MEAS("Amount Received", "Amount Received (Line)"),
        MEAS("Amount Received USD", "Amount Received USD (Line)"),
        MEAS("Amount Received EUR", "Amount Received EUR (Line)"),
    ])
TABLES["Shipments"] = dict(
    desc="Sales lines for the 70 CM bulk items since 2020, SSASPROD / BIQLTabular 'Sales'.",
    cols=[
        C("Order Company", "string", desc="Carries leading zeros ('00010'); stays text."),
        C("Branch Plant", "string"),
        C("Order Number", "int64", "0", desc="Identifier - never aggregate."),
        C("Line Number", "double", desc="Identifier - never aggregate."),
        C("Open Indicator", "string"),
        C("Global Bulk Item", "string"),
        C("Bulk Item", "string"),
        C("2nd Item Number", "string"),
        C("Description 1", "string"),
        C("Description 2", "string", desc="Blank where the sales line carries none (the legacy warehouse shows '-')."),
        C("Freight Handling Code", "string"),
        C("Next Status", "string"),
        C("Order Net Amount USD (Line)", "double", N0, True, "Line-grain input to [Order Net Amount USD]: net amount USD plus the back-ordered extended amount."),
        C("Order Net Amount EUR (Line)", "double", N0, True, "Line-grain input to [Order Net Amount EUR]: native EUR for EUR-currency companies, otherwise USD at the month-end EUR/USD rate A of the GL date."),
        C("Ordered Quantity LBs (Line)", "double", N0, True, "Line-grain input to [Ordered Quantity LBs]."),
        C("Ordered Quantity KGs (Line)", "double", N0, True, "Line-grain input to [Ordered Quantity KGs]."),
        C("Revenue Business Unit", "string"),
        C("TM Name", "string", desc="Territory manager on the sales line; blank where it carries none (the legacy warehouse shows 'Not Available')."),
        C("Customer Name", "string"),
        C("Country Name", "string"),
        C("Global Parent Name", "string"),
        C("Date", "dateTime", DATEFMT, desc="Promised ship date."),
        C("Year", "int64", "0"),
        C("Month", "int64", "0"),
        C("Chemist Name", "string"),
    ],
    measures=[
        MEAS("Order Net Amount USD", "Order Net Amount USD (Line)"),
        MEAS("Order Net Amount EUR", "Order Net Amount EUR (Line)"),
        MEAS("Ordered Quantity LBs", "Ordered Quantity LBs (Line)"),
        MEAS("Ordered Quantity KGs", "Ordered Quantity KGs (Line)"),
    ])
TABLES["Forecast"] = dict(
    desc="Forecast rows for the 70 CM bulk items from the first of the current month to the end of the month 450 days out, SSASPROD / BIQLTabular 'FactForecast'.",
    cols=[
        C("Company Code", "string", desc="Carries leading zeros ('00010'); stays text."),
        C("Branch Plant", "string"),
        C("Global Bulk Item", "string"),
        C("Bulk Item", "string"),
        C("2nd Item Number", "string"),
        C("Item Description 1", "string"),
        C("Item Description 2", "string", desc="Blank where the item carries none (the legacy warehouse shows '-')."),
        C("Requested Date", "dateTime", DATEFMT),
        C("TM Name", "string",
          desc="The customer's commission territory manager from EDW (field-level fallback: FactForecast carries a TM for FC-group customers only); blank where the customer has no FC or CS assignment (the legacy warehouse shows 'Not Available').",
          expr="LOOKUPVALUE ( 'TM Assignment'[TM Name], 'TM Assignment'[Customer Code], Forecast[Customer Code] )"),
        C("Current Forecast (Line)", "double", N0, True, "Line-grain input to [Current Forecast]."),
        C("Primary UOM", "string"),
        C("Current Forecast LB (Line)", "double", N0, True, "Line-grain input to [Current Forecast LB]."),
        C("Current Forecast KG (Line)", "double", N0, True, "Line-grain input to [Current Forecast KG]."),
        C("Date", "dateTime", DATEFMT, desc="Requested date."),
        C("Year", "int64", "0"),
        C("Month", "int64", "0"),
        C("Customer Code", "int64", "0", desc="Identifier - never aggregate."),
        C("Customer Name", "string"),
        C("Global Parent Name", "string"),
        C("Chemist Name", "string"),
    ],
    measures=[
        MEAS("Current Forecast", "Current Forecast (Line)"),
        MEAS("Current Forecast LB", "Current Forecast LB (Line)"),
        MEAS("Current Forecast KG", "Current Forecast KG (Line)"),
    ])
TABLES["Work Orders"] = dict(
    desc="Work-order parts-list lines whose component is a CM bulk item, with the WO header and parent item, SSASPROD / BIQLTabular 'Work Order Parts List'.",
    cols=[
        C("Branch Plant", "string", desc="Work order (parent) branch."),
        C("Global Bulk Item", "string", desc="Parent item."),
        C("Bulk Item", "string", desc="Parent item."),
        C("2nd Item Number", "string", desc="Parent item."),
        C("WO Number", "int64", "0", desc="Identifier - never aggregate."),
        C("Start Date", "dateTime", DATEFMT),
        C("Completion Date", "dateTime", DATEFMT, desc="Blank while the work order is open."),
        C("Year", "int64", "0", desc="Of the completion date; blank while open."),
        C("Month", "int64", "0", desc="Of the completion date; blank while open."),
        C("WO Status", "string"),
        C("Component Branch Plant", "string", desc="Parts-list branch. Displayed as 'Branch Plant'."),
        C("Component 2nd Item Number", "string", desc="Parts-list component item."),
        C("Component UOM", "string"),
        C("Issued Quantity (Line)", "double", N0, True, "Line-grain input to [Issued Quantity]: the parts-list transaction quantity."),
        C("Quantity Ordered (Line)", "double", N0, True, "Line-grain input to [Quantity Ordered]."),
        C("Component Global Bulk Item", "string", desc="Component item branch. Displayed as 'Global Bulk Item'."),
        C("Component Bulk Item", "string", desc="Component item branch. Displayed as 'Bulk Item'."),
        C("Component Item 2nd Item Number", "string", desc="Component item branch. Displayed as '2nd Item Number'."),
        C("Stock Type Code", "string", desc="Component item branch."),
    ],
    measures=[
        MEAS("Issued Quantity", "Issued Quantity (Line)"),
        MEAS("Quantity Ordered", "Quantity Ordered (Line)"),
    ])
TABLES["BOM"] = dict(
    desc="Current single-level manufacturing bills whose component is a CM bulk item, EDWPROD / EDW BIQL.DimBillOfMaterial. BIQLTabular's 'Bill Of Material Expanded' holds no rows in production.",
    cols=[
        C("Branch Plant", "string"),
        C("Parent Second Item Number", "string"),
        C("2nd Item Number", "string", desc="Component item."),
        C("Bulk Item", "string", desc="Component item."),
        C("Global Bulk Item", "string", desc="Component item."),
        C("Quantity (Line)", "double", N0, True, "Line-grain input to [Quantity]: standard quantity required, scaled from JDE's implied two decimals."),
    ],
    measures=[MEAS("Quantity", "Quantity (Line)")])
TABLES["Item Details"] = dict(
    desc="Item-branch attributes for the 47-item CM list outside the LAB branches, SSASPROD / BIQLTabular 'Item Branch'.",
    cols=[
        C("Branch Plant", "string"),
        C("Global Bulk Item", "string"),
        C("Bulk Item", "string"),
        C("2nd Item Number", "string"),
        C("Stock Type Code", "string"),
        C("Master Planning Family", "string"),
        C("Lead Time Level", "int64", "0"),
        C("Lead Time Order to Ship", "int64", "0", desc="Item branch manufacturing lead time."),
        C("Planning Code", "string"),
        C("Planning Time Fence Days", "int64", "0"),
        C("Safety Stock", "double", N0, desc="0 where the item branch carries none, which is how Cognos renders it."),
        C("Shelf Life Days", "int64", "0"),
        C("Supplier Number", "int64", "0", desc="Identifier - never aggregate."),
        C("Supplier Name", "string", desc="Blank where the item branch has no supplier (the legacy warehouse shows 'Not Available')."),
        C("Planner Number", "int64", "0", desc="Identifier - never aggregate."),
        C("Planner Name", "string", desc="Blank where the item branch has no planner (the legacy warehouse shows 'Not Available')."),
        C("Buyer Number", "int64", "0", desc="Identifier - never aggregate."),
        C("Buyer Name", "string", desc="Blank where the item branch has no buyer (the legacy warehouse shows 'Not Available')."),
    ],
    measures=[])

TABLES["TM Assignment"] = dict(
    desc="One territory manager per customer from the EDW commission assignment (BIQL.TbTM_Max_Assignment): the FC-group TM, else the CS-group TM. Looked up by Forecast[TM Name]; not shown.",
    hidden=True,
    cols=[
        C("Customer Code", "int64", "0", desc="Ship-to address number; the lookup key."),
        C("TM Name", "string"),
        C("TM Role", "string", desc="FCGTM or CSGTM - which assignment the name comes from."),
    ],
    measures=[])
ORDER = ["Receipts", "Shipments", "Forecast", "TM Assignment", "Work Orders", "BOM", "Item Details", "Last Refreshed"]

# ----------------------------------------------------------------------------- TMDL
def q(name):
    return name if re.fullmatch(r"[A-Za-z0-9_]+", name) else "'%s'" % name

def indent_block(text, prefix):
    return "\n".join(prefix + l if l else "" for l in text.splitlines())

def table_tmdl(tn):
    t = TABLES[tn]
    out = []
    if t["desc"]:
        out.append("/// " + t["desc"])
    out += ["table %s" % q(tn), "	lineageTag: %s" % tag("table", tn)]
    if t.get("hidden"):
        out.append("\tisHidden")
    out.append("")
    for m in t["measures"]:
        if m["desc"]:
            out.append("\t/// " + m["desc"])
        out.append("\tmeasure %s = SUM ( %s[%s] )" % (q(m["name"]), q(tn), m["col"]))
        out.append("\t\tformatString: %s" % m["fmt"])
        out.append("\t\tlineageTag: %s" % tag("measure", tn, m["name"]))
        out.append("")
    for c in t["cols"]:
        if c["desc"]:
            out.append("\t/// " + c["desc"])
        if c["expr"]:
            out.append("\tcolumn %s = %s" % (q(c["name"]), c["expr"]))
        else:
            out.append("\tcolumn %s" % q(c["name"]))
        out.append("\t\tdataType: %s" % c["dtype"])
        if c["fmt"]:
            out.append("\t\tformatString: %s" % c["fmt"])
        if c["hidden"]:
            out.append("\t\tisHidden")
        out.append("\t\tlineageTag: %s" % tag("column", tn, c["name"]))
        out.append("\t\tsummarizeBy: none")
        if not c["expr"]:
            out.append("\t\tsourceColumn: %s" % c["name"])
        out.append("")
        out.append("\t\tannotation SummarizationSetBy = User")
        if c["dtype"] == "double":
            out.append("")
            out.append('\t\tannotation PBI_FormatHint = {"isDecimal":true}')
        out.append("")
    out.append("\tpartition %s = m" % q(tn))
    out.append("\t\tmode: import")
    out.append("\t\tsource =")
    out.append(indent_block(M[tn], "\t\t\t\t"))
    out.append("")
    out.append("\tannotation PBI_ResultType = Table")
    out.append("")
    return "\n".join(out)

LAST_TMDL = """table 'Last Refreshed'
\tlineageTag: %s

\tmeasure 'Last Refreshed Label' = "Last refreshed: " & FORMAT(MAX('Last Refreshed'[Last Refreshed]), "MMM d, yyyy h:mm:ss AM/PM") & " " & SELECTEDVALUE('Last Refreshed'[Time Zone], "ET")
\t\tlineageTag: %s

\tcolumn 'Last Refreshed'
\t\tdataType: dateTime
\t\tformatString: MMM d, yyyy h:mm:ss AM/PM
\t\tlineageTag: %s
\t\tsummarizeBy: none
\t\tsourceColumn: Last Refreshed

\tcolumn 'Time Zone'
\t\tdataType: string
\t\tlineageTag: %s
\t\tsummarizeBy: none
\t\tsourceColumn: Time Zone

\tpartition 'Last Refreshed' = m
\t\tmode: import
\t\tsource =
%s

\tannotation PBI_ResultType = Table
""" % (tag("table", "Last Refreshed"), tag("measure", "Last Refreshed", "Label"), tag("column", "Last Refreshed", "Last Refreshed"), tag("column", "Last Refreshed", "Time Zone"), indent_block(M_LAST, "\t\t\t\t"))

MODEL_TMDL = """model Model
\tculture: en-US
\tdefaultPowerBIDataSourceVersion: powerBI_V3
\tsourceQueryCulture: en-US
\tdataAccessOptions
\t\tlegacyRedirects
\t\treturnErrorValuesAsNull

annotation PBI_QueryOrder = %s

annotation __PBI_TimeIntelligenceEnabled = 0

annotation PBI_ProTooling = ["DevMode"]

%s

ref cultureInfo en-US
""" % (json.dumps(ORDER), "\n".join("ref table %s" % q(t) for t in ORDER))

# ----------------------------------------------------------------------------- write semantic model
if os.path.exists(OUT):
    shutil.rmtree(OUT, ignore_errors=True)
os.makedirs(os.path.join(SM, "definition", "tables"), exist_ok=True)
os.makedirs(os.path.join(SM, "definition", "cultures"), exist_ok=True)
def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
def wj(path, obj):
    w(path, json.dumps(obj, indent=2, ensure_ascii=False) + "\n")

w(os.path.join(SM, "definition", "model.tmdl"), MODEL_TMDL)
w(os.path.join(SM, "definition", "database.tmdl"), "database\n\tcompatibilityLevel: 1600\n")
w(os.path.join(SM, "definition", "cultures", "en-US.tmdl"), "cultureInfo en-US\n")
for tn in TABLES:
    w(os.path.join(SM, "definition", "tables", tn + ".tmdl"), table_tmdl(tn))
w(os.path.join(SM, "definition", "tables", "Last Refreshed.tmdl"), LAST_TMDL)
wj(os.path.join(SM, "definition.pbism"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json", "version": "4.2", "settings": {}})
wj(os.path.join(SM, ".platform"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json", "metadata": {"type": "SemanticModel", "displayName": NAME}, "config": {"version": "2.0", "logicalId": tag("platform", "sm")}})

# ----------------------------------------------------------------------------- shipped .m files (comment-free) in the report root
for tn in ORDER:
    w(os.path.join(ROOT, tn + ".m"), M[tn] + "\n")

# ----------------------------------------------------------------------------- report
PAGES = [
    # (displayName, table, [(column/measure name, kind, displayName override or None)], sort columns)
    ("Receipts", "Receipts", [
        ("Global Bulk Item", "C"), ("Bulk Item", "C"), ("2nd Item Number", "C"), ("Vendor Name", "C"), ("Vendor ID", "C"),
        ("Received Quantity", "M"), ("Received Quantity LBs", "M"), ("Received Quantity KGs", "M"),
        ("Receipt Transaction Type", "C"), ("Receipt Transaction Date", "C"), ("Order Type", "C"), ("Document Number", "C"),
        ("Line Number", "C"), ("Document Type", "C"), ("Amount Received", "M"), ("Amount Received USD", "M"), ("Amount Received EUR", "M"),
        ("Date", "C"), ("Year", "C"), ("Month", "C")],
     ["Global Bulk Item", "Bulk Item", "2nd Item Number"]),
    ("Shipments", "Shipments", [
        ("Order Company", "C"), ("Branch Plant", "C"), ("Order Number", "C"), ("Line Number", "C"), ("Open Indicator", "C"),
        ("Global Bulk Item", "C"), ("Bulk Item", "C"), ("2nd Item Number", "C"), ("Description 1", "C"), ("Description 2", "C"),
        ("Freight Handling Code", "C"), ("Next Status", "C"), ("Order Net Amount USD", "M"), ("Order Net Amount EUR", "M"),
        ("Ordered Quantity LBs", "M"), ("Ordered Quantity KGs", "M"),
        ("Revenue Business Unit", "C"), ("TM Name", "C"), ("Customer Name", "C"), ("Country Name", "C"), ("Global Parent Name", "C"),
        ("Date", "C"), ("Year", "C"), ("Month", "C"), ("Chemist Name", "C")],
     ["Global Bulk Item", "Bulk Item", "2nd Item Number"]),
    ("Forecast", "Forecast", [
        ("Company Code", "C"), ("Branch Plant", "C"), ("Global Bulk Item", "C"), ("Bulk Item", "C"), ("2nd Item Number", "C"),
        ("Item Description 1", "C"), ("Item Description 2", "C"), ("Requested Date", "C"), ("TM Name", "C"),
        ("Current Forecast", "M"), ("Primary UOM", "C"), ("Current Forecast LB", "M"), ("Current Forecast KG", "M"),
        ("Date", "C"), ("Year", "C"), ("Month", "C"), ("Customer Code", "C"), ("Customer Name", "C"), ("Global Parent Name", "C"), ("Chemist Name", "C")],
     ["Global Bulk Item", "Bulk Item", "2nd Item Number"]),
    ("Work Orders", "Work Orders", [
        ("Branch Plant", "C"), ("Global Bulk Item", "C"), ("Bulk Item", "C"), ("2nd Item Number", "C"), ("WO Number", "C"),
        ("Start Date", "C"), ("Completion Date", "C"), ("Year", "C"), ("Month", "C"), ("WO Status", "C"),
        ("Component Branch Plant", "C", "Branch Plant"), ("Component 2nd Item Number", "C"), ("Component UOM", "C"),
        ("Issued Quantity", "M"), ("Quantity Ordered", "M"),
        ("Component Global Bulk Item", "C", "Global Bulk Item"), ("Component Bulk Item", "C", "Bulk Item"),
        ("Component Item 2nd Item Number", "C", "2nd Item Number"), ("Stock Type Code", "C")],
     ["Global Bulk Item", "Bulk Item", "2nd Item Number"]),
    ("BOM", "BOM", [
        ("Branch Plant", "C"), ("Parent Second Item Number", "C"), ("2nd Item Number", "C"), ("Bulk Item", "C"), ("Global Bulk Item", "C"), ("Quantity", "M")],
     ["Branch Plant", "Parent Second Item Number", "2nd Item Number"]),
    ("Item Details", "Item Details", [
        ("Branch Plant", "C"), ("Global Bulk Item", "C"), ("Bulk Item", "C"), ("2nd Item Number", "C"), ("Stock Type Code", "C"),
        ("Master Planning Family", "C"), ("Lead Time Level", "C"), ("Lead Time Order to Ship", "C"), ("Planning Code", "C"),
        ("Planning Time Fence Days", "C"), ("Safety Stock", "C"), ("Shelf Life Days", "C"), ("Supplier Number", "C"), ("Supplier Name", "C"),
        ("Planner Number", "C"), ("Planner Name", "C"), ("Buyer Number", "C"), ("Buyer Name", "C")],
     ["Global Bulk Item", "Bulk Item", "2nd Item Number", "Branch Plant"]),
]

# sanity: every bound field exists
for _, tn, fields, sorts in PAGES:
    names = {c["name"] for c in TABLES[tn]["cols"]} | {m["name"] for m in TABLES[tn]["measures"]}
    for f in fields:
        assert f[0] in names, (tn, f)
    for s in sorts:
        assert s in names, (tn, s)

def lit(v): return {"expr": {"Literal": {"Value": v}}}
def color(hexv): return {"solid": {"color": {"expr": {"Literal": {"Value": "'%s'" % hexv}}}}}

def field_ref(tn, name, kind):
    key = "Measure" if kind == "M" else "Column"
    return {key: {"Expression": {"SourceRef": {"Entity": tn}}, "Property": name}}

def table_visual(pid, tn, fields, sorts):
    projections = []
    for f in fields:
        name, kind = f[0], f[1]
        p = {"field": field_ref(tn, name, kind), "queryRef": "%s.%s" % (tn, name), "nativeQueryRef": name}
        if len(f) > 2:
            p["displayName"] = f[2]
        projections.append(p)
    colfmt = []
    for f in fields:
        c = next((c for c in TABLES[tn]["cols"] if c["name"] == f[0]), None)
        if c and c["dtype"] in ("int64", "double", "dateTime"):
            colfmt.append({"properties": {"alignment": lit("'Left'")}, "selector": {"metadata": "%s.%s" % (tn, f[0])}})
    return {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.1.0/schema.json",
        "name": vid(pid, "table"),
        "position": {"x": 8, "y": 70, "z": 0, "height": 642, "width": 1264},
        "visual": {
            "visualType": "tableEx",
            "query": {
                "queryState": {"Values": {"projections": projections}},
                "sortDefinition": {"sort": [{"field": field_ref(tn, s, "C"), "direction": "Ascending"} for s in sorts]},
            },
            "objects": {
                "total": [{"properties": {"totals": lit("false")}}],
                "columnHeaders": [{"properties": {"fontColor": color("#FF0000"), "bold": lit("true")}}],
                "grid": [{"properties": {
                    "outlineWeight": lit("1L"), "gridVerticalColor": color("#000000"), "gridHorizontalColor": color("#000000"),
                    "gridHorizontalWeight": lit("1L"), "outlineColor": color("#000000"), "gridHorizontal": lit("true"),
                    "outlineStyle": lit("15D"), "gridVerticalWeight": lit("1L"), "gridVertical": lit("true")}}],
                "columnFormatting": colfmt,
            },
            "visualContainerObjects": {
                "title": [{"properties": {"show": lit("false")}}],
                "stylePreset": [{"properties": {"name": lit("'None'")}}],
                "border": [{"properties": {"show": lit("false")}}],
            },
            "drillFilterOtherVisuals": True,
        },
    }

def textbox(pid, key, pos, runs, align=None, extra=None):
    para = {"textRuns": runs}
    if align:
        para["horizontalTextAlignment"] = align
    v = {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.1.0/schema.json",
        "name": vid(pid, key),
        "position": pos,
        "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": [para]}}]}, "drillFilterOtherVisuals": True},
    }
    if extra:
        v["visual"]["visualContainerObjects"] = extra
    return v

def chrome(pid):
    vs = []
    vs.append(textbox(pid, "title", {"x": 0, "y": 0, "z": 1000, "height": 46, "width": 466, "tabOrder": 1000},
                      [{"value": NAME, "textStyle": {"fontWeight": "bold", "fontFamily": "Arial", "fontSize": "18pt", "color": "#0000ff"}}]))
    vs.append(textbox(pid, "helpdesk", {"x": 617, "y": 15, "z": 2000, "height": 39, "width": 234, "tabOrder": 2000},
                      [{"value": "Submit Helpdesk Ticket", "textStyle": {"fontFamily": "Segoe UI", "fontSize": "12pt"}, "url": "mailto:Helpdesk@michelman.com?subject=Data Warehouse Ticket Request"}],
                      "center",
                      {"title": [{"properties": {"show": lit("false")}}],
                       "border": [{"properties": {"show": lit("true"), "color": {"solid": {"color": {"expr": {"ThemeDataColor": {"ColorId": 0, "Percent": -0.5}}}}}, "radius": lit("5D")}}]}))
    vs.append(textbox(pid, "author", {"x": 863, "y": 12, "z": 3000, "height": 39, "width": 205, "tabOrder": 3000},
                      [{"value": "Report Author: Nick Bubash", "textStyle": {"fontFamily": "Segoe UI", "fontSize": "10pt"}}], "center"))
    vs.append({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.1.0/schema.json",
        "name": vid(pid, "logo"),
        "position": {"x": 1084, "y": 0, "z": 4000, "height": 65, "width": 196, "tabOrder": 4000},
        "visual": {"visualType": "image", "objects": {"general": [{"properties": {"imageUrl": {"expr": {"ResourcePackageItem": {"PackageName": "RegisteredResources", "PackageType": 1, "ItemName": LOGO}}}}}]}, "drillFilterOtherVisuals": True},
    })
    vs.append({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.1.0/schema.json",
        "name": vid(pid, "refreshed"),
        "position": {"x": 8, "y": 40, "z": 5000, "height": 28, "width": 340, "tabOrder": 5000},
        "visual": {
            "visualType": "card",
            "query": {"queryState": {"Values": {"projections": [{"field": field_ref("Last Refreshed", "Last Refreshed Label", "M"), "queryRef": "Last Refreshed.Last Refreshed Label", "nativeQueryRef": "Last Refreshed Label"}]}}},
            "objects": {"labels": [{"properties": {"fontSize": lit("9D")}}], "categoryLabels": [{"properties": {"show": lit("false")}}]},
            "visualContainerObjects": {"title": [{"properties": {"show": lit("false")}}]},
            "drillFilterOtherVisuals": True,
        },
    })
    return vs

os.makedirs(os.path.join(RP, "definition", "pages"), exist_ok=True)
page_ids = []
for disp, tn, fields, sorts in PAGES:
    pid = vid("page", disp)
    page_ids.append(pid)
    pdir = os.path.join(RP, "definition", "pages", pid)
    wj(os.path.join(pdir, "page.json"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.0.0/schema.json", "name": pid, "displayName": disp, "displayOption": "FitToPage", "height": 720, "width": 1280})
    for v in chrome(pid) + [table_visual(pid, tn, fields, sorts)]:
        wj(os.path.join(pdir, "visuals", v["name"], "visual.json"), v)
wj(os.path.join(RP, "definition", "pages", "pages.json"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json", "pageOrder": page_ids, "activePageName": page_ids[0]})
wj(os.path.join(RP, "definition", "version.json"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json", "version": "2.0.0"})
wj(os.path.join(RP, "definition", "report.json"), {
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/2.1.0/schema.json",
    "themeCollection": {"baseTheme": {"name": "CY24SU10", "reportVersionAtImport": "5.59", "type": "SharedResources"}},
    "objects": {"section": [{"properties": {"verticalAlignment": lit("'Top'")}}]},
    "resourcePackages": [
        {"name": "SharedResources", "type": "SharedResources", "items": [{"name": "CY24SU10", "path": "BaseThemes/CY24SU10.json", "type": "BaseTheme"}]},
        {"name": "RegisteredResources", "type": "RegisteredResources", "items": [{"name": LOGO, "path": LOGO, "type": "Image"}]},
    ],
    "settings": {"useStylableVisualContainerHeader": True, "defaultDrillFilterOtherVisuals": True, "allowChangeFilterTypes": True, "useEnhancedTooltips": True, "useDefaultAggregateDisplayName": True},
})
wj(os.path.join(RP, "definition.pbir"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json", "version": "4.0", "datasetReference": {"byPath": {"path": "../" + NAME + ".SemanticModel"}}})
wj(os.path.join(RP, ".platform"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json", "metadata": {"type": "Report", "displayName": NAME}, "config": {"version": "2.0", "logicalId": tag("platform", "rp")}})
os.makedirs(os.path.join(RP, "StaticResources", "SharedResources", "BaseThemes"), exist_ok=True)
shutil.copy(os.path.join(R19, "StaticResources", "SharedResources", "BaseThemes", "CY24SU10.json"), os.path.join(RP, "StaticResources", "SharedResources", "BaseThemes", "CY24SU10.json"))
os.makedirs(os.path.join(RP, "StaticResources", "RegisteredResources"), exist_ok=True)
shutil.copy(os.path.join(DAVE, "StaticResources", "RegisteredResources", LOGO), os.path.join(RP, "StaticResources", "RegisteredResources", LOGO))
wj(os.path.join(OUT, NAME + ".pbip"), {"$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json", "version": "1.0", "artifacts": [{"report": {"path": NAME + ".Report"}}], "settings": {"enableAutoRecovery": True}})
w(os.path.join(OUT, ".gitignore"), "**/.pbi/localSettings.json\n**/.pbi/cache.abf\n")

# also drop the native queries as standalone files for probing / the RDL later
for tn in DAX:
    w(os.path.join(ROOT, "PROBE", "build_" + tn.replace(" ", "_").lower() + ".dax"), DAX[tn] + "\n")
w(os.path.join(ROOT, "PROBE", "build_bom.sql"), SQL_BOM + "\n")
w(os.path.join(ROOT, "PROBE", "build_tm_assignment.sql"), SQL_TM + "\n")
print("written", OUT)
