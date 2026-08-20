"""Emits the report 14 paginated report.

The RDL is the deliverable; this script is how it is maintained. Four tabs — Summary,
Inventory Data, Escor Inventory, Escor Lot Details — each a Rectangle carrying a PageName
so the Excel export lands on a named sheet.

Styling follows reports 19 and 21: Cognos-look 7pt cells, bold red headers, 1pt black
cell borders.
"""

import pathlib
from xml.sax.saxutils import escape

OUT = pathlib.Path(__file__).parent / "14 - Ivan Global Inventory Excel - Select Date (RDL)" / "Ivan Global Inventory Excel - Select Date.rdl"

NS = "http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition"

RED = "#ff0000"
BLACK = "#000000"
GREY = "#666666"
DARK = "#333333"
MID = "#595959"
CELL = "7pt"

BRANCHES = '{ "CINC", "CIN2", "CIN4", "AUBA", "AUB2", "SING", "SNG4", "MUM3", "SHAN" }'
FAMILIES = ('{ "ATP", "ETP", "FBW", "FCB", "FEC", "FRC", "RAW",\n'
            '                    "RBW", "RCB", "REC", "RRC", "RWW", "TOL", "WAG" }')


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

DAX_DATES = """EVALUATE
VAR R14AvailableDates =
    SUMMARIZECOLUMNS (
        'Calendar Inventory Snapshot'[Calendar Date],
        FILTER (
            VALUES ( 'Branch'[Branch Plant] ),
            TRIM ( 'Branch'[Branch Plant] ) IN %s
        ),
        FILTER (
            VALUES ( 'Inventory Snapshot'[CostMethod] ),
            TRIM ( 'Inventory Snapshot'[CostMethod] ) = "07"
        ),
        "QuantityOnHandLB", [Qty On Hand LB]
    )
RETURN
    SELECTCOLUMNS (
        FILTER ( R14AvailableDates, NOT ISBLANK ( [QuantityOnHandLB] ) ),
        "InventoryDate", 'Calendar Inventory Snapshot'[Calendar Date],
        "InventoryDateLabel", FORMAT ( 'Calendar Inventory Snapshot'[Calendar Date], "d MMM, yyyy" )
    )
ORDER BY [InventoryDate] DESC""" % BRANCHES

DAX_LATEST_DATE = """EVALUATE
VAR R14AvailableDates =
    SUMMARIZECOLUMNS (
        'Calendar Inventory Snapshot'[Calendar Date],
        FILTER (
            VALUES ( 'Branch'[Branch Plant] ),
            TRIM ( 'Branch'[Branch Plant] ) IN %s
        ),
        FILTER (
            VALUES ( 'Inventory Snapshot'[CostMethod] ),
            TRIM ( 'Inventory Snapshot'[CostMethod] ) = "07"
        ),
        "QuantityOnHandLB", [Qty On Hand LB]
    )
RETURN
    TOPN (
        1,
        SELECTCOLUMNS (
            FILTER ( R14AvailableDates, NOT ISBLANK ( [QuantityOnHandLB] ) ),
            "InventoryDate", 'Calendar Inventory Snapshot'[Calendar Date]
        ),
        [InventoryDate], DESC
    )""" % BRANCHES

DAX_INVENTORY = """EVALUATE
VAR R14InventoryDate = DATEVALUE ( @InventoryDate ) + TIMEVALUE ( @InventoryDate )
RETURN
    SELECTCOLUMNS (
        FILTER (
            'Inventory Snapshot',
            'Inventory Snapshot'[Calendar Date] = R14InventoryDate
                && TRIM ( 'Inventory Snapshot'[CostMethod] ) = "07"
                && 'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0
                && TRIM ( RELATED ( 'Branch'[Branch Plant] ) ) IN %s
                && TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) )
                    IN %s
        ),
        "Inventory Date", 'Inventory Snapshot'[Calendar Date],
        "REGION", SWITCH (
                TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
                "CINC", "Americas",
                "CIN2", "Americas",
                "CIN4", "Americas",
                "AUBA", "Aubange",
                "AUB2", "Aubange",
                "SING", "Singapore",
                "SNG4", "Singapore",
                "MUM3", "India",
                "SHAN", "China",
                "ERROR"
            ),
        "Branch Plant", TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
        "Global Bulk Item", TRIM ( RELATED ( 'Item Branch'[Item Num Global Bulk] ) ),
        "Bulk Item", TRIM ( RELATED ( 'Item Branch'[Item Num Bulk] ) ),
        "2nd Item Number", TRIM ( RELATED ( 'Item Branch'[Item Num 2nd] ) ),
        "Stock Type Code", TRIM ( RELATED ( 'Item Branch'[Stocking Type] ) ),
        "GL Class Code", TRIM ( 'Inventory Snapshot'[CategoryGLF41021] ),
        "Location", TRIM ( 'Inventory Snapshot'[Location] ),
        "Lot Number", TRIM ( 'Inventory Snapshot'[LotNum] ),
        "Supplier Lot Number", TRIM ( RELATED ( 'Lot'[Supplier Lot Num] ) ),
        "Lot Status", TRIM ( 'Inventory Snapshot'[Lot Status Code] ),
        "Master Planning Family", TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) ),
        "On Hand", 'Inventory Snapshot'[QuantityOnHandPrimaryUOM],
        "UOM", TRIM ( 'Inventory Snapshot'[UOMPrimary] ),
        "OH KGs", CALCULATE ( [Qty On Hand KG] ),
        "OH LBs", CALCULATE ( [Qty On Hand LB] ),
        "OH USD",
            CALCULATE (
                [Total Ext Cost IC USD],
                'Selected UOM Filter'[Selected UOM Code] = 1
            ) + 0,
        "OH EUR",
            'Inventory Snapshot'[AmountValueAtCost]
                * LOOKUPVALUE (
                    'Currency Rates'[ToRateDaily],
                    'Currency Rates'[CurrencySKey], 'Inventory Snapshot'[CurrencyBSKey]
                ),
        "On Hand Date", RELATED ( 'Lot'[On Hand Date] ),
        "Lot Expiry Date", RELATED ( 'Lot'[Lot Expiration Date] ),
        "Memo Lot 1", RELATED ( 'Lot'[Memo Lot 1] ),
        "Memo Lot 2", RELATED ( 'Lot'[Memo Lot 2] ),
        "Commodity Class Description", RELATED ( 'Item Branch'[Commodity Class Codes Desc] ),
        "Commodity Sub Class Description", RELATED ( 'Item Branch'[Commodity Sub Class Codes Desc] )
    )
ORDER BY [REGION], [Global Bulk Item], [Bulk Item], [2nd Item Number]""" % (BRANCHES, FAMILIES)

