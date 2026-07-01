import os
import json
import requests
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
    url = f"https://{ip}/restconf/data/dell-port:ports/ports-state"
    try:
        resp = requests.get(url, auth=(switch_username, switch_password), verify=False, timeout=15)
        resp.raise_for_status()
        return parse_interface_metrics(resp.json(), source)
    except requests.RequestException as e:
        return [f"# Error connecting to {ip}: {e}\n"]


@app.route('/health')
def health():
    return "OK\n"

@app.route('/metrics')
def get_metrics():
    switch_metrics = []
    with ThreadPoolExecutor() as executor:
        futures = [executor.submit(fetch_switch_metrics, ip, source) for ip, source in ip_sources.items()]
        for future in futures:
            switch_metrics.extend(future.result())
    return Response("".join(switch_metrics), mimetype='text/plain')


def parse_interface_metrics(data, source):
    metrics = []
    ports = data.get('dell-port:ports-state', {}).get('port', [])
    for port in ports:
        port_name = port.get('name', '').replace('/', '_')

        temperature = port.get('temperature')
        temp_state = port.get('temp-state')
        voltage = port.get('voltage')
        voltage_state = port.get('voltage-state')

        if temperature is not None:
            metrics.append(f'switch_sfp_temperature{{interface="{port_name}",device="{source}"}} {temperature}\n')
        if temp_state is not None:
            val = 1 if temp_state == 'normal-status' else 0
            metrics.append(f'switch_sfp_temp_state{{interface="{port_name}",device="{source}",state="{temp_state}"}} {val}\n')
        if voltage is not None:
            metrics.append(f'switch_sfp_voltage{{interface="{port_name}",device="{source}"}} {voltage}\n')
        if voltage_state is not None:
            val = 1 if voltage_state == 'normal-status' else 0
            metrics.append(f'switch_sfp_voltage_state{{interface="{port_name}",device="{source}",state="{voltage_state}"}} {val}\n')

        channels = port.get('channel', [])
        for channel in channels:
            sub_port = channel.get('sub-port', '')
            rx_power = channel.get('rx-power')
            tx_power = channel.get('tx-power')
            tx_bias_current = channel.get('tx-bias-current')

            if rx_power is not None and rx_power != 'nan':
                metrics.append(f'switch_interface_channel_rx_power{{interface="{port_name}",subport="{sub_port}",device="{source}"}} {rx_power}\n')
            if tx_power is not None and tx_power != 'nan':
                metrics.append(f'switch_interface_channel_tx_power{{interface="{port_name}",subport="{sub_port}",device="{source}"}} {tx_power}\n')
            if tx_bias_current is not None:
                metrics.append(f'switch_interface_channel_tx_bias_current{{interface="{port_name}",subport="{sub_port}",device="{source}"}} {tx_bias_current}\n')
    return metrics


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
