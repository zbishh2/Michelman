<report xmlns="http://developer.cognos.com/schemas/report/12.0/" useStyleVersion="10" expressionLocale="en-us">
	<modelPath>/content/package[@name='JDE Live Data']/model[@name='model']</modelPath>
	<drillBehavior modelBasedDrillThru="true"/>
	<queries>
		<query name="Planned WO">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="WO Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[WO Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="WO Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[WO Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Start Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Start Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Requested Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Requested Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity Requested" aggregate="total"><expression>average([Work Order Star Schema - JDE].[JDE Work Order].[Quantity Requested])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity Completed" aggregate="total"><expression>average([Work Order Star Schema - JDE].[JDE Work Order].[Quantity Completed])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Unit of Measure" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order].[Unit of Measure]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Component 2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Component 2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Issued Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Issued Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Ordered Quantity" aggregate="total"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Ordered Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Requested Date1" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Requested Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Transaction Date" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[JDE Work Order Parts].[Transaction Date]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="4" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="OPEN RM"><expression>[Ordered Quantity]-[Issued Quantity]</expression></dataItem><dataItem name="DAY OF WEEK"><expression>_day_of_week (to_date({sysdate}),1)</expression></dataItem><dataItem name="DAYS FORWARD"><expression>Decode ([DAY OF WEEK], 4, 4, 5, 4, 6, 3, 2)</expression></dataItem><dataItem name="Master Planning Family" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Component Item Branch].[Master Planning Family]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Branch Plant] in ('CINC')</filterExpression></detailFilter><detailFilter><filterExpression>[WO Status] not in ('93', '94', '95', '97', '99', 'MM', 'CD')</filterExpression></detailFilter><detailFilter><filterExpression>[OPEN RM]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number] not contains ('-')</filterExpression></detailFilter><detailFilter><filterExpression>[Component 2nd Item Number] not contains ('H2O')</filterExpression></detailFilter><detailFilter><filterExpression>[Requested Date1] between to_date({sysdate}-7) and to_date({sysdate}+[DAYS FORWARD])</filterExpression></detailFilter><detailFilter><filterExpression>[Master Planning Family] in ('RRC', 'REC', 'RCB', 'TOL', 'PKG', 'RBW')</filterExpression></detailFilter></detailFilters></query>
		<query name="IOH CINC">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity On Hand" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Quantity On Hand]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Quantity On Hand]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Branch Plant] in ('CINC')</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number] not contains ('H2O')</filterExpression></detailFilter><detailFilter><filterExpression>[Status] in (' ', '-')</filterExpression></detailFilter></detailFilters></query><query name="IOH CIN2">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity On Hand" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Quantity On Hand]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Location" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Location])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Lot Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Lot Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Quantity On Hand]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Branch Plant] in ('CIN2')</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number] not contains ('H2O')</filterExpression></detailFilter><detailFilter><filterExpression>[Status] in (' ', '-')</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[2nd Item Number]='POLYMINP'</filterExpression></detailFilter></detailFilters></query><query name="IOH All">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity On Hand" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Quantity On Hand]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Location" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Location])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Lot Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Lot Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Status" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Status]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Quantity On Hand]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Branch Plant] in ('CIN2', 'CINC')</filterExpression></detailFilter><detailFilter><filterExpression>[2nd Item Number] not contains ('H2O')</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[Status] in (' ', '-')</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[2nd Item Number]='POLYMINP'</filterExpression></detailFilter></detailFilters></query><query name="RM Shortage CINC">
			<source>
				<joinOperation>
					<joinOperands>
						<joinOperand cardinality="0:N"><queryRef refQuery="Planned WO"/></joinOperand>
						<joinOperand cardinality="0:N"><queryRef refQuery="IOH CINC"/></joinOperand>
					</joinOperands>
					<joinFilter>
						<filterExpression>[Planned WO].[Component 2nd Item Number] = [IOH CINC].[2nd Item Number]</filterExpression>
					</joinFilter>
				</joinOperation></source>
			<selection><dataItem name="Component 2nd Item Number" label="RM"><expression>[Planned WO].[Component 2nd Item Number]</expression></dataItem><dataItem name="Quantity On Hand" label="QTY OH in CINC"><expression>average([IOH CINC].[Quantity On Hand])</expression></dataItem><dataItem name="OPEN RM" label="Total RM Needed"><expression>[Planned WO].[Ordered Quantity]-[Planned WO].[Issued Quantity]</expression></dataItem><dataItem name="CHECK"><expression>If ([Quantity On Hand] =0) Then