DAX_ESCOR_INVENTORY = """EVALUATE
VAR R14InventoryDate = DATEVALUE ( @InventoryDate ) + TIMEVALUE ( @InventoryDate )
RETURN
    SELECTCOLUMNS (
        FILTER (
            'Inventory Snapshot',
            'Inventory Snapshot'[Calendar Date] = R14InventoryDate
                && TRIM ( 'Inventory Snapshot'[CostMethod] ) = "07"
                && 'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0
                && TRIM ( RELATED ( 'Item Branch'[Item Num Global Bulk] ) ) = "ESC5200"
        ),
        "Inventory Date", 'Inventory Snapshot'[Calendar Date],
        "Branch Plant", TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
        "Global Bulk Item", TRIM ( RELATED ( 'Item Branch'[Item Num Global Bulk] ) ),
        "Bulk Item", TRIM ( RELATED ( 'Item Branch'[Item Num Bulk] ) ),
        "2nd Item Number", TRIM ( RELATED ( 'Item Branch'[Item Num 2nd] ) ),
        "Last Receipt Date", 'Inventory Snapshot'[Last Receipt Date],
        "Location", TRIM ( 'Inventory Snapshot'[Location] ),
        "Lot Number", TRIM ( 'Inventory Snapshot'[LotNum] ),
        "On Hand Date", RELATED ( 'Lot'[On Hand Date] ),
        "Lot Expiry Date", RELATED ( 'Lot'[Lot Expiration Date] ),
        "Sell by Date", RELATED ( 'Lot'[Sell By Date] ),
        "Supplier Lot Number", TRIM ( RELATED ( 'Lot'[Supplier Lot Num] ) ),
        "Memo Lot 1", RELATED ( 'Lot'[Memo Lot 1] ),
        "Memo Lot 2", RELATED ( 'Lot'[Memo Lot 2] ),
        "Lot Status", TRIM ( RELATED ( 'Lot'[Lot Status Code] ) ),
        "Master Planning Family", TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) ),
        "Quantity on Hand KGs", CALCULATE ( [Qty On Hand KG] ),
        "Quantity on Hand LBs", CALCULATE ( [Qty On Hand LB] ),
        "Quantity on Hand", 'Inventory Snapshot'[QuantityOnHandPrimaryUOM],
        "Primary Unit of Measure", TRIM ( 'Inventory Snapshot'[UOMPrimary] )
    )
ORDER BY [Branch Plant], [Last Receipt Date]"""

SQL_ESCOR_LOT = """SELECT DISTINCT
    LTRIM(RTRIM(lm.IOMCU))                    AS [Branch Plant],
    LTRIM(RTRIM(tag.IMBULK))                  AS [Bulk Item],
    LTRIM(RTRIM(lm.IOLITM))                   AS [2nd Item Number],
    lm.IOITM                                  AS [Item Short ID],
    LTRIM(RTRIM(lm.IOLOTN))                   AS [Lot Number],
    NULLIF(LTRIM(RTRIM(lm.IORLOT)), 'NULL')   AS [Supplier Lot Number],
    LTRIM(RTRIM(lm.IOLOT1))                   AS [Memo Lot 1],
    LTRIM(RTRIM(lm.IOLOT2))                   AS [Memo Lot 2],
    CASE
        WHEN lm.IOOHDJ > 0 THEN
            DATEADD(
                DAY,
                (lm.IOOHDJ % 1000) - 1,
                DATEFROMPARTS((lm.IOOHDJ / 1000) + 1900, 1, 1)
            )
    END                                       AS [On Hand Date]
FROM PRODDTA.F4108 lm
LEFT JOIN
(
    SELECT IMITM, MIN(IMBULK) AS IMBULK
    FROM PRODDTA.F554101
    GROUP BY IMITM
) tag
    ON tag.IMITM = lm.IOITM
WHERE LTRIM(RTRIM(tag.IMBULK)) IN ('ESC5200', 'ESC5200.E', 'ESC5200.S')
ORDER BY [On Hand Date]"""

