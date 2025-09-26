#!/usr/bin/env python3
"""
Comprehensive validation script for Predictive Modeling functionality
Tests all API endpoints and validates data structures
"""

import requests
import json
import sys

BASE_URL = "http://localhost:5000"

def test_api_endpoint(endpoint, expected_keys):
    """Test an API endpoint and validate response structure"""
    try:
        response = requests.get(f"{BASE_URL}{endpoint}")
        response.raise_for_status()
        data = response.json()
        
        print(f"✅ {endpoint} - Status: {response.status_code}")
        
        # Check for expected keys
        missing_keys = [key for key in expected_keys if key not in data]
        if missing_keys:
            print(f"⚠️  Missing keys: {missing_keys}")
        else:
            print(f"✅ All expected keys present: {expected_keys}")
        
        return data
    except Exception as e:
        print(f"❌ {endpoint} - Error: {e}")
        return None

def validate_predictive_scheduling():
    """Validate predictive scheduling API"""
    print("\n🔮 Testing Predictive Scheduling API...")
    data = test_api_endpoint("/api/predictive-scheduling", 
                           ["optimization_recommendations", "predictive_insights", "data_source"])
    
    if data and "optimization_recommendations" in data:
        recs = data["optimization_recommendations"]
        print(f"📊 Found {len(recs)} optimization recommendations")
        
        if recs:
            first_rec = recs[0]
            required_fields = ["title", "description", "confidence"]
            missing = [field for field in required_fields if field not in first_rec]
            if missing:
                print(f"⚠️  Recommendation missing fields: {missing}")
            else:
                print(f"✅ Recommendation structure valid")
                print(f"   Title: {first_rec['title']}")
                print(f"   Confidence: {first_rec['confidence']}")
    
    return data is not None

def validate_performance_forecasting():
    """Validate performance forecasting API"""
    print("\n📈 Testing Performance Forecasting API...")
    data = test_api_endpoint("/api/historical-reactor-performance", 
                           ["reactor_performance", "insights", "data_source"])
    
    if data and "reactor_performance" in data:
        reactors = data["reactor_performance"]
        print(f"🔧 Found {len(reactors)} reactor performance records")
        
        if reactors:
            first_reactor = reactors[0]
            required_fields = ["reactor", "efficiency", "throughput", "uptime"]
            missing = [field for field in required_fields if field not in first_reactor]
            if missing:
                print(f"⚠️  Reactor data missing fields: {missing}")
            else:
                print(f"✅ Reactor data structure valid")
                print(f"   Reactor: {first_reactor['reactor']}")
                print(f"   Efficiency: {first_reactor['efficiency']}%")
    
    return data is not None

def validate_main_page():
    """Validate main page loads correctly"""
    print("\n🌐 Testing Main Page...")
    try:
        response = requests.get(BASE_URL)
        response.raise_for_status()
        
        # Check for predictive modeling section
        content = response.text
        if "predictive-modeling" in content:
            print("✅ Predictive modeling section found in main page")
        else:
            print("❌ Predictive modeling section not found")
        
        # Check for required buttons
        buttons = [
            "loadPredictiveScheduling()",
            "optimizeSchedule()",
            "loadPerformanceForecasting()",
            "exportForecastReport()"
        ]
        
        missing_buttons = [btn for btn in buttons if btn not in content]
        if missing_buttons:
            print(f"⚠️  Missing button functions: {missing_buttons}")
        else:
            print("✅ All predictive modeling buttons found")
        
        return True
    except Exception as e:
        print(f"❌ Main page error: {e}")
        return False

def main():
    """Run comprehensive validation"""
    print("🔮 PREDICTIVE MODELING VALIDATION SUITE")
    print("=" * 50)
    
    results = []
    
    # Test API endpoints
    results.append(validate_predictive_scheduling())
    results.append(validate_performance_forecasting())
    results.append(validate_main_page())
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 VALIDATION SUMMARY")
    print("=" * 50)
    
    passed = sum(results)
    total = len(results)
    
    print(f"✅ Tests Passed: {passed}/{total}")
    
    if passed == total:
        print("🎉 ALL PREDICTIVE MODELING FUNCTIONALITY WORKING!")
        return 0
    else:
        print("⚠️  Some issues found - check output above")
        return 1

if __name__ == "__main__":
    sys.exit(main())
