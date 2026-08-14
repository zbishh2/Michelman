import json, os, re, uuid

ROOT = r"C:\Users\Zack\Documents\Code\Michelman"
DEST = os.path.join(ROOT, "PBIP Projects", "SSAS Pull")
NAME = "SSAS Pull"

# ---- validate every column against the fresh dump ----
with open(os.path.join(ROOT, r"edw_schema\ssasprod.bim"), encoding="utf-8") as f:
    bim = json.load(f)["model"]
bim_tables = {t["name"]: {c["name"]: c.get("dataType") for c in t.get("columns", [])}
              for t in bim["tables"]}

TYPE_MAP = {"decimal": "double", "double": "double", "int64": "int64",
            "string": "string", "dateTime": "dateTime", "boolean": "boolean"}

# (local table name, ssas table name, [columns], dax filter or None)
SPECS = [
    ("FactForecast", "FactForecast", [
        "ItemSKey", "ItemBranchSKey", "BusinessUnitSKey", "OrderDocumentTypeSKey",
        "AddressSKey", "AddressNum", "BusinessUnit", "BypassForcingYN", "ForecastType",
        "ForecastTypeDesc", "ItemNumShort", "ItemNum2nd", "ItemNum3rd", "OrderType",
        "RevisedFlag", "UserID", "CalendarYear", "RequestedDate", "RequestedDateID",
        "RequestedDateSKey", "TimeofDay", "UpdatedDate", "UpdatedDateSKey",
        "AmountExtendedPrice", "AmountForecast", "QuantityForecast", "QuantityOrdered",
        "Bulk Item", "Global Bulk", "DWLoadDate", "Company", "DWSource",
        "ConversionFactorKG", "ConversionFactorLB", "TerritoryManagerSKey", "UOM Primary",
        "QuantityOrderedLB", "QuantityOrderedKG", "QuantityForecastKG", "QuantityForecastLB",
    ], None),
    ("Sales", "Sales", [
        "ItemBranchSKey", "BranchSKey", "ShipToCustomerSKey", "SoldToCustomerSKey",
        "ParentCustomerSKey", "BillToCustomerSKey", "TerritoryManagerSKey",
        "BusinessUnitHeaderSKey", "AddressNum", "AddressNumBillTo",
        "Order Company", "Order Num", "Order Suffix", "Order Type", "Order Type Desc",
        "Line Num", "Line Type", "Document Num", "Document Type", "Original Order Num",
        "Shipment Num", "Record Type", "Sales Table Source", "Item Num 2nd",
        "Description 1", "Description 2",
        "Status Code Last", "Status Code Last Desc", "Status Code Next", "Status Code Next Desc",
        "Open Order Flag", "Actuals vs Open", "Cancelled_Flag", "Hold Orders Code",
        "Filter - Active Order Types", "Order Exclude", "Reason Code", "Reason Code Desc",
        "Revision Reason Code", "Revision Reason",
        "Order Date", "GL Date", "Invoice Date", "Actual Ship Date",
        "Promised Shipment Date", "Promised Delivery Date", "Original Promised Delivery Date",
        "Requested Date", "Scheduled Pick Date", "Updated Date",
        "BusinessUnit",
        "QuantityOrdered", "QuantityShipped", "QuantityBackordered",
        "QuantityCanceledScrapped", "QuantityOrderedPrimaryUOM",
        "ConversionFactorKG", "ConversionFactorLB", "ConversionFactorPrimaryKG",
        "ConversionFactorPrimaryLB", "ConversionFactorWeightKG", "ConversionFactorWeightLB",
        "ConversionFactorUSD", "ConversionFactorEUR", "ConversionFactorLC",
        "UOM", "UOM Primary", "UOM Weight", "UnitWeight",
        "AmountExtendedPrice", "AmountExtendedCost", "AmountExtendedPriceNet",
        "AmountOrderNet", "AmountExtendedPriceUSD", "AmountExtendedCostUSD",
        "AmountOrderNetUSD", "Open Amount", "Amount Unit Price",
        "BackOrderedExtendedAmount", "BackOrderedExtendedCost",
        "Exchange Rate USD", "Exchange Rate EUR", "LocalCurrency",
        "Currency Code Base", "Currency Code From", "Currency Mode",
        "Make Site", "Ship Site", "SalesforceOpportunityID",
        "Carrier Num", "Carrier Name", "Freight Handling Code", "Mode Of Transport",
        "TM Sales Rep Type",
    ],
     "'Sales'[Order Date] >= TODAY () - 1095\n"
     "            || 'Sales'[Promised Shipment Date] >= TODAY () - 1095\n"
     "            || 'Sales'[GL Date] >= TODAY () - 1095"),
    ("Item Branch", "Item Branch", [
        "ItemBranchSKey", "ItemSKey", "Business Unit", "Item Num Short",
        "Item Num 2nd", "Item Num 2nd Desc", "Item Num 2nd and Desc", "Item Num 3rd",
        "Item Bulk", "Item Global Bulk", "Item Num Bulk", "Item Num Global Bulk",
        "Global Bulk Filter", "Master Planning Family", "Master Planning Family Desc",
        "Stocking Type", "Stocking Type Desc", "Line Type",
        "UOM Primary", "UOM Pricing", "UOM Shipping",
        "Item Price Group", "Item Price Group Desc",
        "Planner Num", "Planner Name", "Buyer Name",
        "Branch Supplier Num", "Branch Supplier Name",
        "SafetyStock", "Safety Stock SAFE", "ReorderPoint", "ReorderQuantity",
        "ReorderQuantityMinimum", "ReorderQuantityMaximum", "Qty Order Multiple",
        "Lead Time MFG_BP", "Shelf Life Days", "Active Flag Status",
        "Sales Reporting Code 01", "Sales Reporting Code 01 Desc",
    ], None),
    ("Customer", "Customer", [
        "CustomerSKey", "AddressSKey", "Customer Sold To Num", "Customer Sold To Name",
        "Customer Sold To and Name", "Global Parent Num", "Global Parent Name",
        "Global Parent and Name", "Related Sold to", "Address Num Parent", "Address Num 4th",
        "Customer Segmentation", "Customer Segmentation Desc",
        "Sales Business Unit", "Sales Business Unit Desc",
        "Country", "Country Desc", "State", "State Desc", "City",
        "Type of Customer Desc", "Industry Group Desc", "Region",
        "Customer Status Desc", "Business Group Description",
    ], None),
    ("Customer Ship To", "Customer Ship To", [
        "ShipToCustomerSKey", "AddressSKey", "Customer Ship To", "Customer Ship To Name",
        "Customer Ship To and Name", "Sales Business Unit", "Sales Business Unit Desc",
        "Customer Segmentation", "Customer Segmentation Desc", "Customer Segmentation Group",
        "Customer Segmentation Strategic", "Reporting Region", "Reporting Region ANS",
        "Country", "Country Desc", "State", "State Desc", "City",
        "Type of Customer Desc", "Industry Group Desc",
    ], None),
    ("Territory Manager", "Territory Manager", [
        "TerritoryManagerSKey", "Territory Manager Num", "Territory Manager",
        "Territory Manager and Name", "TM Sales Rep Type", "CustomerCommissionTMSKey",
        "Mailing Name", "TM Sales Rep Type TM1",
    ], None),
    ("Address", "Address", [
        "AddressSKey", "Address Num", "Address Name", "Address and Name",
        "Search Type", "Search Type Desc", "Sales Business Unit", "Sales Business Unit Desc",
        "Customer Segmentation", "Customer Segmentation Desc",
        "Country Desc", "State Desc", "CustomerYN", "SupplierYN",
    ], None),
    ("Business Unit", "Business Unit", [
        "BusinessUnitSKey", "CompanySKey", "Business Unit", "Business Unit Desc",
        "Business Unit and Desc", "Business Unit Type", "Business Unit Type Desc",
        "Business Unit Parent", "Business Unit Parent Desc",
        "Division", "Division Desc", "Region", "Region Desc",
        "Grouping", "Grouping Desc", "Territory", "Territory Desc",
    ], None),
    ("Branch", "Branch", [
        "BranchSKey", "CompanySKey", "Branch Plant", "Branch Plant Desc",
        "Branch Plant and Desc", "Branch Plant Type", "Branch Plant Type Desc",
        "Branch Parent", "Branch Type",
    ], None),
    ("Company", "Company", [
        "CompanySKey", "Company", "Company Desc", "Company and Desc", "Currency",
    ], None),
    ("Date", "Date", [
        "CalendarDate", "DateSKey",
    ], None),
    ("Item", "Item", [
        "ItemSKey", "ItemNumShort", "ItemNum2nd", "ItemNum3rd", "ItemDesc01", "ItemDesc02",
        "StockingType", "StockingTypeDesc", "MasterPlanningFamily", "MasterPlanningFamilyDesc",
        "ProductGroup", "ProductGroupDesc", "ItemPriceGroup", "ItemPriceGroupDesc",
        "CommodityClassCodes", "CommodityClassCodesDesc",
        "CommoditySubClassCodes", "CommoditySubClassCodesDesc",
        "SalesCatalogSections", "SalesCatalogSectionsDesc",
        "SalesCatalogSubsections", "SalesCatalogSubsectionsDesc",
        "SalesReportingCode03", "SalesReportingCode03Desc",
        "SalesReportingCode04", "SalesReportingCode04Desc",
        "ItemCategoryCode06", "ItemCategoryCode06Desc",
        "ItemCategoryCode08", "ItemCategoryCode08Desc",
        "ItemCategoryCode09", "ItemCategoryCode09Desc",
        "ItemCategoryCode10", "ItemCategoryCode10Desc",
        "CommercializationYear", "CommercializationYearDesc",
        "LineType", "ItemBulk", "ItemGlobalBulk",
        "UOMPrimary", "UOMPricing", "UOMPurchasing", "UOMSecondary", "UOMShipping",
        "UOMWeight", "UOMVolume",
        "HazardClass", "HarmonizedShippingCode", "UNNANum",
        "PlanningCode", "OrderPolicyCode", "LeadtimeLevel",
        "DaysShelfLifeDays", "BestBeforeDefaultDays", "SellByDefaultDays",
        "LevelInventoryCost", "UniqueFormulaIdentifier", "DWIsCurrent",
    ], None),
    ("Purchase Order Detail", "Purchase Order Detail", [
        "SupplierSKey", "ItemBranchSKey", "BranchSKey", "AddressSKey",
        "Address Num PO", "Address Num Ship To", "PurchaseOrderSKey",
        "Order Company", "Order Num", "Order Suffix", "Order Type", "Order Type Desc",
        "Line Num", "Line Type", "Original Order Num", "Original Order Type",
        "Related Order Num", "Related Order Type",
        "Status Code Last", "Status Code Next", "Hold Orders Code",
        "Buyer Num", "Buyer Name", "Vendor Name", "Transaction Originator",
        "Item Num_F4311", "Business Unit", "Item Num Short", "Location",
        "Description 1", "Description 2",
        "Order Date", "GL Date", "Requested Date", "Promised Shipment Date",
        "Original Promised Date", "Original Promised Del Date", "Cancel Date",
        "Received Date", "FirstReceivedDate", "LastReceivedDate", "Actual Ship Date",
        "QuantityOrdered", "QuantityOpen", "QuantityReceived", "QuantityRelieved",
        "QuantityOnHold", "QuantityCumulativeReceived", "QuantityOrderedPrimaryUOM",
        "AmountExtendedCost", "AmountExtendedPrice", "AmountOpen", "AmountReceived",
        "AmountOnHold", "AmountRelieved", "PO Unit Cost", "UnitCostPurchasing",
        "ConversionFactorKG", "ConversionFactorLB", "USDRate", "EURRate",
        "Currency Code Base", "Currency Code From",
        "UOM Transaction", "UOM Primary", "UOM Purchasing",
        "Supplier OTIF", "OnTimeFlag", "InFullFlag", "OnTimeInFullFlag", "LateFlag",
        "Past Due Flag", "Days Off Target", "Delivery Status", "Delivery Score",
        "Estimated Lead Time", "ActualLeadTime", "Revision Count",
        "Count Number Reschedule", "Total Reschedule",
    ],
     "'Purchase Order Detail'[Order Date] >= TODAY () - 1095\n"
     "            || 'Purchase Order Detail'[GL Date] >= TODAY () - 1095\n"
     "            || 'Purchase Order Detail'[Received Date] >= TODAY () - 1095"),
    ("Purchase Order Receiver", "Purchase Order Receiver", [
        "SupplierSKey", "ItemBranchSKey", "BranchSKey", "Address Num PO", "PurchaseOrderSKey",
        "Order Company", "Order Num", "Order Suffix", "Order Type",
        "Line Num", "Line Type", "Match Record Type",
        "Document Num", "Document Type", "Document Company",
        "Status Code Last", "Status Code Next", "Supplier Invoice Num", "Location",
        "Description 1",
        "GL Date", "Order Date", "Received Date", "Received Date Line",
        "Transaction Date", "Requested Date", "Original Promised Delivery Date",
        "QuantityOrdered", "QuantityReceived", "QuantityOpen", "QuantityReturned",
        "QuantityRejected", "QuantityScrapped", "QuantityStocked", "QuantityClosed",
        "AmountExtendedCost", "AmountReceived", "AmountOpen", "AmountUnitCost",
        "AmountPaidtoDate",
        "ConversionFactorKG", "ConversionFactorLB", "USDRate", "EURRate",
        "Currency Code Base", "Currency Code From", "UOM Transaction", "UOM Primary",
        "OnTimeFlag", "InFullFlag", "OnTimeInFullFlag", "LateFlag",
        "Days Off Target", "Delivery Status",
    ],
     "'Purchase Order Receiver'[Received Date] >= TODAY () - 1095\n"
     "            || 'Purchase Order Receiver'[GL Date] >= TODAY () - 1095"),
    ("Calendar", "Calendar", [
        "CalendarPattern", "Calendar Date", "DateSKey", "Year Num", "Quarter",
        "Year Quarter", "Period Num", "Year Period", "Period Desc Short",
        "Calendar Month Num", "Calendar Month", "Calendar Month Short Desc", "Week",
        "Calendar Day Num", "Period Begin Date", "Period End Date",
        "Relative Year", "Relative Quarter", "Relative Period", "Relative Week",
        "Relative Day", "Holiday", "IsBusinessDay",
    ],
     "'Calendar'[Calendar Date] >= DATE ( 2019, 1, 1 )\n"
     "            && 'Calendar'[Calendar Date] <= DATE ( 2030, 12, 31 )"),
]

