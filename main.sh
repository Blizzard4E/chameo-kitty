#!/bin/bash

# Usage: ./wallhaven-fetch.sh [timeframe] [aspect_ratio]
# Timeframe options: 1d (1 day), 3d (3 days), 1w (1 week), 1M (1 month), 3M (3 months), 6M (6 months), 1y (1 year)
# Aspect ratio options: 16x9 (widescreen), 21x9 (ultrawide), 16x10, 4x3, 1x1 (square), etc.
# Default is 1M (past month) and 16x9 aspect ratio if not specified
# Example: ./wallhaven-fetch.sh 1w 21x9  # Get popular 21:9 ultrawide wallpapers from the past week

# Check if swww is installed
if ! command -v swww &> /dev/null; then
    echo "Error: swww is not installed. Install it using your package manager."
    echo "For Arch Linux: paru -S swww or yay -S swww"
    exit 1
fi

# Ensure swww daemon is running
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo "Starting swww daemon..."
    swww init
    # Set a small delay after initialization to avoid transition issues
    sleep 1
    # Check if a wallpaper is currently set
    WALLPAPER_SET=false
else
    # Assume a wallpaper is already set if the daemon is running
    WALLPAPER_SET=true
fi

# Define minimum resolution dimensions for 2K
MIN_WIDTH=2560
MIN_HEIGHT=1440

# Define timeframe for popularity (1d, 3d, 1w, 1M, 3M, 6M, 1y)
# Default to 1 month if not specified
TIMEFRAME="${1:-1M}"

# Define aspect ratio filter (16x9, 21x9, 16x10, 4x3, etc.)
# Default to 16x9 (widescreen) if not specified
ASPECT_RATIO="${2:-16x9}"

# Make the API request to Wallhaven, searching for popular images with specified aspect ratio
# Using 'toplist' sorting parameter with timeframe to get popular wallpapers
response=$(curl -s "https://wallhaven.cc/api/v1/search?ratios=${ASPECT_RATIO}&sorting=toplist&order=desc&topRange=${TIMEFRAME}")

# Extract the direct image URL from the JSON response
# We're using jq to parse the JSON and get the first image URL
# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Install it using: sudo pacman -S jq"
    exit 1
fi

# Function to fetch and download a random popular wallpaper with at least 2K resolution
fetch_wallpaper() {
    local save_path=$1
    local max_attempts=10
    local attempt=1
    local fetch_image_url=""
    local width=0
    local height=0
    
    # Make the API request to Wallhaven
    local fetch_response=$(curl -s "https://wallhaven.cc/api/v1/search?ratios=${ASPECT_RATIO}&sorting=toplist&order=desc&topRange=${TIMEFRAME}")
    
    # Count results
    local total_results=$(echo "$fetch_response" | jq '.data | length')
    
    # Check if we have any results
    if [[ "$total_results" -eq 0 ]]; then
        echo "Error: No wallpapers found matching the criteria"
        return 1
    fi
    
    # Try to find a wallpaper with at least 2K resolution
    while [[ $attempt -le $max_attempts && ($width -lt $MIN_WIDTH || $height -lt $MIN_HEIGHT) ]]; do
        echo "Attempt $attempt to find a 2K+ resolution wallpaper with ${ASPECT_RATIO} aspect ratio..."
        
        # Generate a random index
        local fetch_random_index=$((RANDOM % total_results))
        
        # Extract the dimensions
        width=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].dimension_x")
        height=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].dimension_y")
        
        # Extract the aspect ratio for logging
        aspect=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].ratio")
        
        # Check if dimensions are at least 2K
        if [[ $width -ge $MIN_WIDTH && $height -ge $MIN_HEIGHT ]]; then
            fetch_image_url=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].path")
            echo "Found wallpaper with resolution ${width}x${height} (ratio: ${aspect})"
            break
        fi
        
        echo "Skipping wallpaper with resolution ${width}x${height} (too small)"
        ((attempt++))
    done
    
    # Check if we found a suitable wallpaper
    if [[ "$fetch_image_url" == "null" || -z "$fetch_image_url" || $width -lt $MIN_WIDTH || $height -lt $MIN_HEIGHT ]]; then
        echo "Error: Could not find a wallpaper with at least 2K resolution and ${ASPECT_RATIO} aspect ratio after $max_attempts attempts"
        return 1
    fi
    
    # Get the file extension
    local fetch_extension=$(echo "$fetch_image_url" | awk -F. '{print $NF}')
    
    # Determine the full save path with extension
    local full_save_path="${save_path}.${fetch_extension}"
    
    # Download the wallpaper
    echo "Downloading ${width}x${height} wallpaper to ${full_save_path}..."
    curl -s "$fetch_image_url" -o "$full_save_path"
    
    # Check if download was successful
    if [ $? -eq 0 ]; then
        echo "Download complete: $full_save_path"
        return 0
    else
        echo "Error: Failed to download the image"
        return 1
    fi
}

