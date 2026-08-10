<report xmlns="http://developer.cognos.com/schemas/report/12.0/" useStyleVersion="10" expressionLocale="en-us">
	<modelPath>/content/package[@name='JDE Live Data']/model[@name='model']</modelPath>
	<drillBehavior/>
	<queries>
		<query name="Item Information">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Branch Plant])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Tag].[Bulk Item])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[2nd Item Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Master Planning Family" aggregate="none" rollupAggregate="none" label="MPF"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Master Planning Family])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Stock Type" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Stock Type])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Branch Plant] in ('SING', 'SNG4', 'MUM3', 'SHAN', 'AUBA', 'AUB2')</filterExpression></detailFilter><detailFilter><filterExpression>[Stock Type] not in ('I', 'O')</filterExpression></detailFilter></detailFilters></query><query name="Inventory">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Branch Plant])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Tag].[Bulk Item])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[2nd Item Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Location" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Location])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Lot Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Lot Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity On Hand" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Quantity On Hand]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Primary UOM" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Master].[Primary UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Hard Commit" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Hard Commit]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Master Planning Family" aggregate="none" rollupAggregate="none" label="MPF"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Master Planning Family])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="REGION" label="Site"><expression>Decode([Branch Plant],'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'India', 'SHAN', 'China', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'ERROR')</expression></dataItem><dataItem name="NOW" label="Date"><expression>to_date({sysdate})</expression></dataItem><dataItem name="OH KG"><expression>If ([Primary UOM] = 'KG') Then