DAX_REFRESH = """EVALUATE
ROW (
    "LastRefreshed",
    CALCULATE ( MAX ( Audit[DateUpdated] ) )
)"""


# ---------------------------------------------------------------------------
# Column definitions:  (header, rdl field name, format, align, width)
# ---------------------------------------------------------------------------

TXT, NUM, DATE = "text", "num", "date"

INVENTORY_COLS = [
    ("Inventory Date",                  "Inventory_Date",                  DATE, "d MMM, yyyy", 0.85),
    ("REGION",                          "REGION",                          TXT,  None,          0.75),
    ("Branch Plant",                    "Branch_Plant",                    TXT,  None,          0.65),
    ("Global Bulk Item",                "Global_Bulk_Item",                TXT,  None,          1.00),
    ("Bulk Item",                       "Bulk_Item",                       TXT,  None,          1.00),
    ("2nd Item Number",                 "Item_Number_2nd",                 TXT,  None,          1.00),
    ("Stock Type Code",                 "Stock_Type_Code",                 TXT,  None,          0.60),
    ("GL Class Code",                   "GL_Class_Code",                   TXT,  None,          0.60),
    ("Location",                        "Location",                        TXT,  None,          0.70),
    ("Lot Number",                      "Lot_Number",                      TXT,  None,          0.85),
    ("Supplier Lot Number",             "Supplier_Lot_Number",             TXT,  None,          1.00),
    ("Lot Status",                      "Lot_Status",                      TXT,  None,          0.55),
    ("Master Planning Family",          "Master_Planning_Family",          TXT,  None,          0.75),
    ("On Hand",                         "On_Hand",                         NUM,  "#,0",         0.75),
    ("UOM",                             "UOM",                             TXT,  None,          0.45),
    ("OH KGs",                          "OH_KGs",                          NUM,  "#,0",         0.80),
    ("OH LBs",                          "OH_LBs",                          NUM,  "#,0",         0.80),
    ("OH USD",                          "OH_USD",                          NUM,  "$#,0",        0.85),
    ("OH EUR",                          "OH_EUR",                          NUM,  "€#,0",   0.85),
    ("On Hand Date",                    "On_Hand_Date",                    DATE, "d MMM, yyyy", 0.85),
    ("Lot Expiry Date",                 "Lot_Expiry_Date",                 DATE, "d MMM, yyyy", 0.90),
    ("Memo Lot 1",                      "Memo_Lot_1",                      TXT,  None,          0.75),
    ("Memo Lot 2",                      "Memo_Lot_2",                      TXT,  None,          1.40),
    ("Commodity Class Description",     "Commodity_Class_Description",     TXT,  None,          1.30),
    ("Commodity Sub Class Description", "Commodity_Sub_Class_Description", TXT,  None,          1.40),
]

ESCOR_INVENTORY_COLS = [
    ("Inventory Date",          "Inventory_Date",          DATE, "d MMM, yyyy", 0.85),
    ("Branch Plant",            "Branch_Plant",            TXT,  None,          0.65),
    ("Global Bulk Item",        "Global_Bulk_Item",        TXT,  None,          1.00),
    ("Bulk Item",               "Bulk_Item",               TXT,  None,          1.00),
    ("2nd Item Number",         "Item_Number_2nd",         TXT,  None,          1.00),
    ("Last Receipt Date",       "Last_Receipt_Date",       DATE, "d MMM, yyyy", 0.95),
    ("Location",                "Location",                TXT,  None,          0.70),
    ("Lot Number",              "Lot_Number",              TXT,  None,          0.85),
    ("On Hand Date",            "On_Hand_Date",            DATE, "d MMM, yyyy", 0.85),
    ("Lot Expiry Date",         "Lot_Expiry_Date",         DATE, "d MMM, yyyy", 0.90),
    ("Sell by Date",            "Sell_by_Date",            DATE, "d MMM, yyyy", 0.85),
    ("Supplier Lot Number",     "Supplier_Lot_Number",     TXT,  None,          1.00),
    ("Memo Lot 1",              "Memo_Lot_1",              TXT,  None,          0.75),
    ("Memo Lot 2",              "Memo_Lot_2",              TXT,  None,          1.40),
    ("Lot Status",              "Lot_Status",              TXT,  None,          0.55),
    ("Master Planning Family",  "Master_Planning_Family",  TXT,  None,          0.75),
    ("Quantity on Hand KGs",    "Quantity_on_Hand_KGs",    NUM,  "#,0",         1.05),
    ("Quantity on Hand LBs",    "Quantity_on_Hand_LBs",    NUM,  "#,0",         1.05),
    ("Quantity on Hand",        "Quantity_on_Hand",        NUM,  "#,0",         0.95),
    ("Primary Unit of Measure", "Primary_Unit_of_Measure", TXT,  None,          0.95),
]

