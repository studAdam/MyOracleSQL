DROP SEQUENCE refund_id_seq;
CREATE SEQUENCE refund_id_seq
    INCREMENT BY 1
    START WITH 10555;

DROP SEQUENCE ticket_id_seq;
CREATE SEQUENCE ticket_id_seq
    INCREMENT BY 1
    START WITH 15761;
-- cancel trip
CREATE OR REPLACE PROCEDURE prc_cancel_trip (
    p_trip_id IN Trips.TripID%TYPE
)
IS
    v_trip_status       Trips.TripStatus%TYPE;
    v_passenger_count   NUMBER;
    v_payment_amount    Payments.PaymentAmount%TYPE;
    v_refund_id         Refunds.RefundID%TYPE;
    
    -- Cursor to fetch all BookingDetails for the trip
    CURSOR booking_cursor IS
        SELECT  BD.BookingID, BD.TicketID, T.Price, P.PaymentMethod
        FROM    BookingDetails BD
        JOIN    Tickets T   ON BD.TicketID = T.TicketID
        JOIN    Bookings B  ON BD.BookingID = B.BookingID
        JOIN    Payments P  ON P.PaymentID = B.PaymentID
        WHERE   T.TripID = p_trip_id
        AND     BD.RefundID IS NULL
        AND     BD.ExtensionID IS NULL
        AND     UPPER(BD.Status) IN ('BOOKED','TRANSFERRED');
        
BEGIN
    SAVEPOINT start_cancel;-- checkpoint
    
    -- get status
    BEGIN
        SELECT TripStatus
        INTO v_trip_status
        FROM Trips
        WHERE TripID = p_trip_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Trip (' || p_trip_id || ') not found.');
            RAISE_APPLICATION_ERROR(-20001, 'Trip not found.');
    END;

    v_trip_status:= UPPER(v_trip_status);

    -- if not desired status
    IF v_trip_status = 'CANCELLED' THEN
        DBMS_OUTPUT.PUT_LINE('Error: Trip ( ' || p_trip_id || ') is already cancelled.');
        RAISE_APPLICATION_ERROR(-20002, 'Trip is already cancelled.');
    ELSIF v_trip_status = 'END' THEN
        DBMS_OUTPUT.PUT_LINE('Error: Trip (' || p_trip_id || ') has already ended and cannot be cancelled.');
        RAISE_APPLICATION_ERROR(-20003, 'Trip has already ended.');
    END IF;
    
    -- successful case
    FOR booking_rec IN booking_cursor LOOP
        v_refund_id := refund_id_seq.NEXTVAL;
        
        -- make refund
        INSERT INTO Refunds (RefundID, RefundDateTime, RefundAmount, RefundMethod)
        VALUES (v_refund_id, SYSDATE, booking_rec.Price, booking_rec.PaymentMethod);
        
        -- update booking detail's status
        UPDATE  BookingDetails
        SET     RefundID = v_refund_id,
                Status = 'Refunded'
        WHERE   BookingID = booking_rec.BookingID
        AND     TicketID = booking_rec.TicketID;
        
        -- verify update
        IF SQL%ROWCOUNT = 0 THEN
            ROLLBACK TO start_cancel;
            DBMS_OUTPUT.PUT_LINE('Error: Failed to process refund for BookingDetail (BookingID: ' ||
                 booking_rec.BookingID || ', TicketID: '|| booking_rec.TicketID ||').');
            RAISE_APPLICATION_ERROR(-20005, 'Failed to process refund.');
        END IF;
    END LOOP;

    --update
    UPDATE Trips
    SET TripStatus = 'CANCELLED'
    WHERE TripID = p_trip_id;
    
    -- unsuccessful update case
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Failed to cancel trip (' || p_trip_id || ').');
        RAISE_APPLICATION_ERROR(-20004, 'Failed to update trip status.');
    END IF;
    
    -- Commit transaction
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Trip (' || p_trip_id || ') successfully cancelled and refunds processed.');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on any error
        ROLLBACK TO start_cancel;
        DBMS_OUTPUT.PUT_LINE('Error: Failed to cancel trip (' || p_trip_id || '): ' || SQLERRM);
        RAISE_APPLICATION_ERROR(-20006, 'Error in prc_cancel_trip: ' || SQLERRM);
