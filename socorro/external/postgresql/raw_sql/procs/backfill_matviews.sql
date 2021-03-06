CREATE OR REPLACE FUNCTION backfill_matviews(firstday date, lastday date DEFAULT NULL::date, reportsclean boolean DEFAULT true, check_period interval DEFAULT '01:00:00'::interval) RETURNS boolean
    LANGUAGE plpgsql
    SET "TimeZone" TO 'UTC'
    AS $$
DECLARE thisday DATE := firstday;
    last_rc timestamptz;
    first_rc timestamptz;
    last_adu DATE;
    tablename TEXT;
BEGIN
-- this producedure is meant to be called manually
-- by administrators in order to clear and backfill
-- the various matviews in order to recalculate old
-- data which was erroneous.
-- it requires a start date, and optionally an end date
-- no longer takes a product parameter
-- optionally disable reports_clean backfill
-- since that takes a long time

-- this is a temporary fix for matview backfill for mobeta
-- a more complete fix is coming in 19.0.

-- set start date for r_c
first_rc := firstday AT TIME ZONE 'UTC';

-- check parameters
IF firstday > current_date OR lastday > current_date THEN
    RAISE NOTICE 'date parameter error: cannot backfill into the future';
    RETURN FALSE;
END IF;

-- set optional end date
IF lastday IS NULL or lastday = current_date THEN
    last_rc := date_trunc('hour', now()) - INTERVAL '3 hours';
ELSE
    last_rc := ( lastday + 1 ) AT TIME ZONE 'UTC';
END IF;

-- check if lastday is after we have ADU;
-- if so, adjust lastday
SELECT max("date")
INTO last_adu
FROM raw_adi;

IF lastday > last_adu THEN
    RAISE INFO 'last day of backfill period is after final day of ADU.  adjusting last day to %',last_adu;
    lastday := last_adu;
END IF;

-- fill in products
PERFORM update_product_versions();

-- loop through the days, backfilling one at a time
WHILE thisday <= lastday LOOP
    RAISE INFO 'backfilling other matviews for %',thisday;
    RAISE INFO 'adu';
    PERFORM backfill_adu(thisday);
    PERFORM backfill_build_adu(thisday);
    thisday := thisday + 1;

END LOOP;

RETURN true;
END; $$;