([Quantity On Hand])
Else
If ([Primary UOM] = 'LB') Then
([Quantity On Hand]*0.453593)
Else
If ([Primary UOM] = 'EA') Then
([Quantity On Hand]*20)
Else
(100000)</expression></dataItem><dataItem name="OH LB"><expression>If ([Primary UOM] = 'LB') Then
([Quantity On Hand])
Else
If ([Primary UOM] = 'KG') Then
([Quantity On Hand]/0.453593)
Else
If ([Primary UOM] = 'EA') Then
([Quantity On Hand]*44)
Else
(100000)</expression></dataItem><dataItem name="Stock Type" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Stock Type]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Branch Plant] in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC' , 'CIN2', 'CIN4')</filterExpression></detailFilter><detailFilter><filterExpression>[Quantity On Hand]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Bulk Item] in (
'PR3460',
'PR3460.E',
'PR5980I',
'PR5980I.E',
'PR5980I.S',
'PR5985',
'PR5985.E',
'PR5985.S',
'DPI8600.E',
'PH00007E.E',
'201250PX.E',
'DPI8200.E',
'MF4915.E',
'MFHS1130.E',
'MFP1857.E',
'MP3000.E',
'MP48525R.E',
'MP4932.E',
'MP498340R.E',
'PH00017E.E',
'MFP1853R.E',
'MP498345P.E',
'MP4983RHSA.E',
'201081CX',
'241083PX.S',
'241088PX.S',
'241089PX.S',
'241199PX.S',
'241252PX.S',
'251095NX.S',
'251142PX.S',
'251144PX.S',
'251194NX.S',
'251268PX.S',
'MF1204.S',
'MF1306D.S',
'MF1406.S',
'MFHS1881.S',
'MFP1853R.S',
'MFP1883.S',
'MP4982SC.S',
'MP498340R.S',
'MP498345N.S',
'MP4983R.S',
'MP4983RHS.S',
'PH00017E.S',
'PI8545.S',
'241253PX.S',
'241168PX',
'241201FX',
'DP040',
'DPI8600',
'HSCF280',
'ILP040',
'KHI205',
'KHI340',
'MED310',
'MED800',
'MFHS168',
'MFHS268',
'MFP1853R',
'MP04422R',
'MP3000',
'MP48525R',
'MP498340D',
'MP498340R',
'MP498345N',
'MP4983RHS',
'MT242AF',
'PA845H',
'PH00015E',
'PH00017E',
'UBD211',
'UBD268',
'UTS610',
'251379PX.E',
'MFP1883.E',
'MP4983RAM.E',
'PH00001A.E',
'251095NX.E',
'251194NX.E',
'MD7900.E',
'MP4983R.E',
'251246NX.E',
'251095NX',
'251194NX',
'261044NX',
'261074NX',
'605000007',
'MFP1883',
'MP4983R',
'MP4983RN',
'RM108',
'UPR420',
'221247PX.E',
'MP2960.E',
'221247PX',
'231093FX',
'MP2960'
)
</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[Bulk Item] in ('JS168.S' ,
'ME91735.S' ,
'PP05S.S' ,
'ME91240G.S' ,
'TSPP01.S' ,
'ME91735.S' ,
'ME87235.S' ,
'ME91735.S' ,
'211018IX.S' ,
'PP236A.S' ,
'NYS2104.S' ,
'PP236A.S' ,
'ME91240G.S' ,
'JS168.E' ,
'PP236A.S' ,
'ME91240G.S' ,
'ME91735.S' ,
'ME91735.S' ,
'ME91735.S' ,
'BRIJS2.S' ,
'BRIJS20.S', 'JS168.E', 'BRIJS2.E', 'BRIJS20.E', 'ME91735.E')</filterExpression></detailFilter></detailFilters></query><query name="Work Orders">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="WO Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[WO Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="WO Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[WO Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Order Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Order Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Start Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Start Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Requested Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Requested Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Completed Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Completed Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity Requested" aggregate="total"><expression>average([Work Order Star Schema - JDE].[JDE Work Order].[Quantity Requested])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity Completed" aggregate="total"><expression>average([Work Order Star Schema - JDE].[JDE Work Order].[Quantity Completed])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Unit of Measure" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Unit of Measure]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Component 2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Component 2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Component UOM" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Component UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Issued Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Issued Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Ordered Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Ordered Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="REQUEST KG"><expression>If ([Unit of Measure]='LB') Then
([Quantity Requested]*0.453593)
Else
([Quantity Requested])</expression></dataItem><dataItem name="COMPLETE KG"><expression>If ([Unit of Measure]='LB') Then
([Quantity Completed]*0.453593)
Else
([Quantity Completed])</expression></dataItem><dataItem name="P7 ISSUED KG"><expression>If ([Component UOM]='LB') Then
([Issued Quantity]*0.453593)
Else
([Issued Quantity])</expression></dataItem><dataItem name="P7 ORDERED KG"><expression>If ([Component UOM]='LB') Then
([Ordered Quantity]*0.453593)
Else
([Ordered Quantity])</expression></dataItem><dataItem name="STATE"><expression>If ([Quantity Completed]=0 and [WO Status] in ('20', '30', '90') and [P7 ISSUED KG]=0) Then
('OPEN')
Else
('COMPLETE')</expression></dataItem><dataItem name="REGION"><expression>Decode([Branch Plant],'SING', 'Singapore', 'CINC', 'Americas', 'AUBA', 'Aubange', 'CIN2', 'Americas', 'ERROR')</expression></dataItem><dataItem name="P7 ISSUED LB"><expression>If ([Component UOM]='KG') Then
([Issued Quantity]/0.453593)
Else
([Issued Quantity])</expression></dataItem><dataItem name="P7 ORDERED LB"><expression>If ([Component UOM]='KG') Then
([Ordered Quantity]/0.453593)
Else
([Ordered Quantity])</expression></dataItem><dataItem name="P7 REMAINING"><expression>[P7 ORDERED LB]-[P7 ISSUED LB]</expression></dataItem><dataItem name="DATE"><expression>current_timestamp</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Component 2nd Item Number] in ('PR3460',
'PR3460.E',
'PR5980I',
'PR5980I.E',
'PR5980I.S',
'PR5985',
'PR5985.E',
'PR5985.S'
)</filterExpression></detailFilter><detailFilter><filterExpression>[Issued Quantity]+[Ordered Quantity]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Start Date]&gt;=2026-03-01</filterExpression></detailFilter><detailFilter><filterExpression>[Quantity Requested]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number] not contains ('-')</filterExpression></detailFilter><detailFilter><filterExpression>[Unit of Measure] in ('LB', 'KG')</filterExpression></detailFilter><detailFilter><filterExpression>[WO Status] not in ('MM')</filterExpression></detailFilter></detailFilters></query><query name="Sales Orders">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Order Company" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Order Company]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Customer Code" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Ship To Customer].[Customer Code])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Customer Name" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Ship To Customer].[Customer Name])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Customer Segmentation" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Ship To Customer].[Customer Segmentation]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Parent" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Ship To Customer].[Global Parent])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Country Name" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Ship To Customer].[Country Name])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Open Orders].[Branch Plant])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Order Number" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Order Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Open Orders].[2nd Item Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Next Status" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Next Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Last Status" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Last Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Line Type" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Line Type]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Primary Quantity Ordered" aggregate="total"><expression>[Open Order Star Schema - JDE].[Open Orders].[Primary Quantity Ordered]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Primary UOM" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Primary UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Secondary Quantity Ordered" aggregate="total"><expression>[Open Order Star Schema - JDE].[Open Orders].[Secondary Quantity Ordered]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Secondary UOM" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Secondary UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Order Date" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Order Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Requested Date" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Requested Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Promised Ship Date" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Promised Ship Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Scheduled Pick Date" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Scheduled Pick Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Rev Bus Unit" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Rev Bus Unit]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="TM Name" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Open Orders].[TM Name])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Customer PO" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Open Orders].[Customer PO])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Hold Orders Code" aggregate="none" rollupAggregate="none"><expression>[Open Order Star Schema - JDE].[Open Orders].[Hold Orders Code]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="CSR Name" aggregate="none" rollupAggregate="none"><expression>trim([Open Order Star Schema - JDE].[Open Orders].[CSR Name])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Line Type]='S'</filterExpression></detailFilter><detailFilter><filterExpression>[Primary Quantity Ordered]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Next Status] not in ('570', '580', '620', '999')</filterExpression></detailFilter><detailFilter><filterExpression>[Branch Plant] in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC' , 'CIN2', 'CIN4', 'BARC', 'CIND', 'CINR')</filterExpression></detailFilter></detailFilters></query><query name="Sales Order Summary">
			<source>
				<joinOperation>
					<joinOperands>
						<joinOperand cardinality="0:N"><queryRef refQuery="Sales Orders"/></joinOperand>
						<joinOperand cardinality="1:1"><queryRef refQuery="Item Information"/></joinOperand>
					</joinOperands>
					<joinFilter>
						<filterExpression>[Sales Orders].[Branch Plant] = [Item Information].[Branch Plant] and
