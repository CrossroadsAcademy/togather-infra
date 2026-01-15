#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the file path relative to script location
FILE_PATH="$SCRIPT_DIR/../K8s/auto/0-cluster-scoped/infisical-secret.yaml"

echo -e "${GREEN}=== Infisical K8s Secret Manager ===${NC}\n"

# Check if file exists and show appropriate menu
if [ -f "$FILE_PATH" ]; then
    echo -e "${BLUE}Existing secret file found at:${NC}"
    echo -e "${YELLOW}$FILE_PATH${NC}\n"
    echo "What would you like to do?"
    echo "1) Create a new secret file (will ask to override)"
    echo "2) Apply the existing secret file to cluster"
    echo "3) Exit"
    echo ""
    read -p "Enter your choice (1-3): " choice
else
    echo -e "${YELLOW}No existing secret file found.${NC}\n"
    echo "What would you like to do?"
    echo "1) Create a new secret file"
    echo "2) Exit"
    echo ""
    read -p "Enter your choice (1-2): " choice
fi

echo ""

# Function to create secret file
create_secret() {
    # Check if file already exists (for override confirmation)
    if [ -f "$FILE_PATH" ]; then
        echo -e "${YELLOW}Warning: File already exists at $FILE_PATH${NC}"
        read -p "Do you want to override it? (y/N): " override
        if [[ ! "$override" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled.${NC}"
            exit 0
        fi
        echo ""
    fi

    # Prompt for Infisical credentials
    read -p "Enter INFISICAL_CLIENT_ID: " client_id
    read -sp "Enter INFISICAL_CLIENT_SECRET: " client_secret
    echo ""
    read -p "Enter INFISICAL_PROJECT_ID: " project_id

    # Validate inputs
    if [ -z "$client_id" ] || [ -z "$client_secret" ] || [ -z "$project_id" ]; then
        echo -e "\n${RED}Error: All fields are required!${NC}"
        exit 1
    fi

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$FILE_PATH")"

    # Create the YAML file
    cat > "$FILE_PATH" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: infisical-secret
type: Opaque
stringData:
  INFISICAL_CLIENT_ID: $client_id
  INFISICAL_CLIENT_SECRET: $client_secret
  INFISICAL_PROJECT_ID: $project_id
EOF

    # Check if file was created successfully
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Secret file created successfully at: $FILE_PATH${NC}"
        
        # Ask if user wants to apply the secret
        echo ""
        read -p "Do you want to apply this secret to your Kubernetes cluster now? (y/N): " apply_now
        
        if [[ "$apply_now" =~ ^[Yy]$ ]]; then
            apply_secret
        else
            echo -e "\n${YELLOW}📌 To apply later, run:${NC}"
            echo -e "   ${GREEN}kubectl apply -f $FILE_PATH${NC}\n"
        fi
    else
        echo -e "\n${RED}✗ Failed to create secret file${NC}"
        exit 1
    fi
}

# Function to apply secret file
apply_secret() {
    if [ ! -f "$FILE_PATH" ]; then
        echo -e "${RED}✗ Error: Secret file not found at $FILE_PATH${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Applying secret to cluster...${NC}"
    kubectl apply -f "$FILE_PATH"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Secret applied successfully!${NC}\n"
    else
        echo -e "${RED}✗ Failed to apply secret. Please check your kubectl configuration.${NC}\n"
        exit 1
    fi
}

# Handle user choice
if [ -f "$FILE_PATH" ]; then
    case $choice in
        1)
            create_secret
            ;;
        2)
            apply_secret
            ;;
        3)
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
else
    case $choice in
        1)
            create_secret
            ;;
        2)
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
fi