<report xmlns="http://developer.cognos.com/schemas/report/12.0/" expressionLocale="en-us" useStyleVersion="10"><!--RSU-SPC-0093 The report specification was upgraded from "http://developer.cognos.com/schemas/report/8.0/" to "http://developer.cognos.com/schemas/report/12.0/" at 2017-5-17. 18:18:15-->
				<modelPath>/content/package[@name='Data Warehouse']/model[@name='model']</modelPath>
				<drillBehavior modelBasedDrillThru="true"/>
				<queries>
					<query name="JDE">
						<source>
							<model/>
						</source>
						<selection><dataItem aggregate="none" name="Parent Second Item Number" rollupAggregate="none"><expression>[Data Warehouse].[Bill of Material].[Parent Second Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem><dataItem aggregate="none" name="2nd Item Number" rollupAggregate="none"><expression>[Data Warehouse].[Bill of Material].[2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem><dataItem aggregate="none" name="Fixed or Variable Quantity" rollupAggregate="none"><expression>[Data Warehouse].[Bill of Material].[Fixed or Variable Quantity]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem><dataItem aggregate="total" name="Quantity"><expression>Round([Data Warehouse].[Bill of Material].[Quantity]*100,4)</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="9"/><XMLAttribute name="RS_dataUsage" output="no" value="fact"/></XMLAttributes></dataItem><dataItem aggregate="none" name="Stock Type Code" rollupAggregate="none"><expression>[Data Warehouse].[Item].[Stock Type Code]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem><dataItem aggregate="none" name="Branch Plant" rollupAggregate="none"><expression>[Data Warehouse].[Bill of Material].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem></selection>
					<detailFilters><detailFilter><filterExpression>[Stock Type Code] = 'M'</filterExpression></detailFilter><detailFilter><filterExpression>[Data Warehouse].[Bill of Material].[Type of Bill] = 'M'</filterExpression></detailFilter><detailFilter><filterExpression>[Data Warehouse].[Item].[Branch Plant Type] &lt;&gt; 'LAB'</filterExpression></detailFilter><detailFilter use="optional"><filterExpression>[Branch Plant] in (?Branch?)</filterExpression></detailFilter></detailFilters></query>
				<query name="WERCS">
			<source>
				<model/>
			</source>
			<selection><dataItem name="Percent"><expression>Round([Data Warehouse].[Bulk Bill of Material - WERCS].[Percent],4)</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="2"/><XMLAttribute name="RS_dataUsage" output="no" value="fact"/></XMLAttributes></dataItem><dataItem aggregate="none" name="Component 2nd item Number" rollupAggregate="none"><expression>[Data Warehouse].[Bulk Bill of Material - WERCS].[Component 2nd item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem><dataItem aggregate="none" name="Parent 2nd Item Number" rollupAggregate="none"><expression>[Data Warehouse].[Bulk Bill of Material - WERCS].[Parent 2nd Item Number]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem></selection>
		</query><query name="Report">
			<source>
				
			<joinOperation>
			<joinOperands>
				<joinOperand cardinality="1:N"><queryRef refQuery="JDE"/></joinOperand>
				<joinOperand cardinality="0:1"><queryRef refQuery="WERCS"/></joinOperand>
			</joinOperands>
			<joinFilter>
				<filterExpression>[JDE].[Parent Second Item Number] = [WERCS].[Parent 2nd Item Number] and
[JDE].[2nd Item Number] = [WERCS].[Component 2nd item Number]</filterExpression>
			</joinFilter>
		</joinOperation></source>
			<selection><dataItem label="JDE Parent" name="JDE Parent"><expression>[JDE].[Parent Second Item Number]</expression></dataItem><dataItem label="JDE Raw" name="JDE Raw"><expression>[JDE].[2nd Item Number]</expression></dataItem><dataItem label="JDE Percent" name="JDE Percent"><expression>[JDE].[Quantity]</expression></dataItem><dataItem aggregate="none" label="WERCS Percent" name="WERCS Percent" rollupAggregate="none"><expression>[WERCS].[Percent]</expression></dataItem><dataItem label="WERCS Raw" name="WERCS Raw"><expression>[WERCS].[Component 2nd item Number]</expression></dataItem><dataItem label="WERCS Parent" name="WERCS Parent"><expression>[WERCS].[Parent 2nd Item Number]</expression></dataItem><dataItem name="Difference"><expression>abs([JDE].[Quantity]-nvl([WERCS].[Percent],0))</expression></dataItem><dataItemListSummary aggregateMethod="total" name="Total(Difference)" refDataItem="Difference"/><dataItem name="Branch Plant"><expression>[JDE].[Branch Plant]</expression></dataItem><dataItemListSummary aggregateMethod="total" name="Total(Difference)1" refDataItem="Difference"/><dataItemListSummary aggregateMethod="countDistinct" name="Count Distinct(JDE Parent)" refDataItem="JDE Parent"/></selection>
		<summaryFilters><summaryFilter><filterExpression>[Total(Difference)] &lt;&gt; 0</filterExpression><summaryFilterLevels><summaryFilterLevel refDataItem="JDE Parent"/><summaryFilterLevel refDataItem="Branch Plant"/></summaryFilterLevels></summaryFilter></summaryFilters></query><query name="Branch">
			<source>
				<model/>
			</source>
			<selection><dataItem aggregate="none" name="Branch Plant" rollupAggregate="none"><expression>[Data Warehouse].[Bill of Material].[Branch Plant]</expression><XMLAttributes><XMLAttribute name="RS_dataType" output="no" value="3"/><XMLAttribute name="RS_dataUsage" output="no" value="attribute"/></XMLAttributes></dataItem></selection>
		<detailFilters><detailFilter><filterExpression>[Data Warehouse].[Bill of Material].[Type of Bill] = 'M'</filterExpression></detailFilter><detailFilter><filterExpression>[Data Warehouse].[Item].[Stock Type Code] = 'M'</filterExpression></detailFilter><detailFilter><filterExpression>[Data Warehouse].[Bill of Material].[Effective Through Date] &gt; {SYSDATE}</filterExpression></detailFilter><detailFilter><filterExpression>[Data Warehouse].[Item].[Branch Plant Type] &lt;&gt; 'LAB'</filterExpression></detailFilter></detailFilters></query></queries>
				<layouts>
					<layout>
						<reportPages>
							<page name="Page1"><style><defaultStyles><defaultStyle refStyle="pg"/></defaultStyles></style>
								<pageBody><style><defaultStyles><defaultStyle refStyle="pb"/></defaultStyles></style>
									<contents>
										<selectValue autoSubmit="true" multiSelect="false" parameter="Branch" range="false" refQuery="Branch" required="true"><useItem refDataItem="Branch Plant"/></selectValue><list horizontalPagination="true" name="List1" refQuery="Report">
											
											
											
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
												<defaultStyles>
													<defaultStyle refStyle="ls"/>
												</defaultStyles>
												<CSS value="border-collapse:collapse"/>
											</style>
										<listColumns><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles></style><contents><textItem><dataSource><dataItemLabel refDataItem="JDE Parent"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles></style><contents><textItem><dataSource><dataItemValue refDataItem="JDE Parent"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="JDE Parent"/></listColumnBody></listColumn><listColumn><listColumnTitle><contents><textItem><dataSource><dataItemLabel refDataItem="Branch Plant"/></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="np"/></defaultStyles></style><conditionalStyleRefs><conditionalStyleRef refConditionalStyle="Conditional Style 1"/></conditionalStyleRefs></listColumnTitle><listColumnBody><contents><textItem><dataSource><dataItemValue refDataItem="Branch Plant"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="Branch Plant"/><style><defaultStyles><defaultStyle refStyle="np"/></defaultStyles></style><conditionalStyleRefs><conditionalStyleRef refConditionalStyle="Conditional Style 1"/></conditionalStyleRefs></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles></style><contents><textItem><dataSource><dataItemLabel refDataItem="JDE Raw"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lc"/></defaultStyles></style><contents><textItem><dataSource><dataItemValue refDataItem="JDE Raw"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles></style><contents><textItem><dataSource><dataItemLabel refDataItem="JDE Percent"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles></style><contents><textItem><dataSource><dataItemValue refDataItem="JDE Percent"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles></style><contents><textItem><dataSource><dataItemLabel refDataItem="WERCS Percent"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles></style><contents><textItem><dataSource><dataItemValue refDataItem="WERCS Percent"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles></style><contents><textItem><dataSource><dataItemLabel refDataItem="WERCS Raw"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles></style><contents><textItem><dataSource><dataItemValue refDataItem="WERCS Raw"/></dataSource></textItem></contents></listColumnBody></listColumn><listColumn><listColumnTitle><style><defaultStyles><defaultStyle refStyle="lt"/></defaultStyles></style><contents><textItem><dataSource><dataItemLabel refDataItem="WERCS Parent"/></dataSource></textItem></contents></listColumnTitle><listColumnBody><style><defaultStyles><defaultStyle refStyle="lm"/></defaultStyles></style><contents><textItem><dataSource><dataItemValue refDataItem="WERCS Parent"/></dataSource></textItem></contents><listColumnRowSpan refDataItem="WERCS Parent"/></listColumnBody></listColumn><listColumn><listColumnTitle><contents><textItem><dataSource><dataItemLabel refDataItem="Difference"/></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="np"/></defaultStyles></style><conditionalStyleRefs><conditionalStyleRef refConditionalStyle="Conditional Style 1"/></conditionalStyleRefs></listColumnTitle><listColumnBody><contents><textItem><dataSource><dataItemValue refDataItem="Difference"/></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="np"/></defaultStyles></style><conditionalStyleRefs><conditionalStyleRef refConditionalStyle="Conditional Style 1"/></conditionalStyleRefs></listColumnBody></listColumn></listColumns><listGroups><listGroup refDataItem="JDE Parent"><listFooter><listRows><listRow><rowCells><rowCell colSpan="6"><contents><textItem><dataSource><staticValue>     </staticValue></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="of"/></defaultStyles></style></rowCell><rowCell><contents/><style><defaultStyles><defaultStyle refStyle="of"/></defaultStyles></style><conditionalStyleRefs><conditionalStyleRef refConditionalStyle="Conditional Style 1"/></conditionalStyleRefs></rowCell><rowCell><contents><textItem><dataSource><dataItemValue refDataItem="Total(Difference)1"/></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="np"/></defaultStyles></style><conditionalStyleRefs><conditionalStyleRef refConditionalStyle="Conditional Style 1"/></conditionalStyleRefs></rowCell></rowCells></listRow></listRows></listFooter></listGroup><listGroup refDataItem="Branch Plant"><sortList><sortItem refDataItem="JDE Percent" sortOrder="ascending"/></sortList></listGroup><listGroup refDataItem="WERCS Parent"/></listGroups><listOverallGroup><listFooter><listRows><listRow><rowCells><rowCell><contents><textItem><dataSource><dataItemValue refDataItem="Count Distinct(JDE Parent)"/></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="is"/></defaultStyles></style></rowCell><rowCell colSpan="7"><contents><textItem><dataSource><staticValue>Overall</staticValue></dataSource></textItem><textItem><dataSource><staticValue> - </staticValue></dataSource></textItem><textItem><dataSource><staticValue>Count Distinct</staticValue></dataSource></textItem></contents><style><defaultStyles><defaultStyle refStyle="if"/></defaultStyles></style></rowCell></rowCells></listRow></listRows></listFooter></listOverallGroup></list>
									</contents>
								</pageBody>
								<pageHeader>
									<contents>
										<block><style><defaultStyles><defaultStyle refStyle="ta"/></defaultStyles></style>
											<contents>
												<textItem><style><defaultStyles><defaultStyle refStyle="tt"/></defaultStyles></style>
													<dataSource>
														<staticValue>BOM Discrepancies JDE to WERCS</staticValue>
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
			<XMLAttributes><XMLAttribute name="RS_CreateExtendedDataItems" output="no" value="true"/><XMLAttribute name="listSeparator" output="no" value=","/><XMLAttribute name="RS_modelModificationTime" output="no" value="2014-08-01T20:31:06.363Z"/></XMLAttributes><reportName>BOM WERCS Integrity Check</reportName><namedConditionalStyles><advancedConditionalStyle name="Conditional Style 1"><styleCases><styleCase><style><CSS value="visibility:hidden;display:none"/><defaultStyles><defaultStyle refStyle="np"/></defaultStyles></style><reportCondition>1=1</reportCondition></styleCase></styleCases><styleDefault/></advancedConditionalStyle></namedConditionalStyles></report><!--RSUChecksum-v1:54f74948d40d908a22191ade27e2c0eb60f788f9-->
