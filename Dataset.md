# Dataset

This dataset is collected from a prototype energy storage automation platform that has been running for a few years in a handful of different sites. The dataset contains a sample of days around the year: the first 7 days of all calendar months of 2024. This provides a good coverage of different energy situations based on weekdays and seasons.

The data folder contains one JSON file per site per day. The format for filenames is `daily_{siteID}_{date}.json`. The site ID identifies which site the data was taken from.

## Abbreviations
- `AC`: Alternating Current. For this specific dataset this means 230V grid voltage. AC power needs to be converted to DC to charge a battery.
- `DC`: Direct Current. The current that can be used to charge the battery. It needs to be converted back to AC to return to the grid.
- `PV`: Photovoltaic. Power generated from solar panels. Can either be AC (built-in inverter) or DC (no inverter/shares inverter with battery)
- `SoC`: State-of-charge. The amount of charge in the battery. Can either be expressed as a percentage or in (kilo)Watt-hours.
- `W`: Watt. Unit of power, the rate at which energy is ued
- `kW`: Kilowatt. Unit of power, 1000 Watts
- `Wh`: Watt-hour. Unit of energy (__not__ power)
- `kWh`: Kilowatt-hour. Unit of energy, 1000 Watt-hours

## Data format

The dataset contains JSON files for each day in the dataset. Each JSON file consists of two parts: site meta data and input data per schedule slot. The root format of the file is as follows:
```json
{
	"site_info": { ... },
    "schedule_input": [ { ... }, { ... }, { ... } ]
}
```

The chapters below will explain the two parts in more detail

### Site meta data

This section contains information about the site and it's equipment. Most of it is static across different days for the same site. It is still provided in each data file to make each file self-contained. The meta data contains the following fields:
```json
"site_info": 
{
	"site_id": 5,							// Unique identifier of the site this data was exported for
	"initial_charge": 0,					// Charge of the battery at the start of the day (Watt-hours)
	"battery_capacity": 245000,				// Total capacity of the battery (Watt-hours)
	"max_charge_amount": 15000,				// Maximum charge amount that the inverter can process per schedule slot (Watt-hours)
	"max_discharge_amount": 12000,			// Maximum discharge amount that the inverter can process per schedule slot (Watt-hours)
	"charge_efficiency_from_dc": 0.98,		// Efficiency of charging the battery from DC (PV) input (fraction)
	"charge_efficiency_from_ac": 0.82,		// Efficiency of charging the battery from AC (Grid/PV) input (fraction)
	"discharge_efficiency_to_dc": 0.98,		// Efficiency of discharging the battery to DC (fraction)
	"discharge_efficiency_to_ac": 0.82		// Efficiency of discharging the battery to the AC Grid (fraction)
}
```

## Schedule input

Each day defines 48 slots of 30 minutes each. The schedule input will contain an array with 48 elements containing the information for that 30-minute slot. An example of all fields for a slot are given below:
```json
{
	"slot_time": "2024-12-01T10:00:00.000000Z",		// Start time for this slot. End time will always be 30 minutes later
	"price_buying": 0.187,							// Price for buying 1 kWh in this slot (Euros)
	"price_selling": 0.0438,						// Price received for selling 1 kWh in this slot (Euros)
	"production_forecast_ac": 13754.5,				// Amount of AC PV energy produced in this slot (Watt-hours)
	"production_forecast_dc": 598.5,				// Amount of DC PV energy produced in this slot (Watt-hours)
	"consumption_forecast": 2900					// Amount of energy the site will consume in this slot (Watt-hours)
}
```

## Sites

Data from three different sites is included. These sites provide a good mix of different important properties:

| Site ID	| Type			| Capacity	| Energy pricing	| PV type	|
|-----------|---------------|-----------|-------------------|-----------|
| #1		| Residential	| Medium	| Dynamic			| DC		|
| #4		| Residential	| Small		| Dynamic			| AC		|
| #5		| Industrial	| Large		| Static			| Mix		|

## Limitations

This dataset does not include information about the following properties:
- Grid limits for production/consumption
- Netting information (Dutch: "Saldering")
- Inverter power consumption and efficiency at different currents
- Hardware deprecation costs

## License
This dataset is available under Creative Commons BY-NC-SA (https://creativecommons.org/licenses/by-nc-sa/4.0/).