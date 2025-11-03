import json
import re
import sys

index_name = "app-logs"
# Corrected regex to allow hyphens in the service name
log_pattern = re.compile(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) ([\w-]+) (\d{3}) (\d+ms) (\w+) (\w+) (.*)")

bulk_payload = ""
lines_read = 0
lines_matched = 0

try:
    with open("sample_logs.log", "r") as f:
        for line in f:
            lines_read += 1
            match = log_pattern.match(line)
            if not match:
                #print(f"No match: {line.strip()}", file=sys.stderr)
                continue
            
            lines_matched += 1
            timestamp, service, status, response_time, user, transaction, message = match.groups()
            
            log_doc = {
                "@timestamp": timestamp,
                "service": service,
                "status_code": int(status),
                "response_time_ms": int(response_time.replace("ms", "")),
                "user_id": user,
                "transaction_id": transaction,
                "message": message.strip()
            }
            
            action = {"index": {"_index": index_name}}
            bulk_payload += json.dumps(action) + "\n"
            bulk_payload += json.dumps(log_doc) + "\n"
except FileNotFoundError:
    print("Error: sample_logs.log not found.", file=sys.stderr)
    sys.exit(1)

# Sanity check
if lines_matched == 0 and lines_read > 0:
    print(f"Error: Regex did not match any of the {lines_read} lines in the log file.", file=sys.stderr)
    sys.exit(1)

print(bulk_payload)
