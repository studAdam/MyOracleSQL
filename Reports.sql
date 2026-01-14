SET SERVEROUTPUT ON
SET LINESIZE 120
SET PAGESIZE 200


-- Company Revenue across month year
CREATE OR REPLACE PROCEDURE prc_comp_rev_sum_rpt (
    p_startDate IN  CHAR,
    p_endDate   IN  CHAR
)
IS
    v_total_net_revenue NUMBER(13,2);
    v_total_revenue     NUMBER(14,2);

    CURSOR compCursor IS
        SELECT B.CompanyID, A.CompanyName
        FROM Companies A,
            (
                SELECT DISTINCT B.CompanyID
                FROM Trips TP, Buses B
                WHERE TP.BusID = B.BusID
                AND
                    (TripDateTime BETWEEN 
                    TO_DATE(p_startDate,'dd/mm/yyyy') AND TO_DATE(p_endDate, 'dd/mm/yyyy'))
            ) B
        WHERE A.CompanyID = B.CompanyID
        ORDER BY CompanyName;

    compRec compCursor%ROWTYPE;

    CURSOR revCursor IS
        SELECT 
            EXTRACT(YEAR FROM TP.TripDateTime) AS "Year", 
            TO_CHAR(TP.TripDateTime, 'FMMonth') AS "Month",
            SUM(T.Price) AS "Gross Amount",
            SUM(E.ExtensionFees) AS "Extension Fees",
            SUM(R.RefundAmount) AS "Refund Amount",
            SUM(T.Price) + SUM(E.ExtensionFees) - SUM(R.RefundAmount) AS "Net Revenue"
        FROM Trips TP
        JOIN Buses B ON TP.BusID = B.BusID
        JOIN Tickets T ON T.TripID = TP.TripID
        JOIN BookingDetails BD ON BD.TicketID = T.TicketID
        JOIN Extensions E ON E.ExtensionID = BD.ExtensionID
        JOIN Refunds R ON R.RefundID = BD.RefundID
        WHERE B.CompanyID = compRec.CompanyID
        AND (TP.TripDateTime BETWEEN 
                    TO_DATE(p_startDate,'dd/mm/yyyy') AND TO_DATE(p_endDate, 'dd/mm/yyyy'))
        GROUP BY 
            B.CompanyID,
            EXTRACT(YEAR FROM TP.TripDateTime), 
            TO_CHAR(TP.TripDateTime, 'FMMonth')
        ORDER BY "Year", "Month";

    revRec revCursor%ROWTYPE;