END;
/


-- generate ticket
CREATE OR REPLACE PROCEDURE prc_generate_ticket_for_trip (
    p_trip_id       IN Trips.TripID%TYPE,
    p_ticket_price  IN Tickets.Price%TYPE,
    p_quantity      IN NUMBER
) IS
    v_trip_status   Trips.TripStatus%TYPE;
    v_bus_id        Buses.BusID%TYPE;
    v_bus_capacity  Buses.BusCapacity%TYPE;
    v_curr_seats    Trips.AvailableSeats%TYPE;
    v_new_seats     NUMBER;
    v_ticket_id     Tickets.TicketID%TYPE;
    v_seat_no       Tickets.SeatNo%TYPE;
    i NUMBER;

    e_fk_violation  EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fk_violation, -2291); -- ORA-02291: integrity constraint violated - parent key not found

BEGIN
    -- validate input
    IF p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Quantity must be greater than 0.');
    END IF;
    
    IF p_ticket_price <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Ticket price must be greater than 0.');
    END IF;

    SELECT TripStatus, BusID, AvailableSeats
    INTO v_trip_status, v_bus_id, v_curr_seats
    FROM Trips
    WHERE TripID = p_trip_id;

    v_trip_status:= UPPER(v_trip_status);

    IF v_trip_status != 'PLANNING' THEN
        RAISE_APPLICATION_ERROR(-20004, 'Trip must be in Planning phase to generate tickets.');
    END IF;

    BEGIN
        SELECT BusCapacity
        INTO v_bus_capacity
        FROM Buses
        WHERE BusID = v_bus_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'No bus assigned to Trip (' || p_trip_id || ').');
    END;

    -- the resulting available seats cannot be more than bus capacity
    v_new_seats := v_curr_seats + p_quantity;
    IF v_new_seats > v_bus_capacity THEN
        RAISE_APPLICATION_ERROR(-20006, 'Cannot generate tickets: Available seats would exceed bus capacity of ' || v_bus_capacity || '.');
    END IF;
    
    SAVEPOINT start_generate;-- check point

    -- generate ticket
    FOR i IN 1..p_quantity LOOP
        v_ticket_id := ticket_id_seq.NEXTVAL;

        v_seat_no := 'S' || TO_CHAR(v_curr_seats + i);

        INSERT INTO Tickets (TicketID, SeatNo, Price, TripID)
        VALUES (v_ticket_id, v_seat_no, p_ticket_price, p_trip_id);
    END LOOP;

    -- update available seats
    UPDATE Trips
    SET AvailableSeats = v_new_seats
    WHERE TripID = p_trip_id;

    -- verify update
    IF SQL%ROWCOUNT = 0 THEN
        ROLLBACK TO start_generate;
        RAISE_APPLICATION_ERROR(-20007, 'Failed to update available seats for Trip ID ' || p_trip_id || '.');
    END IF;

    -- Commit transaction
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Successfully generated ' || p_quantity || ' tickets for Trip (' || p_trip_id || ') at price ' || p_ticket_price || ' each. Available seats updated: '|| v_curr_seats ||' -> ' || v_new_seats || '.');

EXCEPTION
    WHEN e_fk_violation THEN
        ROLLBACK TO start_generate;
        DBMS_OUTPUT.PUT_LINE('Error: Trip (' || p_trip_id || ') does not exist.');
        RAISE_APPLICATION_ERROR(-20009, 'Invalid TripID: No such trip exists.');
    WHEN NO_DATA_FOUND THEN
        ROLLBACK TO start_generate;
        DBMS_OUTPUT.PUT_LINE('Error: Trip or Bus not found for Trip (' || p_trip_id || ').');
        RAISE_APPLICATION_ERROR(-20003, 'Trip or Bus not found.');
    WHEN OTHERS THEN
        ROLLBACK TO start_generate;
        DBMS_OUTPUT.PUT_LINE('Error generating tickets for Trip (' || p_trip_id || '): ' || SQLERRM);
        RAISE_APPLICATION_ERROR(-20008, 'Error in prc_generate_ticket_for_trip: ' || SQLERRM);
END;
/