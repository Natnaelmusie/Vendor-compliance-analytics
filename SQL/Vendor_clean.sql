-- VENDOR DELIVERY COMPLIANCE — ANALYSIS VIEWS
-- Source table: Inbound_data (cleaned in Python, loaded to SQLite)
-- =====================================================================

-- Remove the earlier view names (superseded by the cleaned names below)
DROP VIEW IF EXISTS Late_date_trends_day;
DROP VIEW IF EXISTS Late_date_trends_month;
DROP VIEW IF EXISTS Late_time_trends;
DROP VIEW IF EXISTS vendor_trend_month;
DROP VIEW IF EXISTS vendor_trend_lateness;


-- =====================================================================
-- FOUNDATION VIEW
-- Adds time_variance (arrival minus booked, in minutes) to every row.
-- Negative = early, positive = late. All analysis builds on this.
-- =====================================================================
DROP VIEW IF EXISTS delivery_analysis;
CREATE VIEW delivery_analysis AS
SELECT *,
       (strftime('%H', Arrival_time)   * 60 + strftime('%M', Arrival_time))
     - (strftime('%H', Booked_In_Time) * 60 + strftime('%M', Booked_In_Time)) AS time_variance
FROM Inbound_data;


-- =====================================================================
-- Q1: Vendor on-time rate
-- Which vendors deliver on time, and which are the worst offenders?
-- =====================================================================
DROP VIEW IF EXISTS on_time_delivery_rates;
CREATE VIEW on_time_delivery_rates AS
SELECT Vendor                                                       AS vendor,
       COUNT(*)                                                     AS total_deliveries,
       SUM(CASE WHEN Compliance_code = 'ONT' THEN 1 ELSE 0 END)     AS ontime_deliveries,
       SUM(CASE WHEN Compliance_code = 'ONT' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS on_time_rate
FROM delivery_analysis
GROUP BY Vendor
ORDER BY on_time_rate ASC;


-- =====================================================================
-- Q3: Vendor compliance breakdown
-- For each vendor, how do deliveries split across on-time, early, and
-- the three lateness bands? Surfaces who drives the severe lateness.
-- Bands: LATE_01 = 0-1hr, LATE_02 = 1-24hr, LATE_03 = 24hr+ (delayed)
-- =====================================================================
DROP VIEW IF EXISTS vendor_compliance_analysis;
CREATE VIEW vendor_compliance_analysis AS
SELECT Vendor                                                        AS vendor,
       SUM(CASE WHEN Compliance_code = 'ONT'     THEN 1 ELSE 0 END)   AS on_time,
       SUM(CASE WHEN Compliance_code = 'EARL'    THEN 1 ELSE 0 END)   AS early,
       SUM(CASE WHEN Compliance_code = 'LATE_01' THEN 1 ELSE 0 END)   AS late_under_1hr,
       SUM(CASE WHEN Compliance_code = 'LATE_02' THEN 1 ELSE 0 END)   AS late_1_to_24hr,
       SUM(CASE WHEN Compliance_code = 'LATE_03' THEN 1 ELSE 0 END)   AS late_severe_24hr_plus
FROM delivery_analysis
GROUP BY Vendor
ORDER BY late_severe_24hr_plus DESC;


-- =====================================================================
-- Q5a: Late rate by weekday  (0 = Sunday ... 6 = Saturday)
-- Do late's cluster on particular days? Volume is near-flat across
-- days, so the rate is a genuine signal rather than a volume artefact.
-- =====================================================================
DROP VIEW IF EXISTS late_rate_by_weekday;
CREATE VIEW late_rate_by_weekday AS
SELECT strftime('%w', Date)                                     AS weekday,
       COUNT(*)                                                 AS total_deliveries,
       SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END)        AS non_compliant_deliveries,
       SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS late_rate
FROM delivery_analysis
GROUP BY strftime('%w', Date);


-- =====================================================================
-- Q5b: Late rate by month  (01 ... 12)
-- Seasonal pattern. Volume is flat (~150/month), so the Nov/Dec climb
-- is a real operational signal, not driven by higher volume.
-- =====================================================================
DROP VIEW IF EXISTS late_rate_by_month;
CREATE VIEW late_rate_by_month AS
SELECT strftime('%m', Date)                                     AS month,
       COUNT(*)                                                 AS total_deliveries,
       SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END)        AS non_compliant_deliveries,
       SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS monthly_late_rate
FROM delivery_analysis
GROUP BY strftime('%m', Date);


-- =====================================================================
-- Q5c: Late rate by booked time slot
-- Does lateness cluster at certain slots? Open-slot bookings are
-- excluded (they were forced to 15:00 in cleaning, so they'd distort
-- the picture). NULL booked_in_time = unscheduled (100% non-compliant).
-- =====================================================================
DROP VIEW IF EXISTS late_rate_by_timeslot;
CREATE VIEW late_rate_by_timeslot AS
SELECT Booked_In_Time                                           AS booked_in_time,
       COUNT(*)                                                 AS total_deliveries,
       SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END)        AS non_compliant_deliveries,
       SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS late_rate
FROM delivery_analysis
WHERE Booking_type != 'Open_slot'
GROUP BY Booked_In_Time
ORDER BY late_rate DESC;


-- =====================================================================
-- Q4: Vendor lateness trend — month over month, per vendor
-- Is each vendor improving or deteriorating? monthly_change = this
-- month's rate minus the same vendor's previous month (positive =
-- worse). January is NULL (no prior month). CTE computes the rate
-- once; the window function reads it partitioned per vendor.
-- =====================================================================
DROP VIEW IF EXISTS vendor_lateness_trend;
CREATE VIEW vendor_lateness_trend AS
WITH vendor_rates AS (
    SELECT strftime('%m', Date)                                 AS month,
           Vendor                                               AS vendor,
           SUM(CASE WHEN Compliant = 'No' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS monthly_late_rate
    FROM delivery_analysis
    GROUP BY Vendor, month
)
SELECT month,
       vendor,
       monthly_late_rate,
       monthly_late_rate
         - LAG(monthly_late_rate) OVER (PARTITION BY vendor ORDER BY month) AS monthly_change
FROM vendor_rates;


-- =====================================================================
-- Q2: Warehouse lateness trend — month over month, whole operation
-- Overall momentum: how fast is lateness rising or falling each month?
-- The Oct/Nov jumps are why October is the early-warning point.
-- Reads the already-computed monthly rate from late_rate_by_month.
-- =====================================================================
DROP VIEW IF EXISTS monthly_lateness_trend;
CREATE VIEW monthly_lateness_trend AS
SELECT month,
       monthly_late_rate - LAG(monthly_late_rate) OVER (ORDER BY month) AS monthly_change
FROM late_rate_by_month;


-- =====================================================================
-- OPTIONAL sanity checks — uncomment to eyeball any view
-- =====================================================================
-- SELECT * FROM on_time_delivery_rates;
-- SELECT * FROM vendor_compliance_analysis;
-- SELECT * FROM late_rate_by_weekday;
-- SELECT * FROM late_rate_by_month;
-- SELECT * FROM late_rate_by_timeslot;
-- SELECT * FROM vendor_lateness_trend;
-- SELECT * FROM monthly_lateness_trend;
