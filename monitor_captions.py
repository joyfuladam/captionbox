#!/usr/bin/env python3
"""
Caption3B Stall Monitor
Monitors the health endpoint to detect when captions are stalling
"""

import requests
import time
import json
from datetime import datetime

def check_health():
    """Check the health endpoint and return status"""
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": f"HTTP {response.status_code}"}
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}

def monitor_captions():
    """Monitor captions for stalls"""
    print("🔍 Caption3B Stall Monitor")
    print("=" * 40)
    print("Monitoring for caption stalls...")
    print("Press Ctrl+C to stop\n")
    
    last_update_time = None
    stall_warnings = 0
    
    while True:
        try:
            health_data = check_health()
            
            if "error" in health_data:
                print(f"❌ Error: {health_data['error']}")
                time.sleep(5)
                continue
            
            current_time = datetime.now()
            time_since_caption = health_data.get("time_since_last_caption", 0)
            is_recognizing = health_data.get("is_recognizing", False)
            timer_active = health_data.get("finalization_timer_active", False)
            interim_text = health_data.get("current_interim_text", "")
            
            # Check for potential stalls
            stall_detected = False
            if is_recognizing and time_since_caption > 10:  # More than 10 seconds without update
                stall_detected = True
                stall_warnings += 1
                print(f"🚨 STALL DETECTED! No captions for {time_since_caption:.1f}s")
                print(f"   Interim text: {interim_text[:50]}...")
                print(f"   Finalization timer: {'Active' if timer_active else 'Inactive'}")
                print()
            
            # Status display
            status_icon = "🟢" if not stall_detected else "🔴"
            recognition_status = "Active" if is_recognizing else "Inactive"
            
            print(f"{status_icon} {current_time.strftime('%H:%M:%S')} | "
                  f"Recognition: {recognition_status} | "
                  f"Last caption: {time_since_caption:.1f}s ago | "
                  f"Timer: {'🕐' if timer_active else '⏸️'}")
            
            if interim_text:
                print(f"   📝 Interim: {interim_text[:80]}...")
            
            # Reset stall warnings if no stall detected
            if not stall_detected and stall_warnings > 0:
                stall_warnings = 0
            
            time.sleep(2)
            
        except KeyboardInterrupt:
            print("\n\n🛑 Monitoring stopped")
            break
        except Exception as e:
            print(f"❌ Monitor error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    monitor_captions() 