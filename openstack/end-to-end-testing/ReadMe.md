# OpenStack End-to-End Testing with Rally
This guide provides step-by-step instructions for installing Rally, setting up the environment, and running a sample task for OpenStack testing. Rally is a benchmarking and testing tool for OpenStack deployments.

## Prerequisites

* An Ubuntu/Debian-based system (commands are tailored for apt).
* Access to an OpenStack environment with admin credentials (e.g., via an openrc file).
* Ensure you have root or sudo access for package installations.

## Install Rally
Install required tools:
```bash
sudo apt update
sudo apt install -y python3-venv git bash-completion
```

Create and activate a virtual environment for Rally:
```bash
python3 -m venv /opt/rally
source /opt/rally/bin/activate
```

Install Rally for OpenStack (using version 3.0.0 as specified; consider checking for updates if needed):
```bash
pip install rally-openstack==3.0.0
```

Set up bash completion for Rally:
```bash
rally bash-completion > /etc/bash_completion.d/rally
source /etc/bash_completion.d/rally
```

**Note:** All subsequent Rally commands should be run within this activated virtual environment. If you start a new terminal session, reactivate it with source `/opt/rally/bin/activate`.

## Setting Up the Environment and Running a Sample Task
Source your OpenStack admin credentials (adjust the path if your openrc file is elsewhere):
```bash
source /opt/admin-openrc.sh
```
Create the Rally database:
```bash
rally db create
```
Create a Rally deployment using the environment variables from the openrc file, and verify it:
```bash
# Create deployment
rally deployment create --fromenv --name=test

# Check deployment
rally deployment list
rally deployment check
rally deployment show
```

Clone the Rally-OpenStack repository for sample scenarios:
```bash
cd /opt/
git clone https://github.com/openstack/rally-openstack.git
```
Test and run a sample Rally scenario (e.g., creating and deleting a flavor):
```bash
cd /opt/rally-openstack/samples/tasks/scenarios/nova/

# Optionally, view the scenario file
vim create-and-delete-flavor.yaml

# Run the scenario (this will output a task UUID)
rally task start ./create-and-delete-flavor.yaml

# Generate an HTML report (replace <task-uuid> with the UUID from the previous command)
rally task report <task-uuid> --out output.html
```
## Tips:

* The rally task start command will display the task UUID in its output. Use that for reporting.
* View the report by opening output.html in a web browser.
* For more scenarios, explore other YAML files in the samples/tasks/scenarios/ directory.
* If you encounter issues, ensure your OpenStack credentials are correctly sourced and the deployment is healthy (use rally deployment check).

## Deactivating the Environment
When finished, deactivate the virtual environment:
```bash
deactivate
```