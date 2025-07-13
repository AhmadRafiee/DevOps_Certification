### Adding or Registering Remote Linux Host in Zabbix Server 
Login to your Zabbix Server portal using admin user’s credentials .To add a host on the Zabbix server, click on Configuration –> Hosts.

On the far top- right end, click on the ‘Create host’ button

On the page that appears, fill out the remote Linux’s details as listed:

- Hostname
- Visible name
- IP address
- Description

Next, click on the ‘select’ button next to the ‘Groups’ text field. On the ‘Host groups’ list, click on ‘Linux servers’ and then click ‘Select’.

As you can see, the group has been added.

We also need to add a template for our server. So, click on the ‘Templates’ menu option.

On the ‘Templates’ list that appears, click on ‘Template OS Linux by Zabbix agent’ and hit the ‘Select’ button.

This takes you back to the home screen and there you can see that your new host system has been added.

To add the CentOS-8 system, repeat the same steps described.

### Graphing statistics of the remote hosts
To represent system metrics in a graphical form, click on ‘Monitoring’  –> ‘Hosts’

Next, click on the host you want to graph and select the ‘graph’ option from the pull-up menu.

Zabbix server will begin generating various graphs representing various system metrics such as Processes, CPU load, and network traffic statistics to mention a few.

Scroll down to view other graphs displaying various metrics as shown below.

We have successfully added 2 Linux host systems to the Zabbix server and managed to graph various system metrics. We appreciate your feedback. Give it a try and let us know your experience.

[link](https://www.linuxtechi.com/add-linux-host-zabbix-server-for-monitoring/)