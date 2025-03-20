#!/bin/bash

# Usage: ./wallhaven-fetch.sh [timeframe]
# Timeframe options: 1d (1 day), 3d (3 days), 1w (1 week), 1M (1 month), 3M (3 months), 6M (6 months), 1y (1 year)
# Default is 1M (past month) if no timeframe is specified
# Example: ./wallhaven-fetch.sh 1w  # Get popular wallpapers from the past week

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

# Create a global COLORS array that will be used by both theming functions
COLORS=()

# Define minimum resolution dimensions for 2K
MIN_WIDTH=2560
MIN_HEIGHT=1440

# Define timeframe for popularity (1d, 3d, 1w, 1M, 3M, 6M, 1y)
# Default to 1 month if not specified
TIMEFRAME="${1:-1M}"

# Function to apply colors from wallpaper to Hyprland configuration
apply_wallpaper_colors_to_hyprland() {
    echo "Applying wallpaper colors to Hyprland configuration..." 
    # Find a vibrant color for active border (preferably from the middle of the array)
    ACTIVE_COLOR="${COLORS[14]}"
    
    # Find a neutral color for inactive border (preferably darker)
    INACTIVE_COLOR="${COLORS[0]}"
    
    # Convert hex colors to rgba format for Hyprland
    # Strip # and add alpha channel
    ACTIVE_RGBA="rgba(${ACTIVE_COLOR:1:2}${ACTIVE_COLOR:3:2}${ACTIVE_COLOR:5:2}ee)"
    INACTIVE_RGBA="rgba(${INACTIVE_COLOR:1:2}${INACTIVE_COLOR:3:2}${INACTIVE_COLOR:5:2}aa)"
    
    # Path to Hyprland config
    HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
    
    # Check if config exists
    if [ ! -f "$HYPR_CONFIG" ]; then
        echo "Error: Hyprland config not found at $HYPR_CONFIG"
        return 1
    fi
    
    # Backup existing config
    cp "$HYPR_CONFIG" "${HYPR_CONFIG}.backup"
    echo "Backed up existing Hyprland config to ${HYPR_CONFIG}.backup"
    
    # Update the border colors in the configuration
    # Using sed to replace the lines containing border colors
    sed -i "s/col\.active_border = rgba([^)]*)/col.active_border = $ACTIVE_RGBA/" "$HYPR_CONFIG"
    sed -i "s/col\.inactive_border = rgba([^)]*)/col.inactive_border = $INACTIVE_RGBA/" "$HYPR_CONFIG"
    
    echo "Hyprland border colors updated successfully!"
    echo "Active border: $ACTIVE_RGBA"
    echo "Inactive border: $INACTIVE_RGBA"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    # Notify user they need to reload Hyprland for changes to take effect
    echo "To apply these changes, you need to reload Hyprland (hyprctl reload) or restart it"
    
    return 0
}

