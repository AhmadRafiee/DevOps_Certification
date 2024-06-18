# Ansible configuration:

### How to set host_key_checking=false in ansible
If you understand the implications and wish to disable this behavior, you can do so by editing `/etc/ansible/ansible.cfg` or `~/.ansible.cfg`:


```bash
[defaults]
host_key_checking = False
```
Alternatively this can be set by the `ANSIBLE_HOST_KEY_CHECKING` environment variable:
```bash
export ANSIBLE_HOST_KEY_CHECKING=False
```


### Setting the Environment (and Working With Proxies)
The environment keyword allows you to set an environment varaible for the action to be taken on the remote target. For example, it is quite possible that you may need to set a proxy for a task that does http requests. Or maybe a utility or script that are called may also need certain environment variables set to run properly.

Here is an example:
```bash
- hosts: all
  remote_user: root

  tasks:

    - name: Install cobbler
      package:
        name: cobbler
        state: present
      environment:
        http_proxy: http://proxy.example.com:8080
```
You can also use it at a play level:
```bash
- hosts: testhost

  roles:
     - php
     - nginx

  environment:
    http_proxy: http://proxy.example.com:8080
```

You can re-use environment settings by defining them as variables in your play and accessing them in a task as you would access any stored Ansible variable.
```bash
- hosts: all
  remote_user: root

  # create a variable named "proxy_env" that is a dictionary
  vars:
    proxy_env:
      http_proxy: http://proxy.bos.example.com:8080
      https_proxy: http://proxy.bos.example.com:8080

  tasks:

    - name: Install cobbler
      ansible.builtin.package:
        name: cobbler
        state: present
      environment: "{{ proxy_env }}"
```