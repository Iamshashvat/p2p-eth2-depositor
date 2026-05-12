// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDepositContract.sol";

contract P2pEth2Depositor is Pausable, Ownable {

    /**
     * @dev Eth2 Deposit Contract address.
     */
    IDepositContract public immutable depositContract;

    /**
     * @dev Minimum and maximum number of validators (deposit entries) per transaction.
     */
    uint256 public constant minValidatorsPerTx = 1;
    uint256 public constant maxValidatorsPerTx = 100;
    uint256 public constant pubkeyLength = 48;
    uint256 public constant credentialsLength = 32;
    uint256 public constant signatureLength = 96;
    bytes1 public constant ETH1_WITHDRAWAL_PREFIX = 0x01;

    /**
     * @dev Per-validator deposit upper bound (`amounts[i] <= maxCollateral`).
     * `collateral` is the 32 ETH threshold used only for the large-deposit withdrawal-credentials guard (`amounts[i] > collateral`).
     */
    uint256 public constant collateral = 32 ether;
    uint256 public constant maxCollateral = 2048 ether;

    /**
     * @dev Setting Eth2 Smart Contract address during construction.
     */
    constructor(bool mainnet, address depositContract_) Ownable(msg.sender) {
        depositContract = mainnet
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa)
            : (depositContract_ == 0x0000000000000000000000000000000000000000)
                ? IDepositContract(0x8c5fecdC472E27Bc447696F431E425D02dd46a8c)
                : IDepositContract(depositContract_);
    }

    /**
     * @dev This contract will not accept direct ETH transactions.
     */
    receive() external payable {
        revert("P2pEth2Depositor: do not send ETH directly here");
    }

    /**
     * @dev Function that allows up to maxValidatorsPerTx validators per transaction.
     *
     * - pubkeys                - Array of BLS12-381 public keys.
     * - withdrawal_credentials - Array of commitments to a public keys for withdrawals.
     * - signatures             - Array of BLS12-381 signatures.
     * - deposit_data_roots     - Array of the SHA-256 hashes of the SSZ-encoded DepositData objects.
     * - amounts                - Array of ETH amounts for each validator deposit.
     */
    function deposit(
        bytes[] calldata pubkeys,
        bytes[] calldata withdrawal_credentials,
        bytes[] calldata signatures,
        bytes32[] calldata deposit_data_roots,
        uint256[] calldata amounts
    ) external payable whenNotPaused {

        uint256 validatorCount = pubkeys.length;

        require(
            validatorCount >= minValidatorsPerTx && validatorCount <= maxValidatorsPerTx,
            "P2pEth2Depositor: you can deposit only 1 to 100 validators per transaction"
        );
        require(
            withdrawal_credentials.length == validatorCount &&
            signatures.length == validatorCount &&
            deposit_data_roots.length == validatorCount &&
            amounts.length == validatorCount,
            "P2pEth2Depositor: amount of parameters do no match");

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < validatorCount; ++i) {
            require(pubkeys[i].length == pubkeyLength, "P2pEth2Depositor: wrong pubkey");
            require(withdrawal_credentials[i].length == credentialsLength, "P2pEth2Depositor: wrong withdrawal credentials");
            require(signatures[i].length == signatureLength, "P2pEth2Depositor: wrong signatures");
            require(amounts[i] <= maxCollateral, "P2pEth2Depositor: amount is above maximum");

            if (amounts[i] > collateral) {
                require(withdrawal_credentials[i][0] != ETH1_WITHDRAWAL_PREFIX, "P2pEth2Depositor: large deposit cannot use 0x01");
            }

            totalAmount += amounts[i];
        }

        require(msg.value == totalAmount, "P2pEth2Depositor: ETH sent must equal sum of amounts");

        for (uint256 i = 0; i < validatorCount; ++i) {
            depositContract.deposit{value: amounts[i]}(
                pubkeys[i],
                withdrawal_credentials[i],
                signatures[i],
                deposit_data_roots[i]
            );

        }

        emit DepositEvent(msg.sender, validatorCount, totalAmount);
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    event DepositEvent(address indexed from, uint256 validatorCount, uint256 totalAmount);
}
