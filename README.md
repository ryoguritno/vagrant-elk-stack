# OpenSearch Docker - Log Parsing and Ingestion

This project demonstrates a complete log parsing, processing, and visualization solution using OpenSearch for an e-commerce platform monitoring system.

## Table of Contents

- [Overview](#overview)
- [Why OpenSearch?](#why-opensearch)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Usage](#usage)
- [Metrics Extracted](#metrics-extracted)
- [Accessing the Dashboard](#accessing-the-dashboard)
- [Troubleshooting](#troubleshooting)

## Overview

This solution parses raw e-commerce transaction logs, extracts key performance metrics, transforms them into structured JSON format, and ingests them into OpenSearch for visualization and alerting.

**Log Format:**

```
[timestamp] [service_name] [status_code] [response_time_ms] [user_id] [transaction_id] [additional_info]
```

**Example:**

```
2023-08-15 13:45:00 checkout 200 120ms user1234 tx5678 Purchased iPhone 13
```

## Why OpenSearch?

I chose OpenSearch Stack (OpenSearch + OpenSearch Dashboards) for the following reasons:

1. **Open Source & Community-Driven** - Fully open-source fork of Elasticsearch with Apache 2.0 license, ensuring long-term sustainability
2. **Real-time Search & Analytics** - Provides near real-time search capabilities essential for monitoring live production systems
3. **Scalability** - Handles millions of log entries and scales horizontally as data volume grows
4. **Rich Visualization** - OpenSearch Dashboards offers powerful visualization options similar to Kibana
5. **Advanced Querying** - Supports complex queries, aggregations, and filters needed for deep log analysis
6. **Built-in Alerting** - Native alerting and anomaly detection capabilities for proactive monitoring
7. **AWS Compatible** - Compatible with AWS OpenSearch Service for easy cloud migration
8. **Active Development** - Backed by AWS and has strong community support with regular updates
9. **Docker Support** - Easy to containerize and deploy consistently across environments
10. **Cost-Effective** - No licensing concerns, making it ideal for both development and production

## Architecture

```
sample.log → parse_logs.sh → parsed_logs.json → Logstash/Fluentd → OpenSearch → OpenSearch Dashboards
                                                                                        ↓
                                                                                  Dashboards
                                                                                  & Alerts
```

## Prerequisites

Before running this project, ensure you have:

- **Docker** v27 or higher
- **Docker Compose** v2.27 or higher
- **Bash** (for running the parser script)
- **Git** (to clone the repository)
- At least **4GB of RAM** available for Docker

## Installation & Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/ryoguritno/vagrant-elk-stack.git
cd vagrant-elk-stack
```

### Step 2: Make the Parser Script Executable

```bash
chmod +x scripts/parse_logs.sh
```

### Step 3: Parse the Log File

Run the parser script to transform raw logs into JSON format:

```bash
./scripts/parse_logs.sh sample.log
```

This will generate two files:

- `parsed_logs.json` - Detailed logs in JSON format
- `metrics_summary.json` - Summary of key metrics

**Expected Output:**

```
==========================================
           PARSING COMPLETE
==========================================
Total Transactions: 20
Average Response Time: 650ms
Error Rate: 25.00%
Success (2xx): 15
Client Errors (4xx): 2
Server Errors (5xx): 3
==========================================
```

### Step 4: Start the OpenSearch Stack

Launch OpenSearch and OpenSearch Dashboards using Docker Compose:

```bash
cd vagrantfile
vagrant up
```

Wait 2-3 minutes for all services to start up completely.

### Cloudflare Tunnel Setup

This project includes a `cloudflared` service to expose the OpenSearch Dashboards to the internet securely. To use this feature, you need to provide a Cloudflare Tunnel token.

1. **Create a `.env` file** in the `opensearch-docker-compose` directory.
2. **Add your tunnel token** to the `.env` file:

    ```
    TUNNEL_TOKEN=your-tunnel-token-goes-here
    ```

When you run `vagrant up`, the `cloudflared` service will automatically start and connect to your Cloudflare account, making the OpenSearch Dashboards accessible via a public URL.

### Step 5: Verify Services are Running

Check that all containers are healthy:

```bash
vagrant ssh 
docker-compose ps
```

You should see services running:

- `opensearch-node` on port 9200
- `opensearch-dashboards` on port 5601
- `logstash` on port 5000 (if using Logstash)

Test OpenSearch:

```bash
curl -XGET https://localhost:9200 -u admin:admin --insecure
```

### Step 6: Create Index Template for Correct Date Mapping

Before ingesting logs, create an index template to ensure OpenSearch correctly maps the `timestamp` field as a date. This is crucial for creating time-based visualizations and dashboards.

First, delete the old `logs` index if it exists:

```bash
curl -XDELETE "https://localhost:9200/logs" -u admin:admin --insecure
```

Now, create the index template:

```bash
curl -XPUT "https://localhost:9200/_index_template/logs_template" \
  -u admin:admin \
  --insecure \
  -H "Content-Type: application/json" \
  -d'
{
  "index_patterns": ["logs*"],
  "template": {
    "mappings": {
      "properties": {
        "timestamp": {
          "type": "date",
          "format": "yyyy-MM-dd HH:mm:ss"
        }
      }
    }
  }
}
'
```

### Step 7: Ingest Logs into OpenSearch

Send the parsed JSON logs to OpenSearch:

**Option A: Using curl (Direct API):**

```bash
cat parsed_logs.json | jq -c '.[]' | while read line; do
  curl -XPOST "https://localhost:9200/logs/_doc" \
    -u admin:admin \
    --insecure \
    -H "Content-Type: application/json" \
    -d "$line"
done
```

**Option B: Bulk import for faster ingestion:**

```bash
# Create bulk import file
jq -c '.[] | {"index": {"_index": "logs"}}, .' parsed_logs.json > bulk_logs.ndjson

# Import to OpenSearch
curl -XPOST "https://localhost:9200/_bulk" \
  -u admin:admin \
  --insecure \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @bulk_logs.ndjson
```

### Step 8: Access OpenSearch Dashboards

Open your browser and navigate to:

```
http://localhost:5601
```

**Default credentials:**

- Username: `admin`
- Password: `admin`

Wait for OpenSearch Dashboards to fully load (you'll see the home screen).

### Step 9: Create Index Pattern

1. Go to **Management** → **Stack Management** → **Index Patterns**
2. Click **Create index pattern**
3. Enter `logs*` as the index pattern name
4. Select `timestamp` as the time field (or `@timestamp` if using Logstash)
5. Click **Create index pattern**

### Step 9: View Your Logs

1. Go to **Discover** in the left sidebar
2. Select your `logs*` index pattern from the dropdown
3. You should now see all ingested logs
4. You can filter and search using the search bar

## Usage

### Running the Complete Pipeline

To run the entire solution from scratch:

```bash
# 1. Parse logs
./scripts/parse_logs.sh sample.log

# 2. Start OpenSearch stack (if not already running)
cd vagrantfile
vagrant up

# 3. Wait for services to be ready
sleep 240

# 4. Ingest logs using bulk API
jq -c '.[] | {"index": {"_index": "logs"}}, .' parsed_logs.json > bulk_logs.ndjson
curl -XPOST "https://localhost:9200/_bulk" \
  -u admin:admin \
  --insecure \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @bulk_logs.ndjson

# 5. Open OpenSearch Dashboards
echo "Open http://localhost:5601 in your browser"
echo "Login with admin/admin"
```

### Stopping the Stack

```bash
docker-compose down
```

### Restarting with Clean Data

```bash
docker-compose down -v  # Removes volumes and data
docker-compose up -d
```

## Metrics Extracted

The `parse_logs.sh` script extracts the following metrics from the raw logs:

### 1. **Total Transactions**

- **Description**: Count of all log entries processed
- **How it's calculated**: Increments a counter for each valid log line
- **Use case**: Understanding overall system traffic volume

### 2. **Average Response Time**

- **Description**: Mean response time across all requests in milliseconds
- **How it's calculated**: `SUM(response_time_ms) / total_transactions`
- **Use case**: Identifying performance degradation trends

### 3. **Error Rate Percentage**

- **Description**: Percentage of requests that resulted in 4xx or 5xx errors
- **How it's calculated**: `((4xx_count + 5xx_count) / total_transactions) × 100`
- **Use case**: Monitoring system health and reliability

### 4. **Status Code Breakdown**

- **2xx Success**: Successful requests
- **4xx Client Errors**: Bad requests, not found, unauthorized, etc.
- **5xx Server Errors**: Internal server errors, service unavailable, timeouts
- **How it's calculated**: Counts entries where status code falls in each range
- **Use case**: Identifying whether errors are client-side or server-side

### 5. **Per-Transaction Details**

Each log entry is transformed into structured JSON containing:

- `timestamp`: When the request occurred
- `service`: Which microservice handled the request
- `status_code`: HTTP status code
- `response_time_ms`: Time taken to process request
- `user_id`: User who made the request
- `transaction_id`: Unique transaction identifier
- `additional_info`: Context about the transaction

## Accessing the Dashboard

### Creating a Basic Dashboard

1. In OpenSearch Dashboards, go to **Dashboard** → **Create dashboard**
2. Click **Add panel** → **Create visualization**
3. Add visualizations for:
   - **Line chart**: Error rate over time
   - **Metric**: Total transactions count
   - **Gauge**: Average response time
   - **Pie chart**: Status code distribution
   - **Bar chart**: Requests per service

### Sample Queries for Analysis

In the OpenSearch Dashboards Discover or Dashboard search bar:

**Find all errors:**

```
status_code >= 400
```

**Find slow requests (over 1 second):**

```
response_time_ms > 1000
```

**Find errors in checkout service:**

```
service: "checkout" AND status_code >= 400
```

**Find specific user's transactions:**

```
user_id: "user1234"
```

**DQL (OpenSearch Query Language) examples:**

```
service: "payment" and status_code: 500
response_time_ms > 2000
status_code: (404 or 500)
```

## Setting Up Alerts (Bonus)

### Creating Error Rate Alert

1. Go to **Alerting** in the left sidebar
2. Click **Create monitor**
3. Configure:
   - **Monitor name**: High Error Rate Alert
   - **Monitor type**: Per query monitor
   - **Index**: logs*
   - **Query**:

     ```json
     {
       "query": {
         "range": {
           "status_code": {
             "gte": 400
           }
         }
       }
     }
     ```

   - **Trigger condition**: If count is above 5 in the last 5 minutes
   - **Action**: Send email notification

4. Save and enable the monitor

## Troubleshooting

### OpenSearch won't start

- Check if you have enough memory: `docker stats`
- Increase Docker memory to at least 4GB in Docker settings
- Check logs: `docker-compose logs opensearch-node`
- Verify vm.max_map_count: `sysctl vm.max_map_count` (should be at least 262144)

### OpenSearch Dashboards shows "OpenSearch Dashboards server is not ready yet"

- Wait 2-3 minutes for OpenSearch to fully start
- Check OpenSearch health: `curl -XGET https://localhost:9200/_cluster/health -u admin:admin --insecure`

### No logs appearing in Discover

- Verify logs were ingested: `curl -XGET "https://localhost:9200/logs/_count" -u admin:admin --insecure`
- Check if index pattern is created correctly
- Verify time range filter in Discover page matches your log timestamps

### Certificate errors

- Use `--insecure` flag with curl commands
- OpenSearch uses self-signed certificates in development mode

### Permission denied when running parse_logs.sh

```bash
chmod +x scripts/parse_logs.sh
```

### Port already in use

- Check what's using the port: `lsof -i :9200` or `lsof -i :5601`
- Stop conflicting services or change ports in docker-compose.yml

## Directory Structure

```
.
├── README.md
├── docker-compose.yml
├── scripts/
│   └── parse_logs.sh
├── sample.log
├── parsed_logs.json (generated)
├── metrics_summary.json (generated)
├── bulk_logs.ndjson (generated)
└── docs/
    └── screenshots.pdf
```

## Resources

- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [OpenSearch Dashboards Guide](https://opensearch.org/docs/latest/dashboards/)
- [Query DSL Reference](https://opensearch.org/docs/latest/query-dsl/)
- [Alerting Plugin](https://opensearch.org/docs/latest/monitoring-plugins/alerting/)