('SHORT')
Else
If ([Quantity On Hand] =null) Then
('SHORT')
Else
If ([Quantity On Hand] &lt; [OPEN RM]) Then
('SHORT')
Else
('OK')</expression></dataItem><dataItem name="SHORT QTY" label="QTY Required from CIN2"><expression>If ([Quantity On Hand]=0 or [Quantity On Hand]=null) Then
([OPEN RM])
Else
([OPEN RM]-[Quantity On Hand])</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Component 2nd Item Number] not in (' ')</filterExpression></detailFilter><detailFilter use="prohibited"><filterExpression>[OPEN RM]&gt;[Quantity On Hand]</filterExpression></detailFilter><detailFilter postAutoAggregation="true"><filterExpression>[CHECK] in ('SHORT')</filterExpression></detailFilter></detailFilters></query><query name="Summary">
			<source>
				<joinOperation>
					<joinOperands>
						<joinOperand cardinality="0:N"><queryRef refQuery="IOH CIN2"/></joinOperand>
						<joinOperand cardinality="0:N"><queryRef refQuery="RM Shortage CINC"/></joinOperand>
					</joinOperands>
					<joinFilter>
						<filterExpression>[IOH CIN2].[2nd Item Number] = [RM Shortage CINC].[Component 2nd Item Number]</filterExpression>
					</joinFilter>
				</joinOperation></source>
			<selection><dataItem name="Component 2nd Item Number" label="RM"><expression>[RM Shortage CINC].[Component 2nd Item Number]</expression></dataItem><dataItem name="SHORT QTY" label="Short Quantity"><expression>[RM Shortage CINC].[SHORT QTY]</expression></dataItem><dataItem name="2nd Item Number" label="RM in CIN2"><expression>[IOH CIN2].[2nd Item Number]</expression></dataItem><dataItem name="Quantity On Hand"><expression>[IOH CIN2].[Quantity On Hand]</expression></dataItem><dataItem name="Lot Number"><expression>[IOH CIN2].[Lot Number]</expression></dataItem><dataItem name="Location"><expression>[IOH CIN2].[Location]</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Component 2nd Item Number] not in (' ')</filterExpression></detailFilter></detailFilters></query><query name="Summary Shortage">
			<source>
				<joinOperation>
					<joinOperands>
						<joinOperand cardinality="0:N"><queryRef refQuery="IOH All"/></joinOperand>
						<joinOperand cardinality="0:N"><queryRef refQuery="RM Shortage CINC"/></joinOperand>
					</joinOperands>
					<joinFilter>
						<filterExpression>[IOH All].[2nd Item Number] = [RM Shortage CINC].[Component 2nd Item Number]</filterExpression>
					</joinFilter>
				</joinOperation></source>
			<selection><dataItem name="Component 2nd Item Number"><expression>[RM Shortage CINC].[Component 2nd Item Number]</expression></dataItem><dataItem name="SHORT QTY"><expression>[RM Shortage CINC].[SHORT QTY]</expression></dataItem><dataItem name="Branch Plant"><expression>[IOH All].[Branch Plant]</expression></dataItem><dataItem name="2nd Item Number"><expression>[IOH All].[2nd Item Number]</expression></dataItem><dataItem name="Quantity On Hand"><expression>[IOH All].[Quantity On Hand]</expression></dataItem><dataItem name="Location"><expression>[IOH All].[Location]</expression></dataItem><dataItem name="Lot Number"><expression>[IOH All].[Lot Number]</expression></dataItem><dataItem name="Status"><expression>[IOH All].[Status]</expression></dataItem><dataItemListSummary refDataItem="Quantity On Hand" aggregateMethod="total" name="Total(Quantity On Hand)"/></selection>
			<detailFilters><detailFilter><filterExpression>[Component 2nd Item Number] not in (' ')</filterExpression></detailFilter></detailFilters></query><query name="Query1">
			<source>
				<joinOperation>
					<joinOperands>
						<joinOperand cardinality="0:N"><queryRef refQuery="RM Shortage CINC"/></joinOperand>
						<joinOperand cardinality="0:N"><queryRef refQuery="Planned WO"/></joinOperand>
					</joinOperands>
					<joinFilter>
						<filterExpression>[RM Shortage CINC].[Component 2nd Item Number] = [Planned WO].[Component 2nd Item Number]</filterExpression>
					</joinFilter>
				</joinOperation></source>
			<selection><dataItem name="Component 2nd Item Number" label="Raw Material"><expression>[RM Shortage CINC].[Component 2nd Item Number]</expression></dataItem><dataItem name="Branch Plant"><expression>[Planned WO].[Branch Plant]</expression></dataItem><dataItem name="2nd Item Number" label="FG Item"><expression>[Planned WO].[2nd Item Number]</expression></dataItem><dataItem name="WO Number" label="WO #"><expression>[Planned WO].[WO Number]</expression></dataItem><dataItem name="Start Date" label="Work Order Start"><expression>[Planned WO].[Start Date]</expression></dataItem><dataItem name="Component 2nd Item Number1"><expression>[Planned WO].[Component 2nd Item Number]</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Component 2nd Item Number] not in (' ')</filterExpression></detailFilter><detailFilter><filterExpression>[Component 2nd Item Number]=[Component 2nd Item Number1]</filterExpression></detailFilter></detailFilters></query></queries>
	<layouts>
		<layout>
			<reportPages>
				<page name="Materials Short">
					<pageBody>
						<contents><table><style><defaultStyles><defaultStyle refStyle="tb"/></defaultStyles><CSS value="border-collapse:collapse;width:100%"/></style><tableRows><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>Raw Materials Needed in CINC</staticValue></dataSource><style><CSS value="color:red;font-weight:bold;font-size:12pt"/></style></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>OBJECTIVE: Identify the materials that need to be transferred to CINC from CIN2.</staticValue></dataSource><style><CSS value="color:blue;font-weight:bold"/></style></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>SCOPE: Parts list required within next (2) business days and material is NOT finished good MPF.</staticValue></dataSource><style><CSS value="color:blue;font-weight:bold"/></style></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents/></tableCell></tableCells></tableRow></tableRows></table><table><style><defaultStyles><defaultStyle refStyle="tb"/></defaultStyles><CSS value="border-collapse:collapse;width:100%"/></style><tableRows><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>Raw Material requirements</staticValue></dataSource><style><CSS value="font-weight:bold;color:blue"/></style></textItem></contents></tableCell></tableCells></tableRow></tableRows></table><list horizontalPagination="true" name="List3" refQuery="RM Shortage CINC">
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
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="OPEN RM"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="OPEN RM"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:blue;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="SHORT QTY"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="SHORT QTY"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="Component 2nd Item Number" sortOrder="ascending"/></sortList></list><table><style><defaultStyles><defaultStyle refStyle="tb"/></defaultStyles><CSS value="border-collapse:collapse;width:100%"/></style><tableRows><tableRow><tableCells><tableCell><contents/></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents/></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents/></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow></tableRows></table><list horizontalPagination="true" name="List2" refQuery="Query1">
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
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Start Date"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/><dataFormat><dateFormat dateStyle="long" displayOrder="DMY" showWeekday="true"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Start Date"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="Start Date"/></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:blue;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="WO Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="WO Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:blue;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><listGroups><listGroup refDataItem="Start Date"><sortList><sortItem refDataItem="Start Date" sortOrder="ascending"/></sortList></listGroup></listGroups></list></contents>
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
				</page><page name="Shortage Details">
					<pageBody>
						<contents><table><style><defaultStyles><defaultStyle refStyle="tb"/></defaultStyles><CSS value="border-collapse:collapse;width:100%"/></style><tableRows><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>OBJECTIVE: Identify the materials that need to be transferred to CINC from CIN2 based on Work Order parts requested date needed by the (2nd) business day forward</staticValue></dataSource><style><CSS value="color:blue;font-weight:bold"/></style></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue/></dataSource><style><CSS value="color:blue;font-weight:bold"/></style></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>Full inventory on hand list of materials needed at CINC</staticValue></dataSource><style><CSS value="color:red;font-weight:bold"/></style></textItem></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents/></tableCell></tableCells></tableRow></tableRows></table><list horizontalPagination="true" name="List5" refQuery="Summary Shortage">
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
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:red;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Component 2nd Item Number"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="Component 2nd Item Number"/></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:red;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="SHORT QTY"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="SHORT QTY"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="SHORT QTY"/></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:blue;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="2nd Item Number"/></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:blue;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="Branch Plant"/></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:blue;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Status"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Status"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="Status"/></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:blue;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Lot Number"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Lot Number"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:blue;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Location"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Location"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="text-align:left;font-weight:bold;color:blue;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:right;border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style><contents><textItem><dataSource><dataItemValue refDataItem="Quantity On Hand"/></dataSource></textItem></contents></listColumnBody></listColumn></listColumns><listGroups><listGroup refDataItem="Component 2nd Item Number"/><listGroup refDataItem="SHORT QTY"/><listGroup refDataItem="2nd Item Number"><sortList><sortItem refDataItem="Lot Number" sortOrder="ascending"/></sortList></listGroup><listGroup refDataItem="Branch Plant"><sortList><sortItem refDataItem="Branch Plant" sortOrder="descending"/></sortList><listFooter><listRows><listRow><rowCells><rowCell colSpan="4"><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem><textItem><dataSource><staticValue> - </staticValue></dataSource></textItem><textItem><dataSource><staticValue>Total</staticValue></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="of"/></defaultStyles><CSS value="border:1pt solid black"/></style></rowCell><rowCell><contents><textItem><dataSource><dataItemValue refDataItem="Total(Quantity On Hand)"/></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="os"/></defaultStyles><CSS value="border:1pt solid black"/><dataFormat><numberFormat decimalSize="0"/></dataFormat></style></rowCell></rowCells></listRow></listRows></listFooter></listGroup><listGroup refDataItem="Status"/></listGroups></list></contents>
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
	<XMLAttributes><XMLAttribute name="RS_CreateExtendedDataItems" value="true" output="no"/><XMLAttribute name="listSeparator" value="," output="no"/><XMLAttribute name="RS_modelModificationTime" value="2020-12-14T17:09:59.699Z" output="no"/></XMLAttributes><reportName>DEMO - RM Staging at Shell Road 2026</reportName></report>
