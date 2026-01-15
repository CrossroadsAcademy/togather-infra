#!/bin/bash

# JWT Secret Encoder
# Encodes a secret string to base64url format (without padding)
# for use in Kubernetes ConfigMaps with JWT authentication

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "JWT Secret Encoder"
echo "=================================================="
echo "This tool encodes your JWT secret to base64url format"
echo "for use in Kubernetes ConfigMaps."
echo ""

# Check if secret is provided as command line argument
if [ $# -gt 0 ]; then
    SECRET="$*"
else
    # Prompt user for input
    read -p "Enter your JWT secret: " SECRET
fi

# Validate input
if [ -z "$SECRET" ]; then
    echo -e "${YELLOW}Error: Secret cannot be empty!${NC}"
    exit 1
fi

# Encode the secret to base64url format
ENCODED=$(echo -n "$SECRET" | base64 | tr '+/' '-_' | tr -d '=')

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/configmap.yaml"

# Generate the ConfigMap YAML
cat > "$OUTPUT_FILE" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: jwt-symmetric-key
data:
  jwks: |
    {
      "keys": [
        {
          "kty": "oct",   
          "alg": "HS256",     
          "k": "$ENCODED", 
          "use": "sig"
        }
      ]
    }   
EOF

# Display results
echo ""
echo "=================================================="
echo -e "${BLUE}Original secret:${NC} $SECRET"
echo -e "${GREEN}Encoded secret:${NC} $ENCODED"
echo "=================================================="
echo ""
echo -e "${GREEN}✓ ConfigMap generated successfully!${NC}"
echo -e "File: ${BLUE}$OUTPUT_FILE${NC}"
echo ""
echo "To apply the ConfigMap to your cluster, run:"
echo -e "${YELLOW}kubectl apply -f $OUTPUT_FILE${NC}"
echo ""
echo "Note: This file is gitignored to protect your secrets."
echo "TO run you can use Skaffold here"