ESCOR_LOT_COLS = [
    ("Branch Plant",        "Branch_Plant",        TXT,  None,          0.65),
    ("Bulk Item",           "Bulk_Item",           TXT,  None,          1.00),
    ("2nd Item Number",     "Item_Number_2nd",     TXT,  None,          1.00),
    ("Item Short ID",       "Item_Short_ID",       NUM,  "0",           0.80),
    ("Lot Number",          "Lot_Number",          TXT,  None,          0.85),
    ("Supplier Lot Number", "Supplier_Lot_Number", TXT,  None,          1.00),
    ("Memo Lot 1",          "Memo_Lot_1",          TXT,  None,          0.75),
    ("Memo Lot 2",          "Memo_Lot_2",          TXT,  None,          1.40),
    ("On Hand Date",        "On_Hand_Date",        DATE, "d MMM, yyyy", 0.85),
]

# Dataset field wiring:  (rdl field name, DataField, CLR type)
DAX_TYPE = {TXT: "System.String", NUM: "System.Double", DATE: "System.DateTime"}

INVENTORY_FIELDS = [(f, "[%s]" % h, DAX_TYPE[k]) for h, f, k, _, _ in INVENTORY_COLS]
ESCOR_INVENTORY_FIELDS = [(f, "[%s]" % h, DAX_TYPE[k]) for h, f, k, _, _ in ESCOR_INVENTORY_COLS]
ESCOR_LOT_FIELDS = [(f, h, "System.Int32" if h == "Item Short ID" else DAX_TYPE[k])
                    for h, f, k, _, _ in ESCOR_LOT_COLS]


# ---------------------------------------------------------------------------
# XML helpers
# ---------------------------------------------------------------------------

def ind(text, n):
    pad = " " * n
    return "\n".join(pad + line if line else line for line in text.split("\n"))


def cell_style(bg=None):
    parts = ["<Style>",
             "  <Border>",
             "    <Color>%s</Color>" % BLACK,
             "    <Style>Solid</Style>",
             "  </Border>"]
    if bg:
        parts.append("  <BackgroundColor>%s</BackgroundColor>" % bg)
    parts += ["  <VerticalAlign>Middle</VerticalAlign>",
              "  <PaddingLeft>2pt</PaddingLeft>",
              "  <PaddingRight>2pt</PaddingRight>",
              "  <PaddingTop>2pt</PaddingTop>",
              "  <PaddingBottom>2pt</PaddingBottom>",
              "</Style>"]
    return "\n".join(parts)


def textbox(name, value, *, size=CELL, bold=False, color=BLACK, fmt=None,
            align="Left", bg=None, bordered=True, padding=True):
    run = ["<TextRun>",
           "  <Value>%s</Value>" % escape(value),
           "  <Style>",
           "    <FontSize>%s</FontSize>" % size]
    if bold:
        run.append("    <FontWeight>Bold</FontWeight>")
    if fmt:
        run.append("    <Format>%s</Format>" % escape(fmt))
    run += ["    <Color>%s</Color>" % color,
            "  </Style>",
            "</TextRun>"]

    if bordered:
        style = cell_style(bg)
    else:
        style = "\n".join(["<Style>",
                           "  <Border>",
                           "    <Style>None</Style>",
                           "  </Border>"] +
                          (["  <PaddingLeft>2pt</PaddingLeft>",
                            "  <PaddingRight>2pt</PaddingRight>",
                            "  <PaddingTop>2pt</PaddingTop>",
                            "  <PaddingBottom>2pt</PaddingBottom>"] if padding else []) +
                          ["</Style>"])

    return "\n".join([
        '<Textbox Name="%s">' % name,
        "  <CanGrow>true</CanGrow>",
        "  <KeepTogether>true</KeepTogether>",
        "  <Paragraphs>",
        "    <Paragraph>",
        "      <TextRuns>",
        ind(run_text(run), 8),
        "      </TextRuns>",
        "      <Style>",
        "        <TextAlign>%s</TextAlign>" % align,
        "      </Style>",
        "    </Paragraph>",
        "  </Paragraphs>",
        ind(style, 2),
        "</Textbox>",
    ])


def run_text(lines):
    return "\n".join(lines)


def floating_textbox(name, value, *, top, left=None, width, height, zindex,
                     size, color, align="Left"):
    box = textbox(name, value, size=size, color=color, align=align, bordered=False)
    extra = ["  <Top>%s</Top>" % top]
    if left is not None:
        extra.append("  <Left>%s</Left>" % left)
    extra += ["  <Height>%s</Height>" % height,
              "  <Width>%s</Width>" % width,
              "  <ZIndex>%d</ZIndex>" % zindex]
    lines = box.split("\n")
    # inject sizing just before the trailing <Style> block
    cut = next(i for i, l in enumerate(lines) if l == "  <Style>")
    return "\n".join(lines[:cut] + extra + lines[cut:])


# ---------------------------------------------------------------------------
# Flat list tablix
# ---------------------------------------------------------------------------

