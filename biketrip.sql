-- start by import bike trip data from 2020-5 to 2021-4 in 12 csv file into database
-- table named as biketrip

-- create December table as Dec has duplicate ride_id which is the primary key
-- clean up duplicate so that possible to add to biketrip table
CREATE TABLE temp_dec(
    ride_id VARCHAR PRIMARY KEY,
	rideable_type VARCHAR,
	started_at timestamp without time zone,
	ended_at timestamp without time zone,
	start_station_name VARCHAR,
	start_station_id VARCHAR,
	end_station_name VARCHAR,
	end_station_id VARCHAR,
	start_lat NUMERIC,
	start_lng NUMERIC,
	end_lat NUMERIC,
	end_lng NUMERIC,
	member_casual VARCHAR
);


-- check duplicate rows
SELECT *
FROM temp_dec
INNER JOIN biketrip
ON biketrip.ride_id = temp_dec.ride_id;


-- delete duplicated rows for december 2020
DELETE FROM temp_dec
USING biketrip
WHERE biketrip.ride_id = temp_dec.ride_id;


-- check number of row in DEC
SELECT COUNT(ride_id)
FROM temp_dec;


-- move data to biketrip
INSERT INTO biketrip
SELECT * FROM temp_dec;


--check whether complete data move successfully by checking the number of dec with temp_dec
SELECT COUNT(EXTRACT(MONTH FROM started_at)) AS month
FROM biketrip
GROUP BY EXTRACT(MONTH FROM started_at)
HAVING EXTRACT(MONTH FROM started_at) = 12;

-- continue import data
-- after import all data, it seems that some entries have end time earlier than start time
-- therefore remove those entry with negative riding time

-- check negative riding time
SELECT COUNT(trip_time)
FROM (
	SELECT
	  ride_id
	  started_at,
	  ended_at,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	GROUP BY 1, 2, 3
	HAVING EXTRACT(EPOCH FROM (ended_at - started_at)) < '0'
	) t;


-- create duplicate table to test delete with below script
CREATE TABLE dummy_biketrip AS (SELECT * FROM biketrip);


--check number of row before and after delete (before delete 3741993 row, after delete 3731696)
SELECT COUNT(ride_id)
FROM biketrip;


-- delete negative trip duration (10297 row)
WITH remove_neg AS (
	SELECT
	  ride_id,
	  started_at,
	  ended_at,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	GROUP BY 1, 2, 3
	HAVING EXTRACT(EPOCH FROM (ended_at - started_at)) < '0'
	)
DELETE FROM biketrip
USING remove_neg
WHERE biketrip.ride_id = remove_neg.ride_id;


-- start to explore the data

-- total ride
SELECT COUNT(ride_id)
FROM biketrip;


-- ride by type
SELECT COUNT(ride_id), rideable_type
FROM biketrip
GROUP BY rideable_type;


-- ride by member_casual -- VIZ 1
SELECT member_casual, COUNT(ride_id)
FROM biketrip
GROUP BY member_casual
ORDER BY member_casual DESC;


-- ride by type AND member_casual -- VIZ 2
SELECT rideable_type, member_casual, COUNT(ride_id) AS num_of_ride
FROM biketrip
GROUP BY rideable_type, member_casual
ORDER BY num_of_ride DESC;


-- number of ride per month -- VIZ 3
SELECT
  CONCAT(EXTRACT(YEAR FROM started_at), '-', EXTRACT(MONTH FROM started_at)) AS month,
  member_casual,
  COUNT(EXTRACT(MONTH FROM started_at)) AS ride_per_month
FROM biketrip
GROUP BY month, member_casual
ORDER BY month;


-- rental time over 24 hours -- VIZ 4
WITH long_rent AS (
	SELECT
	  rideable_type,
	  member_casual,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	ORDER BY trip_time DESC
)
SELECT member_casual, rideable_type, COUNT(member_casual)
FROM long_rent
WHERE trip_time > '86400' -- 24 hours
GROUP BY member_casual, rideable_type;


-- count of instant bike return (ride seconds of less than 60)
WITH instant AS (
	SELECT
	  ride_id,
	  rideable_type,
	  member_casual,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	GROUP BY 1, 2, 3
	HAVING EXTRACT(EPOCH FROM (ended_at - started_at)) < '60'
)
SELECT
  member_casual,
  rideable_type,
  COUNT(trip_time) AS instant_bike_return
FROM instant
GROUP BY member_casual, rideable_type
ORDER BY instant_bike_return DESC;


-- average ride duration exclude instant return -- VIZ 5
WITH instant AS (
	SELECT
	  member_casual,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	)
SELECT
  member_casual,
  AVG(trip_time)/60 AS average_trip_minutes
FROM instant
WHERE trip_time >= '60'
GROUP BY member_casual;


