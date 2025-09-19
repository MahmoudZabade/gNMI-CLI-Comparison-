#!/bin/bash

declare -A commands_dict

commands_dict=(
    ["show interfaces eth0 counters"]="in_octets: 1500000;out_octets: 1400000;in_errors: 10 MB;out_errors: 2"
    ["show memory"]="total_memory: 4096000;available_memory: 1000000"
    ["show interfaces eth1 counters"]="in_octets: 200000;out_octets: 100000"
    ["show cpu"]="cpu_usage: 65"
    ["show ospf status"]="ospf_area: 0.0.0.0;ospf_state: down"
    ["show interfaces eth0 status"]="admin_status: up;oper_status: up"
    ["show interfaces eth0 mac-address"]="mac_address: 00:1C:42:2B:60:5A"
    ["show interfaces eth0 mtu"]="mtu: 1500"
    ["show interfaces eth0 speed"]="speed: 1000"
    ["show bgp neighbors 10.0.0.1"]="peer_as: 65001;connection_state: Established"
    ["show bgp neighbors 10.0.0.1 received-routes"]="received_prefix_count: 120"
    ["show bgp neighbors 10.0.0.1 advertised-routes"]="sent_prefix_count: 95"
    ["show cpu usage"]="cpu_usage: 75"
    ["show cpu user"]="user_usage: 45"
    ["show cpu system"]="system_usage: 20"
    ["show cpu idle"]="idle_percentage: 25"
    ["show ospf area 0.0.0.0"]="area_id: 0.0.0.0;active_interfaces: 4;lsdb_entries: 200"
    ["show ospf neighbors"]="neighbor_id: 1.1.1.1, state: full;neighbor_id: 2.2.2.2, state: full;neighbor_id: 3.3.3.3, state: full"
    ["show disk space"]="total_space: 1024000;used_space: 500000;available_space: 524000"
    ["show disk health"]="disk_health: good"
)



check_if_command_exists_in_dict() {
    local command=$1
    if [ -z "${commands_dict[$command]}" ]; then
        echo "Command does not exist"
        exit 1
    fi
    echo "${commands_dict[$command]}"
}

main() {
    local input_command=$1

    if [ -z "$input_command" ]; then
        echo "Please provide a command"
        exit 1
    fi

    output=$(check_if_command_exists_in_dict "$input_command")
    IFS=';' read -ra output_list <<< "$output"
    for output in "${output_list[@]}"; do
        echo "$output" >> cli_output.txt
    done
}

main "$1"

