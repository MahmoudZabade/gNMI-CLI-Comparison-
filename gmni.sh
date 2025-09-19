#!/bin/bash

declare -A gmni_dict

gmni_dict=(
    ["/interfaces/interface[name=eth0]/state/counters"]="{
 \"in_octets\": 1500000,
 \"out_octets\": 1400000,
 \"in_errors\": \"10 MB\",
 \"out_errors\": 2
}"
    ["/interfaces/interface[name=eth1]/state/counters"]="{
 \"in_octets\": 200000,
 \"out_octets\": 100000,
 \"in_errors\": 5
}"
    ["/system/memory/state"]="{
 \"total_memory\": 4096000,
 \"available_memory\": 1024000
}"
    ["/system/cpu/state/usage"]="{
 \"cpu_usage\": 65,
 \"idle_percentage\": 35
}"
    ["/routing/protocols/protocol[ospf]/ospf/state"]="{
 \"ospf_area\": \"0.0.0.0\",
 \"ospf_state\": \"up\"
}"
    ["/interfaces/interface[name=eth0]/state"]="{
 \"admin_status\": \"up\",
 \"oper_status\": \"up\",
 \"mac_address\": \"00:1C:42:2B:60:5a\",
 \"mtu\": 1500,
 \"speed\": 1000
}"
    ["/bgp/neighbors/neighbor[neighbor_address=10.0.0.1]/state"]="{
 \"peer_as\": 65001,
 \"connection_state\": \"Established\",
 \"received_prefix_count\": 120,
 \"sent_prefix_count\": 95
}"
    ["/system/cpu/state"]="{
 \"cpu_usage\": 75,
 \"user_usage\": 45,
 \"system_usage\": 20,
 \"idle_percentage\": 25.12
}"
    ["/ospf/areas/area[id=0.0.0.0]/state"]="{
 \"area_id\": \"0.0.0.0\",
 \"active_interfaces\": 4,
 \"lsdb_entries\": 200,
 \"adjacencies\": [
  {\"neighbor_id\": \"1.1.1.1\",\"state\": \"full\"},
  {\"neighbor_id\": \"2.2.2.2\",\"state\": \"full\"},
  {\"neighbor_id\": \"3.3.3.3\",\"state\": \"full\"}
 ]
}"
    ["/system/disk/state"]="{
 \"total_space\": 1024000,
 \"used_space\": 500000,
 \"available_space\": 524000,
 \"disk_health\": \"good\"
}"
)

check_if_path_exists_in_dict() {
    local path=$1
    if [ -z "${gmni_dict[$path]}" ]; then
        echo "Path does not exist"
        exit 1
    fi
    echo "${gmni_dict[$path]}"
}

main() {
    local input_path=$1

    if [ -z "$input_path" ]; then
        echo "Please provide a path"
        exit 1
    fi

    output=$(check_if_path_exists_in_dict "$input_path")
    echo "$output" >> gmni_output.txt
}

main "$1"

