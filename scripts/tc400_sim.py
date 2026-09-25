#!/usr/bin/env python3
"""Minimal Pfeiffer TC 400 simulator (Pfeiffer Vacuum protocol over TCP).

Answers queries and commands like the drive unit behind a serial-to-Ethernet
converter: 3-digit checksum, CR terminator, NO_DEF for unknown parameters,
_RANGE for P707 outside 20-100 %.

Usage: tc400_sim.py [port] [reply delay in s]    (defaults: 4001, 0.05)
"""
import socket
import sys
import threading
import time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4001
DELAY = float(sys.argv[2]) if len(sys.argv) > 2 else 0.05  # ~9600 baud RS-485

PARAMS = {
    "001": "000000", "002": "000000", "004": "111111", "009": "000000",
    "010": "000000", "012": "000000", "023": "000000", "026": "000",
    "050": "000000", "303": "000000", "306": "000000", "308": "000820",
    "309": "000000", "310": "000012", "313": "004800", "326": "000031",
    "330": "000027", "346": "000029", "349": "TC 400", "707": "006500",
}


def checksum(s):
    return "%03d" % (sum(s.encode()) % 256)


def reply(addr, param, data):
    r = "%s10%s%02d%s" % (addr, param, len(data), data)
    return (r + checksum(r) + "\r").encode()


def answer(telegram):
    addr, action, param = telegram[:3], telegram[3:5], telegram[5:8]
    data = telegram[10:-3]
    if param not in PARAMS:
        return reply(addr, param, "NO_DEF")
    if action == "10":
        if param == "707" and not 2000 <= int(data) <= 10000:
            return reply(addr, param, "_RANGE")
        PARAMS[param] = data
    return reply(addr, param, PARAMS[param])


def serve(conn):
    buf = b""
    while chunk := conn.recv(256):
        buf += chunk
        while b"\r" in buf:
            line, buf = buf.split(b"\r", 1)
            t = line.decode(errors="replace")
            if len(t) < 13 or checksum(t[:-3]) != t[-3:]:
                print("bad telegram:", t, flush=True)
                continue
            time.sleep(DELAY)
            r = answer(t)
            print(t, "->", r.decode().strip(), flush=True)
            conn.sendall(r)


srv = socket.create_server(("", PORT))
print("TC 400 simulator on port", PORT, flush=True)
while True:
    conn, _ = srv.accept()
    threading.Thread(target=serve, args=(conn,), daemon=True).start()
