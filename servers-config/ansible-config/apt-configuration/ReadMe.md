apt repository variable config:
```bash
# debian mirror repository
mirror_apt_active: true
mirror_domain_name: repo.mecan.ir
```

apt repository task config:
```bash
---
- name: Delete directory sources.list.d
  ansible.builtin.file:
    state: absent
    path: /etc/apt/sources.list.d/

- name: Creates directory sources.list.d
  file:
    path: /etc/apt/sources.list.d
    state: directory

- name: set mirror MeCan.list
  template:
    src: "MeCan.list.j2"
    dest: "/etc/apt/sources.list.d/MeCan.list"

- name: Update and upgrade apt packages after mirror set
  apt:
    upgrade: yes
    update_cache: yes
    cache_valid_time: 86400
```

apt repository template config:
```bash
deb https://{{ mirror_domain_name }}/repository/debian/ bookworm main
deb https://{{ mirror_domain_name }}/repository/debian/ bookworm-updates main
deb https://{{ mirror_domain_name }}/repository/debian/ bookworm-backports main
deb https://{{ mirror_domain_name }}/repository/debian-security/ bookworm-security main
```

apt proxy set variable:
```bash
# debian apt proxy set
apt_proxy_active: true
apt_proxy_address: asir.mecan.ir
apt_proxy_port: 8123
```

apt proxy task config:
```bash
---
- name: Delete apt proxy config if exist
  ansible.builtin.file:
    state: absent
    path: /etc/apt/apt.conf.d/01proxy

- name: set MeCan apt proxy
  template:
    src: "apt-proxy.j2"
    dest: "/etc/apt/apt.conf.d/01proxy"

- name: Update and upgrade apt packages after mirror set
  apt:
    upgrade: yes
    update_cache: yes
    cache_valid_time: 86400
```

apt proxy template config:
```bash
Acquire::http::Proxy "http://{{ apt_proxy_address }}:{{ apt_proxy_port }}";
Acquire::https::Proxy "http://{{ apt_proxy_address }}:{{ apt_proxy_port }}";
{% if mirror_apt_active is true %}
Acquire::http::Proxy::{{ mirror_domain_name }} DIRECT;
{% endif %}
```