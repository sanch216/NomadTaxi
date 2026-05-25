import requests
import time
import random

BASE_URL = "http://192.168.0.106:8080"
PHONE = "7775001"
PASSWORD = "password123"

def simulate():
    print(f"🚀 Starting Driver Simulator for {PHONE}...")
    
    # 1. Login
    try:
        url = f"{BASE_URL}/auth/login"
        print(f"📡 Attempting login at {url}...")
        resp = requests.post(url, json={
            "phone": PHONE,
            "password": PASSWORD
        })
        if resp.status_code != 200:
            print(f"❌ Login failed!")
            print(f"   Status Code: {resp.status_code}")
            print(f"   Response Body: {resp.text}")
            return
        token = resp.json()['token']
        headers = {"Authorization": f"Bearer {token}"}
        print("✅ Logged in successfully.")
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return

    # 2. Set Online
    # We update location to Bishkek Center and status to AVAILABLE
    try:
        params = {
            "lat": 42.8746, 
            "lon": 74.5698,
            "status": "AVAILABLE"
        }
        requests.put(f"{BASE_URL}/api/driver/location", params=params, headers=headers)
        print("✅ Driver status set to AVAILABLE in Bishkek.")
    except Exception as e:
        print(f"❌ Failed to set status: {e}")

    # 3. Poll for Rides
    print("📡 Waiting for ride requests (polling every 3s)...")
    active_ride_id = None

    while True:
        try:
            # Check for current ride
            curr_resp = requests.get(f"{BASE_URL}/api/rides/current", headers=headers)
            
            if curr_resp.status_code == 200 and curr_resp.json():
                ride = curr_resp.json()
                ride_id = ride['id']
                status = ride['status']
                
                if status == 'ACCEPTED':
                    print(f"🚕 Picking up passenger for Ride #{ride_id}...")
                    time.sleep(5)
                    requests.put(f"{BASE_URL}/api/rides/{ride_id}/status?status=ARRIVED", headers=headers)
                elif status == 'ARRIVED':
                    print(f"📍 Arrived at pickup. Waiting for passenger...")
                    time.sleep(5)
                    requests.put(f"{BASE_URL}/api/rides/{ride_id}/status?status=IN_PROGRESS", headers=headers)
                elif status == 'IN_PROGRESS':
                    print(f"🛣️ Trip in progress to {ride['dropoffAddress']}...")
                    time.sleep(10)
                    requests.put(f"{BASE_URL}/api/rides/{ride_id}/status?status=COMPLETED", headers=headers)
                    print(f"🏁 Ride #{ride_id} COMPLETED!")
            
            else:
                # If no active ride, check "feed"
                feed_resp = requests.get(f"{BASE_URL}/api/rides/feed", headers=headers)
                if feed_resp.status_code == 200:
                    rides = feed_resp.json()
                    if rides:
                        target = rides[0] # Take the first one
                        rid = target['id']
                        print(f"✨ Found new Ride Request #{rid} in feed! Accepting...")
                        acc_resp = requests.post(f"{BASE_URL}/api/rides/{rid}/accept", headers=headers)
                        if acc_resp.status_code == 200:
                            print(f"✅ Ride #{rid} accepted successfully.")
                        else:
                            print(f"❌ Failed to accept: {acc_resp.text}")
                
        except Exception as e:
            print(f"⚠️ Loop error: {e}")
            
        time.sleep(3)

if __name__ == "__main__":
    simulate()
