#### Overview

* Zack (LeanGo consultant) is leading dashboard development for two reports: **Customer Complaints %** and **Production Batch Quality** — both currently manually populated **twice a month**

* Salesforce case data is already in ODS and the SSAS model; the key metric is complaint % = (orders − complaint cases) ÷ orders, with the order count coming from JDE

* Zack needs a follow-up session with Jessica and Greg to validate JDE order count logic (which date field, exclusions for cancelled/intercompany orders, company filtering for Americas/Asia/Europe)

* Several access gaps identified: Zack can't see ODS Salesforce or ODS ETL tables, and isn't on the Power BI Teams channel — Dave is fixing both today

* Rohit will schedule a session with Greg; after that, Zack and Dave will set up a recurring weekly Wednesday working session

#### Project setup and Zack's role

* Zack is taking the lead on report development, with Jessica guiding on data requirements and Dave handling any EDW/ODS changes

* Zack has read-only access to ODS and EDW — any development changes (new views, joins, measures) go through Dave and Rohit via a technical spec document

* Rohit's preference is to keep Dave's involvement organized around Wednesday working sessions rather than ad hoc, since Dave is across multiple projects

* The SSAS model was a pre-built package, so keys aren't always reliable — Zack needs to validate joins and check for data integrity gaps rather than assuming they're clean

#### Salesforce data requirements

* The two reports need Salesforce **Case** table data filtered to **Case Record Type = Customer Complaint**, grouped by **Date of Occurrence** (month), and counted by unique case number

* Location field has **4** values — Kemper and Shell (US), Aubange (Europe), Singapore (Asia) — used as the slicer for Americas/Asia/Europe views

* Within complaints, Level 1 breaks cases into **Product Quality** vs. **Product Delivery** for drill-down; users also want to drill to case number, product code, and champion name

* Jessica confirmed all Salesforce data is already in the Power BI model and is the source of truth for the complaint count

#### ODS → EDW → SSAS stack walkthrough

* Data flows: Salesforce API → ODS (dbo.Case in ODS\_Salesforce DB) → EDW views (e.g. TBSF\_Case) → SSAS tabular model → Power BI

* The Case table in SSAS is mostly a dimension table with a straight pull — minimal DAX, just a distinct count of CaseNumber as the only measure

* Dave suggested connecting to ODS dev, EDW dev, and SSAS dev in that order in Management Studio so the sequence mirrors the data flow

* Import mode isn't available by design — Zack needs to validate by running queries in ODS/EDW or exporting filtered slices to Excel

#### JDE order count and complaint % calc

* The denominator for complaint % is order count from JDE, filtered by actual ship date to match the calendar month — Jessica believes it's a straight calendar date match, not a more complex date logic, but this needs confirming with Greg

* Filtering needs to account for cancelled orders, intercompany orders, and company codes **10/20/30** to split Americas/Asia/Europe — Greg is the right person to confirm the exact logic

* Dave has a partial start on this in dev (not validated by Jessica), and will send Zack what he has along with the batch quality PBIX file

* Rohit flagged that JDE sales data in ODS/EDW is mature for other reports but hasn't been built out specifically for this dashboard requirement, so Zack should expect to validate joins and possibly request new views

#### Zack's system access gaps

* Zack can't expand ODS Salesforce or ODS ETL tables in Management Studio — Dave traced it to permissions being copied from another contractor's profile and will fix it today

* Zack isn't a member of the Power BI Teams channel, which is where the shared OneDrive folder with existing PBIX files lives — Dave will add him today

* Zack currently only has the SSAS prod connection string; Dave will include ODS dev and EDW dev connection details in today's email

#### File sharing and next sessions

* Dave will email Zack today: the batch quality PBIX, the partial complaints PBIX, the JDE table reference (ERPRef.com link), and connection strings for ODS dev and EDW dev

* Rohit will create a dedicated Teams channel for this project and send Zack the link so there's a single place for all files

* Rohit will schedule a session with Jessica and Greg to walk through JDE order count logic; after that, Zack will set up a recurring weekly Wednesday session with Dave (Rohit and Jessica optional)
