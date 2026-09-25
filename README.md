# tc400-pump-ioc

EPICS IOC for a **Pfeiffer TC 400** turbo pump drive unit. It speaks the Pfeiffer Vacuum protocol
over RS-485, reached through a serial-to-Ethernet converter on TCP.

Nothing is compiled here: the IOC runs on the stock `streamApp` binary from StreamDevice
(asyn + StreamDevice). The repo only holds runtime files.

```
ioc/
  st.cmd                      startup script
  protocol/pfeiffer.proto     Pfeiffer protocol, one entry per data type
  db/pfeiffer_*.template      generic record templates
  db/tc400.substitutions      TC 400 parameter table (the only device-specific file)
  db/tc400_extra.db           string parameters and error acknowledgement
scripts/tc400_sim.py          TC 400 simulator for testing without a pump
docs/tc400_manual.pdf         manual (local only, not in git): ch. 5.2 telegram, ch. 6 parameters
```

## Run with Docker

```bash
cp .env.example .env      # set P, DEVICE_IP, DEVICE_PORT, ADDR
docker compose up -d --build
docker attach tc400-ioc   # iocsh; detach with Ctrl-P Ctrl-Q
```

The image builds EPICS base 7.0.10, asyn R4-46 and StreamDevice 2.8.26. It uses host networking,
so Channel Access works as on a normal IOC host.

## Run without Docker

```bash
cd ioc
STREAM=/path/to/StreamDevice P=TC400: DEVICE_IP=192.168.0.10 streamApp st.cmd
```

| Variable      | Meaning                                  | Default |
|---------------|------------------------------------------|---------|
| `STREAM`      | StreamDevice install (`dbd/streamApp.dbd`) |       |
| `P`           | PV prefix                                |         |
| `DEVICE_IP`   | serial-to-Ethernet converter             |         |
| `DEVICE_PORT` | converter TCP port                       | `4001`  |
| `ADDR`        | RS-485 address of the pump (P797), 3 digits | `001` |

## Test without a pump

```bash
python3 scripts/tc400_sim.py 4001
```

Then start the IOC with `DEVICE_IP=127.0.0.1`.

## PVs

PV suffixes follow the Sirius convention.

| PV | Param | Access |
|----|-------|--------|
| `Standby-Sel` / `-Sts` | P002 | rw |
| `PumpStation-Sel` / `-Sts` | P010 | rw (On also acknowledges errors) |
| `MotorPump-Sel` / `-Sts` | P023 | rw |
| `SpdSetMode-Sel` / `-Sts` | P026 | rw |
| `SpdSetValue-SP` / `-RB` | P707 | rw, 20–100 %, only used when SpdSetMode is On |
| `Heating-Mon` | P001 | r |
| `RunUpTimeCtrl-Mon` | P004 | r |
| `Venting-Mon` | P012 | r |
| `SealingGas-Mon` | P050 | r |
| `SpdAttained-Mon` | P306 | r |
| `RotSpeed-Mon`, `RotSpeedTarget-Mon` | P309, P308 | r, Hz |
| `DrvCurrent-Mon`, `DrvVoltage-Mon` | P310, P313 | r, A, V |
| `ElecTemp-Mon`, `PumpTemp-Mon`, `MotorTemp-Mon` | P326, P330, P346 | r, °C |
| `ErrorCode-Mon` | P303 | r |
| `Model-Cte` | P349 | r, read once at startup |
| `ErrorAck-Cmd` | P009 | write any value to acknowledge |

To add a parameter, add a row to `db/tc400.substitutions`.

## Design notes

- **No autosave.** The TC 400 keeps its parameters in non-volatile memory, and restoring
  start/stop commands on a pump at IOC start is risky. Setpoints read the pump's value at startup
  instead (`@init`).
- **Readback after a write.** Each `-Sel`/`-SP` forward-links to its readback with `.PROC CA`.
  A plain FLNK would do nothing, because EPICS only forward-processes Passive records and the
  readbacks are periodic.
- **Write replies are checked, not stored** (`%*`). A pump error reply (`_RANGE`, `_LOGIC`) puts
  the setpoint in INVALID alarm, while a put that arrives during a busy write is never overwritten
  by the old echo.
- **Priorities.** Writes run at `PRIO HIGH` and their readbacks at `MEDIUM`, so they jump ahead of
  the periodic scans on the shared RS-485 line.