-- popular start station
WITH popular_start AS (
	SELECT member_casual, start_station_id, COUNT(*) AS popularity, start_lat, start_lng
	FROM biketrip
	GROUP BY 1, 2, 4, 5
	ORDER BY COUNT(*) DESC
)
SELECT member_casual, popularity, start_station_id, start_lat, start_lng
FROM popular_start
WHERE start_station_id IS NOT NULL
ORDER BY popularity DESC;


-- route of popularity over 500 -- VIZ 6
WITH popular_route AS (
	SELECT
	  rideable_type,
	  member_casual,
	  CONCAT(start_station_id, ' to ', end_station_id) AS route
	FROM biketrip
	WHERE
	  start_station_id IS NOT NULL AND
	  end_station_id IS NOT NULL	
)
SELECT rideable_type, member_casual, route, COUNT(route) AS route_count
FROM popular_route
GROUP BY rideable_type, member_casual, route
HAVING COUNT(route) >= '500'
ORDER BY route_count DESC


-- top 100 popular route
SELECT member_casual, COUNT(member_casual)
FROM (
	WITH popular_route AS (
		SELECT
		  rideable_type,
		  member_casual,
		  CONCAT(start_station_id, ' to ', end_station_id) AS route
		FROM biketrip
		WHERE
		  start_station_id IS NOT NULL AND
		  end_station_id IS NOT NULL	
	)
	SELECT rideable_type, member_casual, route, COUNT(route) AS route_count
	FROM popular_route
	GROUP BY rideable_type, member_casual, route
	ORDER BY route_count DESC
	LIMIT 100
) t
GROUP BY member_casual;


-- find duration of same location return
WITH same_location AS (
	SELECT
	  member_casual,
	  rideable_type,
	  start_station_id,
	  end_station_id,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	WHERE
	  start_station_id IS NOT NULL AND
	  end_station_id IS NOT NULL
	GROUP BY
	  member_casual,
	  rideable_type,
	  start_station_id,
	  end_station_id,
	  EXTRACT(EPOCH FROM (ended_at - started_at))
	)
SELECT
  member_casual,
  rideable_type,
  start_station_id,
  end_station_id,  
  trip_time
FROM same_location
WHERE start_station_id = end_station_id
ORDER BY trip_time DESC;


-- member_casual for same location return
WITH same_location AS (
	SELECT
	  member_casual,
	  rideable_type,
	  start_station_id,
	  end_station_id,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time
	FROM biketrip
	WHERE
	  start_station_id IS NOT NULL AND
	  end_station_id IS NOT NULL
	GROUP BY
	  member_casual,
	  rideable_type,
	  start_station_id,
	  end_station_id,
	  EXTRACT(EPOCH FROM (ended_at - started_at))
	)
SELECT member_casual, COUNT(trip_time)
FROM same_location
GROUP BY member_casual;


-- ride in day of week -- VIZ 7
WITH dateofweek AS(
  SELECT member_casual, EXTRACT(DOW FROM started_at) AS dow
  FROM biketrip
)
SELECT member_casual,
  CASE
	WHEN dow = 0 THEN 'Sunday'
	WHEN dow = 1 THEN 'Monday'
	WHEN dow = 2 THEN 'Tuesday'
	WHEN dow = 3 THEN 'Wednesday'
	WHEN dow = 4 THEN 'Thursday'
	WHEN dow = 5 THEN 'Friday'
	WHEN dow = 6 THEN 'Saturday'
    ELSE 'others'
  END AS date_of_week,
  COUNT(dow)
FROM dateofweek
GROUP BY member_casual, dow
ORDER BY COUNT(dow) DESC;


-- duration in  day of week
WITH dow_d AS (
	SELECT
	  member_casual,
	  EXTRACT(EPOCH FROM (ended_at - started_at)) AS trip_time,
	  EXTRACT(DOW FROM started_at) AS dow
	FROM biketrip
	)
SELECT
  member_casual,
  dow,
  AVG(trip_time)/60 AS average_trip_minutes
FROM dow_d
WHERE trip_time >= '60'
GROUP BY member_casual, dow
ORDER BY average_trip_minutes DESC;


-- ride by hours -- VIZ 8
WITH hours AS(
  SELECT member_casual, EXTRACT(HOUR FROM started_at) AS bike_hour
  FROM biketrip
)
SELECT member_casual, bike_hour, COUNT(bike_hour)
FROM hours
GROUP BY member_casual, bike_hour
ORDER BY COUNT(bike_hour) DESC;


-- avg distance -- VIZ 9
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
WITH bd AS (
SELECT member_casual, (point(start_lng, start_lat)<@>point(end_lng, end_lat)) * 1.609344 AS distance
FROM biketrip
WHERE
  start_lng IS NOT NULL AND
  start_lat IS NOT NULL AND
  end_lng IS NOT NULL AND
  end_lat IS NOT NULL AND
  (point(start_lng, start_lat)<@>point(end_lng, end_lat)) * 1.609344 <> '0' -- convert miles to KM
)
SELECT member_casual, AVG(distance) AS avg_ride_km
FROM bd
GROUP BY member_casual;
