DROP TABLE BookingDetails;

DROP TABLE StaffAllocation;
DROP TABLE Tickets;
DROP TABLE DriverLists;

DROP TABLE Trips;
DROP TABLE ServiceDetails;

DROP TABLE Bookings;
DROP TABLE Requests;
DROP TABLE RentalCollections;
DROP TABLE LeaveApplications;
DROP TABLE LeaveCredits;
DROP TABLE Drivers;
DROP TABLE Buses;

DROP TABLE Members;
DROP TABLE Payments;
DROP TABLE Extensions;
DROP TABLE Refunds;
DROP TABLE Services;
DROP TABLE Shops;
DROP TABLE Staffs;
DROP TABLE LeaveTypes;
DROP TABLE Companies;


CREATE TABLE Members (
    MemberID            NUMBER(6)       NOT NULL,
    MemberName          VARCHAR(50)     NOT NULL,
    MemberDOB           DATE            NOT NULL,
    MemberContactNo     VARCHAR(20)     NOT NULL,
    MemberIC            VARCHAR(20)     NOT NULL,
    MemberEmail         VARCHAR(100)    NOT NULL,
    State               VARCHAR(50)     NOT NULL,
    City                VARCHAR(50)     NOT NULL,
    RegistrationFees    NUMBER(5,2)     DEFAULT 10.00           NOT NULL,
    JoinedDate          DATE            DEFAULT TRUNC(SYSDATE)  NOT NULL,
    TotalSpending       NUMBER(10,2)    DEFAULT 0.00            NOT NULL,
    CONSTRAINT Members_PK PRIMARY KEY (MemberID)
);
CREATE TABLE Payments (
    PaymentID           NUMBER(6)       NOT NULL,
    PaymentDateTime     DATE            NOT NULL,
    PaymentAmount       NUMBER(10,2)    NOT NULL,
    PaymentMethod       VARCHAR(50)     NOT NULL,
    CONSTRAINT Payments_PK PRIMARY KEY (PaymentID),
    CONSTRAINT chk_payment_pos_amount CHECK (PaymentAmount >= 0)
);
CREATE TABLE Extensions (
    ExtensionID         NUMBER(6)       NOT NULL,
    ExtendFrom          DATE            NOT NULL,
    ExtendTo            DATE            NOT NULL,
    ApplyDate           DATE            DEFAULT TRUNC(SYSDATE)  NOT NULL,
    ExtensionFees       NUMBER(5,2)     DEFAULT 5.00            NOT NULL,
    CONSTRAINT Extensions_PK PRIMARY KEY (ExtensionID),
    CONSTRAINT chk_ext_date_range CHECK (ExtendFrom <= ExtendTo),
    CONSTRAINT chk_ext_pos_fees CHECK (ExtensionFees >= 0)
);
CREATE TABLE Refunds (
    RefundID        NUMBER(6)       NOT NULL,
    RefundDateTime  DATE            DEFAULT TRUNC(SYSDATE)      NOT NULL,
    RefundAmount    NUMBER(10,2)    NOT NULL,
    RefundMethod    VARCHAR(50)     NOT NULL,
    CONSTRAINT Refunds_PK PRIMARY KEY (RefundID),
    CONSTRAINT chk_ref_pos_fees CHECK (RefundAmount >= 0)
);
CREATE TABLE Services (
    ServiceID   NUMBER(6)       NOT NULL,
    ServiceName VARCHAR(100)    NOT NULL,
    Duration    NUMBER          NOT NULL,
    Cost        NUMBER(10,2)    NOT NULL,
    CONSTRAINT Services_PK PRIMARY KEY (ServiceID)
);
CREATE TABLE Shops (
    ShopID          NUMBER(6)       NOT NULL,
    ShopName        VARCHAR(100)    NOT NULL,
    UnitNo          VARCHAR(20)     NOT NULL,
    ShopContactNo   VARCHAR(20)     NOT NULL,
    ShopType        VARCHAR(50)     NOT NULL,
    CONSTRAINT Shops_PK PRIMARY KEY (ShopID)
);
CREATE TABLE Staffs (
    StaffID         NUMBER(6)       NOT NULL,
    StaffType       VARCHAR(50)     NOT NULL,
    StaffName       VARCHAR(100)    NOT NULL,
    StaffDOB        DATE            NOT NULL,
    ManagerID       NUMBER(6)       NOT NULL,
    CONSTRAINT Staffs_PK PRIMARY KEY (StaffID),
    CONSTRAINT Staffs_ManagerID_FK FOREIGN KEY (ManagerID) REFERENCES Staffs(StaffID)
);
CREATE TABLE LeaveTypes (
    LeaveTypeID     NUMBER(6)       NOT NULL,
    LeaveTypeName   VARCHAR(50)     NOT NULL,
    MaxDuration     NUMBER          NOT NULL,
    CONSTRAINT LT_PK PRIMARY KEY (LeaveTypeID)
);
CREATE TABLE Companies (
    CompanyID       NUMBER(6)       NOT NULL,
    CompanyName     VARCHAR(100)    NOT NULL,
    ContactNo       VARCHAR(20)     NOT NULL,
    CompanyAddress  VARCHAR(255)    NOT NULL,
    CompanyRevenue  NUMBER(12,2)    DEFAULT 0.00    NOT NULL,
    CONSTRAINT Companies_PK PRIMARY KEY (CompanyID),
    CONSTRAINT chk_comp_pos_rvn CHECK (CompanyRevenue >= 0)
);

