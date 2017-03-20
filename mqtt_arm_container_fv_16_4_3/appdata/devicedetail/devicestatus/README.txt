Put a file containing a JSON in here. Device status includes information regarding power sources. Here is a sample device status.
- Status files are written when status is updated. New status should always overwrite the old status file so we only read the latest status.
- Set percentageFull to -1 if it is not applicable to the power source.

Example:
{
    "powerSupplyStatus": [
        {
            "type": "AC",
            "state": "OK",
            "percentageFull": -1,
            "description": "Everything looks good."
        },
        {
            "type": "Battery",
            "state": "Discharging",
            "percentageFull": 30,
            "description": "Battery low!!!"
        },
        {
            "type": "UPS",
            "state": "FAULTY",
            "percentageFull": -1,
            "description": "Attention needed."
        }
    ]
}