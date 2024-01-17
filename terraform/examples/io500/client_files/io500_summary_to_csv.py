#!/usr/bin/env python3
# Copyright 2023 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import re
import csv
import sys
import os

# Function to parse the main results into CSV format
def parse_results_to_csv(script_output):
    header = ['Test', 'Value', 'Unit', 'Time (seconds)']
    parsed_data = []
    parsed_data.append(header)

    # Use regular expression to find all relevant lines for results
    pattern = re.compile(r"\[RESULT\].*?(\w+(?:-\w+)+)\s+([\d.]+)\s+(GiB/s|kIOPS)\s+:\s+time\s+([\d.]+)")

    # Find all matches and add them to the parsed_data list
    for match in pattern.finditer(script_output):
        test, value, unit, time = match.groups()
        parsed_data.append([test, value, unit, time])

    return parsed_data

# Function to parse the score line into CSV format
def parse_score_to_csv(last_line):
    # Use regular expression to extract score components
    score_pattern = re.compile(r"Bandwidth\s+([\d.]+)\s+(GiB/s)\s+:\s+IOPS\s+([\d.]+)\s+(kiops)")
    score_match = score_pattern.search(last_line)
    if score_match:
        bandwidth, bandwidth_unit, iops, iops_unit = score_match.groups()
        return [
            ['Score', 'Value', 'Unit'],
            ['Bandwidth', bandwidth, bandwidth_unit],
            ['IOPS', iops, iops_unit]
        ]
    return []

# Function to parse the total value into CSV format
def parse_total_to_csv(last_line):
    # Use regular expression to extract total value
    total_pattern = re.compile(r"TOTAL\s+([\d.]+)")
    total_match = total_pattern.search(last_line)
    if total_match:
        total_value = total_match.group(1)
        return [['Total'], [total_value]]
    return []

# Main function to handle file operations
def main(file_path):
    print(f"file_path = {file_path}")
    results_dir = os.path.dirname(file_path)
    summary_file = os.path.basename(file_path)
    with open(file_path, 'r') as file:
        lines = file.readlines()

    # The last line contains the score and total
    last_line = lines[-1]

    # Parse the results, score, and total
    results_data = parse_results_to_csv(''.join(lines))
    score_data = parse_score_to_csv(last_line)
    total_data = parse_total_to_csv(last_line)

    # Derive the CSV filenames
    base_filename = summary_file.replace('.txt', '')
    results_csv_filename = f"{results_dir}/daos_io500_{base_filename}.csv"
    score_csv_filename = f"{results_dir}/daos_io500_score.csv"
    total_csv_filename = f"{results_dir}/daos_io500_total.csv"

    # Write the results summary CSV file
    with open(results_csv_filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerows(results_data)

    # Write the score CSV file
    with open(score_csv_filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerows(score_data)

    # Write the total CSV file
    with open(total_csv_filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerows(total_data)

    print(f"Created CSV files:")
    print(results_csv_filename)
    print(score_csv_filename)
    print(total_csv_filename)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 script.py <file_path>")
        sys.exit(1)
    input_file_path = sys.argv[1]
    print(f"input_file_path = {input_file_path}")
    main(input_file_path)