def list_tablix(prefix, cols, dataset, top, width):
    columns = "\n".join("<TablixColumn>\n  <Width>%.2fin</Width>\n</TablixColumn>" % w
                        for *_, w in cols)

    header_cells, detail_cells = [], []
    for i, (header, field, kind, fmt, _w) in enumerate(cols, start=1):
        hb = textbox("%s_Header_%d" % (prefix, i), header,
                     bold=True, color=RED, align="Left", bg="#ffffff")
        header_cells.append("<TablixCell>\n  <CellContents>\n%s\n  </CellContents>\n</TablixCell>"
                            % ind(hb, 4))

        align = "Right" if kind == NUM else "Left"
        db = textbox("%s_Detail_%d" % (prefix, i), "=Fields!%s.Value" % field,
                     fmt=fmt, align=align)
        detail_cells.append("<TablixCell>\n  <CellContents>\n%s\n  </CellContents>\n</TablixCell>"
                            % ind(db, 4))

    rows = "\n".join([
        "<TablixRow>",
        "  <Height>0.38in</Height>",
        "  <TablixCells>",
        ind("\n".join(header_cells), 4),
        "  </TablixCells>",
        "</TablixRow>",
        "<TablixRow>",
        "  <Height>0.24in</Height>",
        "  <TablixCells>",
        ind("\n".join(detail_cells), 4),
        "  </TablixCells>",
        "</TablixRow>",
    ])

    col_members = "\n".join("<TablixMember />" for _ in cols)

    return "\n".join([
        '<Tablix Name="%s_Table">' % prefix,
        "  <TablixBody>",
        "    <TablixColumns>",
        ind(columns, 6),
        "    </TablixColumns>",
        "    <TablixRows>",
        ind(rows, 6),
        "    </TablixRows>",
        "  </TablixBody>",
        "  <TablixColumnHierarchy>",
        "    <TablixMembers>",
        ind(col_members, 6),
        "    </TablixMembers>",
        "  </TablixColumnHierarchy>",
        "  <TablixRowHierarchy>",
        "    <TablixMembers>",
        "      <TablixMember>",
        "        <KeepWithGroup>After</KeepWithGroup>",
        "        <RepeatOnNewPage>true</RepeatOnNewPage>",
        "        <KeepTogether>true</KeepTogether>",
        "      </TablixMember>",
        "      <TablixMember>",
        '        <Group Name="%s_Details" />' % prefix,
        "      </TablixMember>",
        "    </TablixMembers>",
        "  </TablixRowHierarchy>",
        "  <NoRowsMessage>No Data Available</NoRowsMessage>",
        "  <DataSetName>%s</DataSetName>" % dataset,
        "  <Top>%s</Top>" % top,
        "  <Height>0.62in</Height>",
        "  <Width>%.2fin</Width>" % width,
        "  <ZIndex>3</ZIndex>",
        "  <Style>",
        "    <Border>",
        "      <Style>None</Style>",
        "    </Border>",
        "  </Style>",
        "</Tablix>",
    ])


# ---------------------------------------------------------------------------
# Summary matrix
# ---------------------------------------------------------------------------

