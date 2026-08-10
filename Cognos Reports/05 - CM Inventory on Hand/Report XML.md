<report xmlns="http://developer.cognos.com/schemas/report/12.0/" useStyleVersion="10" expressionLocale="en-us">
	<modelPath>/content/package[@name='JDE Live Data']/model[@name='model']</modelPath>
	<drillBehavior modelBasedDrillThru="true" drillUpDown="true"/>
	<queries>
		<query name="Inventory">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Branch Plant" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Global Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Global Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Bulk Item" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Tag].[Bulk Item]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="2nd Item Number" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Location" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Location])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Lot Number" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Lot Number])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Status" aggregate="none" rollupAggregate="none"><expression>trim([Work Order Star Schema - JDE].[Item Branch].[Status])</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="Quantity On Hand" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Quantity On Hand]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Hard Commit" aggregate="total"><expression>[Work Order Star Schema - JDE].[Item Branch].[Hard Commit]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="9" output="no"/><XMLAttribute name="RS_dataUsage" value="fact" output="no"/></XMLAttributes></dataItem><dataItem name="Primary UOM" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Master].[Primary UOM]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="KG/EA On Hand" label="KG/EA OH"><expression>If ([Primary UOM]='LB') Then
([Quantity On Hand]*0.453593)
Else
If ([Primary UOM]='KG') Then
([Quantity On Hand])
Else
([Quantity On Hand])</expression></dataItem><dataItem name="LB/EA On Hand" label="LB/EA OH"><expression>If ([Primary UOM]='KG') Then
([Quantity On Hand]/0.453593)
Else
If ([Primary UOM]='LB') Then
([Quantity On Hand])
Else
([Quantity On Hand])</expression></dataItem><dataItem name="Business Unit" aggregate="none" rollupAggregate="none"><expression>[Work Order Star Schema - JDE].[Item Branch].[Business Unit]</expression><XMLAttributes><XMLAttribute name="RS_dataType" value="3" output="no"/><XMLAttribute name="RS_dataUsage" value="attribute" output="no"/></XMLAttributes></dataItem><dataItem name="REGION"><expression>Decode ([Branch Plant],'CINC', 'Americas', 'CIN2', 'Americas', 'CIN4', 'Americas', 'GRAN', 'Americas', 'DANC', 'Americas', 'AUBA', 'Aubange', 'AUB2', 'Aubange', 'SHAN', 'Shanghai', 'SING', 'Singapore', 'SNG4', 'Singapore', 'MUM3', 'Mumbai', 'OTHER')</expression></dataItem></selection>
			<detailFilters><detailFilter><filterExpression>[Quantity On Hand]&gt;0</filterExpression></detailFilter><detailFilter><filterExpression>[Bulk Item] in ('161017CX' ,
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
'WD40T', 'DPE3500', '191245PX' ,
'201118CX.E' ,
'ACRYLA' ,
'ACTMBS' ,
'AMDBIO' ,
'AMMPERSU' ,
'APT10' ,
'BLACKAN' ,
'BPADA' ,
'CALDB45' ,
'DMAEMA' ,
'DPE3500' ,
'EMA3065' ,
'FERSUL7W' ,
'HP1432AT' ,
'HP1632' ,
'MD4020' ,
'MD4021' ,
'MD4022' ,
'MD4023' ,
'MDU20' ,
'MDU2012B.E' ,
'MDU4075B.E' ,
'MEHQ.E' ,
'PEG1450' ,
'STYRENE' ,
'TBHP70' ,
'U101' ,
'U201' ,
'U2022' ,
'U2022EU.E' ,
'U2023' ,
'U470' ,
'U501' ,
'U501B' ,
'U502' ,
'U502.E' ,
'U505.E' ,
'U601' ,
'U701' ,
'U802' ,
'U802.E' ,
'UNYTEC201' ,
'VER100' ,
'WAV501' ,
'WD40', 'JS037', 'HP401', 'HSCF410')</filterExpression></detailFilter><detailFilter use="optional"><filterExpression>[REGION] in ?Select_Region?</filterExpression></detailFilter></detailFilters></query><query name="Query1"><source><model/></source><selection/></query></queries>
	<layouts>
		<layout>
			<reportPages>
				<page name="Page1"><style><defaultStyles><defaultStyle refStyle="pg"/></defaultStyles></style>
					<pageBody><style><defaultStyles><defaultStyle refStyle="pb"/></defaultStyles></style>
						<contents>
							<table><style><defaultStyles><defaultStyle refStyle="tb"/></defaultStyles><CSS value="border-collapse:collapse;width:100%"/></style><tableRows><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>Select the Region: </staticValue></dataSource><style><CSS value="font-weight:bold;color:red"/></style></textItem><selectValue parameter="Select_Region" refQuery="Inventory" multiSelect="false" range="false" required="false" autoSubmit="true"><useItem refDataItem="REGION"><displayItem refDataItem="REGION"/></useItem><sortList><sortItem refDataItem="REGION"/></sortList></selectValue></contents></tableCell></tableCells></tableRow><tableRow><tableCells><tableCell><contents><textItem><dataSource><staticValue>
															</staticValue></dataSource></textItem></contents></tableCell></tableCells></tableRow></tableRows></table><list refQuery="Inventory" horizontalPagination="true" name="List1">
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
									<CSS value="border-collapse:collapse"/>
								</style>
								<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="REGION"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="3bcf7450-630f-4775-a26e-f599c02cccb0" output="HTML"/><XMLAttribute name="rp_sort" value="a.1" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="REGION"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="d160d874-dc20-48c4-b458-d3583266861d" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="81bda49d-daad-41ea-86fc-062dd8088d75" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="de532a4b-0b68-4fa7-8194-b8a03a605e65" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Bulk Item"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="18485a30-bcb6-491d-a7dc-5939607c9c57" output="HTML"/><XMLAttribute name="rp_sort" value="a.2" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Bulk Item"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="f5ea284b-5041-430a-ab81-c6dfdbb271cd" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="2nd Item Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="2036dfde-ad54-4fa8-b92f-fdfe594d3d98" output="HTML"/><XMLAttribute name="rp_sort" value="a.3" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="2nd Item Number"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="6ca12625-1d83-4ae0-8b62-74500625e634" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Status"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="e443c217-216d-4314-8e56-a9b0a29fd276" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Status"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="9ab11078-dc06-49fa-8f23-beeaa0142507" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="KG/EA On Hand"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="c964f300-e5ca-4586-a6cd-ce43e0c2c04f" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><dataFormat><numberFormat decimalSize="0"/></dataFormat><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="KG/EA On Hand"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="3fc0384e-0ced-4d7e-9300-2f8bb5bd6d0b" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="LB/EA On Hand"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="40bb791f-b501-487f-9a1d-26b07820b04b" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><dataFormat><numberFormat decimalSize="0"/></dataFormat><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="LB/EA On Hand"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="0e886c94-a1bd-45ae-90f0-379604c405cf" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Hard Commit"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="bb37601d-fbc9-428f-a514-c954cbf7722a" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles><dataFormat><numberFormat decimalSize="0"/></dataFormat><CSS value="text-align:right;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Hard Commit"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="532a79ae-461c-46cc-9e01-8affa816e48c" output="HTML"/></XMLAttributes></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles><CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemLabel refDataItem="Primary UOM"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="deeae624-a98e-4472-af9b-bcb652f46bbe" output="HTML"/></XMLAttributes></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles><CSS value="text-align:left;border:1pt solid black"/></style><contents><textItem><dataSource><dataItemValue refDataItem="Primary UOM"/></dataSource></textItem></contents><XMLAttributes><XMLAttribute name="rap_layout_tag" value="50c32513-a1bb-4c24-b10f-008307c11386" output="HTML"/></XMLAttributes></listColumnBody></listColumn></listColumns><sortList><sortItem refDataItem="REGION"/><sortItem refDataItem="Bulk Item"/><sortItem refDataItem="2nd Item Number"/></sortList></list>
						</contents>
					</pageBody>
					<pageHeader>
						<contents>
							<block><style><defaultStyles><defaultStyle refStyle="ta"/></defaultStyles><CSS value="text-align:left"/></style>
								<contents>
									<textItem><style><defaultStyles><defaultStyle refStyle="tt"/></defaultStyles><CSS value="color:blue"/></style>
										<dataSource>
											<staticValue>CM - Inventory on Hand</staticValue>
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
	<XMLAttributes><XMLAttribute name="RS_CreateExtendedDataItems" value="true" output="no"/><XMLAttribute name="listSeparator" value="," output="no"/><XMLAttribute name="RS_modelModificationTime" value="2020-12-14T17:09:59.699Z" output="no"/><XMLAttribute name="RAP_originalUseStyleVersion" value="10" output="no"/></XMLAttributes><reportName>CM - Inventory on Hand</reportName></report>




