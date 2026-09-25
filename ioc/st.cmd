##################################################################
# Pfeiffer TC 400 turbo pump IOC (asyn + StreamDevice)
#
# Run from this directory:  streamApp st.cmd
#
# Environment:
#   STREAM       StreamDevice install (for dbd/streamApp.dbd)
#   P            PV prefix, e.g. "TC400:"
#   DEVICE_IP    serial-to-Ethernet converter
#   DEVICE_PORT  its TCP port                       (default 4001)
#   ADDR         RS-485 address of the pump (P797),
#                3 digits                           (default 001)
##################################################################

dbLoadDatabase("$(STREAM)/dbd/streamApp.dbd")
streamApp_registerRecordDeviceDriver(pdbbase)

epicsEnvSet("STREAM_PROTOCOL_PATH", "protocol")
epicsEnvSet("EPICS_DB_INCLUDE_PATH", "db")

drvAsynIPPortConfigure("PUMP", "$(DEVICE_IP):$(DEVICE_PORT=4001)")

dbLoadTemplate("db/tc400.substitutions", "P=$(P),PORT=PUMP,ADDR=$(ADDR=001)")
dbLoadRecords("db/tc400_extra.db", "P=$(P),PORT=PUMP,ADDR=$(ADDR=001)")

iocInit()
