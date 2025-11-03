#!/bin/bash

# Simple log parser for SRE assignment
# Format: [timestamp] [service_name] [status_code] [response_time_ms] [user_id] [transaction_id] [additional_info]

LOG_FILE="${1:-sample.log}"
OUTPUT_FILE="parsed_logs.json"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file '$LOG_FILE' not found"
    exit 1
fi

echo "Parsing log file: $LOG_FILE"
echo "Output will be saved to: $OUTPUT_FILE"

# Initialize counters
total_transactions=0
total_response_time=0
error_4xx=0
error_5xx=0
success_2xx=0

# Start JSON output
echo "[" > "$OUTPUT_FILE"

first_entry=true

# Parse each line
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Extract fields
    timestamp=$(echo "$line" | awk '{print $1, $2}')
    service=$(echo "$line" | awk '{print $3}')
    status=$(echo "$line" | awk '{print $4}')
    response_time=$(echo "$line" | awk '{print $5}' | sed 's/ms//')
    user_id=$(echo "$line" | awk '{print $6}')
    transaction_id=$(echo "$line" | awk '{print $7}')
    additional_info=$(echo "$line" | cut -d' ' -f8-)
    
    # Count transactions
    ((total_transactions++))
    
    # Sum response times
    total_response_time=$((total_response_time + response_time))
    
    # Count errors by status code
    if [[ $status -ge 200 && $status -lt 300 ]]; then
        ((success_2xx++))
    elif [[ $status -ge 400 && $status -lt 500 ]]; then
        ((error_4xx++))
    elif [[ $status -ge 500 ]]; then
        ((error_5xx++))
    fi
    
    # Add comma before entry if not first
    if [ "$first_entry" = false ]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    first_entry=false
    
    # Write JSON entry
    cat >> "$OUTPUT_FILE" << EOF
  {
    "timestamp": "$timestamp",
    "service": "$service",
    "status_code": $status,
    "response_time_ms": $response_time,
    "user_id": "$user_id",
    "transaction_id": "$transaction_id",
    "additional_info": "$additional_info"
  }
EOF

done < "$LOG_FILE"

# Close JSON array
echo "" >> "$OUTPUT_FILE"
echo "]" >> "$OUTPUT_FILE"

# Calculate metrics
if [ $total_transactions -gt 0 ]; then
    avg_response_time=$((total_response_time / total_transactions))
    error_rate=$(awk "BEGIN {printf \"%.2f\", (($error_4xx + $error_5xx) / $total_transactions) * 100}")
else
    avg_response_time=0
    error_rate=0
fi

# Create metrics summary file
METRICS_FILE="metrics_summary.json"
cat > "$METRICS_FILE" << EOF
{
  "summary": {
    "total_transactions": $total_transactions,
    "average_response_time_ms": $avg_response_time,
    "error_rate_percentage": $error_rate,
    "status_breakdown": {
      "success_2xx": $success_2xx,
      "client_errors_4xx": $error_4xx,
      "server_errors_5xx": $error_5xx
    }
  }
}
EOF

# Print summary to console
echo ""
echo "=========================================="
echo "           PARSING COMPLETE"
echo "=========================================="
echo "Total Transactions: $total_transactions"
echo "Average Response Time: ${avg_response_time}ms"
echo "Error Rate: ${error_rate}%"
echo "Success (2xx): $success_2xx"
echo "Client Errors (4xx): $error_4xx"
echo "Server Errors (5xx): $error_5xx"
echo "=========================================="
echo ""
echo "Output files created:"
echo "  - $OUTPUT_FILE (detailed logs in JSON)"
echo "  - $METRICS_FILE (metrics summary)"
echo ""