-- Michelman Writeback — reason_dim: add the remaining spreadsheet columns
-- Additive migration. Adds 6 columns preserved from
-- "OTIF and Revision Reason Codes.v2_Final.xlsm" (sheet "Reason Codes 20181017")
-- so no source data is lost, then backfills them from the sheet. Existing
-- otif/active/description/category edits are untouched; long_description is
-- only filled where currently NULL (COALESCE).
--
-- New columns (all nullable / default 0), mapped to the sheet:
--   review_530        INTEGER  col D  'Initial Planner Review at 530'  (X->1)
--   review_540        INTEGER  col E  'Changes at 540 or higher'       (X->1)
--   typical_hit       INTEGER  col G  'Typical Codes Used or OTIF Hits'(X->1)
--   old_classification TEXT    col I  'OLD Classification - Ops/Sourcing'
--   usage_examples    TEXT     col J  'Examples: When to Use'
--   region_note       TEXT     col K  (unlabeled region note; e.g. 'India')
-- Idempotent-ish: the ALTERs are guarded by run-once (SQLite has no ADD COLUMN
-- IF NOT EXISTS; re-running errors on the ALTERs only — the UPDATEs are safe).

ALTER TABLE reason_dim ADD COLUMN review_530 INTEGER NOT NULL DEFAULT 0;
ALTER TABLE reason_dim ADD COLUMN review_540 INTEGER NOT NULL DEFAULT 0;
ALTER TABLE reason_dim ADD COLUMN typical_hit INTEGER NOT NULL DEFAULT 0;
ALTER TABLE reason_dim ADD COLUMN old_classification TEXT;
ALTER TABLE reason_dim ADD COLUMN usage_examples TEXT;
ALTER TABLE reason_dim ADD COLUMN region_note TEXT;

CREATE INDEX IF NOT EXISTS idx_reason_dim_review ON reason_dim(review_530, review_540);

UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A1';
UPDATE reason_dim SET review_530=1, review_540=0, typical_hit=0, old_classification='CSR', usage_examples=NULL, region_note='India', long_description=COALESCE(long_description, NULL) WHERE code='A2';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A3';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note='India', long_description=COALESCE(long_description, NULL) WHERE code='A31';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A32';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A33';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A34';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A35';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A36';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A4';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=0, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, NULL) WHERE code='A5';
UPDATE reason_dim SET review_530=1, review_540=0, typical_hit=1, old_classification='Planning', usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, 'Changes to sales order Promised Ship, Scheduled Pick and Promised Delivery, but the item is still within the standard lead time of the product') WHERE code='A6';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='CSR', usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, 'Changes to sales orders at placement or offer not affecting customer shipping dates.') WHERE code='C0';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification=NULL, usage_examples=NULL, region_note='India', long_description=COALESCE(long_description, 'Account on hold due to payment issues.') WHERE code='C1';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='CSR', usage_examples=NULL, region_note='India', long_description=COALESCE(long_description, 'Consolidates Customer Requests Early, Customer Change for Production, Customer Requests Later') WHERE code='C2';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, 'Change due to product being shipped for different B/P than where the order was placed.') WHERE code='C3';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='CSR', usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, 'Only applies to sales orders with multiple line items.  Majority of order ready, shipment delayed at customer request for balance of material.  The lines that are ready get assigned a groupage code, while the one(s) that are driving the delay get a different reason code') WHERE code='C4';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='CSR', usage_examples='Delay in sales order fulfillment, due incorrect  SO coding in JDE  by CSR.
i.e:  CSR enters order less than lead-time
i.e: Order blocks (hold codes) were not removed in timely manner to enable hitting quoted lead time
i.e: Schedule pick date modified at 535 by CSR ; wrong date input', region_note=NULL, long_description=COALESCE(long_description, 'Status code changes or date code errors') WHERE code='C5';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Delay in sales sales order fulfillment due to any internal communication gap which affected the process  (not necessary limited to planning).', region_note=NULL, long_description=COALESCE(long_description, 'Poor communication between planning, shipping and/or planning contributing to the order not shipped when expected.') WHERE code='C6';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, 'Date changed due to delivery of customer supplied raw materials') WHERE code='C7';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification='R&D', usage_examples='Delay in sales order fuflillment due to a FMB Product formula transferred late from LAB* to Branch PLant to allow proper raw material sourcing, unit schedule and planning activities.
This includes any  components switch that extend LT of raw material in formula', region_note=NULL, long_description=COALESCE(long_description, 'Formula released too late from FMB to make standard lead time.  Issues arising from moving from FMB to Production.') WHERE code='F1';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Planning', usage_examples='Delay in sales order fuflillment due to  incorrect lead time, planning parameters and wrong setup in JDE 2nd item number  which affected the correct execution of the MRP routines', region_note=NULL, long_description=COALESCE(long_description, 'Item set up not correct and did not reflect demand in MRP system properly.') WHERE code='L1';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification='Planning', usage_examples='Delay in sales order fulfillment due to missing RM as results of planner  follow MRP messages to prompt for a RM order', region_note=NULL, long_description=COALESCE(long_description, 'Request not sent to purchasing to order material.') WHERE code='L2';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification='Sales', usage_examples='Delay in sales order fulfillment due to  unforeseen or higher than expected demand. 
I.e.: item not ordered because not FCSTed, or components ordered not enought to fulfill entire demand', region_note=NULL, long_description=COALESCE(long_description, 'RM not orderd due to incorrect FCST.  FCST were underestimated or not existing for FG item.') WHERE code='LFC';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification='Inbound', usage_examples='Delay in sales order fulfillment due to any delay on supplier inbound on RM which extended beyond the standard lead time
Wrong item or quantity sent by supplier
i.e. (supplier plant problem, supplier not capable to cope with demand, FM at supplier, delayed due to geopolitical issue, etc)', region_note=NULL, long_description=COALESCE(long_description, 'Delivery delayed on raw material from supplier or not enough raw material on hand not related to L1 or L2, L2FCST') WHERE code='L3';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification='Inbound', usage_examples='Delay in sales order fulfillment due to any delay on intercompany inbound of RM, FG or intermediates  which extended beyond the standard lead time
Wrong item or quantity sent by intercompany supplier', region_note=NULL, long_description=COALESCE(long_description, 'Delivery delayed  due to a late arrival of  product from Intercompany') WHERE code='LIC';
UPDATE reason_dim SET review_530=1, review_540=1, typical_hit=1, old_classification='Inbound', usage_examples='Delay in sales order fulfillment due to any delay on  CM inbound of FG which extended beyond the standard lead time
Wrong item or quantity sent by Contract Manufacturer', region_note=NULL, long_description=COALESCE(long_description, 'Delivery delayed  due to a late arrival of a Contract Manufactured Item') WHERE code='LCM';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Product location incorrect in JDE causing delay in shipping personnel locating material.', region_note=NULL, long_description=COALESCE(long_description, 'Product didn''t ship or had issues resulting in a delay to the customer.') WHERE code='L4';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Inbound', usage_examples='inbound of RM from external supplier unable to be delivered due to acts of Gods', region_note=NULL, long_description=COALESCE(long_description, 'R/M''s unable to be delivered due to weather/storms,supplier plants being shut down or roads inaccessible.  Limited to significant natural disaster events.') WHERE code='L5';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Any delay associated to Off Spec production which require adminstration (i.e. waiver, QC check, customer acceptance, etc) to allow to ship the non prime  material.', region_note=NULL, long_description=COALESCE(long_description, 'Customer approves receiving material from Michelman that is out-of-spec') WHERE code='LQW';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Any delay associated to equipment failure/maintence downtimes (brakdown or planned)  causing delay in order fulfillment.
i.e:reactor sealing, breakdown of auxilliaries sytems as feeding lines, tablets, etc)', region_note=NULL, long_description=COALESCE(long_description, 'Equipment not running due to mechanical issues.  Equipment breakdown resulting in missing a ship date.') WHERE code='P3';
UPDATE reason_dim SET review_530=1, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Any delay associated to plant capacity not enought to cover high/surge deamand, as result order was delayed
All work centers & resources  should be available (no dowtimes), otherwise use P3 or P5', region_note=NULL, long_description=COALESCE(long_description, 'Product not manufactured due to lack of equipment availability.  Only to be used on the initial review of the sales order.  Use P3, P5 or PD1 primarily.') WHERE code='P4';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Any delay associated to workforce shortage due to sick leaves/absenteism or wrong resource scheduling (vacation leave or work underestimations)', region_note=NULL, long_description=COALESCE(long_description, 'Manpower shortages/call offs.  Only used when unexpected call-off happens and order would be ready if that individual showed up to work.  Otherwise, it should go to PD1.') WHERE code='P5';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Operations', usage_examples='Any delay associated to JDE not reflecting the correct inventory quantityies on FG or RM 