# hard validation: every column must exist in the dump, with a mappable type
errors = []
for local, ssas, cols, _ in SPECS:
    if ssas not in bim_tables:
        errors.append(f"table missing: {ssas}")
        continue
    for c in cols:
        if c not in bim_tables[ssas]:
            errors.append(f"{ssas}[{c}] not in ssasprod.bim")
        elif bim_tables[ssas][c] not in TYPE_MAP:
            errors.append(f"{ssas}[{c}] unmappable type {bim_tables[ssas][c]}")
if errors:
    print("VALIDATION FAILED:")
    for e in errors:
        print(" ", e)
    raise SystemExit(1)
print("all columns validated against ssasprod.bim")

# ---- TMDL helpers ----
def tmdl_name(n):
    return n if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", n) else f"'{n}'"

def dax_query(ssas, cols, flt):
    proj = ",\n".join(f'        ""{c}"", \'{ssas}\'[{c}]' for c in cols)
    if flt:
        flt_escaped = flt.replace('"', '""')
        body = (f"EVALUATE\nVAR PullRows =\n    FILTER (\n        '{ssas}',\n"
                f"        {flt_escaped}\n    )\nRETURN\n"
                f"    SELECTCOLUMNS (\n        PullRows,\n{proj}\n    )")
        body = body.replace(f"FILTER (\n        '{ssas}',", f"FILTER (\n        '{ssas}',")
    else:
        body = f"EVALUATE\nSELECTCOLUMNS (\n    '{ssas}',\n{proj}\n)"
    return body

