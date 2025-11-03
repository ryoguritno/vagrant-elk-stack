# OpenSearch Cluster with Vagrant and Docker

This project provides two methods for deploying a multi-node OpenSearch cluster with OpenSearch Dashboards:

1.  **Vagrant + Docker (Recommended):** Deploys a full three-node, security-enabled OpenSearch cluster, complete with a custom Filebeat image for log shipping. This is the most complete setup.
2.  **Docker Compose Only:** Deploys a simpler two-node cluster for quick local testing without a virtual machine.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) (Required for the recommended setup)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (or another Vagrant provider)
- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/)

---

## Method 1: Vagrant + Docker Setup (Recommended)

This method provisions a Debian VM and runs a secure, three-node OpenSearch cluster inside it using Docker Compose.

### How to Run

1.  **Configure Host Machine (One-time setup):**
    Raise your host machine's ulimits for OpenSearch to handle high I/O.

    ```bash
    sudo sysctl -w vm.max_map_count=512000
    ```
    To make this setting persistent, add `vm.max_map_count=512000` to `/etc/sysctl.conf` and run `sudo sysctl -p`.

2.  **Start the Vagrant VM and Services:**
    Open your terminal in the project root directory and run:

    ```bash
    vagrant up
    ```

    This single command will automatically:
    - Create and configure a Debian 12 virtual machine.
    - Install Docker and Docker Compose inside the VM.
    - Generate the necessary TLS certificates for the cluster.
    - Build a custom Filebeat image to ensure correct file permissions.
    - Start the three-node OpenSearch cluster, Filebeat, and OpenSearch Dashboards using the configuration in `opensearch-docker-compose/`.
    - Initialize the OpenSearch security plugin.

### Access the Services

-   **OpenSearch Dashboards:**
    -   **URL:** [https://localhost:5601](https://localhost:5601)
    -   You will see a browser warning about a self-signed certificate. You can safely proceed.
    -   **Username:** `admin`
    -   **Password:** `admin` (This is configured by the security initialization script).

-   **OpenSearch API:**
    -   **URL:** [https://localhost:9200](https://localhost:9200)
    -   You can test the connection with `curl`:
        ```bash
        curl -k -u admin:admin https://localhost:9200
        ```

### Filebeat Configuration

The Vagrant setup includes a Filebeat container that ships logs from all Docker containers on the VM to OpenSearch. This uses a custom Dockerfile (`opensearch-docker-compose/filebeat.Dockerfile`) to ensure the correct file ownership and permissions.

---

## Method 2: Docker Compose Only Setup (Simple)

This method uses the `docker-compose.yml` file in the root of the project to launch a basic two-node cluster directly on your local machine.

### How to Run

1.  **Configure Admin Password:**
    Create a `.env` file in the project root and specify the admin password for OpenSearch.

    ```bash
    # .env
    OPENSEARCH_INITIAL_ADMIN_PASSWORD=mysecretpassword
    ```

2.  **Start the Services:**
    Run the following command from the project root directory:
    ```bash
    docker-compose up -d
    ```
    This will start a two-node OpenSearch cluster and OpenSearch Dashboards.

### Access the Services

-   **OpenSearch Dashboards:**
    -   **URL:** [http://localhost:5601](http://localhost:5601)
    -   **Username:** `admin`
    -   **Password:** The password you set in the `.env` file.

-   **OpenSearch API:**
    -   **URL:** [https://localhost:9200](https://localhost:9200)
    -   You can test the connection with `curl`:
        ```bash
        curl -k -u admin:<your_password> https://localhost:9200
        ```
        Replace `<your_password>` with the password from your `.env` file.

---

## Importing Sample Logs into OpenSearch Dashboards

This project includes `sample_logs.log` and an `upload_script.py` to help you populate your OpenSearch instance with sample data.

**Note:** The default password `admin` is used in the commands below. If you are using the **Docker Compose Only** method, replace `admin:admin` with `admin:<your_password>`.

### 1. Prepare the OpenSearch Index

Before uploading, you must create the `app-logs` index with the correct field mappings.

**a. Delete existing `app-logs` index (if any):**
```bash
curl -k -u admin:admin -X DELETE https://localhost:9200/app-logs
```

**b. Create `app-logs` index with correct mapping:**
This command ensures the `@timestamp` field is recognized as a date, which is crucial for time-based visualizations in OpenSearch Dashboards.
```bash
curl -k -u admin:admin -X PUT "https://localhost:9200/app-logs" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "@timestamp": {
        "type": "date",
        "format": "yyyy-MM-dd HH:mm:ss"
      },
      "service": { "type": "keyword" },
      "status_code": { "type": "integer" },
      "response_time_ms": { "type": "integer" },
      "user_id": { "type": "keyword" },
      "transaction_id": { "type": "keyword" },
      "message": { "type": "text" }
    }
  }
}
'
```
You should see `{"acknowledged":true,"shards_acknowledged":true,"index":"app-logs"}` as a response.

### 2. Upload Sample Logs

Use the provided Python script to parse `sample_logs.log` and upload them to your OpenSearch instance.

```bash
python3 upload_script.py | curl -k -u admin:admin --data-binary @- -H "Content-Type: application/json" https://localhost:9200/_bulk
```

### 3. Create Index Pattern in OpenSearch Dashboards

1.  **Open OpenSearch Dashboards:** Go to `https://localhost:5601`.
2.  **Log in** with your admin credentials.
3.  **Navigate to Index Patterns:**
    *   In the left-hand menu, go to **Stack Management** > **Index Patterns**.
4.  **Create New Index Pattern:**
    *   Click **Create index pattern**.
    *   For the "Index pattern name", enter `app-logs`.
    *   Click **Next step**.
5.  **Configure Time Field:**
    *   From the "Time field" dropdown, select **`@timestamp`**.
    *   Click **Create index pattern**.

You can now go to the **Discover** section to explore your log data.

## Managing the Vagrant Environment

These commands apply only to the **Vagrant + Docker** setup.

-   **SSH into the VM:**
    ```bash
    vagrant ssh
    ```

-   **Stop the VM:**
    ```bash
    vagrant halt
    ```

-   **Destroy the VM (Deletes all data):**
    ```bash
    vagrant destroy
    ```
