# OpenSearch Cluster with Vagrant and Docker

This project deploys a two-node OpenSearch cluster with OpenSearch Dashboards using Vagrant and Docker Compose.

## Key Concepts

- OpenSearch is [the successor of OpenDistro](https://opendistro.github.io/for-elasticsearch/blog/2021/06/forward-to-opensearch/)
- OpenSearch = Elasticsearch
- OpenSearch Dashboards = Kibana

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (or another Vagrant provider)
- [Docker](https://docs.docker.com/engine/install/) should be installed on your local machine, but the provisioning script will install it inside the Vagrant VM.

## Setup

1.  **Configure Admin Password:**
    The default admin password for OpenSearch is set in the `.env` file. You can change it by modifying the `OPENSEARCH_INITIAL_ADMIN_PASSWORD` variable.

    ```bash
    # .env
    OPENSEARCH_INITIAL_ADMIN_PASSWORD=admin
    ```

2.  **Vagrant Configuration:**
    The `vagrantfile/Vagrantfile` is configured to create a Debian 12 VM and forward the following ports:
    -   `9200` (OpenSearch API) to `9200` on your host machine.
    -   `5601` (OpenSearch Dashboards) to `5601` on your host machine.

## How to Run

1.  **Configure Host Machine:**
    Raise your host's ulimits for OpenSearch to handle high I/O:

    ```bash
    sudo sysctl -w vm.max_map_count=512000
    ```
    To make this setting persistent, add `vm.max_map_count=512000` to `/etc/sysctl.conf` and run `sudo sysctl -p`.

2.  **Generate Certificates:**
    Navigate to the `opensearch-docker-compose` directory and generate the necessary TLS certificates for the cluster:

    ```bash
    cd opensearch-docker-compose
    bash generate-certs.sh
    cd ..
    ```

3.  **Start the Vagrant VM and Services:**
    Open your terminal in the project root directory and run:

    ```bash
    vagrant up
    ```

    This command will:
    -   Create a new virtual machine.
    -   Install Docker and Docker Compose inside the VM.
    -   Build a custom Filebeat image to ensure correct file permissions.
    -   Start the OpenSearch cluster, Filebeat, and other services using `docker-compose up -d`.

4.  **Initialize Security Plugin:**
    Wait about 30 seconds for the cluster to start, then run the following command to initialize the security plugin. This command needs to be run from within the `opensearch-docker-compose` directory inside the Vagrant VM.

    ```bash
    vagrant ssh
    cd opensearch-docker-compose
    docker compose exec os01 bash -c "chmod +x plugins/opensearch-security/tools/securityadmin.sh && bash plugins/opensearch-security/tools/securityadmin.sh -cd config/opensearch-security -icl -nhnv -cacert config/certificates/ca/ca.pem -cert config/certificates/ca/admin.pem -key config/certificates/ca/admin.key -h localhost"
    exit
    ```

## Filebeat Configuration

This project uses Filebeat to ship logs from Docker containers to OpenSearch. Due to file permission issues with the default Filebeat setup, this project uses a custom Dockerfile (`filebeat.Dockerfile`) to build a Filebeat image with the correct ownership for the configuration and certificate files.

The `docker-compose.yml` is configured to build this custom image and use the `log` input to read logs directly from `/var/lib/docker/containers/*/*.log`.

## Access the Services

-   **OpenSearch Dashboards:**
    -   URL: [https://localhost:5601](https://localhost:5601)
    -   You will see a warning about a self-signed certificate. You can safely proceed.
    -   Username: `admin`
    -   Password: The password you set in the `.env` file (default is `admin`).

-   **OpenSearch API:**
    -   URL: [https://localhost:9200](https://localhost:9200)
    -   You can test the connection with `curl`:
        ```bash
        curl -k -u admin:<your_password> https://localhost:9200
        ```
        Replace `<your_password>` with the password from your `.env` file.

## Importing Sample Logs into OpenSearch Dashboards

This project includes `sample_logs.log` and an `upload_script.py` to help you quickly populate your OpenSearch instance with sample data and visualize it in OpenSearch Dashboards.

### 1. Prepare the OpenSearch Index

Before uploading, ensure your `app-logs` index has the correct mapping for time-based data. If you've previously uploaded logs or created an `app-logs` index, you might need to delete it first to apply the correct mapping.

**a. Delete existing `app-logs` index (if any):**
```bash
curl -k -u admin:admin -X DELETE https://localhost:9200/app-logs
```
You should see `{"acknowledged":true}` as a response.

**b. Create `app-logs` index with correct mapping:**
This command creates the `app-logs` index and ensures the `@timestamp` field is recognized as a date field, which is crucial for OpenSearch Dashboards.
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
This command will output a JSON response indicating the success of the bulk upload.

### 3. Create Index Pattern in OpenSearch Dashboards

After uploading the logs, you need to create an index pattern in OpenSearch Dashboards to visualize them.

1.  **Open OpenSearch Dashboards:** Go to `https://localhost:5601` in your web browser.
2.  **Log in:** Use `admin` as the username and `admin` (or your configured password from `.env`) as the password.
3.  **Hard Refresh (Recommended):** Before proceeding, perform a hard refresh of your browser (`Ctrl+Shift+R` or `Cmd+Shift+R`) to clear any cached data.
4.  **Navigate to Index Patterns:**
    *   In the left-hand navigation menu, click on **Stack Management**.
    *   Under "Kibana", click on **Index Patterns**.
5.  **Delete Old Pattern (if it exists):** If you see an existing `app-logs` index pattern, delete it first.
6.  **Create New Index Pattern:**
    *   Click the **Create index pattern** button.
    *   In the "Index pattern name" field, **carefully type** `app-logs`.
    *   You should see a message like "Success! Your index pattern matches 1 source."
    *   Click **Next step**.
7.  **Configure Time Field:**
    *   From the "Time field" dropdown, select **`@timestamp`**.
    *   Click **Create index pattern**.

You can now go to the **Discover** section in OpenSearch Dashboards to view and explore your `app-logs` data.

## Managing the Environment

-   **SSH into the VM:**
    ```bash
    vagrant ssh
    ```

-   **Stop the VM:**
    ```bash
    vagrant halt
    ```

-   **Destroy the VM:**
    This will delete the virtual machine and all the data in the OpenSearch cluster.
    ```bash
    vagrant destroy
    ```

## Advanced: Hot-Warm Architecture

Use a [hot-warm cluster architecture](https://opensearch.org/docs/latest/opensearch/cluster/#advanced-step-7-set-up-a-hot-warm-architecture) if you have data that you rarely want to update or search so you can place them on lower-cost storage nodes.

<center>
    <img alt="Hot-warm architecture schema" src="./opensearch-docker-compose/hot-warm-architecture.jpg" />
</center>

<details>
<summary>Hot-warm architecture cluster setup instructions...</summary>
<br>

Raise your host's ulimits for OpenSearch to handle high I/O :

```bash
sudo sysctl -w vm.max_map_count=512000
# Persist this setting in `/etc/sysctl.conf` and execute `sysctl -p`
```

Now, we will generate the certificates for the cluster :

```bash
# You may want to edit the OPENDISTRO_DN variable first
bash generate-certs-hot-warm.sh
```

Adjust `Xms/Xmx` parameters and start the cluster :

```bash
docker compose -f docker-compose.hot-warm.yml up -d
```

Wait about 60 seconds and run `securityadmin` to initialize the security plugin :

```bash
docker compose exec os01 bash -c "chmod +x plugins/opensearch-security/tools/securityadmin.sh && bash plugins/opensearch-security/tools/securityadmin.sh -cd config/opensearch-security -icl -nhnv -cacert config/certificates/ca/ca.pem -cert config/certificates/ca/admin.pem -key config/certificates/ca/admin.key -h localhost"
```

> Find all the configuration files in the container's `/usr/share/opensearch/config/opensearch-security` directory. You might want to [mount them as volumes](https://opendistro.github.io/for-elasticsearch-docs/docs/install/docker-security/).

Access OpenSearch Dashboards through [https://localhost:5601](https://localhost:5601)

Default username is `admin` and password is `admin`

> Take a look at [OpenSearch's internal users documentation](https://opensearch.org/docs/security-plugin/configuration/yaml/) to add, remove or update a user.

</details>

To add an index to a warm node :

```json
PUT newindex
{
  "settings": {
    "index.routing.allocation.require.temp": "warm"
  }
}
```

You might want to use [Index State Management (ILM)](https://opensearch.org/docs/latest/im-plugin/index/) to automatically move old indices from _hot_ to _warm_ nodes.

## Why OpenSearch

- Fully open source (including plugins)
- Fully under Apache 2.0 license
- Advanced security plugin (free)
- Alerting plugin (free)
- Allows you to [perform SQL queries against OpenSearch](https://opensearch.org/docs/latest/search-plugins/sql/index/)
- Maintained by AWS and used for its cloud services