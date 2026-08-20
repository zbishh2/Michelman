let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
VAR Bulks = { ""161017CX"", ""161190PX"", ""171143PX"", ""171228PX.E"", ""181020CX.E"", ""181136IX"", ""181192IX"", ""181193EU.E"", ""191011CX"", ""191026CX.E"", ""191245PX"", ""23409A"", ""ABEX2525"", ""APT10"", ""APT11"", ""DMAEMA"", ""EMA3065"", ""ET2012.E"", ""ET2022.E"", ""ET4075.E"", ""ET440.E"", ""FERSUL7W"", ""HP1432AT"", ""HP1632"", ""MD4020"", ""MD4020C"", ""MD4020S"", ""MD4021"", ""MD4021C"", ""MD4021S"", ""MD4022"", ""MD4022C"", ""MD4023"", ""MD4023C"", ""MDU20"", ""MDU2012.E"", ""MDU2012B.E"", ""MDU4075.E"", ""MDU4075B.E"", ""MDU440.E"", ""MDU440B.E"", ""MPEG2000"", ""MW40504"", ""MW40514"", ""NP4LF"", ""NP4LF.S"", ""OMS"", ""PUD1.E"", ""STODSO"", ""U1001"", ""U101"", ""U201"", ""U2022"", ""U2022EU.E"", ""U2023"", ""U204"", ""U204EU.E"", ""U470"", ""U501"", ""U501B"", ""U502"", ""U502.E"", ""U502X1.E"", ""U601"", ""U701"", ""U802"", ""U802.E"", ""WAV501"", ""WD40"", ""WD40T"" }
VAR WindowStart = DATE ( YEAR ( TODAY () ), MONTH ( TODAY () ), 1 )
VAR WindowEnd = EOMONTH ( TODAY () + 450, 0 )
VAR Forecasts =
    FILTER (
        FactForecast,
        TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks
            && FactForecast[RequestedDate] >= WindowStart
            && FactForecast[RequestedDate] <= WindowEnd
            && FactForecast[QuantityForecast] > 0
    )
RETURN
    SELECTCOLUMNS (
        Forecasts,
        ""Company Code"", FactForecast[Company],
        ""Branch Plant"", TRIM ( FactForecast[BusinessUnit] ),
        ""Global Bulk Item"", FactForecast[Global Bulk],
        ""Bulk Item"", FactForecast[Bulk Item],
        ""2nd Item Number"", FactForecast[ItemNum2nd],
        ""Item Description 1"", RELATED ( 'Item Branch'[Item Num 2nd Desc] ),
        ""Item Description 2"", RELATED ( 'Item Branch'[Description 2] ),
        ""Requested Date"", FactForecast[RequestedDate],
        ""Current Forecast (Line)"", FactForecast[QuantityForecast],
        ""Primary UOM"", FactForecast[UOM Primary],
        ""Current Forecast LB (Line)"", FactForecast[QuantityForecastLB],
        ""Current Forecast KG (Line)"", FactForecast[QuantityForecastKG],
        ""Date"", FactForecast[RequestedDate],
        ""Year"", YEAR ( FactForecast[RequestedDate] ),
        ""Month"", MONTH ( FactForecast[RequestedDate] ),
        ""Customer Code"", FactForecast[AddressNum],
        ""Customer Name"", RELATED ( 'Address'[Address Name] ),
        ""Global Parent Name"", RELATED ( 'Address'[Global Parent Desc] ),
        ""Chemist Name"", RELATED ( 'Item Branch'[Chemist Name] )
    )
"
        ]
    ),
    Data = Table.TransformColumnNames(
        Raw,
        each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]")
            then Text.Middle(_, 1, Text.Length(_) - 2)
            else _
    )
in
    Data
