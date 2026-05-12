P2P Eth2 Depositor
=========

P2P Eth2 Depositor allows convenient way to send 1 to 100 deposits in one transaction to Eth2 Deposit Contract.

Contracts
=========

Below is a list of contracts we use for this service:

<dl>
  <dt>Ownable, Pausable</dt>
  <dd><a href="https://github.com/OpenZeppelin/openzeppelin-contracts">OpenZeppelin Contracts</a> (installed as a Foundry dependency under <code>lib/openzeppelin-contracts</code>, tag <code>v5.6.1</code>). The first contract manages ownership; the second supports pausing.</dd>
</dl>

<dl>
  <dt>P2pEth2Depositor</dt>
  <dd>A smart contract that forwards variable per-validator deposit amounts (capped at 2048 ETH per entry) and sends up to 100 deposit calls per transaction to Eth2 Deposit Contract.</dd>
</dl>

Installation
------------

Install [Foundry](https://getfoundry.sh) and pull the repository from `GitHub`:

    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    git clone https://github.com/p2p-org/p2p-eth2-depositor
    cd p2p-eth2-depositor
    git submodule update --init --recursive
Deployment (Mainnet)
------------

```bash    
forge create --rpc-url https://mainnet.infura.io/v3/<YOUR INFURA KEY> \
    --constructor-args true 0x0000000000000000000000000000000000000000 \
    --private-key <YOUR PRIVATE KEY> src/P2pEth2Depositor.sol:P2pEth2Depositor \
    --etherscan-api-key <YOUR ETHERSCAN API KEY> \
    --verify
```

How to Use
------------

1. Choose amount of Eth2 validator nodes you want to create.
2. Create arrays with your pubkeys, withdrawal_credentials, signatures, calldata deposit_data_roots, and deposit amounts.
3. Use _deposit()_ function on `P2pEth2Depositor` with `msg.value` equal to the sum of all values in `amounts`.

Each value in `amounts` must not exceed **2048 ETH**. There is **no minimum** enforced by this contract; use amounts appropriate for your chain and tooling.

Deposits **strictly above 32 ETH** reject withdrawal credentials whose first byte is execution-withdrawal **`0x01`**. Other prefixes such as **`0x00`**, **`0x02`**, and future 32-byte credential formats are allowed. Deposits **at most 32 ETH** remain credential-type independent aside from length.

This wrapper does not replicate every protocol rule: the official deposit contract may still revert on amounts or deposit data that consensus rejects.

Important: `deposit_data_root` must be generated from the exact deposit data, including the exact amount being deposited. Do not fake or reuse a 32 ETH `deposit_data_root` for variable deposits.

License
=========

MIT

Code based on Abyss finance example https://github.com/abyssfinance/abyss-eth2depositor
