#!/bin/bash

# Small Batch Reactor Scheduling System - Database Management Script
# This script provides database management utilities

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[DB]${NC} $1"
}

# Database connection parameters
DB_HOST="localhost"
DB_PORT="65432"
DB_USER="dbadmin"
DB_NAME="reactor_scheduling"

# Function to execute SQL command
execute_sql() {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "$1"
}

# Function to execute SQL file
execute_sql_file() {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status      - Show database status and table counts"
    echo "  backup      - Create database backup"
    echo "  restore     - Restore database from backup"
    echo "  reset       - Reset database (WARNING: destroys all data)"
    echo "  test        - Test database connectivity"
    echo "  tables      - List all tables"
    echo "  reactors    - Show reactor information"
    echo "  schedule    - Show active schedule"
    echo "  utilization - Show reactor utilization stats"
    echo "  help        - Show this help message"
}

# Function to show database status
show_status() {
    print_header "Database Status"
    echo ""
    
    # Show current network configuration
    if [ -f "./get_local_ip.sh" ]; then
        CURRENT_IP=$(./get_local_ip.sh primary)
        print_status "Current server IP: $CURRENT_IP"
        print_status "Database accessible at: $CURRENT_IP:$DB_PORT"
        echo ""
    fi
    
    # Test connection
    if execute_sql "SELECT 'Connection successful!' as status;" > /dev/null 2>&1; then
        print_status "✓ Database connection successful"
        print_status "  Host: $DB_HOST:$DB_PORT"
        print_status "  Database: $DB_NAME"
        print_status "  User: $DB_USER"
    else
        print_error "✗ Database connection failed"
        print_error "  Check if PostgreSQL is running on port $DB_PORT"
        return 1
    fi
    
    # Show table counts
    print_status "Table record counts:"
    execute_sql "
        SELECT 'Reactors: ' || COUNT(*) FROM reactors
        UNION ALL
        SELECT 'Processes: ' || COUNT(*) FROM processes
        UNION ALL
        SELECT 'Schedule Entries: ' || COUNT(*) FROM schedule_entries
        UNION ALL
        SELECT 'Pocket Yields: ' || COUNT(*) FROM pocket_yields
        UNION ALL
        SELECT 'Process Parameters: ' || COUNT(*) FROM process_parameters
        UNION ALL
        SELECT 'Maintenance Log: ' || COUNT(*) FROM maintenance_log;
    "
    
    # Show active schedules
    echo ""
    print_status "Active schedules:"
    execute_sql "SELECT COUNT(*) as active_count FROM schedule_entries WHERE status IN ('Scheduled', 'Running');"
}

# Function to backup database
backup_database() {
    BACKUP_FILE="reactor_scheduling_backup_$(date +%Y%m%d_%H%M%S).sql"
    print_header "Creating database backup: $BACKUP_FILE"
    
    pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        print_status "✓ Backup created successfully: $BACKUP_FILE"
        print_status "File size: $(du -h $BACKUP_FILE | cut -f1)"
    else
        print_error "✗ Backup failed"
        return 1
    fi
}

# Function to test connectivity
test_connection() {
    print_header "Testing Database Connectivity"
    echo ""
    
    # Test basic connection
    if execute_sql "SELECT version();" > /dev/null 2>&1; then
        print_status "✓ PostgreSQL connection successful"
        
        # Show version
        print_status "Database version:"
        execute_sql "SELECT version();"
        
        # Test each table
        echo ""
        print_status "Testing table access:"
        
        tables=("reactors" "processes" "schedule_entries" "pocket_yields" "process_parameters" "maintenance_log")
        for table in "${tables[@]}"; do
            if execute_sql "SELECT COUNT(*) FROM $table;" > /dev/null 2>&1; then
                count=$(execute_sql "SELECT COUNT(*) FROM $table;" -t | tr -d ' ')
                print_status "✓ $table: $count records"
            else
                print_error "✗ $table: access failed"
            fi
        done
        
    else
        print_error "✗ Database connection failed"
        return 1
    fi
}

# Function to show tables
show_tables() {
    print_header "Database Tables"
    execute_sql "\dt"
}

# Function to show reactors
show_reactors() {
    print_header "Reactor Information"
    execute_sql "
        SELECT reactor_name, reactor_type, chamber_type, pocket_count, 
               location, is_active
        FROM reactors 
        ORDER BY reactor_name;
    "
}

# Function to show schedule
show_schedule() {
    print_header "Active Schedule"
    execute_sql "
        SELECT batch_id, reactor_name, process_name, 
               scheduled_start, scheduled_end, status, operator_name
        FROM active_schedules
        ORDER BY scheduled_start;
    "
}

# Function to show utilization
show_utilization() {
    print_header "Reactor Utilization"
    execute_sql "
        SELECT reactor_name, reactor_type, total_runs, 
               ROUND(avg_yield, 2) as avg_yield,
               ROUND(total_runtime_hours, 1) as runtime_hours
        FROM reactor_utilization
        ORDER BY total_runs DESC;
    "
}

# Function to reset database
reset_database() {
    print_warning "WARNING: This will destroy all data in the database!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        print_header "Resetting database..."
        
        # Drop and recreate database
        psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
        psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"
        
        # Run setup script if it exists
        if [ -f "setup_database.sql" ]; then
            print_status "Running database setup script..."
            execute_sql_file "setup_database.sql"
            print_status "✓ Database reset completed"
        else
            print_warning "setup_database.sql not found. Database is empty."
        fi
    else
        print_status "Database reset cancelled"
    fi
}

# Main script logic
case "$1" in
    "status")
        show_status
        ;;
    "backup")
        backup_database
        ;;
    "test")
        test_connection
        ;;
    "tables")
        show_tables
        ;;
    "reactors")
        show_reactors
        ;;
    "schedule")
        show_schedule
        ;;
    "utilization")
        show_utilization
        ;;
    "reset")
        reset_database
        ;;
    "help"|"")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
