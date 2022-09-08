# Installation ansible on Ubuntu linux

### Install dependencies and configure Ansible Repository
Install ansible dependencies by running the following apt command,
```bash
sudo apt install -y software-properties-common
```
Once the dependencies are installed then configure PPA repository for ansible, run
```bash
sudo add-apt-repository --yes --update ppa:ansible/ansible
```
Now update repository by running beneath apt command.
```bash
sudo apt update
```

### Install latest version of ansible
Now we are ready to install latest version of Ansible on Ubuntu 20.04 LTS / 21.04, run following command.
```bash
sudo apt install -y ansible
```
After the successful installation of Ansible, verify its version by executing the command

```bash
ansible --version
```
Great, above output confirms that Ansible version 2.9.6 is installed.