def partition_block(local, ssas, cols, flt):
    dax = dax_query(ssas, cols, flt)
    dax_lines = "\n".join("\t\t\t\t" + ln if ln else "" for ln in dax.split("\n"))
    m = (
        '\t\t\t\tlet\n'
        '\t\t\t\t    Raw = AnalysisServices.Database(\n'
        '\t\t\t\t        "SSASPROD",\n'
        '\t\t\t\t        "BIQLTabular",\n'
        '\t\t\t\t        [\n'
        '\t\t\t\t            Query = "\n'
        f'{dax_lines}\n'
        '\t\t\t\t"\n'
        '\t\t\t\t        ]\n'
        '\t\t\t\t    ),\n'
        '\t\t\t\t    Data = Table.TransformColumnNames(\n'
        '\t\t\t\t        Raw,\n'
        '\t\t\t\t        each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]")\n'
        '\t\t\t\t            then Text.Middle(_, 1, Text.Length(_) - 2)\n'
        '\t\t\t\t            else _\n'
        '\t\t\t\t    )\n'
        '\t\t\t\tin\n'
        '\t\t\t\t    Data'
    )
    return (f"\tpartition {tmdl_name(local)} = m\n"
            f"\t\tmode: import\n"
            f"\t\tsource =\n{m}\n")

