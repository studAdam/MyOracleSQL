CREATE OR REPLACE TRIGGER trg_update_trip_status
BEFORE UPDATE OF TripStatus ON Trips
FOR EACH ROW
DECLARE
    v_bus_id            Buses.BusID%TYPE;
    v_company_id        Companies.CompanyID%TYPE;

    v_new_status        VARCHAR2(50);
    v_old_status        VARCHAR2(50);
    v_revenue           NUMBER;
    v_passenger_count   NUMBER;
BEGIN
    v_new_status := UPPER(TO_CHAR(:NEW.TripStatus));
    v_old_status := UPPER(TO_CHAR(:OLD.TripStatus));

    IF v_new_status NOT IN ('SCHEDULED', 'END', 'CANCELLED') THEN
            RAISE_APPLICATION_ERROR(-20013, 'Invalid TripStatus for Trip (' || :NEW.TripID || '): ' || :NEW.TripStatus);
    END IF;

    -- Cannot change status if the trip is ended
    IF v_old_status = 'END' THEN
        RAISE_APPLICATION_ERROR(-20008, 'Cannot change status of TripID: ' || :NEW.TripID || ' as it is already Ended.');
    END IF;

    BEGIN
        SELECT      BusID, CompanyID
        INTO        v_bus_id, v_company_id
        FROM        Buses
        WHERE       BusID = :NEW.BusID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'No bus or company found for TripID: ' || :NEW.TripID);
    END;

    SELECT  COUNT(BD.TicketID)
    INTO    v_passenger_count
    FROM    Tickets T 
    JOIN    BookingDetails BD ON BD.TicketID = T.TicketID
    WHERE   T.TripID = :NEW.TripID
    AND     BD.RefundID IS NULL
    AND     (UPPER(BD.Status) IN ('BOOKED','TRANSFERRED'));

    -- Trip cannot start if number of passengers is less than 15
    IF v_new_status = 'END' AND v_passenger_count < 15 THEN
        RAISE_APPLICATION_ERROR(-20009, 'Cannot set Trip (' || :NEW.TripID || ') to End. Passenger count (' || v_passenger_count || ') is less than 15. Only Cancelled is allowed.');
    END IF;

    IF  v_old_status = 'PLANNING' AND v_new_status = 'SCHEDULED' THEN
        IF :NEW.AvailableSeats < 15 THEN
            RAISE_APPLICATION_ERROR(-20009, 'Cannot set Trip (' || :NEW.TripID || ') to Scheduled. Available seats (' || :NEW.AvailableSeats || ') is less than 15. Please add more available seats.');
        END IF;

    ELSIF v_old_status = 'SCHEDULED' AND v_new_status = 'END' THEN
        UPDATE  Buses
        SET     TravelledDistance = TravelledDistance + :NEW.Distance
        WHERE   BusID = v_bus_id;

        SELECT  SUM(T.Price) +
                SUM(CASE WHEN BD.ExtensionID IS NOT NULL THEN E.ExtensionFees ELSE 0 END) -
                SUM(CASE WHEN BD.RefundID IS NOT NULL THEN R.RefundAmount ELSE 0 END)
        INTO        v_revenue
        FROM        BookingDetails BD
        JOIN        Tickets T       ON  T.TicketID = BD.TicketID
        JOIN        Bookings B      ON  B.BookingID = BD.BookingID
        LEFT JOIN   Extensions E    ON  E.ExtensionID = BD.ExtensionID
        LEFT JOIN   Refunds R       ON  R.RefundID = BD.RefundID
        WHERE       T.TripID = :NEW.TripID;

        UPDATE  Companies
        SET     CompanyRevenue = CompanyRevenue + v_revenue
        WHERE   CompanyID = v_company_id;

    ELSIF v_new_status != 'CANCELLED' AND v_passenger_count < 15 THEN
        RAISE_APPLICATION_ERROR(-20010, 'TripID: ' || 
                                :NEW.TripID || ' has ' ||
                                 v_passenger_count ||
                                  ' passengers (< 15). Only Cancelled status is allowed.');

    END IF;