# Function to extract colors from the wallpaper (shared by both terminal and Hyprland functions)
extract_colors_from_wallpaper() {
    echo "Extracting color palette from current wallpaper..."
    
    # Find the current wallpaper
    CURRENT_WALLPAPER=$(find "$SAVE_DIR" -name "current.*" | head -1)
    
    if [ ! -f "$CURRENT_WALLPAPER" ]; then
        echo "Error: No current wallpaper found"
        return 1
    fi
    
    # Check if imagemagick is installed (for convert command)
    if ! command -v convert &> /dev/null; then
        echo "Error: ImageMagick is not installed. Install it using: sudo pacman -S imagemagick"
        return 1
    fi
    
    # Create temp directory for palette extraction
    TEMP_DIR="/tmp/wallpaper-palette"
    mkdir -p "$TEMP_DIR"
    
    # Extract 16 dominant colors from the wallpaper
    echo "Extracting dominant colors..."
    convert "$CURRENT_WALLPAPER" -resize 400x400 -colors 16 -unique-colors txt:- | grep -v "^#" > "$TEMP_DIR/colors.txt"
    
    # Create an array of colors
    COLORS=()
    while read -r line; do
        # Extract hex color code from line and remove alpha channel if present
        COLOR=$(echo "$line" | grep -o '#[0-9a-fA-F]*')
        # Remove alpha channel (last 2 characters) if color is 9 characters (#RRGGBBAA)
        if [ ${#COLOR} -eq 9 ]; then
            COLOR="${COLOR:0:7}"
        fi
        COLORS+=("$COLOR")
    done < "$TEMP_DIR/colors.txt"
    
    # Fill with default colors if we don't have enough
    while [ ${#COLORS[@]} -lt 16 ]; do
        COLORS+=("#000000")
    done
    
    return 0
}

# Function to extract color palette from the current wallpaper and update kitty config
apply_wallpaper_colors_to_kitty() {
    echo "Applying colors to kitty terminal configuration..."
    
    # Extract colors if not already done
    if [ ${#COLORS[@]} -eq 0 ]; then
        extract_colors_from_wallpaper
        if [ $? -ne 0 ]; then
            echo "Failed to extract colors from wallpaper"
            return 1
        fi
    fi
    
    # Sort colors by brightness for better assignment
    # (This is a simplified approach - a more sophisticated sorting could be implemented)
    
    # Assign foreground/background colors
    # Use the lightest color for foreground and darkest for background
    BACKGROUND_COLOR="${COLORS[0]}"
    FOREGROUND_COLOR="${COLORS[15]}"
    CURSOR_COLOR="${COLORS[7]}"
    SELECTION_BG="${COLORS[8]}"
    SELECTION_FG="${COLORS[0]}"
    
    # Path to kitty config
    KITTY_CONFIG="$HOME/.config/kitty/kitty.conf"
    
    # Create kitty config directory if it doesn't exist
    mkdir -p "$(dirname "$KITTY_CONFIG")"
    
    # Backup existing kitty config if it exists
    if [ -f "$KITTY_CONFIG" ]; then
        cp "$KITTY_CONFIG" "${KITTY_CONFIG}.backup"
        echo "Backed up existing kitty config to ${KITTY_CONFIG}.backup"
    fi
    
    # Create or update kitty config with the new colors
    echo "Updating kitty configuration..."
    cat > "$KITTY_CONFIG" << EOL
# Auto-generated kitty color configuration from wallpaper
# Generated on $(date)

foreground $FOREGROUND_COLOR
background $BACKGROUND_COLOR
cursor $CURSOR_COLOR
color0 ${COLORS[0]}
color1 ${COLORS[1]}
color2 ${COLORS[2]}
color3 ${COLORS[3]}
color4 ${COLORS[4]}
color5 ${COLORS[5]}
color6 ${COLORS[6]}
color7 ${COLORS[7]}
color8 ${COLORS[8]}
color9 ${COLORS[9]}
color10 ${COLORS[10]}
color11 ${COLORS[11]}
color12 ${COLORS[12]}
color13 ${COLORS[13]}
color14 ${COLORS[14]}
color15 ${COLORS[15]}
selection_foreground $SELECTION_FG
selection_background $SELECTION_BG

# Include any custom kitty settings that were previously defined
# You may want to add your custom settings below this line

background_opacity 0.85
background_blur 1 
EOL
    
    # If there was a previous config, append non-color settings to the new config
    if [ -f "${KITTY_CONFIG}.backup" ]; then
        echo "" >> "$KITTY_CONFIG"
        echo "# Previous custom settings (non-color related)" >> "$KITTY_CONFIG"
        grep -v "^color\|^background\|^foreground\|^cursor\|^selection_" "${KITTY_CONFIG}.backup" | grep -v "^#" >> "$KITTY_CONFIG"
    fi
    
    echo "Kitty terminal colors updated successfully!"
    echo "Config saved to: $KITTY_CONFIG"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    # Reload kitty config if kitty is running
    if pgrep -x "kitty" > /dev/null; then
        echo "Reloading kitty configuration..."
        pkill -USR1 kitty
    fi
    
    return 0
}

# Function to fetch and download a random popular wallpaper with at least 2K resolution
fetch_wallpaper() {
    local save_path=$1
    local max_attempts=10
    local attempt=1
    local fetch_image_url=""
    local width=0
    local height=0
    
    # Make the API request to Wallhaven
    local fetch_response=$(curl -s "https://wallhaven.cc/api/v1/search?sorting=toplist")
    
    # Check if API request was successful (empty response means no internet)
    if [ -z "$fetch_response" ]; then
        echo "Error: Failed to connect to Wallhaven API. Check your internet connection."
        return 1
    fi
    
    # Count results
    local total_results=$(echo "$fetch_response" | jq '.data | length')
    
    # Check if we have any results
    if [[ "$total_results" -eq 0 ]]; then
        echo "Error: No wallpapers found matching the criteria"
        return 1
    fi
    
    # Try to find a wallpaper with at least 2K resolution
    while [[ $attempt -le $max_attempts && ($width -lt $MIN_WIDTH || $height -lt $MIN_HEIGHT) ]]; do
        echo "Attempt $attempt to find a 2K+ resolution wallpaper..."
        
        # Generate a random index
        local fetch_random_index=$((RANDOM % total_results))
        
        # Extract the dimensions
        width=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].dimension_x")
        height=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].dimension_y")
        
        # Check if dimensions are at least 2K
        if [[ $width -ge $MIN_WIDTH && $height -ge $MIN_HEIGHT ]]; then
            fetch_image_url=$(echo "$fetch_response" | jq -r ".data[$fetch_random_index].path")
            echo "Found wallpaper with resolution ${width}x${height}"
            break
        fi
        
        echo "Skipping wallpaper with resolution ${width}x${height} (too small)"
        ((attempt++))
    done
    
    # Check if we found a suitable wallpaper
    if [[ "$fetch_image_url" == "null" || -z "$fetch_image_url" || $width -lt $MIN_WIDTH || $height -lt $MIN_HEIGHT ]]; then
        echo "Error: Could not find a wallpaper with at least 2K resolution after $max_attempts attempts"
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
        
        # Apply color palette to kitty terminal
        apply_wallpaper_colors_to_kitty
        
        # Apply color palette to Hyprland
        apply_wallpaper_colors_to_hyprland 
    else
        echo "Warning: No current wallpaper found to apply"
    fi
    
    echo "Setup complete! You now have both current and next wallpapers ready."
    echo "Current: $CURRENT_WALLPAPER"
    echo "Next: $(find "$SAVE_DIR" -name "next.*" | head -1)"
    
else
    # Normal rotation as before
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
    
    # Try to fetch a new next wallpaper
    echo "Fetching new next wallpaper..."
    if fetch_wallpaper "$SAVE_DIR/next"; then
        echo "Next wallpaper set successfully!"
    else
        echo "Failed to set next wallpaper. Will continue using current wallpaper."
        # Note that we don't exit here - we still apply the current wallpaper
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
        
        # Apply color palette to kitty terminal
        apply_wallpaper_colors_to_kitty

        apply_wallpaper_colors_to_hyprland
    else
        echo "Warning: No current wallpaper found to apply"
    fi
    
    echo "Rotation complete!"
    echo "Current: $CURRENT_WALLPAPER"
    echo "Next: $(find "$SAVE_DIR" -name "next.*" | head -1)"
fi