CREATE TABLE Bookings (
    BookingID       NUMBER(6)   NOT NULL,
    BookingDateTime DATE        DEFAULT TRUNC(SYSDATE)  NOT NULL,
    MemberID        NUMBER      NOT NULL,
    PaymentID       NUMBER      NOT NULL,
    CONSTRAINT Bookings_PK PRIMARY KEY (BookingID),
    CONSTRAINT Bookings_MemberID_FK FOREIGN KEY (MemberID) REFERENCES Members(MemberID),
    CONSTRAINT Bookings_PaymentID_FK FOREIGN KEY (PaymentID) REFERENCES Payments(PaymentID)
);
CREATE TABLE Requests (
    RequestID       NUMBER(6)       NOT NULL,
    RequestStatus   VARCHAR(20)     DEFAULT 'Pending'       NOT NULL,
    RequestDateTime DATE            DEFAULT TRUNC(SYSDATE)  NOT NULL,
    RequestType     VARCHAR(50)     NOT NULL,
    StaffID         NUMBER(6)       NOT NULL,
    MemberID        NUMBER(6)       NOT NULL,
    CONSTRAINT Requests_PK PRIMARY KEY (RequestID),
    CONSTRAINT Requests_StaffID_FK FOREIGN KEY (StaffID) REFERENCES Staffs(StaffID),
    CONSTRAINT Requests_MemberID_FK FOREIGN KEY (MemberID) REFERENCES Members(MemberID)
);
CREATE TABLE RentalCollections (
    RentalCollectionID  NUMBER(6)       NOT NULL,
    StaffID             NUMBER(6)       NOT NULL,
    ShopID              NUMBER(6)       NOT NULL,
    CollectionStatus    VARCHAR(20)     NOT NULL,
    CollectionAmount    NUMBER(10,2)    NOT NULL,
    PaymentDate         DATE            DEFAULT TRUNC(SYSDATE),
    IssuedDate          DATE            NOT NULL,
    CONSTRAINT RC_PK PRIMARY KEY (RentalCollectionID, ShopID, StaffID),
    CONSTRAINT RC_ShopID_FK FOREIGN KEY (ShopID) REFERENCES Shops(ShopID),
    CONSTRAINT RC_StaffID_FK FOREIGN KEY (StaffID) REFERENCES Staffs(StaffID),
    CONSTRAINT chk_RC_pos_amt CHECK (CollectionAmount >= 0)
);
CREATE TABLE LeaveApplications (
    LeaveApplicationID          NUMBER(6)   NOT NULL,
    ToDate                      DATE        NOT NULL,
    FromDate                    DATE        NOT NULL,
    TotalDays                   NUMBER(2)   NOT NULL,
    LeaveApplicationStatus      VARCHAR(20) DEFAULT 'Pending'       NOT NULL,
    AppliedDate                 DATE        DEFAULT TRUNC(SYSDATE)  NOT NULL,
    ReviewDate                  DATE        DEFAULT NULL,
    StaffID                     NUMBER(6)   NOT NULL,
    ManagerID                   NUMBER(6)   NOT NULL,
    LeaveTypeID                 NUMBER(6)   NOT NULL,
    CONSTRAINT LA_PK PRIMARY KEY (LeaveApplicationID),
    CONSTRAINT LA_StaffID_FK FOREIGN KEY (StaffID) REFERENCES Staffs(StaffID),
    CONSTRAINT LA_ManagerID_FK FOREIGN KEY (ManagerID) REFERENCES Staffs(StaffID),
    CONSTRAINT LA_LeaveTypeID_FK FOREIGN KEY (LeaveTypeID) REFERENCES LeaveTypes(LeaveTypeID)
);
CREATE TABLE LeaveCredits (
    LeaveCreditYear     NUMBER      NOT NULL,
    LeaveTypeID         NUMBER(6)   NOT NULL,
    StaffID             NUMBER(6)   NOT NULL,
    TotalCredits        NUMBER(2)   DEFAULT 14      NOT NULL,
    UsedCredits         NUMBER(2)   NOT NULL,
    RemainingCredits    NUMBER(2)   NOT NULL,
    CONSTRAINT LC_PK PRIMARY KEY (LeaveCreditYear, LeaveTypeID, StaffID),
    CONSTRAINT LC_LeaveTypeID_FK FOREIGN KEY (LeaveTypeID) REFERENCES LeaveTypes(LeaveTypeID),
    CONSTRAINT LC_StaffID_FK FOREIGN KEY (StaffID) REFERENCES Staffs(StaffID),
    CONSTRAINT chk_LC_cred_match CHECK (TRUNC(UsedCredits + RemainingCredits) = TotalCredits)
);
CREATE TABLE Drivers (
    DriverID    NUMBER(6)       NOT NULL,
    DriverName  VARCHAR(100)    NOT NULL,
    DriverDOB   DATE            NOT NULL,
    CompanyID   NUMBER(6)       NOT NULL,
    CONSTRAINT Drivers_PK PRIMARY KEY (DriverID),
    CONSTRAINT Drivers_CompanyID_FK FOREIGN KEY (CompanyID) REFERENCES Companies(CompanyID)
);
CREATE TABLE Buses (
    BusID               NUMBER(6)       NOT NULL,
    BusCapacity         NUMBER(3)       NOT NULL,
    BusPlate            VARCHAR(20)     NOT NULL,
    BusType             VARCHAR(50)     NOT NULL,
    BusCC               NUMBER(4)       NOT NULL,
    TravelledDistance   NUMBER(10,2)    DEFAULT 0.00    NOT NULL,
    JoinedDate          DATE            NOT NULL,
    CompanyID           NUMBER(6)       NOT NULL,
    CONSTRAINT Buses_PK PRIMARY KEY (BusID),
    CONSTRAINT Buses_CompanyID_FK FOREIGN KEY (CompanyID) REFERENCES Companies(CompanyID),
    CONSTRAINT chk_bus_pos_cap CHECK (BusCapacity >= 0),
    CONSTRAINT chk_bus_pos_cc CHECK (BusCC >= 0),
    CONSTRAINT chk_bus_pos_td CHECK (TravelledDistance >= 0)
);
CREATE TABLE Trips (
    TripID          NUMBER(6)       NOT NULL,
    TripDateTime    DATE            NOT NULL,
    StartTerminal   VARCHAR(100)    NOT NULL,
    EndTerminal     VARCHAR(100)    NOT NULL,
    Distance        NUMBER(10,2)    NOT NULL,
    AvailableSeats  NUMBER(3)       NOT NULL,
    TripStatus      VARCHAR(20)     DEFAULT 'Scheduled' NOT NULL,  
    BusID           NUMBER(6)       NOT NULL,
    CONSTRAINT Trips_PK PRIMARY KEY (TripID),
    CONSTRAINT Trips_BusID_PK FOREIGN KEY (BusID) REFERENCES Buses(BusID),
    CONSTRAINT chk_tp_pos_seat CHECK (AvailableSeats >= 0)
);
CREATE TABLE ServiceDetails (
    ServiceDetailID NUMBER(6)   NOT NULL,
    ServiceDate     DATE        NOT NULL,
    BusID           NUMBER(6)   NOT NULL,
    ServiceID       NUMBER(6)   NOT NULL,
    CONSTRAINT SD_PK PRIMARY KEY (ServiceDetailID),
    CONSTRAINT SD_BusID_FK FOREIGN KEY (BusID) REFERENCES Buses(BusID),
    CONSTRAINT SD_ServiceID_FK FOREIGN KEY (ServiceID) REFERENCES Services(ServiceID)
);

