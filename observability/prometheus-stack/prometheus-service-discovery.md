# Prometheus [File | Http] service discovery
Prometheus supports file-based service discovery and HTTP-based service discovery for dynamically configuring scrape targets. Here’s an example for both:

## 1. File-Based Service Discovery
Prometheus dynamically discovers targets from a JSON or YAML file. The file's content must be updated externally, and Prometheus reloads the configuration when the file changes.

File content (`targets.json`):

```json
[
  {
    "targets": ["192.168.1.100:9100", "192.168.1.101:9100"],
    "labels": {
      "env": "production",
      "job": "node_exporter"
    }
  },
  {
    "targets": ["192.168.1.102:9100"],
    "labels": {
      "env": "staging",
      "job": "node_exporter"
    }
  }
]
```
Prometheus configuration (`prometheus.yml`):
```yaml
scrape_configs:
  - job_name: 'node_exporter_file_sd'
    file_sd_configs:
      - files:
          - /path/to/targets.json
```

`targets.yaml` (YAML File with Targets)
```yaml
- targets:
    - "192.168.1.100:9100"
    - "192.168.1.101:9100"
  labels:
    env: production
    job: node_exporter
- targets:
    - "192.168.1.102:9100"
  labels:
    env: staging
    job: node_exporter
```

Prometheus Configuration (`prometheus.yml`)
```yaml
scrape_configs:
  - job_name: 'node_exporter_file_sd'
    file_sd_configs:
      - files:
          - /path/to/targets.yaml
```

Other example file service discovery
```yaml
file_sd_config:
  files:
    - "/etc/prometheus/external/targets/*.yml"
    - "/opt/monitoring/targets/prod-*.yml"
    - "/data/dynamic-targets-[0-9]*.yaml"
  refresh_interval: 120
```
### Workflow
  - You update targets.json dynamically via scripts or orchestration tools.
  - Prometheus automatically reloads the file and updates targets without requiring a restart.

## 2. HTTP-Based Service Discovery
Prometheus queries an HTTP endpoint that returns the target information in JSON format.

HTTP endpoint response (`http://example.com/targets`):

```json
[
  {
    "targets": ["192.168.1.200:9100", "192.168.1.201:9100"],
    "labels": {
      "env": "development",
      "job": "node_exporter"
    }
  },
  {
    "targets": ["192.168.1.202:9100"],
    "labels": {
      "env": "testing",
      "job": "node_exporter"
    }
  }
]
```
Prometheus configuration (`prometheus.yml`):

```yaml
scrape_configs:
  - job_name: 'node_exporter_http_sd'
    http_sd_configs:
      - url: 'http://example.com/targets'
        refresh_interval: 30s
```

For HTTP-based service discovery, Prometheus directly supports Basic Authentication when querying the service discovery endpoint.

Prometheus configuration (`prometheus.yml`):
```yaml
scrape_configs:
  - job_name: 'node_exporter_http_sd'
    http_sd_configs:
      - url: 'https://example.com/targets'
        basic_auth:
          username: 'myuser'
          password: 'mypassword'
        refresh_interval: 30s
```

### Workflow
  - The HTTP server dynamically generates the JSON payload with target information.
  - Prometheus queries the endpoint every 30 seconds (as configured in refresh_interval).

### Key Notes:
  - Both methods enable dynamic discovery of targets.
  - Use file-based SD when you have external processes (e.g., CI/CD pipelines or automation scripts) that can write to files.
  - Targets are read from a local YAML file.
  - Configuration is updated dynamically when the file changes.
  - Use HTTP-based SD when you have an API or service registry (e.g., Consul or custom service) that can dynamically serve target data.
  - Let me know if you need further customization for your use case!
  - Prometheus queries a service discovery API endpoint.
  - Basic Authentication can be configured using basic_auth in the scrape config.


## Subnet scanning as a service discovery
Prometheus does not natively support subnet scanning as a service discovery mechanism. However, it can integrate with external tools or service discovery APIs to achieve this functionality. Here's how you can set up Prometheus service discovery for a subnet, depending on your requirements:

### File-Based Service Discovery
You can use an external script or tool to scan the subnet and generate a file (`targets.json`) that Prometheus will read.

Step 1: Script to Discover Targets in a Subnet
Here’s a Python script to scan a subnet (e.g., `192.168.1.0/24`) and generate a `targets.json` file with active hosts running on a specific port (e.g., `9100` for `node_exporter`):

```python
import json
import socket
from ipaddress import ip_network

# Define the subnet and port to scan
SUBNET = "192.168.1.0/24"
PORT = 9100
TIMEOUT = 0.1  # Timeout in seconds for connection attempts
OUTPUT_FILE = "/path/to/targets.json"  # Path to save the generated file

def scan_subnet(subnet, port):
    """Scan a subnet for active targets on the specified port."""
    targets = []
    for ip in ip_network(subnet).hosts():
        try:
            with socket.create_connection((str(ip), port), timeout=TIMEOUT):
                targets.append(f"{ip}:{port}")
                print(f"Discovered target: {ip}:{port}")
        except Exception:
            pass
    return targets

def write_targets_file(targets, output_file):
    """Write the discovered targets to a Prometheus-compatible JSON file."""
    target_data = [{"targets": targets, "labels": {"job": "node_exporter", "env": "subnet"}}]
    with open(output_file, "w") as f:
        json.dump(target_data, f, indent=4)
    print(f"Targets written to {output_file}")

if __name__ == "__main__":
    # Scan subnet and save targets to file
    discovered_targets = scan_subnet(SUBNET, PORT)
    if discovered_targets:
        write_targets_file(discovered_targets, OUTPUT_FILE)
    else:
        print("No active targets found.")
```

### Step 2: Prometheus Configuration
Add the following configuration to your `prometheus.yml` to use the generated `targets.json` file:

```yaml
scrape_configs:
  - job_name: 'node_exporter_subnet'
    file_sd_configs:
      - files:
          - /path/to/targets.json
        refresh_interval: 30s  # Refresh file every 30 seconds
```