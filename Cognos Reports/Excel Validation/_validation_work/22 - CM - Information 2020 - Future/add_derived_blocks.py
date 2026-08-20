"""Adds the derived-column blocks to the Notes sheet of the report 22 workbook, in place.

One block per source-query section, to the right of the query text (columns I:L): every column
on the page that is not read straight from a cube column or measure, with Dave's definition, the
Cognos native SQL, and ours. Edits the delivered workbook through Excel so nothing else on the
sheet is touched; the builder is not re-run.
"""
import win32com.client as com

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
COL0 = 9  # column I
HDR = ["Column", "Dave's definition", "Cognos native SQL", "Our definition"]

BLOCKS = {
 "1. Receipts": [
  ["Vendor Name", "Supplier[Supplier Name]", 'VENDOR.VENDOR_NAME',
   "RELATED ( Supplier[Supplier Name] ); when blank, LOOKUPVALUE ( Address[Address Name], Address[Address Num], [Address Num PO] ) - 2 rows (vendor 322976) whose SupplierSKey the cube does not resolve"],
  ["Bulk Item", "(not on his page - Receipts joined to ItemBranch on ItemBranchSKey)", "ITEM.BULK_ITEM",
   "RELATED ( 'Item Branch'[Item Num Bulk] ); blank rendered as \"-\" (Cognos's render of an empty bulk, 8 rows)"],
  ["Received Quantity", "measure [PO Rec Qty Received]", "sum(RECEIPT_ACTIVITY_MEASURES.RECEIVED_QUANTITY)  (primary UOM)",
   "IF ( [UOM Primary] = \"LB\", [QuantityReceivedLB], IF ( [UOM Primary] = \"KG\", [QuantityReceivedKG], [QuantityReceived] ) ) - the cube's QuantityReceived is in transaction UOM; Cognos shows primary UOM (58 WD40-UN rows are DR->LB x350)"],
  ["Year / Month", "Power Query: Date.Year / Date.Month of Received Date", "TIME_OTHER_DATE.GREGORIAN_CALENDAR_YEAR / _MONTH  (receipt date)",
   "YEAR ( [Received Date] ) / MONTH ( [Received Date] )"],
 ],
 "2. Shipments": [
  ["Branch Plant", "Branch[Branch Plant]", "ORDER_ACTIVITY_MEASURES.ORGANIZATION_ID", "TRIM ( Sales[BusinessUnit] )"],
  ["Description 2", "(not on his page)", "ORDER_ACTIVITY_MEASURES.DESCRIPTION_2", "Sales[Description 2]; blank rendered as \"-\""],
  ["Order Net Amount USD", "measure [Order Net Amt SPD USD]",
   "sum( round( (case when ORDER_NET_AMOUNT = 0 and QTY_BACKORDERED > 0 then ordered qty x ORDER_NET_PRICE else ORDER_NET_AMOUNT end) / EXCHANGE_RATE, 2 ) x T5 rate to USD (type M, GL/ordered date) x SALES_FACTOR )",
   "Sales[AmountOrderNetUSD] + Sales[BackOrderedExtendedAmount]  (the back-ordered amount is nonzero only when Net = 0; 2 rows)"],
  ["Order Net Amount EUR", "(none - [Order Net Amt SPD] is the local-currency amount)", "same, x T12 rate to EUR",
   "IF ( Sales[LocalCurrency] = \"EUR\", [AmountOrderNetEUR] + [BackOrderedExtendedAmountEUR], DIVIDE ( Net USD, EUR->USD ToRateA ) ) - rate = Currency Rates row at EOMONTH of GL Date (Order Date when GL Date is blank). The cube's EUR columns are null for USD-local companies"],
  ["Raw Material Margin USD / EUR", "(none)",
   "sum( (net x SALES_FACTOR - A1_COST x SALES_FACTOR - PRICE_ORDER_SUMMARY.DELV_FREIGHT - WAREHOUSE - ADD_FREIGHT, each x SALES_FACTOR) x rate )",
   "SUBSTITUTE, open with Dave: Net USD - Sales[AmountExtendedCostUSD] (standard cost). EUR: EUR-local Net EUR - [AmountExtendedCostEUR], else margin USD / EUR->USD rate. A1 cost and the PRICE_ORDER_SUMMARY freight/warehouse buckets exist only in the legacy DW. Total -2.1% vs Cognos"],
  ["TM Name", "'Territory Manager'[Territory Manager]", "VENDOR_ALIAS_TM.MAILING_NAME  (vendor row of SALES_REP_ID)",
   "RELATED ( 'Territory Manager'[Mailing Name] ); blank rendered as \"Not Available\""],
  ["Year / Month", "Power Query: Date.Year / Date.Month of Promised Shipment Date", "TIME_DUE_DATE.GREGORIAN_CALENDAR_YEAR / _MONTH",
   "YEAR ( Sales[Promised Shipment Date] ) / MONTH ( ... )"],
 ],
 "3. Forecast": [
  ["(whole page)", "Not in Dave's PBIP", "", ""],
  ["Branch Plant", "-", "INVENTORY_DEMAND.COMPANYBRANCH_PLANT", "TRIM ( FactForecast[BusinessUnit] )"],
  ["Item Description 2", "-", "ITEM.ITEM_DESCRIPTION_2", "RELATED ( 'Item Branch'[Description 2] ); blank rendered as \"-\""],
  ["TM Name", "-", "VENDOR_ALIAS_TM.MAILING_NAME  (vendor row of SALES_REP_ID)",
   "RELATED ( 'Territory Manager'[Mailing Name] ); blank rendered as \"Not Available\" - FactForecast carries a TM for FC-group customers only (730 rows differ)"],
  ["Revenue Business Unit", "-", "ORGANIZATION_ALIAS_RBU.ORGANIZATION_CODE", "NOT PRODUCED - not on FactForecast; EDW fallback if Dave needs it"],
  ["Year / Month", "-", "TIME_OTHER_DATE.GREGORIAN_CALENDAR_YEAR / _MONTH  (requested date)", "YEAR ( FactForecast[RequestedDate] ) / MONTH ( ... )"],
 ],
 "4. Work Orders": [
  ["Branch Plant", "Branch[Branch Plant]  (the parts-list Branch relationship = the component's branch)", "WORK_ORDER.BRANCH_PLANT  (the work order's branch)",
   "LOOKUPVALUE ( Branch[Branch Plant], Branch[BranchSKey], 'Work Order Detail'[BranchSKey] of the row's WorkOrderSKey ) - the parent work order's branch (Work Order itself has no branch column)"],
  ["Global Bulk Item / Bulk Item", "'Item Branch'[Item Global Bulk] / [Item Bulk]  (the component's item, via the parts-list relationship)", "ITEM.GLOBAL_BULK_ITEM / BULK_ITEM joined on WORK_ORDER.ITEM_SID  (the parent item)",
   "LOOKUPVALUE ( 'Item Branch'[Item Global Bulk] / [Item Bulk], 'Item Branch'[ItemBranchSKey], 'Work Order Detail'[ItemBranchSKey] of the row's WorkOrderSKey ) - the parent item; the component's own bulk is the separate Component Bulk Item column"],
  ["Completion Date", "'Work Order Parts List'[Completion Date]", "WORK_ORDER.COMPLETION_DATE",
   "RELATED ( 'Work Order'[Completed Date] ); 1900-12-31 or earlier (the cube's no-date marker) rendered blank"],
  ["Year / Month", "(not on his page)", "TIME_COMPLETED_DATE.GREGORIAN_CALENDAR_YEAR / _MONTH  (0 when there is no completion date)",
   "YEAR / MONTH of Completion Date - blank when uncompleted, where Cognos prints 0 (89 rows)"],
  ["Component Branch Plant", "(not on his page)", "WORD_ORDER_PARTS_LIST.BRANCH_PLANT", "TRIM ( 'Work Order Parts List'[BusinessUnit] )"],
 ],
 "5. BOM": [
  ["Source", "ODSPROD PRODDTA.F3002, multi-level staged explosion (CINC/CIN2/CIN4/COLR, stock types O/I excluded, as-of @AsOfNow)", "DW_LEGACY.BILL_OF_MATERIAL, single level",
   "EDWPROD BIQL.DimBillOfMaterial, single level - the cube has no bill of material (Bill Of Material Expanded is empty in production)"],
  ["Quantity", "IXQNTY / 1000000 with explosion math (ResolvedComponentQty cascades; Original Quantity = ComponentQtyRaw / LogicalParentQty)", "sum(BILL_OF_MATERIAL.QUANTITY)",
   "b.QuantityStandardRequired / 100.0  (EDW stores the quantity x100)"],
  ["Parent Second Item Number", "from the explosion (Parent 2nd Item Number)", "ITEM.ITEM_NUMBER_2ND of the kit item (BILL_OF_MATERIAL_KIT__IT_SID)",
   "LEFT JOIN BIQL.DimItemBranch pib ON pib.ItemBranchSKey = b.ParentItemBranchSKey"],
  ["Branch Plant / 2nd / Bulk / Global Bulk", "from F3002 / F4101 / F4102", "BILL_OF_MATERIAL.BRANCH_PLANT; ITEM_ALIAS_COMP.* (the component item)",
   "LTRIM(RTRIM(...)) of b.Branch and the component item-branch (ib) columns"],
 ],
 "6. Item Details": [
  ["Branch Plant", "Branch[Branch Plant]", "ITEM.BRANCH_PLANT", "TRIM ( 'Item Branch'[Business Unit] ); rows with a blank business unit excluded (the item-master rows Cognos shows as N/A)"],
  ["Safety Stock", "'Item Branch'[SafetyStock]", "ITEM.SAFETY_STOCK", "IF ( ISBLANK ( 'Item Branch'[SafetyStock] ), 0, 'Item Branch'[SafetyStock] )"],
  ["Supplier / Planner / Buyer Name", "Supplier[Supplier Name] (via relationship), 'Item Branch'[Planner Name], [Buyer Name]", "VENDOR_ALIAS_ITEM_SUPPLIER / _PLANNER / _BUYER.VENDOR_NAME",
   "'Item Branch'[Branch Supplier Name] / [Planner Name] / [Buyer Name]; blank rendered as \"Not Available\""],
 ],
}


