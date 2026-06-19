import os
import requests
import xml.etree.ElementTree as ET
from flask import Flask, Response
from concurrent.futures import ThreadPoolExecutor
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

app = Flask(__name__)

switch_username = os.environ.get('SWITCH_USERNAME')
switch_password = os.environ.get('SWITCH_PASSWORD')

ip_sources = {}
with open('element.ssh', 'r') as file:
    for line in file:
        ip, source = line.strip().split()
        ip_sources[ip] = source


def fetch_switch_metrics(ip, source):
    url = f"https://{ip}/restconf/data/openconfig-platform:ports-state"
    try:
        resp = requests.get(url, auth=(switch_username, switch_password), verify=False, timeout=15)
        resp.raise_for_status()
        return parse_interface_metrics(resp.text, source)
    except requests.RequestException as e:
        return [f"# Error connecting to {ip}: {e}\n"]


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

        temperature = port.find('temperature')
        temp_state = port.find('temp-state')
        voltage = port.find('voltage')
        voltage_state = port.find('voltage-state')

        if temperature is not None:
            metrics.append(f'switch_sfp_temperature{{interface="{port_name}",source="{source}"}} {temperature.text}\n')
        if temp_state is not None:
            val = 1 if temp_state.text == 'normal-status' else 0
            metrics.append(f'switch_sfp_temp_state{{interface="{port_name}",source="{source}",state="{temp_state.text}"}} {val}\n')
        if voltage is not None:
            metrics.append(f'switch_sfp_voltage{{interface="{port_name}",source="{source}"}} {voltage.text}\n')
        if voltage_state is not None:
            val = 1 if voltage_state.text == 'normal-status' else 0
            metrics.append(f'switch_sfp_voltage_state{{interface="{port_name}",source="{source}",state="{voltage_state.text}"}} {val}\n')

        channels = port.findall('.//channel')
        for channel in channels:
            sub_port = channel.find('sub-port').text
            rx_power = channel.find('rx-power')
            tx_power = channel.find('tx-power')
            tx_bias_current = channel.find('tx-bias-current')

            if rx_power is not None:
                metrics.append(f'switch_interface_channel_rx_power{{interface="{port_name}",subport="{sub_port}",source="{source}"}} {rx_power.text}\n')
            if tx_power is not None:
                metrics.append(f'switch_interface_channel_tx_power{{interface="{port_name}",subport="{sub_port}",source="{source}"}} {tx_power.text}\n')
            if tx_bias_current is not None:
                metrics.append(f'switch_interface_channel_tx_bias_current{{interface="{port_name}",subport="{sub_port}",source="{source}"}} {tx_bias_current.text}\n')
    return metrics


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
