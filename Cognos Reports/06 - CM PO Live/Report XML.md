<report xmlns="http://developer.cognos.com/schemas/report/12.0/" useStyleVersion="10" expressionLocale="en-us">
	<modelPath>/content/package[@name='JDE Live Data']/model[@name='model']</modelPath>
	<drillBehavior modelBasedDrillThru="true" drillUpDown="true"/>
	<queries>
		<query name="Purchase Orders">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Company" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Company]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Purchase Order Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Purchase Order Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Purchase Order Type" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Purchase Order Type]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Line Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Line Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Purchase Order].[Branch Plant])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Requested Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Requested Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Reference 2" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Reference 2]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Reporting Code 3" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Reporting Code 3]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Purchase Order].[2nd Item Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Secondary Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Secondary Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Primary Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Primary Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Last Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Last Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Next Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Next Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Promised Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Promised Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Open Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Open Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Vendor Code" aggregate="total"><expression>[Work Order Star Schema - JDE].[Purchase Order].[Vendor Code]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Vendor Name" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Purchase Order].[Vendor Name])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="REGION"><expression>Decode ([Branch Plant],'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'OTHER')</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Open Quantity]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Promised Date]&gt;=to_date({sysdate})-90</filterExpression></detailFilter><detailFilter use="optional"><filterExpression>[Promised Date] between ?1 - Start? and ?2 - End?</filterExpression></detailFilter><detailFilter use="optional"><filterExpression>[REGION] in ?Select_Region?</filterExpression></detailFilter></detailFilters></query>
		<query name="Item Branch">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
		</query><query name="PO Summary">
			<source>
				<joinOperation>
					<joinOperands>
						<joinOperand cardinality="0:N"><queryRef refQuery="Purchase Orders"/></joinOperand>
						<joinOperand cardinality="1:1"><queryRef refQuery="Item Branch"/></joinOperand>
					</joinOperands>
					<joinFilter>
						<filterExpression>[Purchase Orders].[Branch Plant] = [Item Branch].[Branch Plant] and
[Purchase Orders].[2nd Item Number] = [Item Branch].[2nd Item Number]</filterExpression>
					</joinFilter>
				</joinOperation></source>
			<selection><dataItem name="Company"><expression>[Purchase Orders].[Company]</expression></dataItem><dataItem name="Purchase Order Number" label="PO #"><expression>[Purchase Orders].[Purchase Order Number]</expression></dataItem><dataItem name="Line Number" label="Line #"><expression>[Purchase Orders].[Line Number]</expression></dataItem><dataItem name="Branch Plant" label="Branch"><expression>[Purchase Orders].[Branch Plant]</expression></dataItem><dataItem name="Requested Date"><expression>[Purchase Orders].[Requested Date]</expression></dataItem><dataItem name="2nd Item Number" label="Item"><expression>[Purchase Orders].[2nd Item Number]</expression></dataItem><dataItem name="Secondary Quantity" label="2nd QTY"><expression>[Purchase Orders].[Secondary Quantity]</expression></dataItem><dataItem name="Primary Quantity" label="QTY"><expression>[Purchase Orders].[Primary Quantity]</expression></dataItem><dataItem name="Next Status"><expression>[Purchase Orders].[Next Status]</expression></dataItem><dataItem name="Promised Date"><expression>[Purchase Orders].[Promised Date]</expression></dataItem><dataItem name="Open Quantity" label="Open QTY"><expression>[Purchase Orders].[Open Quantity]</expression></dataItem><dataItem name="Vendor Name"><expression>[Purchase Orders].[Vendor Name]</expression></dataItem><dataItem name="Branch Plant1"><expression>[Item Branch].[Branch Plant]</expression></dataItem><dataItem name="Bulk Item"><expression>[Item Branch].[Bulk Item]</expression></dataItem><dataItem name="2nd Item Number1"><expression>[Item Branch].[2nd Item Number]</expression></dataItem><dataItem name="REGION"><expression>Decode ([Branch Plant],'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'OTHER')</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Branch Plant]=[Branch Plant1]</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number]=[2nd Item Number1]</filterExpression></detailFilter><detailFilter><filterExpression>[Bulk Item] in ('161017CX' ,
'161190PX' ,
'171143PX' ,
'171228PX.E' ,
'181020CX.E' ,
'181136IX' ,
'181192IX' ,
'181193EU.E' ,
'191011CX' ,
'191026CX.E' ,
'191245PX' ,
'23409A' ,
'ABEX2525' ,
'APT10' , 'APT11', 
'DMAEMA' ,
'EMA3065' ,
'ET2012.E' ,
'ET2022.E' ,
'ET4075.E' ,
'ET440.E' ,
'FERSUL7W' ,
'HP1432AT' ,
'HP1632' ,
'MD4020' ,
'MD4020C' ,
'MD4020S' ,
'MD4021' ,
'MD4021C' ,
'MD4021S' ,
'MD4022' ,
'MD4022C' ,
'MD4023' ,
'MD4023C' ,
'MDU20' ,
'MDU2012.E' ,
'MDU2012B.E' ,
'MDU4075.E' ,
'MDU4075B.E' ,
'MDU440.E' ,
'MDU440B.E' ,
'MPEG2000' ,
'MW40504' ,
'MW40514' ,
'NP4LF' ,
'NP4LF.S' ,
'OMS' ,
'PUD1.E' ,
'STODSO' ,
'U1001' ,
'U101' ,
'U201' ,
'U2022' ,
'U2022EU.E' ,
'U2023' ,
'U204' ,
'U204EU.E' ,
'U470' ,
'U501' ,
'U501B' ,
'U502' ,
'U502.E' ,
'U502X1.E' ,
'U601' ,
'U701' ,
'U802' ,
'U802.E' ,
'WAV501' ,
'WD40' ,
'WD40T', 'DPE3500', 'JS037', 'HP401', 'HSCF410', 'UNYTEC201')</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[REGION] in ?Select_Region?</filterExpression></detailFilter></detailFilters></query><query name="Query1"><source><model/></source><selection/></query><query name="Query2"><source><model/></source><selection/></query></queries>
	<layouts>
		<layout>
			<reportPages>
				<page name="Page1"><style><defaultStyles><defaultStyle refStyle="pg"/></defaultStyles></style>
					<pageBody><style><defaultStyles><defaultStyle refStyle="pb"/></defaultStyles></style>
						<contents>
							<table><style><defaultStyles><defaultStyle refStyle="tb"/></defaultStyles><CSS value="border-collapse:collapse;width:100%"/></style><tableRows><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>Enter the Date Range:  Beginning </staticValue></dataSource><style><CSS value="font-weight:bold;color:red"/></style></textItem><selectDate parameter="1 - Start" multiSelect="false" range="false" required="false" selectDateUI="editBox"/><textItem><dataSource><staticValue>    and End Date</staticValue></dataSource><style><CSS value="font-weight:bold;color:red"/></style></textItem><selectDate parameter="2 - End" multiSelect="false" range="false" required="false" selectDateUI="editBox"/></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>Select the Region: </staticValue></dataSource><style><CSS value="font-weight:bold;color:red"/></style></textItem><selectValue parameter="Select_Region" refQuery="Purchase Orders" multiSelect="false" range="false" required="false" autoSubmit="true"><sortList><sortItem refDataItem="REGION"/></sortList><useItem refDataItem="REGION"><displayItem refDataItem="REGION"/></useItem></selectValue><promptButton type="finish">
														<contents/>
														<style>
															<defaultStyles>
																<defaultStyle refStyle="bp"/>
															</defaultStyles>
														</style>
													</promptButton></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow></tableRows></table><list horizontalPagination="true" name="List1" refQuery="PO Summary">
								<noDataHandler>
									<contents>
										<block name="RAP_NDH_List1"><contents><block>
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
												</block></contents></block></contents>
								</noDataHandler>
								<style>
									<defaultStyles>
										<defaultStyle refStyle="ls"/>
									</defaultStyles>
									<CSS value="border-collapse:collapse;text-align:left"/>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Company"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="52850f06-3c52-4d3a-a933-449e1bc3a7ed" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Company"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="f1513c3c-1351-4a41-823b-a1fab4d638c3" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="e76ff079-9b0e-47f7-9e02-d4c76e3c46d0" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="0f1e1e26-d6cb-43df-89da-dbcc15de7d1b" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Purchase Order Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="e1b3d737-0aaf-4e00-b20a-91d2ed72b4da" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Purchase Order Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="2609728f-4fe0-4558-a3ed-0317857df6d2" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Line Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="1130f2e7-646c-4c43-b205-3677389458c7" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Line Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="e38d077c-5d4e-4a33-93c3-57385fe6eb58" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="e3967e95-cb55-4997-9e37-33138209a8d1" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="d729b6ad-cc08-4ba0-aeb6-617a6d96b095" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="d05d73ec-c4b0-472f-a1f1-27e75b59cfd0" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="45ecaa9e-2c93-45df-bdb0-3ec6e80fc0a0" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary Quantity"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="39b6745d-6301-457a-8719-a8a360e95019" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary Quantity"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="b4266e7d-0f57-4801-b16e-f3701575f011" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Open Quantity"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="9045e0fe-9c80-40e9-bb28-82642e95ee03" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Open Quantity"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="d86341e6-5cfc-4885-982f-4229cefc26d5" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Secondary Quantity"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="42cd81a7-963e-48c8-af9b-633d355f9ce7" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Secondary Quantity"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="09fe6328-58a0-42bc-a145-069ee02c3c2a" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Next Status"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="6d44409b-f4cb-48d8-922c-cdfd9584a645" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Next Status"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="868e2117-5222-4d98-8e87-d7a6368a174b" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Requested Date"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="938c394a-0d60-43a6-a8b0-5e947653593a" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Requested Date"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="18ff8226-e788-49a1-8d31-a035b2bc1ef2" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Promised Date"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="11e8dacb-53ce-4e48-b08d-ecd6fadd88c5" output="HTML"/><XMLAttribute name="rp_sort" value="a" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="medium"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Promised Date"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="75cfd2d0-a07a-4bc6-aa34-221adf0d6aec" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Vendor Name"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="bed58a87-8e19-48b3-a33c-88f47ae1bbe9" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Vendor Name"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="dbaeb36a-559e-400d-94ea-8fe1673e2a14" output="HTML"/></XMLAttributes></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="Promised Date" sortOrder="ascending"/></sortList></list>
						</contents>
					</pageBody>
					<pageHeader>
						<contents>
							<block><style><defaultStyles><defaultStyle refStyle="ta"/></defaultStyles><CSS value="text-align:left"/></style>
								<contents>
									<textItem><style><defaultStyles><defaultStyle refStyle="tt"/></defaultStyles><CSS value="color:blue"/></style>
										<dataSource>
											<staticValue>CM - PO Live</staticValue>
										</dataSource>
									</textItem>
								</contents>
							</block>
						</contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="ph"/>
							</defaultStyles>
							<CSS value="padding-bottom:10px"/>
						</style>
					</pageHeader>
					<pageFooter>
						<contents>
							<table>
								<tableRows>
									<tableRow>
										<tableCells>
											<tableCell>
												<contents>
													<date>
														<style>
															<dataFormat>
																<dateFormat/>
															</dataFormat>
														</style>
													</date>
												</contents>
												<style>
													<CSS value="vertical-align:top;text-align:left;width:25%"/>
												</style>
											</tableCell>
											<tableCell>
												<contents>
													<pageNumber/>
												</contents>
												<style>
													<CSS value="vertical-align:top;text-align:center;width:50%"/>
												</style>
											</tableCell>
											<tableCell>
												<contents>
													<time>
														<style>
															<dataFormat>
																<timeFormat/>
															</dataFormat>
														</style>
													</time>
												</contents>
												<style>
													<CSS value="vertical-align:top;text-align:right;width:25%"/>
												</style>
											</tableCell>
										</tableCells>
									</tableRow>
								</tableRows>
								<style>
									<defaultStyles>
										<defaultStyle refStyle="tb"/>
									</defaultStyles>
									<CSS value="border-collapse:collapse;width:100%"/>
								</style>
							</table>
						</contents>
						<style>
							<defaultStyles>
								<defaultStyle refStyle="pf"/>
							</defaultStyles>
							<CSS value="padding-top:10px"/>
						</style>
					</pageFooter>
				</page>
			</reportPages>
		</layout>
	</layouts>
	<XMLAttributes><XMLAttribute name="RS_CreateExtendedDataItems" value="true" output="no"/><XMLAttribute name="listSeparator" value="," output="no"/><XMLAttribute name="RS_modelModificationTime" value="2020-12-14T17:09:59.699Z" output="no"/><XMLAttribute name="RAP_originalUseStyleVersion" value="10" output="no"/></XMLAttributes><reportName>CM - PO Live</reportName></report>