def main():
    xl = com.DispatchEx("Excel.Application")  # private instance, never the user's open Excel
    xl.Visible = False; xl.DisplayAlerts = False
    wb = xl.Workbooks.Open(WB)
    ws = wb.Worksheets("Notes")
    last = ws.UsedRange.Rows.Count + ws.UsedRange.Row
    # locate the source-query headings
    heads = {}
    for r in range(1, last + 1):
        v = ws.Cells(r, 3).Value
        if isinstance(v, str):
            for k in BLOCKS:
                if v.startswith(k + " "):
                    heads[k] = r
    assert len(heads) == len(BLOCKS), heads
    ref = ws.Cells(heads["1. Receipts"], 3)          # the section heading: font of the sheet
    fname, fsize = ref.Font.Name, ref.Font.Size
    for k, rows in BLOCKS.items():
        r0 = heads[k]
        c = ws.Cells(r0, COL0); c.Value = "Derived columns - not a direct cube column or measure"
        c.Font.Name, c.Font.Size, c.Font.Bold = fname, fsize, True
        r = r0 + 1
        for j, h in enumerate(HDR):
            c = ws.Cells(r, COL0 + j); c.Value = h
            c.Font.Name, c.Font.Size, c.Font.Bold = fname, fsize, True
            c.Interior.Color = 0xE5E5E7  # BGR of E7E5E5
            c.WrapText = True; c.VerticalAlignment = -4160
        r += 1
        for row in rows:
            for j, v in enumerate(row):
                c = ws.Cells(r, COL0 + j); c.Value = v
                c.Font.Name, c.Font.Size, c.Font.Bold = fname, fsize, (j == 0)
                c.WrapText = True; c.VerticalAlignment = -4160
            r += 1
        rng = ws.Range(ws.Cells(r0 + 1, COL0), ws.Cells(r - 1, COL0 + len(HDR) - 1))
        for b in (7, 8, 9, 10, 11, 12):   # xlEdgeLeft..xlInsideHorizontal
            bd = rng.Borders(b); bd.LineStyle = 1; bd.Weight = 2; bd.Color = 0xBFBFBF
        ws.Range(ws.Cells(r0 + 2, COL0), ws.Cells(r - 1, COL0)).Rows.AutoFit()
    ws.Columns(8).ColumnWidth = 3
    for j, w in enumerate((26, 46, 58, 64)):
        ws.Columns(COL0 + j).ColumnWidth = w
    ws.Activate(); ws.Range("A1").Select()
    wb.Save(); wb.Close(True); xl.Quit()
    print("blocks at rows", heads)


if __name__ == "__main__":
    main()