[Sales Orders].[2nd Item Number] = [Item Information].[2nd Item Number]</filterExpression>
					</joinFilter>
				</joinOperation></source>
			<selection><dataItem name="Order Company"><expression>[Sales Orders].[Order Company]</expression></dataItem><dataItem name="Customer Code"><expression>[Sales Orders].[Customer Code]</expression></dataItem><dataItem name="Customer Name"><expression>[Sales Orders].[Customer Name]</expression></dataItem><dataItem name="Customer Segmentation" label="Segmentation"><expression>[Sales Orders].[Customer Segmentation]</expression></dataItem><dataItem name="Global Parent"><expression>[Sales Orders].[Global Parent]</expression></dataItem><dataItem name="Country Name"><expression>[Sales Orders].[Country Name]</expression></dataItem><dataItem name="Hold Orders Code"><expression>[Sales Orders].[Hold Orders Code]</expression></dataItem><dataItem name="Branch Plant"><expression>[Sales Orders].[Branch Plant]</expression></dataItem><dataItem name="Order Number"><expression>[Sales Orders].[Order Number]</expression></dataItem><dataItem name="2nd Item Number"><expression>[Sales Orders].[2nd Item Number]</expression></dataItem><dataItem name="Next Status"><expression>[Sales Orders].[Next Status]</expression></dataItem><dataItem name="Last Status"><expression>[Sales Orders].[Last Status]</expression></dataItem><dataItem name="ORDER KGs"><expression>If ([Primary UOM]='LB') Then