def table_tmdl(idx, local, ssas, cols, flt):
    prefix = f"a5{idx:02x}0000-0000-4000-8000"
    out = [f"table {tmdl_name(local)}", f"\tlineageTag: {prefix}-0000000000a1", ""]
    for i, c in enumerate(cols, start=1):
        dt = TYPE_MAP[bim_tables[ssas][c]]
        out.append(f"\tcolumn {tmdl_name(c)}")
        out.append(f"\t\tdataType: {dt}")
        out.append(f"\t\tlineageTag: {prefix}-{i:012x}")
        out.append("\t\tsummarizeBy: none")
        out.append(f"\t\tsourceColumn: {c}")
        out.append("")
        out.append("\t\tannotation SummarizationSetBy = Automatic")
        out.append("")
    out.append(partition_block(local, ssas, cols, flt))
    out.append("\tannotation PBI_ResultType = Table")
    out.append("")
    return "\n".join(out)

def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print("wrote", os.path.relpath(path, ROOT))

SM = os.path.join(DEST, f"{NAME}.SemanticModel")
RP = os.path.join(DEST, f"{NAME}.Report")

for i, (local, ssas, cols, flt) in enumerate(SPECS, start=1):
    write(os.path.join(SM, "definition", "tables", f"{local}.tmdl"),
          table_tmdl(i, local, ssas, cols, flt))

