#!/usr/bin/env python3
"""Decode nmcli escaping before serializing the SSID as JSON."""
import json
import subprocess


def fields(line):
    result, value, escaped = [], [], False
    for char in line:
        if escaped:
            value.append(char)
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(''.join(value))
            value = []
        else:
            value.append(char)
    result.append(''.join(value))
    return result


def main():
    status = {'icon': '󰖪', 'ssid': 'Disconnected', 'strength': 0}
    try:
        output = subprocess.run(
            ['nmcli', '-t', '-f', 'ACTIVE,SSID,SIGNAL', 'device', 'wifi', 'list', '--rescan', 'no'],
            capture_output=True, text=True, timeout=3, check=True,
        ).stdout
        for line in output.splitlines():
            row = fields(line)
            if len(row) == 3 and row[0] == 'yes':
                status = {'icon': '󰖩', 'ssid': row[1], 'strength': int(row[2])}
                break
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    print(json.dumps(status, ensure_ascii=False))


if __name__ == '__main__':
    main()