def summary_tablix(top):
    prefix = "Summary_Table"
    value_cols = [("OH LBs", "OH_LBs", "#,0"), ("OH USD", "OH_USD", "$#,0")]

    def value_cell(name, field, fmt, bold):
        return textbox(name, "=Sum(Fields!%s.Value)" % field, fmt=fmt, align="Right", bold=bold)

    body_rows = []
    for row_name, bold in (("Family", False), ("RegionTotal", True)):
        cells = []
        for label, field, fmt in value_cols:
            tb = value_cell("%s_%s_%s" % (prefix, row_name, field), field, fmt, bold)
            cells.append("<TablixCell>\n  <CellContents>\n%s\n  </CellContents>\n</TablixCell>"
                         % ind(tb, 4))
        body_rows.append("\n".join([
            "<TablixRow>",
            "  <Height>0.24in</Height>",
            "  <TablixCells>",
            ind("\n".join(cells), 4),
            "  </TablixCells>",
            "</TablixRow>",
        ]))

    corner_cell = lambda n: (
        "<TablixCornerCell>\n  <CellContents>\n%s\n  </CellContents>\n</TablixCornerCell>"
        % ind(textbox("%s_Corner_%s" % (prefix, n), "", bg="#ffffff"), 4))

    corner = "\n".join([
        "<TablixCorner>",
        "  <TablixCornerRows>",
        "    <TablixCornerRow>",
        ind(corner_cell("1a"), 6),
        ind(corner_cell("1b"), 6),
        "    </TablixCornerRow>",
        "    <TablixCornerRow>",
        ind(corner_cell("2a"), 6),
        ind(corner_cell("2b"), 6),
        "    </TablixCornerRow>",
        "  </TablixCornerRows>",
        "</TablixCorner>",
    ])

    measure_members = "\n".join(
        "\n".join([
            "<TablixMember>",
            "  <TablixHeader>",
            "    <Size>0.30in</Size>",
            "    <CellContents>",
            ind(textbox("%s_MeasureHeader_%s" % (prefix, field), label,
                        align="Right", bg="#ffffff"), 6),
            "    </CellContents>",
            "  </TablixHeader>",
            "</TablixMember>",
        ]) for label, field, _fmt in value_cols)

    column_hierarchy = "\n".join([
        "<TablixColumnHierarchy>",
        "  <TablixMembers>",
        "    <TablixMember>",
        '      <Group Name="Summary_LotStatus">',
        "        <GroupExpressions>",
        "          <GroupExpression>=Fields!Lot_Status.Value</GroupExpression>",
        "        </GroupExpressions>",
        "      </Group>",
        "      <SortExpressions>",
        "        <SortExpression>",
        "          <Value>=Fields!Lot_Status.Value</Value>",
        "        </SortExpression>",
        "      </SortExpressions>",
        "      <TablixHeader>",
        "        <Size>0.30in</Size>",
        "        <CellContents>",
        ind(textbox("%s_LotStatusHeader" % prefix, "=Fields!Lot_Status.Value",
                    bold=True, color=RED, bg="#ffffff"), 10),
        "        </CellContents>",
        "      </TablixHeader>",
        "      <TablixMembers>",
        ind(measure_members, 8),
        "      </TablixMembers>",
        "    </TablixMember>",
        "  </TablixMembers>",
        "</TablixColumnHierarchy>",
    ])

    row_hierarchy = "\n".join([
        "<TablixRowHierarchy>",
        "  <TablixMembers>",
        "    <TablixMember>",
        '      <Group Name="Summary_Region">',
        "        <GroupExpressions>",
        "          <GroupExpression>=Fields!REGION.Value</GroupExpression>",
        "        </GroupExpressions>",
        "      </Group>",
        "      <SortExpressions>",
        "        <SortExpression>",
        "          <Value>=Fields!REGION.Value</Value>",
        "        </SortExpression>",
        "      </SortExpressions>",
        "      <TablixHeader>",
        "        <Size>1.10in</Size>",
        "        <CellContents>",
        ind(textbox("%s_RegionHeader" % prefix, "=Fields!REGION.Value"), 10),
        "        </CellContents>",
        "      </TablixHeader>",
        "      <TablixMembers>",
        "        <TablixMember>",
        '          <Group Name="Summary_Family">',
        "            <GroupExpressions>",
        "              <GroupExpression>=Fields!Master_Planning_Family.Value</GroupExpression>",
        "            </GroupExpressions>",
        "          </Group>",
        "          <SortExpressions>",
        "            <SortExpression>",
        "              <Value>=Fields!Master_Planning_Family.Value</Value>",
        "            </SortExpression>",
        "          </SortExpressions>",
        "          <TablixHeader>",
        "            <Size>1.10in</Size>",
        "            <CellContents>",
        ind(textbox("%s_FamilyHeader" % prefix,
                    "=Fields!Master_Planning_Family.Value"), 14),
        "            </CellContents>",
        "          </TablixHeader>",
        "        </TablixMember>",
        "        <TablixMember>",
        "          <TablixHeader>",
        "            <Size>1.10in</Size>",
        "            <CellContents>",
        ind(textbox("%s_TotalHeader" % prefix, "Total", bold=True), 14),
        "            </CellContents>",
        "          </TablixHeader>",
        "          <KeepWithGroup>Before</KeepWithGroup>",
        "        </TablixMember>",
        "      </TablixMembers>",
        "    </TablixMember>",
        "  </TablixMembers>",
        "</TablixRowHierarchy>",
    ])

    return "\n".join([
        '<Tablix Name="%s">' % prefix,
        ind(corner, 2),
        "  <TablixBody>",
        "    <TablixColumns>",
        "      <TablixColumn>",
        "        <Width>1.00in</Width>",
        "      </TablixColumn>",
        "      <TablixColumn>",
        "        <Width>1.00in</Width>",
        "      </TablixColumn>",
        "    </TablixColumns>",
        "    <TablixRows>",
        ind("\n".join(body_rows), 6),
        "    </TablixRows>",
        "  </TablixBody>",
        ind(column_hierarchy, 2),
        ind(row_hierarchy, 2),
        "  <NoRowsMessage>No Data Available</NoRowsMessage>",
        "  <DataSetName>dsInventory</DataSetName>",
        "  <Top>%s</Top>" % top,
        "  <Height>1.08in</Height>",
        "  <Width>4.20in</Width>",
        "  <ZIndex>3</ZIndex>",
        "  <Style>",
        "    <Border>",
        "      <Style>None</Style>",
        "    </Border>",
        "  </Style>",
        "</Tablix>",
    ])


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

def section(name, title, tablix, *, page_name, top, height, page_break,
            context_dataset, body_width, dated, stamp_left):
    items = [
        floating_textbox("%s_Title" % name, title, top="0in", width="10in",
                         height="0.35in", zindex=0, size="14pt", color=DARK),
        floating_textbox(
            "%s_Context" % name,
            ('="Inventory Date: " & Format(Parameters!InventoryDate.Value, "d MMM, yyyy") & "   |   '
             if dated else '="')
            + ('Rows: " & Format(CountRows("%s"), "#,0")' % context_dataset),
            top="0.36in", width="12in", height="0.24in", zindex=1, size="9pt", color=MID),
        floating_textbox(
            "%s_Refresh" % name,
            '="Cube last loaded: " & Format(First(Fields!LastRefreshed.Value, "dsRefresh"), '
            '"MMM d, yyyy h:mm:ss tt")',
            top="0.03in", left="%.2fin" % stamp_left, width="4.35in",
            height="0.25in", zindex=2, size="8pt", color=GREY, align="Right"),
        tablix,
    ]

    parts = ['<Rectangle Name="%s">' % name,
             "  <ReportItems>",
             ind("\n".join(items), 4),
             "  </ReportItems>"]
    if page_break:
        parts += ["  <PageBreak>",
                  "    <BreakLocation>Start</BreakLocation>",
                  "  </PageBreak>"]
    parts += ["  <PageName>%s</PageName>" % escape(page_name),
              "  <Top>%s</Top>" % top,
              "  <Height>%s</Height>" % height,
              "  <Width>%.2fin</Width>" % body_width,
              "  <ZIndex>%d</ZIndex>" % SECTION_Z[name],
              "  <Style>",
              "    <Border>",
              "      <Style>None</Style>",
              "    </Border>",
              "  </Style>",
              "</Rectangle>"]
    return "\n".join(parts)


