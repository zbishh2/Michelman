-- Michelman Writeback — Reason Code dimension SEED (48 codes)
-- Generated from "OTIF and Revision Reason Codes.v2_Final.xlsm":
--   * code / description / otif flag (col F "X") / category (col H "Classif
--     Review Dec 2024") from sheet "Reason Codes 20181017" (the authoritative
--     dimension + OTIF flag).
--   * long_description enriched from sheet "OTIF Hits" for the 28 OTIF-hit codes
--     (stale sheet spellings reverse-mapped: L2 FCST->LFC, L3INT->LIC, L3CM->LCM;
--     descriptions verified identical).
-- otif=1 on exactly the 28 codes flagged "X" today, so OTIF is unchanged on the
-- first refresh after the cutover. active=0 for the single "do not use" code (A3).
-- exemption_criteria is left NULL (no per-row data in the sheet) — editable later.
--
-- Idempotent: ON CONFLICT refreshes description/long/category/sort but PRESERVES
-- any later edits to `otif` and `active` (the fields users maintain in the visual).
INSERT INTO reason_dim (code, description, long_description, exemption_criteria, otif, category, active, sort_order)
VALUES
  ('A1', 'Assigning Lot Number', NULL, NULL, 0, NULL, 1, 10),
  ('A2', 'Schedule pick date change', NULL, NULL, 0, NULL, 1, 20),
  ('A3', 'do not use', NULL, NULL, 0, NULL, 0, 30),
  ('A31', 'CSR - no impact', NULL, NULL, 0, NULL, 1, 40),
  ('A32', 'FMB - no impact', NULL, NULL, 0, NULL, 1, 50),
  ('A33', 'RM issue - no impact', NULL, NULL, 0, NULL, 1, 60),
  ('A34', 'Equipment Issues - no impact', NULL, NULL, 0, NULL, 1, 70),
  ('A35', 'Capacity Issues - no impact', NULL, NULL, 0, NULL, 1, 80),
  ('A36', 'Labor Issues / RH - no impact', NULL, NULL, 0, NULL, 1, 90),
  ('A4', 'Logistic review', NULL, NULL, 0, NULL, 1, 100),
  ('A5', 'Int''l. Doc. Conv. Cor.', NULL, NULL, 0, NULL, 1, 110),
  ('A6', 'Scheduler Assign Dates', NULL, NULL, 0, NULL, 1, 120),
  ('C0', 'No effect / Pas effet client', NULL, NULL, 0, NULL, 1, 130),
  ('C1', 'Credit Hold / Paiement', NULL, NULL, 0, NULL, 1, 140),
  ('C2', 'Cust Req / Demande client', NULL, NULL, 0, NULL, 1, 150),
  ('C3', 'Branch Plant Change', NULL, NULL, 0, NULL, 1, 160),
  ('C4', 'Groupage', NULL, NULL, 0, NULL, 1, 170),
  ('C5', 'Order Entry Error / CSR', 'Status code changes or date code errors', NULL, 1, 'Sales', 1, 180),
  ('C6', 'Communication', 'Poor communication between planning, shipping and/or planning contributing to the order not shipped when expected.', NULL, 1, 'SC', 1, 190),
  ('C7', 'Customer Supplied Raw Mat.', NULL, NULL, 0, NULL, 1, 200),
  ('F1', 'FMB / Scale Up Issues', 'Formula released too late from FMB to make standard lead time.  Issues arising from moving from FMB to Production.', NULL, 1, 'R&D', 1, 210),
  ('L1', 'Incorrect Item Set Up in JDE', 'Item set up not correct and did not reflect demand in MRP system properly.', NULL, 1, 'SC', 1, 220),
  ('L2', 'Raw Material not ordered / RM', 'Request not sent to purchasing to order material.', NULL, 1, 'SC', 1, 230),
  ('LFC', 'RM not orderd due to incorrect FCST', 'RM not orderd due to incorrect FCST.  FCST were underestimated or not existing for item.', NULL, 1, 'Sales', 1, 240),
  ('L3', 'RM Delivery Issue / qt RM', 'Delivery delayed on raw material from supplier or not enough raw material on hand not related to L1 or L2.', NULL, 1, 'Procurement', 1, 250),
  ('LIC', 'Intercompany', 'Inbound shipments into region from another Michelman company in another region.', NULL, 1, 'Procurement', 1, 260),
  ('LCM', 'CM', 'Contract Manufactured Item', NULL, 1, 'Procurement', 1, 270),
  ('L4', 'Shipping Error', 'Product didn''t ship or had issues resulting in a delay to the customer.', NULL, 1, 'SC', 1, 280),
  ('L5', 'Weather/Storm Related Delays', 'R/M''s unable to be delivered due to weather/storms,supplier plants being shut down or roads inaccessible.  Limited to significant natural disaster events.', NULL, 1, 'Procurement', 1, 290),
  ('LQW', 'Lower Quality Sales', 'Customer approves receiving material from Michelman that is out-of-spec', NULL, 1, 'Operations', 1, 300),
  ('P3', 'Equipment Issues', 'Equipment not running due to mechanical issues.  Equipment breakdown resulting in missing a ship date.', NULL, 1, 'Operations', 1, 310),
  ('P4', 'Capacity Issues / capacite', 'Product not manufactured due to lack of equipment availability.  Only to be used on the initial review of the sales order.  Use P3, P5 or PD1 primarily.', NULL, 1, 'SC', 1, 320),
  ('P5', 'Labor Issues / RH', 'Manpower shortages/call offs.  Only used when unexpected call-off happens and order would be ready if that individual showed up to work.  Otherwise, it should go to PD1.', NULL, 1, 'Operations', 1, 330),
  ('P6', 'SS Shortage / Inv Issues', 'Incorrrect inventory in JDE', NULL, 1, 'SC', 1, 340),
  ('P7', 'Intermediate Delay', 'Intermediate not available, causes production to change a ship date.  Only to be used if forecasted volume has been reasonable.  If forecast has been significantly higher than normal, classify as L3.', NULL, 1, 'Operations', 1, 350),
  ('P8', 'Lead Time Delay', 'First commit from production is outside of standard leadtime', NULL, 1, 'Operations (??)', 1, 360),
  ('P9', 'Pilot Plant Lead Time Delay', 'Order can not be met due to Pilot Plant Capacity issues', NULL, 1, 'SC', 1, 370),
  ('PD1', '1st Prod Delay / delai prod', 'First Schedule pick date change due to production issues.', NULL, 1, 'Operations', 1, 380),
  ('PD2', '2nd Prod Delay / delai prod', 'Schedule pick date changed a second time due to production issues.', NULL, 1, 'Operations', 1, 390),
  ('PD3', 'Multiple Production Delays', 'Schedule pick date changed more than two times due to production issues.', NULL, 1, 'Operations', 1, 400),
  ('Q1', 'Non Conf Batch / Non FTRB', 'Quality issue with production batch.', NULL, 1, 'Operations', 1, 410),
  ('Q2', 'RM Qual Issue / qualite RM', 'Non-conforming material received from supplier.', NULL, 1, 'Procurement', 1, 420),
  ('SS', 'Ship Short', 'For items that are not classified as sell-alls or bulk tanker shipments, shipping less than the customer requested.', NULL, 1, 'Operations', 1, 430),
  ('T0', 'MM Carrier Issues / logistique (No OTIF)', NULL, NULL, 0, NULL, 1, 440),
  ('T1', 'MM Carrier Issues / logistique', 'Michelman routed carrier did not show up or made change to pick up time.', NULL, 1, 'SC', 1, 450),
  ('T2', 'Cust Carrier issues / EXW', NULL, NULL, 0, NULL, 1, 460),
  ('T3', 'MM Carrier Weather Delay', 'Michelman routed carrier did not show because of weather.  Used primarily during winter shipping as a result of snow or ice storms', NULL, 1, 'SC', 1, 470),
  ('T4', 'Tanker Line Full', 'Unable to accomadate customer demand due to the Tanker line be full and reasonable accomodations made to reallocate manpower.', NULL, 1, 'SC', 1, 480)
ON CONFLICT(code) DO UPDATE SET
  description      = excluded.description,
  long_description = excluded.long_description,
  category         = excluded.category,
  sort_order       = excluded.sort_order,
  updated_at       = datetime('now');
