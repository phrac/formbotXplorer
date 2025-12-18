#!/bin/bash

# Check for correct usage
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <AXIS> <TYPE>"
    echo "Example: $0 X idexcp"
    exit 1
fi

AXIS_ARG=$1
TYPE_ARG=$2

# Convert to lowercase for internal processing
AXIS_LOWER=$(echo "$AXIS_ARG" | tr '[:upper:]' '[:lower:]')
TYPE_LOWER=$(echo "$TYPE_ARG" | tr '[:upper:]' '[:lower:]')
AXIS_UPPER=$(echo "$AXIS_ARG" | tr '[:lower:]' '[:upper:]')


# Get the current time and date
time_str=$(date +"%H%M")
date_str=$(date +"%d%m%Y")

# Construct the output filename
output_filename="$HOME/printer_data/config/03_Resonance_Measurements/shaper_calibrate_${AXIS_LOWER}_${TYPE_LOWER}_${time_str}_${date_str}.png"

# Find the most recently created file matching the patterns
latest_file=$(find /tmp -maxdepth 1 -type f \( -name "resonances_${AXIS_LOWER}_*.csv" -o -name "calibration_data_${AXIS_LOWER}_*.csv" \) -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

# Check if a valid file was found
if [ -z "$latest_file" ]; then
  echo "Error: No matching file found for resonances_${AXIS_LOWER}_*.csv or calibration_data_${AXIS_LOWER}_*.csv"
  exit 1
fi

# Debugging: print the selected file
echo "Using file: $latest_file"

# Run the Python script and capture its output
# Using the specific virtualenv python as preferred
shaper_output=$($HOME/klippy-env/bin/python3 $HOME/klipper/scripts/calibrate_shaper.py "$latest_file" -o "$output_filename")

# Print the output filename
echo "Output file: $output_filename"

# Extract the recommended shaper type and frequency
recommended_shaper=$(echo "$shaper_output" | grep "Recommended shaper" | awk '{print $4}')
recommended_freq=$(echo "$shaper_output" | grep "Recommended shaper" | awk '{print $6}')

# Check if extraction was successful
if [ -z "$recommended_shaper" ] || [ -z "$recommended_freq" ]; then
  echo "Error: Could not extract recommended shaper or frequency"
  # Potentially print shaper_output to help debug
  echo "Shaper Output was:"
  echo "$shaper_output"
  exit 1
fi

# Define the configuration file path
config_file="$HOME/printer_data/config/variables.cfg"

# Backup the configuration file as a hidden file
cp "$config_file" "$HOME/printer_data/config/.variables.cfg.bak"

# Define the config keys based on the pattern "shaper_type_xidexcp" -> axis + type
# The pattern in old files was: "shaper_type_" + to_lower(axis) + to_lower(type)
# e.g. X idexcp -> shaper_type_xidexcp
# e.g. Y t0 -> shaper_type_yt0

config_key_base="${AXIS_LOWER}${TYPE_LOWER}"
type_key="shaper_type_${config_key_base}"
freq_key="shaper_freq_${config_key_base}"

echo "Updating $config_file with $type_key and $freq_key"

# Update or add the shaper settings
if grep -q "^${type_key}" "$config_file"; then
  # Update existing entries
  sed -i "s/^${type_key}.*/${type_key} = '$recommended_shaper'/" "$config_file"
else
  # Add new entry with a newline
  echo -e "\n${type_key} = '$recommended_shaper'" >> "$config_file"
fi

if grep -q "^${freq_key}" "$config_file"; then
  # Update existing entries
  sed -i "s/^${freq_key}.*/${freq_key} = $recommended_freq/" "$config_file"
else
  # Add new entry with a newline
  echo "${freq_key} = $recommended_freq" >> "$config_file"
fi

# Ensure proper formatting by adding a newline after the last variable if needed
sed -i -e '$a\' "$config_file"

echo "Recommended shaper settings updated in $config_file"
echo "Backup saved as $HOME/printer_data/config/.variables.cfg.bak"
