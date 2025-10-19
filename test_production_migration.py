#!/usr/bin/env python3
"""
Test script to verify all endpoints are using production database
"""
import requests
import json

BASE_URL = "http://localhost:5000"

def test_endpoint(name, endpoint, expected_keys, check_production=True):
    """Test an API endpoint"""
    print(f"\n{'='*60}")
    print(f"Testing: {name}")
    print(f"Endpoint: {endpoint}")
    print(f"{'='*60}")
    
    try:
        response = requests.get(f"{BASE_URL}{endpoint}", timeout=10)
        
        if response.status_code != 200:
            print(f"❌ FAILED: Status code {response.status_code}")
            print(f"   Error: {response.text[:200]}")
            return False
        
        data = response.json()
        
        # Check for error in response
        if 'error' in data:
            print(f"❌ FAILED: API returned error")
            print(f"   Error: {data['error'][:200]}")
            return False
        
        # Check expected keys
        missing_keys = [k for k in expected_keys if k not in data]
        if missing_keys:
            print(f"⚠️  WARNING: Missing keys: {missing_keys}")
        
        # Check for production data indicators
        if check_production:
            data_str = json.dumps(data)
            if 'Production Database' in data_str or 'mesprod' in data_str:
                print(f"✅ VERIFIED: Using production database")
            elif 'reactor_scheduling' in data_str or 'staging' in data_str.lower():
                print(f"❌ FAILED: Still using staging database!")
                return False
            else:
                print(f"✅ PASS: No staging references found")
        
        # Print sample data
        for key in expected_keys:
            if key in data:
                value = data[key]
                if isinstance(value, list):
                    print(f"   {key}: {len(value)} items")
                    if len(value) > 0:
                        print(f"      Sample: {value[0] if not isinstance(value[0], dict) else list(value[0].keys())}")
                elif isinstance(value, dict):
                    print(f"   {key}: {list(value.keys())[:5]}")
                else:
                    print(f"   {key}: {value}")
        
        print(f"✅ SUCCESS: {name}")
        return True
        
    except Exception as e:
        print(f"❌ FAILED: {str(e)}")
        return False

def main():
    print("\n" + "="*60)
    print("PRODUCTION DATABASE MIGRATION VERIFICATION")
    print("="*60)
    
    tests = [
        ("Status Check", "/api/status", ["status", "database"], True),
        ("Reactors List", "/api/reactors", ["reactors", "count"], True),
        ("Schedule List", "/api/schedule", ["schedule", "count"], True),
        ("Processes List", "/api/processes", ["processes", "count"], True),
        ("Reactor Assignment", "/api/reactor-assignment", ["assignments", "insights"], True),
        ("Historical Runs", "/api/historical-runs", ["historical_runs", "insights"], True),
        ("Production Stats", "/api/production-stats", ["database_info", "table_stats"], True),
        ("AI Schedule Optimization", "/api/ai-schedule-optimization", ["optimization_recommendations", "revenue_analysis"], True),
    ]
    
    results = []
    for test in tests:
        result = test_endpoint(*test)
        results.append((test[0], result))
    
    # Summary
    print("\n" + "="*60)
    print("MIGRATION TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for _, r in results if r)
    total = len(results)
    
    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 ALL TESTS PASSED - Production migration successful!")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) failed - Review errors above")
        return 1

if __name__ == "__main__":
    exit(main())
