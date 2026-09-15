import random
import datetime

async def delete_snapshot(opensearch, params):
    await opensearch.snapshot.delete(repository=params["repository"], snapshot=params["snapshot"])

# Common helper functions
def random_money_values(max_value):
    gte_cents = random.randrange(0, max_value*100)
    lte_cents = random.randrange(gte_cents, max_value*100)
    return {
        "gte":gte_cents/100,
        "lte":lte_cents/100
    }

def random_dates(min_value, max_value, format_string, opensearch_query_format):
    # arguments are datetime objects
    min_timestamp = datetime.datetime.timestamp(min_value)
    max_timestamp = datetime.datetime.timestamp(max_value)
    diff = max_timestamp - min_timestamp
    gte_fraction = random.uniform(0, 1)
    lte_fraction = random.uniform(gte_fraction, 1.0)

    gte_date = datetime.datetime.fromtimestamp(min_timestamp + int(gte_fraction * diff))
    lte_date = datetime.datetime.fromtimestamp(min_timestamp + int(lte_fraction * diff))
    return {
        "gte":gte_date.strftime(format_string),
        "lte":lte_date.strftime(format_string),
        "format":opensearch_query_format
    }

# Standard value sources for our operations
start_date = datetime.datetime(2015, 1, 1)
end_date = datetime.datetime(2015, 1, 15)

def total_amount_source():
    return random_money_values(111.98)

def date_source_with_hours():
    return random_dates(start_date, end_date, format_string="%Y-%m-%d %H:%M:%S", opensearch_query_format="yyyy-MM-dd HH:mm:ss")

def date_source_without_hours():
    return random_dates(start_date, end_date, format_string="%d/%m/%Y", opensearch_query_format="dd/MM/yyyy")

def trip_distance_source():
    gte = random.randint(0, 10)
    lte = random.randint(gte, 20)
    return {"gte":gte, "lte":lte}

def bounding_box_source(): 
    top_longitude = random.uniform(-74.27, -73.68)
    top_latitude = random.uniform(40.49, 40.92)

    bottom_longitude = random.uniform(top_longitude, -73.68)
    bottom_latitude = random.uniform(40.49, top_latitude)

    # widen the box if it's small so we match more docs
    if bottom_longitude - top_longitude < 0.35: 
        bottom_longitude += 0.2
        top_longitude -= 0.2
    if top_latitude - bottom_latitude < 0.25: 
        top_latitude += 0.1 
        bottom_latitude -= 0.1 
    return { 
        "top_left":[top_longitude, top_latitude],
        "bottom_right":[bottom_longitude, bottom_latitude]
    }

def register(registry):
    # Register standard value sources for range queries defined in operations/default.json. 
    # These are only used if --randomization-enabled is present. 
    registry.register_standard_value_source("range", "total_amount", total_amount_source)
    registry.register_standard_value_source("distance_amount_agg", "trip_distance", trip_distance_source)
    registry.register_standard_value_source("autohisto_agg", "dropoff_datetime", date_source_without_hours)
    registry.register_standard_value_source("date_histogram_agg", "dropoff_datetime", date_source_without_hours)
    registry.register_standard_value_source("date_histogram_calendar_interval", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("date_histogram_calendar_interval_with_tz", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("date_histogram_fixed_interval", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("date_histogram_fixed_interval_with_tz", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("date_histogram_fixed_interval_with_metrics", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("auto_date_histogram", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("auto_date_histogram_with_tz", "dropoff_datetime", date_source_with_hours)
    registry.register_standard_value_source("auto_date_histogram_with_metrics", "dropoff_datetime", date_source_with_hours)

    registry.register_standard_value_source("bbox", "pickup_location", bounding_box_source)
    registry.register_query_randomization_info("bbox", "geo_bounding_box", [["top_left"], ["bottom_right"]], [])

    registry.register_runner("delete-snapshot", delete_snapshot, async_runner=True)
