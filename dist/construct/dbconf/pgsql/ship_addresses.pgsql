Database  ship_addresses  ship_addresses.txt __SQLDSN__
#ifdef SQLUSER
Database  ship_addresses  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  ship_addresses  PASS         __SQLPASS__
#endif
Database  ship_addresses  COLUMN_DEF   "code=char(9) NOT NULL PRIMARY KEY"
Database  ship_addresses  COLUMN_DEF   "username=CHAR(20) NOT NULL"
Database  ship_addresses  COLUMN_DEF   "entry=CHAR(9) NOT NULL"
Database  ship_addresses  COLUMN_DEF   "addr_nick=text"
Database  ship_addresses  COLUMN_DEF   "company=text"
Database  ship_addresses  COLUMN_DEF   "fname=text"
Database  ship_addresses  COLUMN_DEF   "lname=text"
