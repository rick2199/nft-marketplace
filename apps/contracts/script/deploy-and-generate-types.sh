# Check if an RPC URL is passed as an argument
RPC_URL=$1
if [ -z "$RPC_URL" ]; then
    echo "No RPC URL provided. Exiting..."
    exit 1
fi

PRIVATE_KEY=$2
if [ -z "$PRIVATE_KEY" ]; then
    echo "No private key provided. Exiting..."
    exit 1
fi

# Define the paths to your web contract data files and env file
NFT_CONTRACT_PATH="../web/contracts/NFT.json"
MARKETPLACE_CONTRACT_PATH="../web/contracts/Marketplace.json"
TYPES_PATH="../web/types/contracts"
ENV_FILE="../web/.env.local"

# Ensure the directories exist
mkdir -p $(dirname "$NFT_CONTRACT_PATH")
mkdir -p $(dirname "$MARKETPLACE_CONTRACT_PATH")
mkdir -p "$TYPES_PATH"

# Check if .env.local exists, create it if not
if [ ! -f "$ENV_FILE" ]; then
    echo ".env.local file not found, creating it..."
    touch "$ENV_FILE"
fi

###########################################
# Deploy NFT Contract and extract details #
###########################################

echo "Deploying NFT contract to $RPC_URL..."
NFT_DEPLOY_OUTPUT=$(forge script script/DeployNFT.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY)

NFT_CONTRACT_ADDRESS=$(echo "$NFT_DEPLOY_OUTPUT" | grep "contract NFT" | sed -E 's/.*contract NFT (0x[a-fA-F0-9]{40}).*/\1/')

if [ -z "$NFT_CONTRACT_ADDRESS" ]; then
    echo "Failed to deploy NFT contract. Could not find contract address."
    exit 1
fi

echo "NFT Contract deployed at: $NFT_CONTRACT_ADDRESS"

# Get the ABI for NFT contract
NFT_ABI_PATH="$(dirname $(dirname $(realpath $0)))/out/NFT.sol/NFT.json"
if [ ! -f "$NFT_ABI_PATH" ]; then
    echo "NFT ABI not found. Make sure the contract has been compiled."
    exit 1
fi
NFT_ABI=$(cat "$NFT_ABI_PATH" | jq '.abi')

# Save NFT contract data to web
echo "Saving NFT contract data to web..."
cat <<EOF > $NFT_CONTRACT_PATH
{
    "abi": $NFT_ABI
}
EOF

###############################################
# Deploy NFTMarketplace Contract and extract #
###############################################

echo "Deploying NFTMarketplace contract to $RPC_URL..."
MARKETPLACE_DEPLOY_OUTPUT=$(forge script script/DeployMarketplace.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY)

MARKETPLACE_CONTRACT_ADDRESS=$(echo "$MARKETPLACE_DEPLOY_OUTPUT" | grep "contract Marketplace" | sed -E 's/.*contract Marketplace (0x[a-fA-F0-9]{40}).*/\1/')

if [ -z "$MARKETPLACE_CONTRACT_ADDRESS" ]; then
    echo "Failed to deploy NFTMarketplace contract. Could not find contract address."
    exit 1
fi

echo "NFTMarketplace Contract deployed at: $MARKETPLACE_CONTRACT_ADDRESS"

# Get the ABI for NFTMarketplace contract
MARKETPLACE_ABI_PATH="$(dirname $(dirname $(realpath $0)))/out/Marketplace.sol/Marketplace.json"
if [ ! -f "$MARKETPLACE_ABI_PATH" ]; then
    echo "Marketplace ABI not found. Make sure the contract has been compiled."
    exit 1
fi
MARKETPLACE_ABI=$(cat "$MARKETPLACE_ABI_PATH" | jq '.abi')

# Save NFTMarketplace contract data to web
echo "Saving Marketplace contract data to web..."
cat <<EOF > $MARKETPLACE_CONTRACT_PATH
{
    "abi": $MARKETPLACE_ABI
}
EOF

#############################################
# Generate TypeScript types for both contracts
#############################################

echo "Generating TypeScript types..."
npx typechain --target ethers-v5 --out-dir $TYPES_PATH $NFT_ABI_PATH $MARKETPLACE_ABI_PATH

#############################################
# Update Environment Variables
#############################################

echo "Updating contract addresses in environment file..."
# Check and update environment variables instead of overwriting
sed -i.bak '/NEXT_PUBLIC_NFT_CONTRACT_ADDRESS/d' "$ENV_FILE"
sed -i.bak '/NEXT_PUBLIC_MARKETPLACE_CONTRACT_ADDRESS/d' "$ENV_FILE"

cat <<EOF >> "$ENV_FILE"
NEXT_PUBLIC_NFT_CONTRACT_ADDRESS=$NFT_CONTRACT_ADDRESS
NEXT_PUBLIC_MARKETPLACE_CONTRACT_ADDRESS=$MARKETPLACE_CONTRACT_ADDRESS
EOF

echo "Environment variables saved to $ENV_FILE"
echo "Contract data and types saved to web."