END;
/

DROP TABLE Trips_Audit;

CREATE TABLE Trips_Audit(
    Trips_AuditID       NUMBER(6)           PRIMARY KEY,
    TripID	            NUMBER(6)           NOT NULL,
    TripDateTime        DATE                NOT NULL,
    NewTripDateTime     DATE                DEFAULT NULL,
    StartTerminal       VARCHAR(100)        NOT NULL,
    NewStartTerminal    VARCHAR(100)        DEFAULT NULL,
    EndTerminal         VARCHAR(100)        NOT NULL,
    NewEndTerminal      VARCHAR(100)        DEFAULT NULL,
    Distance            NUMBER(10,2)        NOT NULL,
    NewDistance         NUMBER(10,2)        DEFAULT NULL,
    AvailableSeats      NUMBER(3)           DEFAULT 0   NOT NULL,
    NewAvailableSeats   NUMBER(3)           DEFAULT NULL,
    TripStatus          VARCHAR(20)         DEFAULT 'Upcoming'    NOT NULL,
    NewTripStatus       VARCHAR(20)         DEFAULT NULL,
    BusID               NUMBER(6)           NOT NULL,       
    NewBusID            NUMBER(6)           DEFAULT NULL,       
    UserID              VARCHAR(30)         NOT NULL,   
    TransDate           DATE                NOT NULL,
    TransTime           CHAR(8)             NOT NULL,
    TransAction         VARCHAR(6)          NOT NULL    
);

DROP SEQUENCE trips_auditid_seq;
CREATE SEQUENCE trips_auditid_seq
    INCREMENT BY 1
    START WITH 100000;

CREATE OR REPLACE TRIGGER trg_track_Trips
AFTER INSERT OR UPDATE OR DELETE ON Trips
FOR EACH ROW
BEGIN     
    CASE
     WHEN INSERTING THEN
       INSERT INTO Trips_Audit(
           Trips_AuditID,
           TripID,
           TripDateTime,
           StartTerminal,
           EndTerminal,
           Distance,
           AvailableSeats,
           TripStatus,
           BusID,
           UserID,
           TransDate,
           TransTime,
           TransAction
       )   
       VALUES(
           trips_auditid_seq.NEXTVAL,
           :NEW.TripID,
           :NEW.TripDateTime,
           :NEW.StartTerminal,
           :NEW.EndTerminal,
           :NEW.Distance,
           :NEW.AvailableSeats,
           :NEW.TripStatus,
           :NEW.BusID,
           USER, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), 'INSERT'
       );
     WHEN UPDATING THEN
       INSERT INTO Trips_Audit
       VALUES(
           trips_auditid_seq.NEXTVAL,
           :OLD.TripID,
           :OLD.TripDateTime,
           :New.TripDateTime,
           :OLD.StartTerminal,
           :New.StartTerminal,
           :OLD.EndTerminal,
           :New.EndTerminal,
           :OLD.Distance,
           :New.Distance,
           :OLD.AvailableSeats,
           :New.AvailableSeats,
           :OLD.TripStatus,
           :New.TripStatus,
           :OLD.BusID,
           :New.BusID,
           USER, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), 'UPDATE');
     WHEN DELETING THEN
       INSERT INTO Trips_Audit(
           Trips_AuditID,
           TripID,
           TripDateTime,
           StartTerminal,
           EndTerminal,
           Distance,
           AvailableSeats,
           TripStatus,
           BusID,
           UserID,
           TransDate,
           TransTime,
           TransAction
       )
       VALUES(
           trips_auditid_seq.NEXTVAL,
           :OLD.TripID,
           :OLD.TripDateTime,
           :OLD.StartTerminal,
           :OLD.EndTerminal,
           :OLD.Distance,
           :OLD.AvailableSeats,
           :OLD.TripStatus,
           :OLD.BusID,
           USER, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), 'DELETE');
    END CASE;
END;
/