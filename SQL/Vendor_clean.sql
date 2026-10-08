<html>
<head>
<title>console.sql</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style type="text/css">
.s0 { color: #7a7e85;}
.s1 { color: #bcbec4;}
.s2 { color: #cf8e6d;}
.s3 { color: #bcbec4;}
.s4 { color: #6aab73;}
.s5 { color: #2aacb8;}
</style>
</head>
<body bgcolor="#191a1c">
<table CELLSPACING=0 CELLPADDING=5 COLS=1 WIDTH="100%" BGCOLOR="#606060" >
<tr><td><center>
<font face="Arial, Helvetica" color="#000000">
console.sql</font>
</center></td></tr></table>
<pre><span class="s0">-- VENDOR DELIVERY COMPLIANCE — ANALYSIS VIEWS</span>
<span class="s0">-- Source table: Inbound_data (cleaned in Python, loaded to SQLite)</span>
<span class="s0">-- =====================================================================</span>

<span class="s0">-- Remove the earlier view names (superseded by the cleaned names below)</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">Late_date_trends_day</span><span class="s3">;</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">Late_date_trends_month</span><span class="s3">;</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">Late_time_trends</span><span class="s3">;</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">vendor_trend_month</span><span class="s3">;</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">vendor_trend_lateness</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- FOUNDATION VIEW</span>
<span class="s0">-- Adds time_variance (arrival minus booked, in minutes) to every row.</span>
<span class="s0">-- Negative = early, positive = late. All analysis builds on this.</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">delivery_analysis</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">delivery_analysis </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">*</span><span class="s3">,</span>
       <span class="s3">(</span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%H'</span><span class="s3">, </span><span class="s1">Arrival_time</span><span class="s3">)   </span><span class="s1">* </span><span class="s5">60 </span><span class="s1">+ strftime</span><span class="s3">(</span><span class="s4">'%M'</span><span class="s3">, </span><span class="s1">Arrival_time</span><span class="s3">))</span>
     <span class="s1">- </span><span class="s3">(</span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%H'</span><span class="s3">, </span><span class="s1">Booked_In_Time</span><span class="s3">) </span><span class="s1">* </span><span class="s5">60 </span><span class="s1">+ strftime</span><span class="s3">(</span><span class="s4">'%M'</span><span class="s3">, </span><span class="s1">Booked_In_Time</span><span class="s3">)) </span><span class="s2">AS </span><span class="s1">time_variance</span>
<span class="s2">FROM </span><span class="s1">Inbound_data</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q1: Vendor on-time rate</span>
<span class="s0">-- Which vendors deliver on time, and which are the worst offenders?</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">on_time_delivery_rates</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">on_time_delivery_rates </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">Vendor                                                       </span><span class="s2">AS </span><span class="s1">vendor</span><span class="s3">,</span>
       <span class="s1">COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">)                                                     </span><span class="s2">AS </span><span class="s1">total_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'ONT' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)     </span><span class="s2">AS </span><span class="s1">ontime_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'ONT' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">) </span><span class="s1">* </span><span class="s5">100.0 </span><span class="s1">/ COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">on_time_rate</span>
<span class="s2">FROM </span><span class="s1">delivery_analysis</span>
<span class="s2">GROUP BY </span><span class="s1">Vendor</span>
<span class="s2">ORDER BY </span><span class="s1">on_time_rate </span><span class="s2">ASC</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q3: Vendor compliance breakdown</span>
<span class="s0">-- For each vendor, how do deliveries split across on-time, early, and</span>
<span class="s0">-- the three lateness bands? Surfaces who drives the severe lateness.</span>
<span class="s0">-- Bands: LATE_01 = 0-1hr, LATE_02 = 1-24hr, LATE_03 = 24hr+ (delayed)</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">vendor_compliance_analysis</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">vendor_compliance_analysis </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">Vendor                                                        </span><span class="s2">AS </span><span class="s1">vendor</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'ONT'     </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)   </span><span class="s2">AS </span><span class="s1">on_time</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'EARL'    </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)   </span><span class="s2">AS </span><span class="s1">early</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'LATE_01' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)   </span><span class="s2">AS </span><span class="s1">late_under_1hr</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'LATE_02' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)   </span><span class="s2">AS </span><span class="s1">late_1_to_24hr</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliance_code = </span><span class="s4">'LATE_03' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)   </span><span class="s2">AS </span><span class="s1">late_severe_24hr_plus</span>
<span class="s2">FROM </span><span class="s1">delivery_analysis</span>
<span class="s2">GROUP BY </span><span class="s1">Vendor</span>
<span class="s2">ORDER BY </span><span class="s1">late_severe_24hr_plus </span><span class="s2">DESC</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q5a: Late rate by weekday  (0 = Sunday ... 6 = Saturday)</span>
<span class="s0">-- Do late's cluster on particular days? Volume is near-flat across</span>
<span class="s0">-- days, so the rate is a genuine signal rather than a volume artefact.</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">late_rate_by_weekday</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">late_rate_by_weekday </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%w'</span><span class="s3">, </span><span class="s2">Date</span><span class="s3">)                                     </span><span class="s2">AS </span><span class="s1">weekday</span><span class="s3">,</span>
       <span class="s1">COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">)                                                 </span><span class="s2">AS </span><span class="s1">total_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)        </span><span class="s2">AS </span><span class="s1">non_compliant_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">) </span><span class="s1">* </span><span class="s5">100.0 </span><span class="s1">/ COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">late_rate</span>
<span class="s2">FROM </span><span class="s1">delivery_analysis</span>
<span class="s2">GROUP BY </span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%w'</span><span class="s3">, </span><span class="s2">Date</span><span class="s3">);</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q5b: Late rate by month  (01 ... 12)</span>
<span class="s0">-- Seasonal pattern. Volume is flat (~150/month), so the Nov/Dec climb</span>
<span class="s0">-- is a real operational signal, not driven by higher volume.</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">late_rate_by_month</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">late_rate_by_month </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%m'</span><span class="s3">, </span><span class="s2">Date</span><span class="s3">)                                     </span><span class="s2">AS </span><span class="s1">month</span><span class="s3">,</span>
       <span class="s1">COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">)                                                 </span><span class="s2">AS </span><span class="s1">total_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)        </span><span class="s2">AS </span><span class="s1">non_compliant_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">) </span><span class="s1">* </span><span class="s5">100.0 </span><span class="s1">/ COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">monthly_late_rate</span>
<span class="s2">FROM </span><span class="s1">delivery_analysis</span>
<span class="s2">GROUP BY </span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%m'</span><span class="s3">, </span><span class="s2">Date</span><span class="s3">);</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q5c: Late rate by booked time slot</span>
<span class="s0">-- Does lateness cluster at certain slots? Open-slot bookings are</span>
<span class="s0">-- excluded (they were forced to 15:00 in cleaning, so they'd distort</span>
<span class="s0">-- the picture). NULL booked_in_time = unscheduled (100% non-compliant).</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">late_rate_by_timeslot</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">late_rate_by_timeslot </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">Booked_In_Time                                           </span><span class="s2">AS </span><span class="s1">booked_in_time</span><span class="s3">,</span>
       <span class="s1">COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">)                                                 </span><span class="s2">AS </span><span class="s1">total_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">)        </span><span class="s2">AS </span><span class="s1">non_compliant_deliveries</span><span class="s3">,</span>
       <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">) </span><span class="s1">* </span><span class="s5">100.0 </span><span class="s1">/ COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">late_rate</span>
<span class="s2">FROM </span><span class="s1">delivery_analysis</span>
<span class="s2">WHERE </span><span class="s1">Booking_type != </span><span class="s4">'Open_slot'</span>
<span class="s2">GROUP BY </span><span class="s1">Booked_In_Time</span>
<span class="s2">ORDER BY </span><span class="s1">late_rate </span><span class="s2">DESC</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q4: Vendor lateness trend — month over month, per vendor</span>
<span class="s0">-- Is each vendor improving or deteriorating? monthly_change = this</span>
<span class="s0">-- month's rate minus the same vendor's previous month (positive =</span>
<span class="s0">-- worse). January is NULL (no prior month). CTE computes the rate</span>
<span class="s0">-- once; the window function reads it partitioned per vendor.</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">vendor_lateness_trend</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">vendor_lateness_trend </span><span class="s2">AS</span>
<span class="s2">WITH </span><span class="s1">vendor_rates </span><span class="s2">AS </span><span class="s3">(</span>
    <span class="s2">SELECT </span><span class="s1">strftime</span><span class="s3">(</span><span class="s4">'%m'</span><span class="s3">, </span><span class="s2">Date</span><span class="s3">)                                 </span><span class="s2">AS </span><span class="s1">month</span><span class="s3">,</span>
           <span class="s1">Vendor                                               </span><span class="s2">AS </span><span class="s1">vendor</span><span class="s3">,</span>
           <span class="s1">SUM</span><span class="s3">(</span><span class="s2">CASE WHEN </span><span class="s1">Compliant = </span><span class="s4">'No' </span><span class="s2">THEN </span><span class="s5">1 </span><span class="s2">ELSE </span><span class="s5">0 </span><span class="s2">END</span><span class="s3">) </span><span class="s1">* </span><span class="s5">100.0 </span><span class="s1">/ COUNT</span><span class="s3">(</span><span class="s1">*</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">monthly_late_rate</span>
    <span class="s2">FROM </span><span class="s1">delivery_analysis</span>
    <span class="s2">GROUP BY </span><span class="s1">Vendor</span><span class="s3">, </span><span class="s1">month</span>
<span class="s3">)</span>
<span class="s2">SELECT </span><span class="s1">month</span><span class="s3">,</span>
       <span class="s1">vendor</span><span class="s3">,</span>
       <span class="s1">monthly_late_rate</span><span class="s3">,</span>
       <span class="s1">monthly_late_rate</span>
         <span class="s1">- LAG</span><span class="s3">(</span><span class="s1">monthly_late_rate</span><span class="s3">) </span><span class="s2">OVER </span><span class="s3">(</span><span class="s2">PARTITION BY </span><span class="s1">vendor </span><span class="s2">ORDER BY </span><span class="s1">month</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">monthly_change</span>
<span class="s2">FROM </span><span class="s1">vendor_rates</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- Q2: Warehouse lateness trend — month over month, whole operation</span>
<span class="s0">-- Overall momentum: how fast is lateness rising or falling each month?</span>
<span class="s0">-- The Oct/Nov jumps are why October is the early-warning point.</span>
<span class="s0">-- Reads the already-computed monthly rate from late_rate_by_month.</span>
<span class="s0">-- =====================================================================</span>
<span class="s2">DROP VIEW IF EXISTS </span><span class="s1">monthly_lateness_trend</span><span class="s3">;</span>
<span class="s2">CREATE VIEW </span><span class="s1">monthly_lateness_trend </span><span class="s2">AS</span>
<span class="s2">SELECT </span><span class="s1">month</span><span class="s3">,</span>
       <span class="s1">monthly_late_rate - LAG</span><span class="s3">(</span><span class="s1">monthly_late_rate</span><span class="s3">) </span><span class="s2">OVER </span><span class="s3">(</span><span class="s2">ORDER BY </span><span class="s1">month</span><span class="s3">) </span><span class="s2">AS </span><span class="s1">monthly_change</span>
<span class="s2">FROM </span><span class="s1">late_rate_by_month</span><span class="s3">;</span>


<span class="s0">-- =====================================================================</span>
<span class="s0">-- OPTIONAL sanity checks — uncomment to eyeball any view</span>
<span class="s0">-- =====================================================================</span>
<span class="s0">-- SELECT * FROM on_time_delivery_rates;</span>
<span class="s0">-- SELECT * FROM vendor_compliance_analysis;</span>
<span class="s0">-- SELECT * FROM late_rate_by_weekday;</span>
<span class="s0">-- SELECT * FROM late_rate_by_month;</span>
<span class="s0">-- SELECT * FROM late_rate_by_timeslot;</span>
<span class="s0">-- SELECT * FROM vendor_lateness_trend;</span>
<span class="s0">-- SELECT * FROM monthly_lateness_trend;</span></pre>
</body>
</html>