#!/usr/bin/env python3
"""
One-time migration: backfill state, city, and address fields for all
Firestore documents in 'stations' and 'dumpStations' collections.

Usage: pip install geopy firebase-admin && python3 migrate_addresses.py
"""

import time
import firebase_admin
from firebase_admin import credentials, firestore
from geopy.geocoders import Nominatim

# ── Firebase Init ──
cred = credentials.Certificate(
    "/Users/scottkriss/Desktop/glamping-ec504-firebase-adminsdk-fbsvc-8efc3adff2.json"
)
firebase_admin.initialize_app(cred)
db = firestore.client()

# ── Geocoder (free, no API key needed) ──
geolocator = Nominatim(user_agent="glampingstations-migration")


def reverse_geocode(lat: float, lng: float) -> dict:
    """Returns {'state': ..., 'city': ..., 'address': ...} or empty strings."""
    try:
        location = geolocator.reverse(f"{lat}, {lng}", exactly_one=True, language="en")
        if location and location.raw.get("address"):
            addr = location.raw["address"]
            state = addr.get("state", "")
            city = addr.get("city") or addr.get("town") or addr.get("village") or addr.get("hamlet") or ""

            # Build readable address
            parts = []
            house = addr.get("house_number", "")
            road = addr.get("road", "")
            if house and road:
                parts.append(f"{house} {road}")
            elif road:
                parts.append(road)
            if city:
                parts.append(city)
            if state:
                parts.append(state)
            address_str = ", ".join(parts) if parts else ""

            return {"state": state, "city": city, "address": address_str}
    except Exception as e:
        print(f"  Geocode error for ({lat}, {lng}): {e}")
    return {"state": "", "city": "", "address": ""}


def migrate_collection(collection_name: str):
    print(f"\n{'='*50}")
    print(f"Migrating collection: {collection_name}")
    print(f"{'='*50}")

    docs = db.collection(collection_name).stream()
    count = 0
    skipped = 0

    for doc in docs:
        data = doc.to_dict()
        name = data.get("name", "(unnamed)")
        lat = data.get("latitude", 0)
        lng = data.get("longitude", 0)

        # Skip if already has address data
        if data.get("state") and data.get("address"):
            print(f"  SKIP {name} — already has address data")
            skipped += 1
            continue

        print(f"  Geocoding {name} ({lat}, {lng})...", end=" ")
        geo = reverse_geocode(lat, lng)

        if geo["state"] or geo["address"]:
            db.collection(collection_name).document(doc.id).update(geo)
            print(f"-> {geo['city']}, {geo['state']}")
            count += 1
        else:
            print("-> NO RESULT")

        # Nominatim rate limit: 1 request per second
        time.sleep(1.1)

    print(f"\nDone: {count} updated, {skipped} skipped")


if __name__ == "__main__":
    migrate_collection("stations")
    migrate_collection("dumpStations")
    print("\nMigration complete!")
