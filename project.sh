#!/bin/bash

declare -A path_dict

path_dict=(
    ["/interfaces/interface[name=eth0]/state/counters"]="show interfaces eth0 counters"
    ["/interfaces/interface[name=eth1]/state/counters"]="show interfaces eth1 counters"
    ["/system/memory/state"]="show memory"
    ["/system/cpu/state/usage"]="show cpu"
    ["/routing/protocols/protocol[ospf]/ospf/state"]="show ospf status"
    ["/interfaces/interface[name=eth0]/state"]="show interfaces eth0 status;show interfaces eth0 mac-address;show interfaces eth0 mtu;show interfaces eth0 speed"
    ["/bgp/neighbors/neighbor[neighbor_address=10.0.0.1]/state"]="show bgp neighbors 10.0.0.1;show bgp neighbors 10.0.0.1 received-routes;show bgp neighbors 10.0.0.1 advertised-routes"
    ["/system/cpu/state"]="show cpu usage;show cpu user;show cpu system;show cpu idle"
    ["/ospf/areas/area[id=0.0.0.0]/state"]="show ospf area 0.0.0.0;show ospf neighbors"
    ["/system/disk/state"]="show disk space;show disk health"
)

# Function to sanitize keys by removing any unwanted characters
sanitize_key() {
    local key="$1"
    echo "$key" | sed -e 's/[[:space:][:punct:]]//g'  # Remove spaces and punctuation
}




