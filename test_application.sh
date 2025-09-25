#!/bin/bash

# Comprehensive Application Test Suite
# Tests all API endpoints and functionality

echo "=== REACTOR SCHEDULING SYSTEM - COMPREHENSIVE TEST SUITE ==="
echo "Date: $(date)"
echo "Testing application at: http://localhost:5000"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test function
test_endpoint() {
    local endpoint=$1
    local description=$2
    local expected_fields=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $endpoint - $description... "
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "http://localhost:5000$endpoint")
    http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS:.*//g')
    
    if [ "$http_code" -eq 200 ]; then
        # Check if response contains expected fields
        if [ -n "$expected_fields" ]; then
            for field in $expected_fields; do
                if echo "$body" | grep -q "\"$field\""; then
                    continue
                else
                    echo -e "${RED}FAIL${NC} - Missing field: $field"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                    return 1
                fi
            done
        fi
        echo -e "${GREEN}PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} - HTTP $http_code"
        echo "Response: $body" | head -c 200
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test web interface
test_web_interface() {
    echo -n "Testing web interface... "
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "http://localhost:5000/")
    http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$http_code" -eq 200 ]; then
        if echo "$response" | grep -q "<title>"; then
            echo -e "${GREEN}PASS${NC}"
            return 0
        else
            echo -e "${RED}FAIL${NC} - No HTML title found"
            return 1
        fi
    else
        echo -e "${RED}FAIL${NC} - HTTP $http_code"
        return 1
    fi
}

echo "=== CORE API ENDPOINTS ==="
test_endpoint "/api/status" "System Status" "status timestamp network"
test_endpoint "/api/reactors" "Reactor List" "reactors count"
test_endpoint "/api/schedule" "Schedule Data" "schedule count"
test_endpoint "/api/processes" "Process List" "processes count"

echo ""
echo "=== AI ANALYSIS ENDPOINTS ==="
test_endpoint "/api/reactor-assignment" "AI Reactor Assignment" "assignments insights"
test_endpoint "/api/historical-runs" "Historical Runs" "historical_runs insights"
test_endpoint "/api/ai-analysis/full-performance" "Full Performance Analysis" "reactor_efficiency process_performance"

echo ""
echo "=== ENTERPRISE ENDPOINTS ==="
test_endpoint "/api/production-stats" "Production Statistics" "database_size record_statistics"
test_endpoint "/api/historical-reactor-performance" "Historical Performance" "reactor_performance insights"
test_endpoint "/api/advanced-spc-analysis" "Advanced SPC Analysis" "quarterly_analysis event_analysis"
test_endpoint "/api/predictive-scheduling" "Predictive Scheduling" "optimization_recommendations"

echo ""
echo "=== WEB INTERFACE ==="
test_web_interface

echo ""
echo "=== DATABASE CONNECTIVITY ==="
echo -n "Testing database connection... "
if psql -h localhost -p 65432 -U dbadmin -d reactor_scheduling -c "SELECT COUNT(*) FROM reactors;" > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo -n "Testing production database connection... "
if psql -h localhost -p 65432 -U dbadmin -d mesprod -c "SELECT COUNT(*) FROM mes.gt_tools LIMIT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""
echo "=== APPLICATION HEALTH ==="
echo -n "Testing Flask application process... "
if pgrep -f "python.*app.py" > /dev/null; then
    echo -e "${GREEN}PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo -n "Testing network accessibility... "
if curl -s http://localhost:5000/api/status > /dev/null; then
    echo -e "${GREEN}PASS${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""
echo "=== TEST SUMMARY ==="
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✅ ALL TESTS PASSED - APPLICATION IS FULLY FUNCTIONAL${NC}"
    exit 0
else
    echo -e "\n${RED}❌ SOME TESTS FAILED - APPLICATION HAS ISSUES${NC}"
    exit 1
fi
