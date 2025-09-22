-include .env

.PHONY: install test test-sepolia deploy-anvil deploy-sepolia rebuild interact-anvil

install :; forge install foundry-rs/forge-std@v1.8.2 && forge install OpenZeppelin/openzeppelin-contracts@v5.4.0 && forge install cyfrin/foundry-devops@0.4.0 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1

rebuild:
	forge clean && forge build

deploy-anvil :
	forge script script/$(NAME).s.sol --rpc-url $(LOCAL_RPC_URL) --account defaultKey --sender $(ANVIL_SENDER) $(ARGS)

deploy-sepolia :
	forge script script/$(NAME).s.sol --rpc-url $(SEPOLIA_RPC_URL) --account sepoliaKey --sender $(SEPOLIA_SENDER) $(ARGS)

interact-anvil :
	forge script script/Interaction.s.sol:$(NAME) --rpc-url $(LOCAL_RPC_URL) --account defaultKey --sender $(ANVIL_SENDER) $(ARGS)

test:
	forge test

test-sepolia :
	forge test --fork-url $(SEPOLIA_RPC_URL) -vvvv --sender $(SEPOLIA_SENDER)