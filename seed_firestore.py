#!/usr/bin/env python3
"""
Seed Firestore with updated stations data (includes favorite field).
Usage: python3 seed_firestore.py
"""

import json
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin
cred = credentials.Certificate("/Users/scottkriss/Desktop/glamping-ec504-firebase-adminsdk-fbsvc-8efc3adff2.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- Gas Stations ---
with open("GlampingStations/stations.json", "r") as f:
    stations = json.load(f)

print(f"Uploading {len(stations)} gas stations...")
for station in stations:
    doc_id = station["id"]
    db.collection("stations").document(doc_id).set(station)
    fav = " *FAV*" if station.get("favorite") else ""
    print(f"  -> {station['name']}{fav}")

# --- Dump Stations ---
with open("GlampingStations/dumpstations.json", "r") as f:
    dump_stations = json.load(f)

print(f"\nUploading {len(dump_stations)} dump stations...")
for station in dump_stations:
    doc_id = station["id"]
    db.collection("dumpStations").document(doc_id).set(station)
    fav = " *FAV*" if station.get("favorite") else ""
    print(f"  -> {station['name']}{fav}")

print("\nDone! All stations uploaded to Firestore with favorite flags.")