If JDE shows RM but physcally not available, late order will be flagged with P6 (not L3)
Incorrect inventory on intermediate which forced to reschedule new batch or to produce a short batch', region_note=NULL, long_description=COALESCE(long_description, 'Incorrrect inventory in JDE') WHERE code='P6';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Operations', usage_examples='Delay on intermediate production has ultimately delayed FG production batch', region_note=NULL, long_description=COALESCE(long_description, 'Intermediate not available, causes production to change a ship date.  Only to be used if forecasted volume has been reasonable.  If forecast has been significantly higher than normal, classify as L3. L2FCST') WHERE code='P7';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='This OTIF code is not to be used anymore', region_note='India', long_description=COALESCE(long_description, 'DO NOT USE First commit from production is outside of standard leadtime') WHERE code='P8';
UPDATE reason_dim SET review_530=1, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='Orders are dealyed due to usage of the R&D asset to fulill commercial production (normally multiple runs are required)
the target is to hilight that a smaller batch unit may be needed in the plant', region_note=NULL, long_description=COALESCE(long_description, 'Order can not be met due to Pilot Plant Capacity issues (commercial product)') WHERE code='P9';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Operations', usage_examples='1st Prodction Dalay.
It may be due to assets taking longer to produce previous batches (i.e. hold tank availability, packing line availability,..)', region_note=NULL, long_description=COALESCE(long_description, 'First Schedule pick date change due to production issues.') WHERE code='PD1';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='2nd Prodction Dalay.
It may be due to assets taking longer to produce previous batches (i.e. hold tank availability, packing line availability,..)', region_note=NULL, long_description=COALESCE(long_description, 'Schedule pick date changed a second time due to production issues.') WHERE code='PD2';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Operations', usage_examples='3rd Prodction Dalay.
It may be due to assets taking longer to produce previous batches (i.e. hold tank availability, packing line availability,..)', region_note=NULL, long_description=COALESCE(long_description, 'Schedule pick date changed more than two times due to production issues.') WHERE code='PD3';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Quality', usage_examples='Delay generated by non prime (out of specs) production
Normally delay is due to reworking activities or second prodction runs', region_note=NULL, long_description=COALESCE(long_description, 'Quality issue with production batch.') WHERE code='Q1';
UPDATE reason_dim SET review_530=0, review_540=0, typical_hit=1, old_classification='Inbound', usage_examples='Delay associated to non confirming material received from supplier
This applies to non prime production  executed using non conforming material (i.e Fusabond case in 2024)', region_note=NULL, long_description=COALESCE(long_description, 'Non-conforming material received from supplier.') WHERE code='Q2';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Operations', usage_examples='Order partially fulfilled due to  shorter the expected batch (yields), material loss dueing packing
i.e: Batch yielded only 52 drums, need to adjust order (all RMs were in position to', region_note=NULL, long_description=COALESCE(long_description, 'For items that are not classified as sell-alls or bulk tanker shipments, shipping less than the customer requested.') WHERE code='SS';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=0, old_classification=NULL, usage_examples='T0 should be used when a departure delay—linked to transport organized by Michelman—does not affect the confirmed customer arrival date. Any Promised Ship Date postponement categorized under T0 will not result in an OTIF miss.

Examples incude:
- Sea transfer shipments – Vessel availability: Promised Ship Date is postponed up to 7 days compared to the original reference date used on the order confirmation due to vessel schedule, but the customer arrival date remains unaffected
- Sea transfer - Vessel delay: Promised Ship Date is postponed (up to 7 days) due to vessel delay, with no impact on the customer arrival date
- Groupage/LTL: Promised Ship Date shifts slightly from the original reference date, but customer arrival timing is maintained', region_note=NULL, long_description=COALESCE(long_description, 'Departure Delay – No Impact on Arrival
Delay at departure caused by a Michelman-routed carrier (e.g., no-show or rescheduled pickup) which does not affect the confirmed customer arrival date.') WHERE code='T0';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Logistics', usage_examples='delay due to outbound logistics', region_note=NULL, long_description=COALESCE(long_description, 'Michelman routed carrier did not show up or made change to pick up time. Arrival date at customer is affected') WHERE code='T1';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification=NULL, usage_examples=NULL, region_note=NULL, long_description=COALESCE(long_description, 'Delay caused by customer carrier issues.') WHERE code='T2';
UPDATE reason_dim SET review_530=0, review_540=1, typical_hit=1, old_classification='Logistics', usage_examples='delay due to outbound logistics due to acts of God', region_note=NULL, long_description=COALESCE(long_description, 'Michelman routed carrier did not show because of weather.  Used primarily during winter shipping as a result of snow or ice storms') WHERE code='T3';
UPDATE reason_dim SET review_530=1, review_540=0, typical_hit=1, old_classification='Logistics', usage_examples='delay due to tanker line scheduling', region_note=NULL, long_description=COALESCE(long_description, 'Unable to accomadate customer demand due to the Tanker line be full and reasonable accomodations made to reallocate manpower.') WHERE code='T4';
