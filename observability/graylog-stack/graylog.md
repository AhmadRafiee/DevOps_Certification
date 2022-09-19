### Configure Ubuntu Client to Send Logs whit rsyslog server

Now it's time to configure the Ubuntu client machine for sending logs to the Graylog server. And this can be done by using the Rsyslog service.

First, connect to your Ubuntu machine using the ssh command below.
```bash
ssh user@SERVER-IP
```
Check the Rsyslog package on the Ubuntu machine and make sure it's installed.
```bash
sudo dpkg -l | grep rsyslog
sudo apt info rsyslog
```
you can see the rsyslog package is installed by default. The "ii" on the field means installed.

Now verify the Rsyslog service using the below command.
```bash
sudo systemctl is-enabled rsyslog
sudo systemctl status rsyslog
```
You will see the rsyslog service is enabled, which means it will be automatically run on the system startup. And the current status of the rsyslog service is running.

To send logs from the Ubuntu client machine to the Graylog server using rsyslog, you will need to create a new additional rsyslog configuration. The default configuration of rsyslog is "/etc/rsyslog.conf" file, and additional rsyslog configuration can be stored at the "/etc/rsyslog.d" directory.

Create a new additional rsyslog configuration `/etc/rsyslog.d/60-graylog.conf` using nano editor.
```bash
sudo vim /etc/rsyslog.d/60-graylog.conf
```
Add the following configuration to the file.
```bash
*.*@192.168.5.10:5148;RSYSLOG_SyslogProtocol23Format
```
Save and close the file when you are done.

The IP address is 192.168.5.10 here is the IP address of the Graylog server, which is running the inputs on the UDP port 5148.

Now restart the rsyslog service to apply new changes and new configuration using the below command.
```bash
sudo systemctl restart rsyslog
```
And you have completed the basic rsyslog configuration for sending logs to the Graylog server.

