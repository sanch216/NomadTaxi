import requests
import random
import time

BASE_URL = "http://192.168.0.106:8080"

DRIVERS = [
    {"name": "Azamat (Economy)", "phone": "7775001", "class": "ECONOMY", "car": "Toyota Camry 50"},
    {"name": "Mirlan (Comfort)", "phone": "7775002", "class": "COMFORT", "car": "Hyundai Sonata"},
    {"name": "Bakyt (Business)", "phone": "7775003", "class": "BUSINESS", "car": "Mercedes-Benz S-Class"},
    {"name": "Ulan (Economy)", "phone": "7775004", "class": "ECONOMY", "car": "Honda Fit"},
    {"name": "Chyngyz (Comfort)", "phone": "7775005", "class": "COMFORT", "car": "Toyota Prius"},
]

def populate():
    print("Starting driver population...")
    
    for d in DRIVERS:
        # 1. Register
        print(f"Registering {d['name']}...")
        reg_payload = {
            "phone": d['phone'],
            "password": "password123",
            "fullName": d['name'],
            "role": "DRIVER"
        }
        try:
            reg_resp = requests.post(f"{BASE_URL}/auth/register", json=reg_payload)
            print(f"   Registration Status: {reg_resp.status_code}")
            if reg_resp.status_code != 200:
                print(f"   Registration Body: {reg_resp.text}")
        except Exception as e:
            print(f"   Registration request failed: {e}")

        # 2. Login
        login_payload = {
            "phone": d['phone'],
            "password": "password123"
        }
        resp = requests.post(f"{BASE_URL}/auth/login", json=login_payload)
        if resp.status_code != 200:
            print(f"Login failed for {d['phone']}")
            continue
        
        token = resp.json()['token']
        headers = {"Authorization": f"Bearer {token}"}

        # 3. Update Location & Details
        # Bishkek Center approx: 42.8746, 74.5698
        lat = 42.8746 + random.uniform(-0.03, 0.03)
        lon = 74.5698 + random.uniform(-0.03, 0.03)
        
        params = {
            "lat": lat,
            "lon": lon,
            "status": "AVAILABLE",
            "carClass": d['class'],
            "carModel": d['car'],
            "carNumber": f"01KG {random.randint(100,999)} {''.join(random.choices('ABC', k=3))}"
        }
        
        upd_resp = requests.put(f"{BASE_URL}/api/driver/location", params=params, headers=headers)
        if upd_resp.status_code == 200:
            print(f"Driver {d['name']} is now ONLINE at {lat:.4f}, {lon:.4f} ({d['class']})")
        else:
            print(f"Failed to update location for {d['name']} (Status: {upd_resp.status_code}): {upd_resp.text[:200]}")

if __name__ == "__main__":
    populate()