last_refreshed = """table 'Last Refreshed'
\tlineageTag: a5ff0000-0000-4000-8000-0000000000a1

\tcolumn 'Last Refreshed'
\t\tdataType: dateTime
\t\tformatString: MMM d, yyyy h:mm:ss AM/PM
\t\tlineageTag: a5ff0000-0000-4000-8000-0000000000b1
\t\tsummarizeBy: none
\t\tsourceColumn: Last Refreshed

\tpartition 'Last Refreshed' = m
\t\tmode: import
\t\tsource =
\t\t\t\tlet
\t\t\t\t    Output = #table(
\t\t\t\t        type table [ #"Last Refreshed" = datetime ],
\t\t\t\t        { { DateTime.LocalNow() } }
\t\t\t\t    )
\t\t\t\tin
\t\t\t\t    Output

\tannotation PBI_ResultType = Table
"""
write(os.path.join(SM, "definition", "tables", "Last Refreshed.tmdl"), last_refreshed)

order = json.dumps([s[0] for s in SPECS] + ["Last Refreshed"])
refs = "\n".join(f"ref table {tmdl_name(s[0])}" for s in SPECS) + "\nref table 'Last Refreshed'"
model = (
    "model Model\n"
    "\tculture: en-US\n"
    "\tdefaultPowerBIDataSourceVersion: powerBI_V3\n"
    "\tsourceQueryCulture: en-US\n"
    "\tdataAccessOptions\n"
    "\t\tlegacyRedirects\n"
    "\t\treturnErrorValuesAsNull\n"
    "\n"
    f"annotation PBI_QueryOrder = {order}\n"
    "\n"
    "annotation __PBI_TimeIntelligenceEnabled = 0\n"
    "\n"
    'annotation PBI_ProTooling = ["DevMode"]\n'
    "\n"
    f"{refs}\n"
)
write(os.path.join(SM, "definition", "model.tmdl"), model)
write(os.path.join(SM, "definition", "database.tmdl"), "database\n\tcompatibilityLevel: 1600\n")
write(os.path.join(SM, "definition.pbism"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",
    "version": "4.2", "settings": {}}, indent=2) + "\n")