([Primary Quantity Ordered]*0.453593)
Else
If ([Primary UOM]='KG') Then
([Primary Quantity Ordered])
Else
If ([Primary UOM]='EA') Then
([Primary Quantity Ordered]*20)
Else
(1000000)</expression></dataItem><dataItem name="ORDER LBs"><expression>if ([Primary UOM]='LB') Then
([Primary Quantity Ordered])
Else
If ([Primary UOM]='KG') Then
([Primary Quantity Ordered]/0.453593)
Else
if ([Primary UOM] = 'EA') Then
([Primary Quantity Ordered]*44)
Else
(1000000)</expression></dataItem><dataItem name="Primary Quantity Ordered" label="Prim QTY"><expression>[Sales Orders].[Primary Quantity Ordered]</expression></dataItem><dataItem name="Primary UOM" label="UOM"><expression>[Sales Orders].[Primary UOM]</expression></dataItem><dataItem name="Secondary Quantity Ordered" label="2nd QTY"><expression>[Sales Orders].[Secondary Quantity Ordered]</expression></dataItem><dataItem name="Secondary UOM" label="UOM2"><expression>[Sales Orders].[Secondary UOM]</expression></dataItem><dataItem name="Requested Date"><expression>[Sales Orders].[Requested Date]</expression></dataItem><dataItem name="Promised Ship Date"><expression>[Sales Orders].[Promised Ship Date]</expression></dataItem><dataItem name="Scheduled Pick Date"><expression>[Sales Orders].[Scheduled Pick Date]</expression></dataItem><dataItem name="TM Name"><expression>[Sales Orders].[TM Name]</expression></dataItem><dataItem name="CSR Name"><expression>[Sales Orders].[CSR Name]</expression></dataItem><dataItem name="Order Date"><expression>[Sales Orders].[Order Date]</expression></dataItem><dataItem name="Customer PO"><expression>[Sales Orders].[Customer PO]</expression></dataItem><dataItem name="Branch Plant1"><expression>[Item Information].[Branch Plant]</expression></dataItem><dataItem name="Global Bulk Item"><expression>[Item Information].[Global Bulk Item]</expression></dataItem><dataItem name="Bulk Item"><expression>[Item Information].[Bulk Item]</expression></dataItem><dataItem name="2nd Item Number1"><expression>[Item Information].[2nd Item Number]</expression></dataItem><dataItem name="Master Planning Family" label="MPF"><expression>[Item Information].[Master Planning Family]</expression></dataItem><dataItem name="Stock Type"><expression>[Item Information].[Stock Type]</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Branch Plant]=[Branch Plant1]</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number]=[2nd Item Number1]</filterExpression></detailFilter><detailFilter><filterExpression>[Bulk Item] in ('PR3460',
'PR3460.E',
'PR5980I',
'PR5980I.E',
'PR5980I.S',
'PR5985',
'PR5985.E',
'PR5985.S',
'DPI8600.E',
'PH00007E.E',
'201250PX.E',
'DPI8200.E',
'MF4915.E',
'MFHS1130.E',
'MFP1857.E',
'MP3000.E',
'MP48525R.E',
'MP4932.E',
'MP498340R.E',
'PH00017E.E',
'MFP1853R.E',
'MP498345P.E',
'MP4983RHSA.E',
'201081CX',
'241083PX.S',
'241088PX.S',
'241089PX.S',
'241199PX.S',
'241252PX.S',
'251095NX.S',
'251142PX.S',
'251144PX.S',
'251194NX.S',
'251268PX.S',
'MF1204.S',
'MF1306D.S',
'MF1406.S',
'MFHS1881.S',
'MFP1853R.S',
'MFP1883.S',
'MP4982SC.S',
'MP498340R.S',
'MP498345N.S',
'MP4983R.S',
'MP4983RHS.S',
'PH00017E.S',
'PI8545.S',
'241253PX.S',
'241168PX',
'241201FX',
'DP040',
'DPI8600',
'HSCF280',
'ILP040',
'KHI205',
'KHI340',
'MED310',
'MED800',
'MFHS168',
'MFHS268',
'MFP1853R',
'MP04422R',
'MP3000',
'MP48525R',
'MP498340D',
'MP498340R',
'MP498345N',
'MP4983RHS',
'MT242AF',
'PA845H',
'PH00015E',
'PH00017E',
'UBD211',
'UBD268',
'UTS610',
'251379PX.E',
'MFP1883.E',
'MP4983RAM.E',
'PH00001A.E',
'251095NX.E',
'251194NX.E',
'MD7900.E',
'MP4983R.E',
'251246NX.E',
'251095NX',
'251194NX',
'261044NX',
'261074NX',
'605000007',
'MFP1883',
'MP4983R',
'MP4983RN',
'RM108',
'UPR420',
'221247PX.E',
'MP2960.E',
'221247PX',
'231093FX',
'MP2960'
)</filterExpression></detailFilter></detailFilters></query><query name="Inventory - New">
			<source>
				<model/>
			</source>
			<selection><dataItem name="REGION"><expression>Decode([Branch Plant], 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'AUBA', 'EMEA', 'AUB2', 'EMEA', 'SING', 'PacRim', 'SNG4', 'PacRim', 'MUM3', 'India', 'SHAN', 'China')</expression></dataItem><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Location" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Location])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Lot Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Lot Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Status" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Status])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity On Hand" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Quantity On Hand]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Primary UOM" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Master].[Primary UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="1"><expression>1</expression></dataItem><dataItem name="LB"><expression>If ([Primary UOM]='LB') Then
([Quantity On Hand])
Else
If ([Primary UOM]='KG') Then
([Quantity On Hand]/0.453593)
Else
If ([Primary UOM]='EA') Then
([Quantity On Hand]*40)
Else
(0)</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Status] = null or [Status] in ('T', 'B', 'Q', 'H')</filterExpression></detailFilter><detailFilter><filterExpression>[Branch Plant] in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC' , 'CIN2', 'CIN4')</filterExpression></detailFilter><detailFilter><filterExpression>[Bulk Item] in ('251194NX.E',
'DPI8200.E',
'201250PX.E',
'251095NX.E',
'DPI8600.E',
'DP040',
'251194NX',
'DPI8600',
'251095NX',
'251194NX.S',
'PR5985',
'PR5985.E',
'PR5985.S'
)</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[Bulk Item] in ('JS168.S' ,
'ME91735.S' ,
'PP05S.S' ,
'ME91240G.S' ,
'TSPP01.S' ,
'ME91735.S' ,
'ME87235.S' ,
'ME91735.S' ,
'211018IX.S' ,
'PP236A.S' ,
'NYS2104.S' ,
'PP236A.S' ,
'ME91240G.S' ,
'JS168.E' ,
'PP236A.S' ,
'ME91240G.S' ,
'ME91735.S' ,
'ME91735.S' ,
'ME91735.S' ,
'BRIJS2.S' ,
'BRIJS20.S', 'JS168.E', 'BRIJS2.E', 'BRIJS20.E', 'ME91735.E')</filterExpression></detailFilter></detailFilters></query><query name="Safety Stock - New">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Primary UOM" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Master].[Primary UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Safety Stock" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Safety Stock]/10000</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="1"><expression>1</expression></dataItem><dataItem name="REGION"><expression>Decode([Branch Plant], 'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'AUBA', 'EMEA', 'AUB2', 'EMEA', 'SING', 'PacRim', 'SNG4', 'PacRim', 'MUM3', 'India', 'SHAN', 'China')</expression></dataItem><dataItem name="LB Safety Stock"><expression>if ([Primary UOM]='LB') Then
([Safety Stock])
Else
If ([Primary UOM]='KG') Then
([Safety Stock]/0.453593)
Else
if ([Primary UOM]='EA') Then
([Safety Stock]*40)
Else
(0)</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Branch Plant] in ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC' , 'CIN2', 'CIN4')</filterExpression></detailFilter><detailFilter><filterExpression>[Bulk Item] in ('251194NX',
'DPI8200',
'201250PX',
'251095NX',
'DPI8600',
'DP040',
'251194NX.E',
'DPI8200.E',
'201250PX.E',
'251095NX.E',
'DPI8600.E',
'DP040.E',
'251194NX.S',
'DPI8200.S',
'201250PX.S',
'251095NX.S',
'DPI8600.S',
'DP040.S',
'PR5985',
'PR5985.E',
'PR5985.S'
)</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[Bulk Item] in ('JS168.S' ,
'ME91735.S' ,
'PP05S.S' ,
'ME91240G.S' ,
'TSPP01.S' ,
'ME91735.S' ,
'ME87235.S' ,
'ME91735.S' ,
'211018IX.S' ,
'PP236A.S' ,
'NYS2104.S' ,
'PP236A.S' ,
'ME91240G.S' ,
'JS168.E' ,
'PP236A.S' ,
'ME91240G.S' ,
'ME91735.S' ,
'ME91735.S' ,
'ME91735.S' ,
'BRIJS2.S' ,
'BRIJS20.S', 'JS168.E', 'BRIJS2.E', 'BRIJS20.E', 'ME91735.E')</filterExpression></detailFilter></detailFilters></query></queries>
	<layouts>
		<layout>
			<reportPages>
				<page name="Inventory">
					<pageBody>
						<contents><list horizontalPagination="true" name="List1" refQuery="Inventory">
								<noDataHandler>
									<contents>
										<block>
											<contents>
												<textItem>
													<dataSource>
														<staticValue>No Data Available</staticValue>
													</dataSource>
													<style>
														<CSS value="padding:10px 18px;"/>
													</style>
												</textItem>
											</contents>
										</block>
									</contents>
								</noDataHandler>
								<style>
									<CSS value="border-collapse:collapse"/>
									<defaultStyles>
										<defaultStyle refStyle="ls"/>
									</defaultStyles>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REGION"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="REGION"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Stock Type"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Stock Type"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Lot Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Lot Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Location"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Location"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Status"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Status"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Hard Commit"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Hard Commit"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Master Planning Family"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Master Planning Family"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="NOW"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="NOW"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="OH KG"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="OH KG"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="OH LB"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="OH LB"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="Global Bulk Item"/><sortItem refDataItem="Bulk Item"/><sortItem refDataItem="2nd Item Number"/></sortList></list></contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="pb"/>
							</defaultStyles>
						</style>
					</pageBody>
					<style>
						<defaultStyles>
							<defaultStyle refStyle="pg"/>
						</defaultStyles>
					</style>
				</page><page name="Work Order">
					<pageBody>
						<contents><list horizontalPagination="true" name="List4" refQuery="Work Orders">
								<noDataHandler>
									<contents>
										<block>
											<contents>
												<textItem>
													<dataSource>
														<staticValue>No Data Available</staticValue>
													</dataSource>
													<style>
														<CSS value="padding:10px 18px;"/>
													</style>
												</textItem>
											</contents>
										</block>
									</contents>
								</noDataHandler>
								<style>
									<CSS value="border-collapse:collapse"/>
									<defaultStyles>
										<defaultStyle refStyle="ls"/>
									</defaultStyles>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REGION"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="REGION"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="STATE"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="STATE"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="WO Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="WO Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="WO Status"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="WO Status"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Start Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Start Date"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Completed Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Completed Date"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Quantity Requested"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Quantity Requested"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Quantity Completed"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Quantity Completed"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Component UOM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Component UOM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REQUEST KG"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="REQUEST KG"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="COMPLETE KG"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="COMPLETE KG"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="P7 ISSUED KG"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="P7 ISSUED KG"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="P7 ORDERED KG"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="P7 ORDERED KG"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="P7 ISSUED LB"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="P7 ISSUED LB"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="P7 ORDERED LB"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="P7 ORDERED LB"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="P7 REMAINING"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="P7 REMAINING"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="DATE"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="DATE"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="REGION"/><sortItem refDataItem="Start Date"/><sortItem refDataItem="Completed Date"/></sortList></list></contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="pb"/>
							</defaultStyles>
						</style>
					</pageBody>
					<style>
						<defaultStyles>
							<defaultStyle refStyle="pg"/>
						</defaultStyles>
					</style>
				</page><page name="Sales Orders">
					<pageBody>
						<contents><list horizontalPagination="true" name="List3" refQuery="Sales Order Summary">
								<noDataHandler>
									<contents>
										<block>
											<contents>
												<textItem>
													<dataSource>
														<staticValue>No Data Available</staticValue>
													</dataSource>
													<style>
														<CSS value="padding:10px 18px;"/>
													</style>
												</textItem>
											</contents>
										</block>
									</contents>
								</noDataHandler>
								<style>
									<CSS value="border-collapse:collapse;text-align:left;border:1pt solid black"/>
									<defaultStyles>
										<defaultStyle refStyle="ls"/>
									</defaultStyles>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Order Company"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Order Company"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Customer Code"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Customer Code"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Customer Name"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Customer Name"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Customer Segmentation"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Customer Segmentation"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Global Parent"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Global Parent"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Country Name"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Country Name"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Order Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Order Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Hold Orders Code"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Hold Orders Code"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Next Status"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Next Status"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Last Status"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Last Status"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="ORDER KGs"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="ORDER KGs"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="ORDER LBs"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="ORDER LBs"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary Quantity Ordered"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary Quantity Ordered"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Secondary Quantity Ordered"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Secondary Quantity Ordered"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Secondary UOM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Secondary UOM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Order Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Order Date"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Requested Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Requested Date"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Promised Ship Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Promised Ship Date"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Scheduled Pick Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium" displayOrder="DMY"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Scheduled Pick Date"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="CSR Name"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="CSR Name"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="TM Name"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="TM Name"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Customer PO"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Customer PO"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Master Planning Family"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Master Planning Family"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Stock Type"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Stock Type"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="Order Company"/><sortItem refDataItem="Global Bulk Item"/><sortItem refDataItem="Bulk Item"/><sortItem refDataItem="Scheduled Pick Date"/></sortList></list></contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="pb"/>
							</defaultStyles>
						</style>
					</pageBody>
					<style>
						<defaultStyles>
							<defaultStyle refStyle="pg"/>
						</defaultStyles>
					</style>
				</page><page name="Inventory HP">
					<pageBody>
						<contents><list horizontalPagination="true" name="List5" refQuery="Inventory - New">
								<noDataHandler>
									<contents>
										<block>
											<contents>
												<textItem>
													<dataSource>
														<staticValue>No Data Available</staticValue>
													</dataSource>
													<style>
														<CSS value="padding:10px 18px;"/>
													</style>
												</textItem>
											</contents>
										</block>
									</contents>
								</noDataHandler>
								<style>
									<CSS value="border-collapse:collapse"/>
									<defaultStyles>
										<defaultStyle refStyle="ls"/>
									</defaultStyles>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REGION"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="REGION"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Location"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Location"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Lot Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Lot Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Status"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Status"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><dataFormat><numberFormat decimalSize="0"/></dataFormat><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="LB"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><dataFormat><numberFormat decimalSize="0"/></dataFormat><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="LB"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="Global Bulk Item"/><sortItem refDataItem="Bulk Item"/><sortItem refDataItem="2nd Item Number"/></sortList></list></contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="pb"/>
							</defaultStyles>
						</style>
					</pageBody>
					<style>
						<defaultStyles>
							<defaultStyle refStyle="pg"/>
						</defaultStyles>
					</style>
				</page><page name="Safety Stock HP">
					<pageBody>
						<contents><list horizontalPagination="true" name="List2" refQuery="Safety Stock - New">
								<noDataHandler>
									<contents>
										<block>
											<contents>
												<textItem>
													<dataSource>
														<staticValue>No Data Available</staticValue>
													</dataSource>
													<style>
														<CSS value="padding:10px 18px;"/>
													</style>
												</textItem>
											</contents>
										</block>
									</contents>
								</noDataHandler>
								<style>
									<CSS value="border-collapse:collapse"/>
									<defaultStyles>
										<defaultStyle refStyle="ls"/>
									</defaultStyles>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REGION"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="REGION"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Global Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary UOM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Safety Stock"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Safety Stock"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="LB Safety Stock"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="LB Safety Stock"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REGION"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="REGION"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="REGION"/></sortList></list></contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="pb"/>
							</defaultStyles>
						</style>
					</pageBody>
					<style>
						<defaultStyles>
							<defaultStyle refStyle="pg"/>
						</defaultStyles>
					</style>
				</page></reportPages>
		</layout>
	</layouts>
	<XMLAttributes><XMLAttribute name="RS_CreateExtendedDataItems" value="true" output="no"/><XMLAttribute name="listSeparator" value="," output="no"/><XMLAttribute name="RS_modelModificationTime" value="2020-12-14T17:09:59.699Z" output="no"/></XMLAttributes><reportName>1 - Ivan SK 2023</reportName></report>
