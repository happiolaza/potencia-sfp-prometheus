import os
import paramiko
import xml.etree.ElementTree as ET
from flask import Flask, Response
#from prometheus_flask_exporter import PrometheusMetrics
from concurrent.futures import ThreadPoolExecutor

app = Flask(__name__)
#metrics = PrometheusMetrics(app)

switch_username = os.environ.get('SWITCH_USERNAME')
switch_password = os.environ.get('SWITCH_PASSWORD')

# Leer IPs y valores de source desde el archivo element.ssh
ip_sources = {}
with open('element.ssh', 'r') as file:
    for line in file:
        ip, source = line.strip().split()
        ip_sources[ip] = source

def fetch_switch_metrics(ip, source):
    ssh_client = paramiko.SSHClient()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh_client.connect(hostname=ip, username=switch_username, password=switch_password)
        stdin, stdout, stderr = ssh_client.exec_command('show interface phy-eth | display-xml | no-more')
        xml_data = stdout.read().decode()
        return parse_interface_metrics(xml_data, source)
    except (paramiko.AuthenticationException, paramiko.SSHException) as e:
        return f"Error connecting to {ip}: {e}\n"
    finally:
        ssh_client.close()

@app.route('/metrics')
def get_metrics():
    switch_metrics = []
    with ThreadPoolExecutor() as executor:
        futures = [executor.submit(fetch_switch_metrics, ip, source) for ip, source in ip_sources.items()]
        for future in futures:
            switch_metrics.extend(future.result())
    return Response("".join(switch_metrics), mimetype='text/plain')

def parse_interface_metrics(xml_data, source):
    metrics = []
    root = ET.fromstring(xml_data)
    ports = root.findall('.//port')
    for port in ports:
        port_name = port.find('name').text.replace('/', '_')
        channels = port.findall('.//channel')
        for channel in channels:
            sub_port = channel.find('sub-port').text
            rx_power = channel.find('rx-power').text
            tx_power = channel.find('tx-power').text
            tx_bias_current = channel.find('tx-bias-current').text
            metrics.append(f'switch_interface_channel_rx_power{{interface="{port_name}", subport="{sub_port}", source="{source}"}} {rx_power}\n')
            metrics.append(f'switch_interface_channel_tx_power{{interface="{port_name}", subport="{sub_port}", source="{source}"}} {tx_power}\n')
            metrics.append(f'switch_interface_channel_tx_bias_current{{interface="{port_name}", subport="{sub_port}", source="{source}"}} {tx_bias_current}\n')
    return metrics

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