write(os.path.join(SM, ".platform"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
    "metadata": {"type": "SemanticModel", "displayName": NAME},
    "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}, indent=2) + "\n")

write(os.path.join(RP, ".platform"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
    "metadata": {"type": "Report", "displayName": NAME},
    "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}, indent=2) + "\n")
write(os.path.join(RP, "definition.pbir"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
    "version": "4.0",
    "datasetReference": {"byPath": {"path": f"../{NAME}.SemanticModel"}}}, indent=2) + "\n")
write(os.path.join(RP, "definition", "version.json"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json",
    "version": "2.0.0"}, indent=2) + "\n")
write(os.path.join(RP, "definition", "report.json"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/2.1.0/schema.json",
    "themeCollection": {"baseTheme": {"name": "CY24SU10", "reportVersionAtImport": "5.59", "type": "SharedResources"}},
    "resourcePackages": [{"name": "SharedResources", "type": "SharedResources",
                          "items": [{"name": "CY24SU10", "path": "BaseThemes/CY24SU10.json", "type": "BaseTheme"}]}],
    "settings": {"useStylableVisualContainerHeader": True, "defaultDrillFilterOtherVisuals": True,
                 "allowChangeFilterTypes": True, "useEnhancedTooltips": True,
                 "useDefaultAggregateDisplayName": True}}, indent=2) + "\n")
write(os.path.join(RP, "definition", "pages", "pages.json"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json",
    "pageOrder": ["a5100001"], "activePageName": "a5100001"}, indent=2) + "\n")
write(os.path.join(RP, "definition", "pages", "a5100001", "page.json"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.0.0/schema.json",
    "name": "a5100001", "displayName": "Pull", "displayOption": "FitToPage",
    "height": 720, "width": 1280}, indent=2) + "\n")

write(os.path.join(DEST, f"{NAME}.pbip"), json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
    "version": "1.0",
    "artifacts": [{"report": {"path": f"{NAME}.Report"}}],
    "settings": {"enableAutoRecovery": True}}, indent=2) + "\n")
write(os.path.join(DEST, ".gitignore"), "**/.pbi/localSettings.json\n**/.pbi/cache.abf\n")

print("\ntotal columns:", sum(len(s[2]) for s in SPECS))
