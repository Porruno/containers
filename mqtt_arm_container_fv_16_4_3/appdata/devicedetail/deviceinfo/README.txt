Place a JSON file here. Contains hardware info and sim info

JSON Requirement:
- HardwareInfo should always contain the full set of hardware. Same for SimInfo. Edge Gateway will replace the old information with the new list.
- Fields under properties are arbitrary key-value pairs. Both key and value must be strings.
- Other fields (category, manufacturer, model, etc) are defined fields.

Example hardware info:
{
    "hardwareInfo": [
        {
            "category": "cpu",
            "manufacturer": "ABC Inc.",
            "model": "CPU123",
            "firmware": "1.1.1",
            "properties": {
                "numberOfProcessors": "1",
                "frequency": "1GHz",
                "numberOfCores": "2"
            }
        },
        {
            "category": "modem",
            "manufacturer": "Netgear",
            "model": "101",
            "firmware": "1.2.3"
        },
        {
            "category": "ups",
            "manufacturer": "Controlled Power Company",
            "model": "LT700",
            "firmware": "1.1.1",
            "properties": {
                "Detail": "http://www.controlledpwr.com/brochureFiles/35/LTSeriesBrochure.pdf",
                "Full load runtimes": "11.5 min",
                "Weight": "70 lbs",
                "VA": "700",
                "Dimensions": "8.125\" W x 17.5\" D x 17.5\" H",
                "Half load runtimes": "30 min",
                "WATTS": "500",
                "BTU's/Hour": "256"
            }
        },
        {
            "category": "memory",
            "manufacturer": "Kingston",
            "model": "HyperX FURY",
            "properties": {
                "Detail": "http://media.kingston.com/pdfs/HyperX_FURY_DDR3_US.pdf",
                "Speed": "1866MHz",
                "Storage Temperature": "-55C to 100C",
                "Type": "DDR3",
                "Dimensions": "133.35mm x 32.8mm",
                "Voltage": "1.35V",
                "Capacity": "8GB",
                "Operating Temperature": "0C to 85C"
            }
        },
        {
            "category": "memory",
            "manufacturer": "Samsung",
            "model": "generic",
            "properties": {
                "Speed": "1333MHz",
                "Type": "DDR3",
                "Voltage": "1.35V",
                "Part Numbers": "M393B1K70CH0-YH9, M393B1K70DH0-YH9",
                "Capacity": "8GB"
            }
        }
    ]
} 

Example sim info:
{
    "simInfo": [
        {
            "iccid": "8991101200003111111",
            "imei": "490154203237512"
        },
        {
            "iccid": "8991101200003123456",
            "imei": "990000862471854"
        },
        {
            "iccid": "8991101200003987654",
            "imei": "356938035643809"
        }
    ]
}