SECTION_Z = {
    "SummarySection": 0,
    "InventorySection": 1,
    "EscorInventorySection": 2,
    "EscorLotSection": 3,
}


# ---------------------------------------------------------------------------
# Datasets
# ---------------------------------------------------------------------------

COMMANDS = []


def dataset(name, source, command, fields, *, parameterized):
    """Query text is stashed and re-inserted after indentation, so the DAX and T-SQL
    keep the indentation they were written with."""
    COMMANDS.append(escape(command))
    token = "@@COMMAND%d@@" % (len(COMMANDS) - 1)
    qp = ""
    if parameterized:
        qp = "\n".join([
            "    <QueryParameters>",
            '      <QueryParameter Name="InventoryDate">',
            "        <Value>=Parameters!InventoryDate.Value</Value>",
            "      </QueryParameter>",
            "    </QueryParameters>",
        ]) + "\n"

    field_xml = "\n".join(
        "\n".join([
            '<Field Name="%s">' % f,
            "  <rd:TypeName>%s</rd:TypeName>" % t,
            "  <DataField>%s</DataField>" % escape(d),
            "</Field>",
        ]) for f, d, t in fields)

    return "\n".join([
        '<DataSet Name="%s">' % name,
        "  <Query>",
        "    <DataSourceName>%s</DataSourceName>" % source,
        qp + "    <CommandText>%s</CommandText>" % token,
        "  </Query>",
        "  <Fields>",
        ind(field_xml, 4),
        "  </Fields>",
        "</DataSet>",
    ])


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def build():
    body_width = 21.5
    inventory_width = sum(w for *_, w in INVENTORY_COLS)
    escor_inv_width = sum(w for *_, w in ESCOR_INVENTORY_COLS)
    escor_lot_width = sum(w for *_, w in ESCOR_LOT_COLS)

    datasources = "\n".join([
        '<DataSource Name="SSASPROD_BIQLTabular_ISH">',
        "  <rd:SecurityType>Integrated</rd:SecurityType>",
        "  <ConnectionProperties>",
        "    <DataProvider>OLEDB-MD</DataProvider>",
        "    <ConnectString>Data Source=SSASPROD;Initial Catalog=BIQLTabular_ISH</ConnectString>",
        "    <IntegratedSecurity>true</IntegratedSecurity>",
        "  </ConnectionProperties>",
        "  <rd:DataSourceID>14000000-0000-4000-8000-000000000001</rd:DataSourceID>",
        "</DataSource>",
        '<DataSource Name="ODSPROD_ODS">',
        "  <rd:SecurityType>Integrated</rd:SecurityType>",
        "  <ConnectionProperties>",
        "    <DataProvider>SQL</DataProvider>",
        "    <ConnectString>Data Source=ODSPROD;Initial Catalog=ODS</ConnectString>",
        "    <IntegratedSecurity>true</IntegratedSecurity>",
        "  </ConnectionProperties>",
        "  <rd:DataSourceID>14000000-0000-4000-8000-000000000002</rd:DataSourceID>",
        "</DataSource>",
    ])

    datasets = "\n".join([
        dataset("InventoryDates", "SSASPROD_BIQLTabular_ISH", DAX_DATES,
                [("InventoryDate", "[InventoryDate]", "System.DateTime"),
                 ("InventoryDateLabel", "[InventoryDateLabel]", "System.String")],
                parameterized=False),
        dataset("LatestInventoryDate", "SSASPROD_BIQLTabular_ISH", DAX_LATEST_DATE,
                [("InventoryDate", "[InventoryDate]", "System.DateTime")],
                parameterized=False),
        dataset("dsInventory", "SSASPROD_BIQLTabular_ISH", DAX_INVENTORY,
                INVENTORY_FIELDS, parameterized=True),
        dataset("dsEscorInventory", "SSASPROD_BIQLTabular_ISH", DAX_ESCOR_INVENTORY,
                ESCOR_INVENTORY_FIELDS, parameterized=True),
        dataset("dsEscorLot", "ODSPROD_ODS", SQL_ESCOR_LOT,
                ESCOR_LOT_FIELDS, parameterized=False),
        dataset("dsRefresh", "SSASPROD_BIQLTabular_ISH", DAX_REFRESH,
                [("LastRefreshed", "[LastRefreshed]", "System.DateTime")],
                parameterized=False),
    ])

    sections = "\n".join([
        section("SummarySection", "Summary", summary_tablix("0.68in"),
                page_name="Summary", top="0in", height="1.80in", page_break=False,
                context_dataset="dsInventory", body_width=body_width,
                dated=True, stamp_left=8.00),
        section("InventorySection", "Inventory Data",
                list_tablix("InventorySection", INVENTORY_COLS, "dsInventory",
                            "0.68in", inventory_width),
                page_name="Inventory Data", top="1.90in", height="1.30in", page_break=True,
                context_dataset="dsInventory", body_width=body_width,
                dated=True, stamp_left=inventory_width - 4.35),
        section("EscorInventorySection", "Escor Inventory",
                list_tablix("EscorInventorySection", ESCOR_INVENTORY_COLS,
                            "dsEscorInventory", "0.68in", escor_inv_width),
                page_name="Escor Inventory", top="3.30in", height="1.30in", page_break=True,
                context_dataset="dsEscorInventory", body_width=body_width,
                dated=True, stamp_left=escor_inv_width - 4.35),
        section("EscorLotSection", "Escor Lot Details",
                list_tablix("EscorLotSection", ESCOR_LOT_COLS, "dsEscorLot",
                            "0.68in", escor_lot_width),
                page_name="Escor Lot Details", top="4.70in", height="1.30in", page_break=True,
                context_dataset="dsEscorLot", body_width=body_width,
                dated=False, stamp_left=escor_lot_width - 4.35),
    ])

    footer = "\n".join([
        "<PageFooter>",
        "  <Height>0.22in</Height>",
        "  <PrintOnFirstPage>true</PrintOnFirstPage>",
        "  <PrintOnLastPage>true</PrintOnLastPage>",
        "  <ReportItems>",
        ind(floating_textbox("ExecutionTime", "=Globals!ExecutionTime", top="0.02in",
                             left="18.5in", width="2.75in", height="0.2in", zindex=0,
                             size="8pt", color=GREY, align="Right"), 4),
        "  </ReportItems>",
        "  <Style>",
        "    <Border>",
        "      <Style>None</Style>",
        "    </Border>",
        "  </Style>",
        "</PageFooter>",
    ])

    report = "\n".join([
        '<?xml version="1.0" encoding="utf-8"?>',
        '<Report MustUnderstand="df" xmlns="%s" '
        'xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner" '
        'xmlns:df="%s/defaultfontfamily" '
        'xmlns:am="http://schemas.microsoft.com/sqlserver/reporting/authoringmetadata">'
        % (NS, NS),
        "  <rd:ReportUnitType>Inch</rd:ReportUnitType>",
        "  <rd:ReportID>14000000-0000-4000-8000-000000000014</rd:ReportID>",
        "  <df:DefaultFontFamily>Segoe UI</df:DefaultFontFamily>",
        "  <AutoRefresh>0</AutoRefresh>",
        "  <DataSources>",
        ind(datasources, 4),
        "  </DataSources>",
        "  <DataSets>",
        ind(datasets, 4),
        "  </DataSets>",
        "  <ReportSections>",
        "    <ReportSection>",
        "      <Body>",
        "        <ReportItems>",
        ind(sections, 10),
        "        </ReportItems>",
        "        <Height>6.10in</Height>",
        "        <Style>",
        "          <Border>",
        "            <Style>None</Style>",
        "          </Border>",
        "        </Style>",
        "      </Body>",
        "      <Width>%.2fin</Width>" % body_width,
        "      <Page>",
        ind(footer, 8),
        "        <PageWidth>22in</PageWidth>",
        "        <LeftMargin>0.25in</LeftMargin>",
        "        <RightMargin>0.25in</RightMargin>",
        "        <TopMargin>0.25in</TopMargin>",
        "        <BottomMargin>0.25in</BottomMargin>",
        "        <Style />",
        "      </Page>",
        "    </ReportSection>",
        "  </ReportSections>",
        "  <ReportParameters>",
        '    <ReportParameter Name="InventoryDate">',
        "      <DataType>DateTime</DataType>",
        "      <DefaultValue>",
        "        <DataSetReference>",
        "          <DataSetName>LatestInventoryDate</DataSetName>",
        "          <ValueField>InventoryDate</ValueField>",
        "        </DataSetReference>",
        "      </DefaultValue>",
        "      <Prompt>Inventory Date</Prompt>",
        "      <ValidValues>",
        "        <DataSetReference>",
        "          <DataSetName>InventoryDates</DataSetName>",
        "          <ValueField>InventoryDate</ValueField>",
        "          <LabelField>InventoryDateLabel</LabelField>",
        "        </DataSetReference>",
        "      </ValidValues>",
        "    </ReportParameter>",
        "  </ReportParameters>",
        "  <ReportParametersLayout>",
        "    <GridLayoutDefinition>",
        "      <NumberOfColumns>2</NumberOfColumns>",
        "      <NumberOfRows>1</NumberOfRows>",
        "      <CellDefinitions>",
        "        <CellDefinition>",
        "          <ColumnIndex>0</ColumnIndex>",
        "          <RowIndex>0</RowIndex>",
        "          <ParameterName>InventoryDate</ParameterName>",
        "        </CellDefinition>",
        "      </CellDefinitions>",
        "    </GridLayoutDefinition>",
        "  </ReportParametersLayout>",
        "  <ConsumeContainerWhitespace>true</ConsumeContainerWhitespace>",
        "</Report>",
    ])

    for i, command in enumerate(COMMANDS):
        report = report.replace("@@COMMAND%d@@" % i, command)

    OUT.write_text(report, encoding="utf-8-sig")
    print("wrote %s (%d lines)" % (OUT, report.count("\n") + 1))
    print("widths: inventory %.2fin | escor inventory %.2fin | escor lot %.2fin"
          % (inventory_width, escor_inv_width, escor_lot_width))


if __name__ == "__main__":
    build()
