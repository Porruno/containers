Put a file containing a JSON here regarding software info. Conditions are as follows:
- File is provided when device is first boot, and when software is added or updated.
- File must contain the full set of software installed. Edge Gateway will replace the old information with the new list.
- Timestamp field must be in RFC3399 format. See examples below.
- Type field can be UNKNOWN_TYPE (default), APPLICATION_TYPE, SYSTEM_TYPE, CONFIGURATION_TYPE.
- Only one file is expected. If more than one file is found, the first valid file will be used. Extra files will be renamed to <filename>.extra.<timestamp>.

Example:
{
    "softwareInfo": [
        {
            "name": "SomeCoolApp",
            "vendor": "Huawei Technologies Co.",
            "version": "1.0.0",
            "installTime": "2016-10-28T03:20:23+00:00",
            "status": "inactive",
            "description": "You wanna run this!"
        },
        {
            "name": "OpenVPN Client",
            "vendor": "OpenVPN Technologies, Inc.",
            "version": "2.3.12",
            "installTime": "2016-10-25T03:54:43.230Z",
            "status": "active",
            "description": "Securing your traffic"
        },
        {
            "name": "Wind River Linux",
            "vendor": "Wind River",
            "type": "SYSTEM_TYPE",
            "version": "7.0.0.18",
            "installTime": "2016-10-24T18:15:30-05:00",
            "status": "active",
            "description": "Blah"
        }
    ]
}