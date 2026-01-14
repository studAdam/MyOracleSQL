DROP INDEX trip_status_index;
CREATE INDEX trip_status_index
ON Trips(UPPER(TripStatus));

DROP INDEX bookingDetails_status_index;
CREATE INDEX bookingDetails_status_index
ON BookingDetails(UPPER(Status));

-- Tactical Level (to manage bus assignment and trip schedule efficiently)
CREATE OR REPLACE VIEW low_pas_load_trip AS
SELECT      TP.TripDateTime,
            TP.TripID,
            TP.AvailableSeats AS "Empty Slot Amount",
            COUNT(BD.PassengerIC) AS "Passenger Count",
            COUNT(BD.PassengerIC) / (TP.AvailableSeats + COUNT(BD.PassengerIC)) AS "Passenger Load Factor"
FROM        Trips           TP 
JOIN        Tickets         T   ON  T.TripID        = TP.TripID
JOIN        BookingDetails  BD  ON  BD.TicketID     = T.TicketID
WHERE       BD.RefundID IS NULL
AND         (UPPER(BD.Status) IN ('BOOKED','TRANSFERRED'))
AND         UPPER(TP.TripStatus) = 'END'     
GROUP BY    TP.TripDateTime, TP.TripID, TP.AvailableSeats
HAVING      COUNT(BD.PassengerIC) / (TP.AvailableSeats + COUNT(BD.PassengerIC)) < 0.4
ORDER BY    "Passenger Count" DESC, "Empty Slot Amount"
WITH READ ONLY CONSTRAINT low_pas_load_route_readOnly;


COLUMN CompanyName FORMAT A26
COLUMN BusType FORMAT A10
COLUMN Route FORMAT A25
COLUMN TripID FORMAT 999999
COLUMN PLF FORMAT 0.9999

SELECT  LPLT.TripID,
        T.StartTerminal || ' -> ' || T.EndTerminal AS "Route",
        C.CompanyName, B.BusType,
        LPLT."Passenger Load Factor" AS PLF
FROM    low_pas_load_trip  LPLT
JOIN    Trips               T       ON  T.TripID    = LPLT.TripID
JOIN    Buses               B       ON  B.BusID     = T.BusID
JOIN    Companies           C       ON  C.CompanyID = B.CompanyID
WHERE   LPLT.TripDateTime BETWEEN TO_DATE('01/01/2025','dd/mm/yyyy') AND TO_DATE('31/12/2025','dd/mm/yyyy');

-- Operational Level (Passenger Yield assess the effectiveness of pricing strategies, 
-- evaluate the profitability of routes, and 
-- make informed decisions about revenue management and capacity)
CREATE OR REPLACE VIEW py_per_rpk_trip AS
SELECT      TP.TripDateTime,
            TP.TripID,
            SUM(T.Price) AS "Revenue",
            COUNT(BD.PassengerIC) AS "Passenger Count",
            COUNT(BD.PassengerIC) * TP.Distance AS "Revenue Passenger Kilometer",
            SUM(T.Price) / (COUNT(BD.PassengerIC) * TP.Distance) AS "Revenue per RPK"
FROM        Trips           TP
JOIN        Tickets         T   ON  T.TripID        = TP.TripID
JOIN        BookingDetails  BD  ON  BD.TicketID     = T.TicketID
WHERE       BD.RefundID IS NULL
AND         (UPPER(BD.Status) IN ('BOOKED','TRANSFERRED'))
AND         UPPER(TP.TripStatus) = 'END'
GROUP BY    TP.TripDateTime, TP.TripID, TP.Distance
ORDER BY    "Revenue per RPK" DESC
WITH READ ONLY CONSTRAINT py_per_rpk_trip_readOnly;

COLUMN CompanyName FORMAT A26
COLUMN Route FORMAT A25
COLUMN TripID FORMAT 999999
COLUMN PY FORMAT 0.9999

SELECT  PPRT.TripID,
        T.StartTerminal || ' -> ' || T.EndTerminal AS "Route",
        C.CompanyName, 
        PPRT."Revenue per RPK" AS PY
FROM    py_per_rpk_trip     PPRT
JOIN    Trips               T       ON  T.TripID    = PPRT.TripID
JOIN    Buses               B       ON  B.BusID     = T.BusID
JOIN    Companies           C       ON  C.CompanyID = B.CompanyID
WHERE   PPRT.TripDateTime BETWEEN TO_DATE('01/01/2025','dd/mm/yyyy') AND TO_DATE('31/12/2025','dd/mm/yyyy');