process_json() {
    local json_input="$1"
    
    # Clean up the JSON input (removes extra spaces between keys and colons)
    local cleaned_json=$(echo "$json_input" | sed -e 's/\([{,]\)\s*\([a-zA-Z_][a-zA-Z0-9_]\)\s:/\1"\2":/g')

    # Remove any percentage signs from the cleaned JSON input
    cleaned_json=$(echo "$cleaned_json" | sed 's/%//g')

    # Process first-level keys (those that are not inside 'adjacencies')
    local first_level_keys=$(echo "$cleaned_json" | jq -r 'to_entries | 
        map(select(.key != "adjacencies")) | 
        .[] | 
        select(.value | type != "array") | 
        "\(.key): \(.value)"')

    # Initialize counter for neighbor_id
    local neighbor_id_counter=1

    # Initialize adjacency output string
    local adjacency_entries=""

    # Check if the 'adjacencies' field exists and is an array
    if echo "$cleaned_json" | jq -e '.adjacencies? | type == "array"' >/dev/null; then
        # Iterate over the adjacencies array and modify neighbor_id and state with counters
        while IFS= read -r adjacency; do
            # Extract the original neighbor_id and state values
            neighbor_id=$(echo "$adjacency" | jq -r '.neighbor_id')
            state=$(echo "$adjacency" | jq -r '.state')

            # Remove percentage sign from neighbor_id and state if present
            neighbor_id=$(echo "$neighbor_id" | sed 's/%//g')
            state=$(echo "$state" | sed 's/%//g')

            # Create modified keys with counter and original value
            modified_neighbor_id="neighbor_id$neighbor_id"
            modified_state="state$neighbor_id"

            # Append the result in the desired format
            adjacency_entries+="$modified_neighbor_id: $neighbor_id, $modified_state: $state"$'\n'

            # Increment the counter for the next neighbor_id
            ((neighbor_id_counter++))
        done < <(echo "$cleaned_json" | jq -c '.adjacencies[]')
    fi

    # Remove the final newline from adjacency entries, if any
    adjacency_entries=$(echo -n "$adjacency_entries" | sed -z '$ s/\n$//')

    # Output first-level keys to file
    echo "$first_level_keys" > processed.txt

    # If adjacency entries exist, add them after processing
    if [ -n "$adjacency_entries" ]; then
        echo "$adjacency_entries" >> processed.txt
    fi
}

# Function to process the input file and remove percentage signs
# Function to process the input file and modify numeric values
process_file() {
    local input_file=$1
    local output_file=$2

    while IFS= read -r line; do
        # Remove any percentage sign from the line
        line=$(echo "$line" | sed 's/%//g')

        # Process each value in the line
        modified_line=""
        for word in $line; do
            # Check if the word is a number
            if [[ "$word" =~ ^[0-9]+\.[0-9]+$ ]]; then
                # If the number ends with .0 or .00 (or more zeros), convert it to integer
                if [[ "$word" =~ \.0+$ ]]; then
                    word=$(echo "$word" | cut -d '.' -f 1)  # Strip the decimals
                fi
            fi

            # Append the (modified or unmodified) word to the modified line
            if [[ -z "$modified_line" ]]; then
                modified_line="$word"
            else
                modified_line="$modified_line $word"
            fi
        done

        # Check if the line contains a neighbor_id
        if [[ $line == neighbor_id:* ]]; then
            # Extract the neighbor_id and state values
            neighbor_id=$(echo "$line" | grep -oP 'neighbor_id: \K[^\s,]+')
            state=$(echo "$line" | grep -oP 'state: \K.+')

            # Remove percentage signs from neighbor_id and state
            neighbor_id=$(echo "$neighbor_id" | sed 's/%//g')
            state=$(echo "$state" | sed 's/%//g')

            # Create new keys by appending the original neighbor_id to both neighbor_id and state keys
            new_neighbor_id_key="neighbor_id${neighbor_id}"
            new_state_key="state${neighbor_id}"

            # Format the output for this line
            echo "$new_neighbor_id_key: $neighbor_id, $new_state_key: $state" >> "$output_file"
        else
            # Print the modified line to the output file
            echo "$modified_line" >> "$output_file"
        fi
    done < "$input_file"
}



normalize_file() {
    local input_file="$1"
    local output_file="$2"

    # Check if the input file exists
    if [ ! -f "$input_file" ]; then
        echo "File $input_file does not exist!"
        exit 1
    fi

    # Process the input file:
    # 1. Remove underscores
    # 2. Convert to lowercase
    # 3. Replace commas with newlines
    # 4. Remove spaces before "state" keys
    # 5. Remove periods
    sed 's/_//g' < "$input_file" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/,/\n/g' | \
    sed 's/ state/state/g' | \
    sed 's/\.//g' > "$output_file"

    #echo "Normalization complete. Output saved to $output_file"
}



compare_normalized_outputs() {
    local gnmi_file="$1"
    local cli_file="$2"

    # Check if the files exist
    if [ ! -f "$gnmi_file" ]; then
        echo "gNMI file $gnmi_file does not exist!"
        exit 1
    fi

    if [ ! -f "$cli_file" ]; then
        echo "CLI file $cli_file does not exist!"
        exit 1
    fi

    # Convert the files into associative arrays for key-value comparison
    declare -A gnmi_dict
    declare -A cli_dict

    # Function to read key-value pairs into an associative array
    read_file_to_dict() {
        local file="$1"
        declare -n dict="$2"  # Use nameref for associative array
        while IFS=': ' read -r key value; do
            # Trim whitespace from key and value
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            dict["$key"]="$value"
        done < "$file"
    }

    # Read files into associative arrays
    read_file_to_dict "$gnmi_file" gnmi_dict
    read_file_to_dict "$cli_file" cli_dict

    # Flag to track differences
    local differences_found=false

    # Compare keys and values between gNMI and CLI
    echo "Comparing outputs..."

    # Check for missing or differing keys in gNMI
    for key in "${!gnmi_dict[@]}"; do
        if [ -z "${cli_dict[$key]}" ]; then
            echo "Key '$key' is present in gNMI but missing in CLI."
            differences_found=true
        elif [ "${gnmi_dict[$key]}" != "${cli_dict[$key]}" ]; then
            echo "Key '$key' has different values: gNMI='${gnmi_dict[$key]}', CLI='${cli_dict[$key]}'."
            differences_found=true
        fi
    done

    # Check for extra keys in CLI not in gNMI
    for key in "${!cli_dict[@]}"; do
        if [ -z "${gnmi_dict[$key]}" ]; then
            echo "Key '$key' is present in CLI but missing in gNMI."
            differences_found=true
        fi
    done

    # Final result
    if [ "$differences_found" = false ]; then
        echo "Both gNMI and CLI outputs match!"
    else
        echo "Differences were found between gNMI and CLI outputs."
    fi
}



process_input() {
    local input_file=$1
    local output_file="$input_file.processed"

    # Create or clear the output file
    > "$output_file"

    # Read the file line by line
    while IFS=': ' read -r key value unit; do
        # Handle case where there is no unit
        if [[ -z "$unit" ]]; then
            unit="no_unit"
        fi

        # Convert value if unit is KB, MB, or GB
        case "${unit^^}" in
            KB) converted_value=$((value * 1024)) ;;          # KB to bytes
            MB) converted_value=$((value * 1024 * 1024)) ;;   # MB to bytes
            GB) converted_value=$((value * 1024 * 1024 * 1024)) ;; # GB to bytes
            *) converted_value=$value ;;                      # No conversion if no unit or unrecognized unit
        esac

        # Append the result to the output file
        echo "$key: $converted_value" >> "$output_file"
    done < "$input_file"

    # Optionally, replace the original file with the processed one
    mv "$output_file" "$input_file"
}