BEGIN
    OPEN compCursor;
    v_total_revenue:= 0;
    LOOP
        FETCH compCursor INTO compRec;
        EXIT WHEN compCursor%NOTFOUND;

        --Header
        DBMS_OUTPUT.PUT_LINE(LPAD(':',120,':'));
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        DBMS_OUTPUT.PUT_LINE('Company: '|| compRec.CompanyName);
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        DBMS_OUTPUT.PUT_LINE(LPAD('=',120,'='));

        --Heading
        DBMS_OUTPUT.PUT_LINE(
            RPAD('Year-Month',14,' ') || ' ' ||
            LPAD('Gross Amount',25,' ') || ' ' ||
            LPAD('Extension Fees',25,' ') || ' ' ||
            LPAD('Refund Amount',25,' ') || ' ' ||
            LPAD('Net Revenue',27,' ')
        );
        DBMS_OUTPUT.PUT_LINE(LPAD('=',120,'='));

        --Body
        OPEN revCursor;
        v_total_net_revenue := 0;
        LOOP
            FETCH revCursor INTO revRec;
            IF (revCursor%ROWCOUNT = 0) THEN
                DBMS_OUTPUT.PUT_LINE('Company '|| compRec.CompanyName || ' is not found.');
            END IF;
            EXIT WHEN revCursor%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE(
                RPAD(revRec."Year" ||'-'||revRec."Month",14,' ') || ' ' ||
                LPAD(TO_CHAR(revRec."Gross Amount",'$9,999,999,999.99'),25,' ') || ' ' ||
                LPAD(TO_CHAR(revRec."Extension Fees",'$9,999,999,999.99'),25,' ') || ' ' ||
                LPAD(TO_CHAR(revRec."Refund Amount",'$9,999,999,999.99'),25,' ') || ' ' ||
                LPAD(TO_CHAR(revRec."Net Revenue",'$9,999,999,999.99'),27,' ')
            );
            v_total_net_revenue := v_total_net_revenue + revRec."Net Revenue";
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(LPAD('=',120,'='));
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        DBMS_OUTPUT.PUT_LINE('Total net revenue: '|| TO_CHAR(v_total_net_revenue,'$99,999,999,999.99'));
        CLOSE revCursor;
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        
        DBMS_OUTPUT.PUT_LINE(LPAD('-',120,'-'));
        DBMS_OUTPUT.PUT_LINE(LPAD('-',120,'-'));

        v_total_revenue := v_total_revenue + v_total_net_revenue;
        
    END LOOP;

    --Footer
    DBMS_OUTPUT.PUT_LINE(CHR(5));
    DBMS_OUTPUT.PUT_LINE('Total revenue: '|| TO_CHAR(v_total_revenue,'$999,999,999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Total number of companies: '|| compCursor%ROWCOUNT);
    CLOSE compCursor;
    DBMS_OUTPUT.PUT_LINE(CHR(5));
    DBMS_OUTPUT.PUT_LINE(LPAD('=',54,'=') || RPAD('End Of Report',66,'='));

END;
/

EXEC prc_comp_rev_sum_rpt('01/01/2024','31/12/2025');


-- Average route fares comparison across month year
CREATE OR REPLACE PROCEDURE prc_route_fares_sum_rpt (
    p_startDate IN  CHAR,
    p_endDate   IN  CHAR
)
IS
    v_total_route_fares     NUMBER(12,2);
    v_total_ticket_count    NUMBER(12);

    CURSOR routeCursor IS
        SELECT DISTINCT StartTerminal, EndTerminal
        FROM Trips
        WHERE (TripStatus = 'End' OR TripStatus = 'Scheduled')
        AND   
            (TripDateTime BETWEEN 
                    TO_DATE(p_startDate,'dd/mm/yyyy') AND TO_DATE(p_endDate, 'dd/mm/yyyy'))
        ORDER BY StartTerminal, EndTerminal;

    routeRec routeCursor%ROWTYPE;

    CURSOR priceCursor IS
        SELECT 
            EXTRACT(YEAR FROM TP.TripDateTime) AS "Year", 
            TO_CHAR(TP.TripDateTime, 'FMMonth') AS "Month",
            COUNT(T.TicketID) AS "Ticket Count",
            AVG(T.Price) AS "Average Fares"
        FROM Trips TP
        JOIN Tickets T ON TP.TripID = T.TripID
        WHERE (TripStatus = 'End' OR TripStatus = 'Scheduled')
        AND  (TP.TripDateTime BETWEEN 
                    TO_DATE(p_startDate,'dd/mm/yyyy') AND TO_DATE(p_endDate, 'dd/mm/yyyy'))
        AND  TP.StartTerminal = routeRec.StartTerminal
        AND  TP.EndTerminal = routeRec.EndTerminal
        GROUP BY 
            EXTRACT(YEAR FROM TP.TripDateTime), 
            TO_CHAR(TP.TripDateTime, 'FMMonth')
        ORDER BY "Year", "Month";

    priceRec priceCursor%ROWTYPE;

BEGIN
    OPEN routeCursor;
    LOOP
        FETCH routeCursor INTO routeRec;
        EXIT WHEN routeCursor%NOTFOUND;

        --Header
        DBMS_OUTPUT.PUT_LINE(LPAD(':',120,':'));
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        DBMS_OUTPUT.PUT_LINE('Route: '|| routeRec.StartTerminal||' -> '|| routeRec.EndTerminal);
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        DBMS_OUTPUT.PUT_LINE(LPAD('=',120,'='));

        --Heading
        DBMS_OUTPUT.PUT_LINE(
            RPAD('Year-Month',100,' ') || ' ' ||
            LPAD('Average fares',19,' ')
        );
        DBMS_OUTPUT.PUT_LINE(LPAD('=',120,'='));

        --Body
        OPEN priceCursor;
        v_total_route_fares := 0;
        v_total_ticket_count:= 0;
        LOOP
            FETCH priceCursor INTO priceRec;
            IF (priceCursor%ROWCOUNT = 0) THEN
                DBMS_OUTPUT.PUT_LINE('Route '|| routeRec.StartTerminal||
                    ' -> '|| routeRec.EndTerminal || ' is not found.');
            END IF;
            EXIT WHEN priceCursor%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE(
                RPAD(priceRec."Year" ||'-'||priceRec."Month",100,' ') || ' ' ||
                LPAD(TO_CHAR(priceRec."Average Fares",'$9,999.99'),19,' ')
            );
            v_total_ticket_count:= v_total_ticket_count + priceRec."Ticket Count";
            v_total_route_fares := v_total_route_fares + priceRec."Ticket Count" * priceRec."Average Fares";
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(LPAD('=',120,'='));
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        DBMS_OUTPUT.PUT_LINE('Average Fares over period ('||p_startDate||'-'||p_endDate||
            '): '|| TO_CHAR(v_total_route_fares / v_total_ticket_count,'$9,990.99'));
        CLOSE priceCursor;
        DBMS_OUTPUT.PUT_LINE(CHR(5));
        
        DBMS_OUTPUT.PUT_LINE(LPAD('-',120,'-'));
        DBMS_OUTPUT.PUT_LINE(LPAD('-',120,'-'));
        
    END LOOP;

    --Footer
    DBMS_OUTPUT.PUT_LINE(CHR(5));
    DBMS_OUTPUT.PUT_LINE('Total number of routes: '|| routeCursor%ROWCOUNT);
    CLOSE routeCursor;
    DBMS_OUTPUT.PUT_LINE(CHR(5));
    DBMS_OUTPUT.PUT_LINE(LPAD('=',54,'=') || RPAD('End Of Report',66,'='));

END;
/

EXEC prc_route_fares_sum_rpt('01/01/2024','31/12/2025');