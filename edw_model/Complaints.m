// Complaints — one row per Salesforce case, all record types.
// Source: ODSDEV ODS_SalesForce.dbo.Case — the raw SF object mirror (live chain; EDWPROD's SF
// feed is frozen at 2024-08 and is deep-history only). Single-server: the RecordType, Account,
// Product2 and User lookups all join on ODSDEV, so the whole query folds to one SQL statement.
//
// CONNECTION: navigation pattern (Sql.Databases -> drill), not a native query, so it folds and
// binds to the on-prem gateway. ODSDEV must be registered on the gateway (UPN ZackB@michem.com).
//
// Columns worth knowing:
//   Record_Type     = RecordType.Name via RecordTypeId. All 13 ids in use resolve; the RTFT
//                     numerator's record type is "Batch Mfg Issue" (id 012f4000000DyF9AAK).
//   Days_Case_Open  = SF's days_Case_Open__c: calendar days CreatedDate -> ClosedDate, frozen at
//                     close, counting to today while open. NULL on the ~5.9k closed cases that
//                     carry no ClosedDate — correct for averaging, they simply drop out.
//                     Do NOT derive this from ClosedDate locally: null ClosedDate does not mean
//                     open (IsClosed disagrees on ~23% of cases), so a derived count-to-today
//                     poisons the average.
//   Customer        = Account.Name via AccountId (the raw Case has no readable account name).
//   Customer_Code   = Ship_To_Customer_Code__c (matches what BIQL exposed as Customer_Code__c).
//   Product_ID      = Product_Code__c, an 18-char Product2 Id -> Product_Name / Product_Code.
//   Champion_ID     = Champion__c, an 18-char User Id -> Champion_Name.
//   Date_of_Occurrence: the raw SF field name is misspelled ("Occurance").
let
    Source = Sql.Databases("ODSDEV"),
    ODS_SF = Source{[Name = "ODS_SalesForce"]}[Data],
    SF_Case = ODS_SF{[Schema = "dbo", Item = "Case"]}[Data],
    Kept = Table.SelectColumns(
        SF_Case,
        {
            "CaseNumber", "Date_of_Occurance__c", "CreatedDate",
            "Level_1__c", "Level_2__c", "Region__c", "Location__c",
            "Complaint_Valid__c", "RecordTypeId", "AccountId",
            "Product_Code__c", "Champion__c",
            "Status", "Subject", "Description",
            "Responsible_Department__c",
            "Root_Cause_Detail_1__c", "Root_Cause_Detail_2__c",
            "Root_Cause_Description__c", "Preventive_Action__c",
            "Lot_Number__c",
            "Ship_To_Customer_Code__c",
            "Account_Segmentation__c",
            "Quantity_Impacted__c", "Quantity_Delivered__c",
            "UOM__c",
            "days_Case_Open__c"
        }
    ),
    Renamed = Table.RenameColumns(
        Kept,
        {
            {"Date_of_Occurance__c", "Date_of_Occurrence"},
            {"Level_1__c", "Level_1"},
            {"Level_2__c", "Level_2"},
            {"Region__c", "Region"},
            {"Location__c", "Location"},
            {"Complaint_Valid__c", "Complaint_Valid"},
            {"Product_Code__c", "Product_ID"},
            {"Champion__c", "Champion_ID"},
            {"Status", "Case_Status"},
            {"Responsible_Department__c", "Responsible_Department"},
            {"Root_Cause_Detail_1__c", "Root_Cause_Detail_1"},
            {"Root_Cause_Detail_2__c", "Root_Cause_Detail_2"},
            {"Root_Cause_Description__c", "Root_Cause_Description"},
            {"Preventive_Action__c", "Preventive_Action"},
            {"Lot_Number__c", "Lot_Number"},
            {"Ship_To_Customer_Code__c", "Customer_Code"},
            {"Account_Segmentation__c", "Customer_Segmentation"},
            {"Quantity_Impacted__c", "Quantity_Impacted"},
            {"Quantity_Delivered__c", "Quantity_Delivered"},
            {"UOM__c", "UOM"},
            {"days_Case_Open__c", "Days_Case_Open"}
        }
    ),
    Typed = Table.TransformColumnTypes(
        Renamed,
        {
            {"Date_of_Occurrence", type date},
            {"CreatedDate", type datetime},
            {"Days_Case_Open", Int64.Type}
        },
        "en-US"
    ),
    RecordTypeDim = Table.SelectColumns(
        ODS_SF{[Schema = "dbo", Item = "RecordType"]}[Data], {"Id", "Name"}),
    AccountDim = Table.SelectColumns(
        ODS_SF{[Schema = "dbo", Item = "Account"]}[Data], {"Id", "Name"}),
    Product2Dim = Table.SelectColumns(
        ODS_SF{[Schema = "dbo", Item = "Product2"]}[Data], {"Id", "Name", "ProductCode"}),
    UserDim = Table.SelectColumns(
        ODS_SF{[Schema = "dbo", Item = "User"]}[Data], {"Id", "Name"}),
    JoinRecordType = Table.NestedJoin(
        Typed, {"RecordTypeId"}, RecordTypeDim, {"Id"}, "RTJoin", JoinKind.LeftOuter),
    AddRecordType = Table.ExpandTableColumn(JoinRecordType, "RTJoin", {"Name"}, {"Record_Type"}),
    JoinAccount = Table.NestedJoin(
        AddRecordType, {"AccountId"}, AccountDim, {"Id"}, "AcctJoin", JoinKind.LeftOuter),
    AddCustomer = Table.ExpandTableColumn(JoinAccount, "AcctJoin", {"Name"}, {"Customer"}),
    JoinProduct = Table.NestedJoin(
        AddCustomer, {"Product_ID"}, Product2Dim, {"Id"}, "Product2Join", JoinKind.LeftOuter),
    AddProduct = Table.ExpandTableColumn(
        JoinProduct, "Product2Join", {"Name", "ProductCode"}, {"Product_Name", "Product_Code"}),
    JoinChampion = Table.NestedJoin(
        AddProduct, {"Champion_ID"}, UserDim, {"Id"}, "UserJoin", JoinKind.LeftOuter),
    AddChampion = Table.ExpandTableColumn(JoinChampion, "UserJoin", {"Name"}, {"Champion_Name"}),
    RemovedIds = Table.RemoveColumns(AddChampion, {"AccountId"})
in
    RemovedIds