# remove_percentage_sign() {
#     local input_file="$1"
#     local output_file="${2:-$input_file}"  # Default to overwriting the input file if no output file is specified

#     # Use sed to remove all '%' characters and write the result to the output file
#     sed 's/%//g' "$input_file" > "$output_file"
# }



check_if_path_exists_in_dict() {
    local path=$1
    if [ -z "${path_dict[$path]}" ]; then
        echo "Path does not exist"
        exit 1
    fi
    echo "${path_dict[$path]}"
}

cli_command() {
    local command=$1
    ./cli.sh "$command"
}

gmni_command() {
    local path=$1
    ./gmni.sh "$path"
}


main() {
    local input_path=$1

    if [ -z "$input_path" ]; then
        echo "Please provide a path"
        exit 1
    fi

    commands=$(check_if_path_exists_in_dict "$input_path")
    
    gmni_command "$input_path"
    
    echo "gnmi before edit"
    cat gmni_output.txt
    echo ""
    echo "" 

    gmni_output=$(cat gmni_output.txt)
    process_json "$gmni_output"
    IFS=';' read -ra command_list <<< "$commands"
    for command in "${command_list[@]}"; do
        cli_command "$command"
    done

    # echo "gnmi after edit"   
    # cat processed.txt
    # echo ""
    # echo ""
    # echo "cli after edit"   
    output_file="final_processed.txt"
    process_file "cli_output.txt" "$output_file"
    # cat $output_file
    # echo ""
    # echo ""

    # Normalize both files with specified output names
    normalize_file "processed.txt" "normalized_processed.txt"
    normalize_file "final_processed.txt" "normalized_cli_output.txt"
    #remove_percentage_sign "final_processed.txt" "final_processed.txt"
    #remove_percentage_sign "cli_output.txt" "cli_output.txt"

    echo "gnmi after normalized"   
    cat normalized_processed.txt
    echo ""
    echo "cli after normalized"   
    cat normalized_cli_output.txt
    echo ""
    process_input "normalized_processed.txt"
    process_input "normalized_cli_output.txt"
    echo "gnmi after normalized units"   
    cat normalized_processed.txt
    echo ""
    echo "cli after normalized units"   
    cat normalized_cli_output.txt
    echo ""

    compare_normalized_outputs "normalized_processed.txt" "normalized_cli_output.txt"

}

rm -f cli_output.txt gmni_output.txt processed.txt normalized_processed.txt normalized_cli_output.txt final_processed.txt
main "$1"
