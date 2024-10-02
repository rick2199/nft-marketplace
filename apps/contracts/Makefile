RPC_URL ?= http://localhost:8545
PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Default task: Compile contracts
build:
	@echo "Compiling contracts..."
	forge build

install:
	@echo "Installing dependencies..."
	forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit

# Deploy contracts and generate ABI and address by calling the bash script
deploy-and-generate-types: build
	@echo "Deploying contracts and generating types..."
	# Call your bash script and pass the RPC_URL as an argument
	bash ./script/deploy-and-generate-types.sh $(RPC_URL) $(PRIVATE_KEY)

# Clean output directory
clean:
	@echo "Cleaning up..."
	rm -rf out

# Run tests
test:
	@echo "Running tests..."
	forge test
