# Ansible useful commands

### Directory Structure:
 To create a role using the ansible-galaxy command, we can simply use the below syntax in our terminal:
```bash
ansible-galaxy init <ROLE_NAME>
# for example
ansible-galaxy init nginx
```


### Simple Modules
Ping hosts
```bash
ansible <HOST_GROUP> -m ping
# for example
ansible localhost -m ping
```
Display gathered facts
```bash
ansible <HOST_GROUP> -m setup | less
# for example
ansible localhost -m setup | less
```
Filter gathered facts
```bash
ansible <HOST_GROUP> -m setup -a "filter=ansible_distribution*"
# for example
ansible localhost -m setup -a "filter=ansible_distribution*"
```

Copy SSH key manually
```bash
ansible <HOST_GROUP> -m authorized_key -a "user=root key='ssh-rsa AAAA...XXX == root@hostname'"
# for example
ansible localhost -m authorized_key -a "user=root key='ssh-rsa AAAA...XXX == root@hostname'"
```

### Limit to one or more hosts
This is required when one wants to run a playbook against a host group, but only against one or more members of that group.

Limit to one host
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit "host1"
```
Limit to multiple hosts
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit "host1,host2"
```
Negated limit. NOTE: Single quotes MUST be used to prevent bash interpolation.
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit 'all:!host1'
```
Limit to host group
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit 'group1'
```

### Limiting Tasks with Tags
Limit to all tags matching install
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --tags 'install'
```
Skip any tag matching sudoers
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --skip-tags 'sudoers'
```

### Check for bad syntax
One can check to see if code contains any syntax errors by running the playbook.

Check for bad syntax:
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --syntax-check
```

### Running a playbook in dry-run mode
Sometimes it can be useful to see what Ansible might do, but without actually changing anything.

One can run in dry-run mode like this:
```bash
ansible-playbook playbooks/PLAYBOOK_NAME.yml --check
```

### Managing files
An ad hoc task can harness the power of Ansible and SCP to transfer many files to multiple machines in parallel. To transfer a file directly to all servers in the [atlanta] group:
```bash
ansible atlanta -m copy -a "src=/etc/hosts dest=/tmp/hosts"
```

The ansible.builtin.file module allows changing ownership and permissions on files. These same options can be passed directly to the copy module as well:
```bash
ansible webservers -m file -a "dest=/srv/foo/a.txt mode=600"
ansible webservers -m file -a "dest=/srv/foo/b.txt mode=600 owner=mdehaan group=mdehaan"
```

### Install packages
ansible ad hoc command to install packages:
```bash
ansible localhost -a "apt install vim" --become
ansible all -i hosts.yml -a "apt install vim" --become
ansible all -i hosts.yml -m shell -a "apt install vim" --become
```

### ansible fact and filter data
Facts include a large amount of variable data, filter useful data from it.
```bash
ansible all -i inventories/hosts.yml -m setup  -a "filter=ansible_os_family"
ansible all -i inventories/hosts.yml -m setup  -a "filter=ansible_nodename"
ansible all -i inventories/hosts.yml -m setup  -a "filter=ansible_interfaces"
ansible all -i inventories/hosts.yml -m setup  -a "filter=ansible_lsb"
ansible all -i inventories/hosts.yml -m setup  -a "filter=ansible_memory_mb"
ansible all -i inventories/hosts.yml -m setup  -a "filter=ansible_processor_vcpus"
```

### Managing services
Ensure a service is started on all webservers:
```bash
ansible webservers -m ansible.builtin.service -a "name=httpd state=started"
```
Alternatively, restart a service on all webservers:

```bash
ansible webservers -m ansible.builtin.service -a "name=httpd state=restarted"
```
Ensure a service is stopped:

```bash
ansible webservers -m ansible.builtin.service -a "name=httpd state=stopped"
ansible all -i inventories/hosts.yml -m service -a 'name=nginx state=started'
ansible all -i inventories/hosts.yml -a 'systemctl status nginx'
```