# Create the save directory if it doesn't exist
SAVE_DIR="$HOME/Pictures/chameo"
mkdir -p "$SAVE_DIR"

# Check if we're running for the first time (no current wallpaper)
FIRST_RUN=true
for ext in jpg png jpeg webp; do
    if [ -f "$SAVE_DIR/current.$ext" ]; then
        FIRST_RUN=false
        break
    fi
done

if $FIRST_RUN; then
    echo "First run detected! Setting up both current and next wallpapers..."
    echo "Using aspect ratio: ${ASPECT_RATIO}"
    
    # Fetch current wallpaper
    echo "Fetching current wallpaper..."
    if fetch_wallpaper "$SAVE_DIR/current"; then
        echo "Current wallpaper set successfully!"
    else
        echo "Failed to set current wallpaper. Please run the script again."
        exit 1
    fi
    
    # Fetch next wallpaper
    echo "Fetching next wallpaper..."
    if fetch_wallpaper "$SAVE_DIR/next"; then
        echo "Next wallpaper set successfully!"
    else
        echo "Failed to set next wallpaper. Please run the script again."
        exit 1
    fi
    
    # Apply the current wallpaper using swww
    CURRENT_WALLPAPER=$(find "$SAVE_DIR" -name "current.*" | head -1)
    if [ -f "$CURRENT_WALLPAPER" ]; then
        echo "Setting current wallpaper using swww..."
        if [ "$WALLPAPER_SET" = false ]; then
            # First set the wallpaper without transition if none is set
            swww img "$CURRENT_WALLPAPER"
            echo "Initial wallpaper set successfully!"
            # Small delay to ensure wallpaper is fully loaded
            sleep 1
            # Now apply the same wallpaper again but with transition for visual confirmation
            swww img "$CURRENT_WALLPAPER" --transition-type random --transition-pos center
        else
            # Use transition for subsequent runs
            swww img "$CURRENT_WALLPAPER" --transition-type random --transition-pos center
        fi
        echo "Wallpaper set successfully!"
    else
        echo "Warning: No current wallpaper found to apply"
    fi
    
    echo "Setup complete! You now have both current and next wallpapers ready."
    echo "Current: $CURRENT_WALLPAPER"
    echo "Next: $(find "$SAVE_DIR" -name "next.*" | head -1)"
    
else
    # Normal rotation as before
    echo "Using aspect ratio: ${ASPECT_RATIO}"
    
    # Find extensions of existing files
    CURRENT_EXT=$(find "$SAVE_DIR" -name "current.*" | awk -F. '{print $NF}')
    NEXT_EXT=$(find "$SAVE_DIR" -name "next.*" | awk -F. '{print $NF}')
    
    # If we have a prev file, remove it
    find "$SAVE_DIR" -name "prev.*" -delete
    
    # If we have a current file, rename it to prev
    if [ ! -z "$CURRENT_EXT" ]; then
        mv "$SAVE_DIR/current.$CURRENT_EXT" "$SAVE_DIR/prev.$CURRENT_EXT"
        echo "Moved current wallpaper to prev"
    fi
    
    # If we have a next file, rename it to current
    if [ ! -z "$NEXT_EXT" ]; then
        mv "$SAVE_DIR/next.$NEXT_EXT" "$SAVE_DIR/current.$NEXT_EXT"
        echo "Moved next wallpaper to current"
    else
        echo "Warning: No next wallpaper found to move to current"
    fi
    
    # Fetch a new next wallpaper
    echo "Fetching new next wallpaper..."
    if fetch_wallpaper "$SAVE_DIR/next"; then
        echo "Next wallpaper set successfully!"
    else
        echo "Failed to set next wallpaper. Please run the script again."
        exit 1
    fi
    
    # Apply the wallpaper using swww
    CURRENT_WALLPAPER=$(find "$SAVE_DIR" -name "current.*" | head -1)
    if [ -f "$CURRENT_WALLPAPER" ]; then
        echo "Setting current wallpaper using swww..."
        if [ "$WALLPAPER_SET" = false ]; then
            # First set the wallpaper without transition if none is set
            swww img "$CURRENT_WALLPAPER"
            echo "Initial wallpaper set successfully!"
            # Small delay to ensure wallpaper is fully loaded
            sleep 1
            # Now apply the same wallpaper again but with transition for visual confirmation
            swww img "$CURRENT_WALLPAPER" --transition-type random --transition-pos center
        else
            # Use transition for subsequent runs
            swww img "$CURRENT_WALLPAPER" --transition-type random --transition-pos center
        fi
        echo "Wallpaper set successfully!"
    else
        echo "Warning: No current wallpaper found to apply"
    fi
    
    echo "Rotation complete!"
    echo "Current: $CURRENT_WALLPAPER"
    echo "Next: $(find "$SAVE_DIR" -name "next.*" | head -1)"
fi