CREATE TABLE StaffAllocation (
    ServiceDetailID NUMBER(6)   NOT NULL,
    StaffID         NUMBER(6)   NOT NULL,
    StartTime       DATE        NOT NULL,
    EndTime         DATE        NOT NULL,
    CONSTRAINT SA_PK PRIMARY KEY (ServiceDetailID, StaffID),
    CONSTRAINT SA_ServiceDetailID_FK FOREIGN KEY (ServiceDetailID) REFERENCES ServiceDetails(ServiceDetailID),
    CONSTRAINT SA_StaffID_FK FOREIGN KEY (StaffID) REFERENCES Staffs(StaffID)
);
CREATE TABLE Tickets (
    TicketID        NUMBER(10)      NOT NULL,
    SeatNo          VARCHAR(10)     NOT NULL,
    Price           NUMBER(7,2)     NOT NULL,
    TripID          NUMBER(6)       NOT NULL,
    CONSTRAINT Tickets_PK PRIMARY KEY (TicketID),
    CONSTRAINT Tickets_TripID_FK FOREIGN KEY (TripID) REFERENCES Trips(TripID),
    CONSTRAINT chk_t_pos_price CHECK (Price >= 0)
);
CREATE TABLE DriverLists (
    TripID      NUMBER(6)       NOT NULL,
    DriverID    NUMBER(6)       NOT NULL,
    StartTime   DATE            NOT NULL,
    EndTime     DATE            NOT NULL,
    CONSTRAINT DL_PK PRIMARY KEY (TripID, DriverID),
    CONSTRAINT DL_TripID_FK FOREIGN KEY (TripID) REFERENCES Trips(TripID),
    CONSTRAINT DL_DriverID_FK FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID),
    CONSTRAINT chk_DL_max_duration CHECK ((EndTime - StartTime) * 24 <= 12)
);

CREATE TABLE BookingDetails (
    BookingID       NUMBER(6)       NOT NULL,
    TicketID        NUMBER(6)       NOT NULL,
    PassengerName   VARCHAR(50)     NOT NULL,
    PassengerIC     VARCHAR(20)     NOT NULL,
    Status          VARCHAR(20)     DEFAULT 'Booked'    NOT NULL,
    ExtensionID     NUMBER(6)       DEFAULT NULL,
    RefundID        NUMBER(6)       DEFAULT NULL,
    CONSTRAINT BD_PK PRIMARY KEY (BookingID, TicketID),
    CONSTRAINT BD_BookingID_FK FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID),
    CONSTRAINT BD_ExtensionID_FK FOREIGN KEY (ExtensionID) REFERENCES Extensions(ExtensionID),
    CONSTRAINT BD_RefundID_FK FOREIGN KEY (RefundID) REFERENCES Refunds(RefundID),
    CONSTRAINT BD_TicketID_FK FOREIGN KEY (TicketID) REFERENCES Tickets(TicketID)
);
