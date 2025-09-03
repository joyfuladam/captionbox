#!/bin/bash

# Log Rotation Script for Caption3B
# Automatically manages log files to prevent disk space issues

set -e

LOG_DIR="."
MAX_LOG_SIZE="50M"  # Maximum size before rotation
MAX_BACKUPS=3       # Keep only this many backup files

# Log files to manage
LOG_FILES=(
    "caption_log.txt"
    "local_app.log"
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔄 Log Rotation Script${NC}"
echo "=========================="

# Function to rotate a single log file
rotate_log() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        echo "Log file $log_file not found, skipping..."
        return
    fi
    
    local file_size=$(du -h "$log_file" | cut -f1)
    echo "Checking $log_file (size: $file_size)"
    
    # Check if file needs rotation
    if [ -s "$log_file" ] && [ "$(du -m "$log_file" | cut -f1)" -gt "$(echo $MAX_LOG_SIZE | sed 's/M//')" ]; then
        echo -e "${YELLOW}⚠️  Rotating $log_file (exceeds $MAX_LOG_SIZE)${NC}"
        
        # Create timestamped backup
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${log_file%.*}_${timestamp}.${log_file##*.}"
        
        # Move current log to backup
        mv "$log_file" "$backup_file"
        
        # Create new empty log file
        touch "$log_file"
        
        echo -e "${GREEN}✅ Rotated $log_file to $backup_file${NC}"
        
        # Clean up old backups
        cleanup_old_backups "$log_file"
    else
        echo -e "${GREEN}✅ $log_file is within size limits${NC}"
    fi
}

# Function to clean up old backup files
cleanup_old_backups() {
    local log_file="$1"
    local base_name="${log_file%.*}"
    local extension="${log_file##*.}"
    
    # Find all backup files for this log
    local backup_files=($(ls -t "${base_name}_"*".${extension}" 2>/dev/null | grep -v "$log_file" || true))
    
    if [ ${#backup_files[@]} -gt $MAX_BACKUPS ]; then
        echo "Cleaning up old backups (keeping $MAX_BACKUPS)..."
        
        # Remove excess backup files
        for ((i=MAX_BACKUPS; i<${#backup_files[@]}; i++)); do
            echo "Removing old backup: ${backup_files[$i]}"
            rm -f "${backup_files[$i]}"
        done
        
        echo -e "${GREEN}✅ Cleanup complete${NC}"
    fi
}

# Function to check disk space
check_disk_space() {
    echo -e "\n${GREEN}💾 Disk Space Check:${NC}"
    df -h . | grep -E "(Filesystem|/dev/)"
    
    local usage=$(df . | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$usage" -gt 90 ]; then
        echo -e "${RED}⚠️  CRITICAL: Disk usage is ${usage}%${NC}"
    elif [ "$usage" -gt 80 ]; then
        echo -e "${YELLOW}⚠️  WARNING: Disk usage is ${usage}%${NC}"
    else
        echo -e "${GREEN}✅ Disk usage is ${usage}% (healthy)${NC}"
    fi
}

# Function to show current log status
show_log_status() {
    echo -e "\n${GREEN}📊 Current Log Status:${NC}"
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -f "$log_file" ]; then
            local size=$(du -h "$log_file" 2>/dev/null | cut -f1 || echo "0")
            local lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            echo "$log_file: $size, $lines lines"
        else
            echo "$log_file: not found"
        fi
    done
    
    # Show backup files
    echo -e "\n${GREEN}📁 Backup Files:${NC}"
    local backup_count=0
    for log_file in "${LOG_FILES[@]}"; do
        local base_name="${log_file%.*}"
        local extension="${log_file##*.}"
        local backups=($(ls -t "${base_name}_"*".${extension}" 2>/dev/null | grep -v "$log_file" || true))
        backup_count=$((backup_count + ${#backups[@]}))
        
        if [ ${#backups[@]} -gt 0 ]; then
            echo "$log_file backups:"
            for backup in "${backups[@]}"; do
                local backup_size=$(du -h "$backup" 2>/dev/null | cut -f1 || echo "0")
                echo "  - $backup ($backup_size)"
            done
        fi
    done
    
    if [ $backup_count -eq 0 ]; then
        echo "No backup files found"
    fi
}

# Main execution
main() {
    echo "Starting log rotation process..."
    echo "Max log size: $MAX_LOG_SIZE"
    echo "Max backups: $MAX_BACKUPS"
    echo ""
    
    # Check disk space
    check_disk_space
    
    # Rotate logs if needed
    echo -e "\n${GREEN}🔄 Rotating Log Files:${NC}"
    for log_file in "${LOG_FILES[@]}"; do
        rotate_log "$log_file"
    done
    
    # Show final status
    show_log_status
    
    echo -e "\n${GREEN}✅ Log rotation complete!${NC}"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -s, --status        Show current log status only"
    echo "  -c, --cleanup       Clean up old backups only"
    echo "  -f, --force         Force rotation of all logs"
    echo ""
    echo "Examples:"
    echo "  $0                  # Run normal log rotation"
    echo "  $0 -s               # Show status only"
    echo "  $0 -c               # Clean up old backups"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -s|--status)
        show_log_status
        exit 0
        ;;
    -c|--cleanup)
        echo "Cleaning up old backups..."
        for log_file in "${LOG_FILES[@]}"; do
            cleanup_old_backups "$log_file"
        done
        exit 0
        ;;
    -f|--force)
        echo "Force rotating all logs..."
        for log_file in "${LOG_FILES[@]}"; do
            if [ -f "$log_file" ] && [ -s "$log_file" ]; then
                local timestamp=$(date +%Y%m%d_%H%M%S)
                local backup_file="${log_file%.*}_${timestamp}.${log_file##*.}"
                mv "$log_file" "$backup_file"
                touch "$log_file"
                echo "Force rotated $log_file to $backup_file"
            fi
        done
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac



