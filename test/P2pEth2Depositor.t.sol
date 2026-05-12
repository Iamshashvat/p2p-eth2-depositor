// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../src/P2pEth2Depositor.sol";
import "../src/interfaces/IDepositContract.sol";

interface Vm {
    function deal(address who, uint256 newBalance) external;
    function expectRevert() external;
    function expectRevert(bytes calldata revertData) external;
}

contract MockDepositContract is IDepositContract {
    uint256 public depositsCount;
    uint256 public totalReceived;
    uint256 public lastAmount;

    function deposit(
        bytes calldata,
        bytes calldata,
        bytes calldata,
        bytes32
    ) external payable {
        depositsCount += 1;
        totalReceived += msg.value;
        lastAmount = msg.value;
    }

    function get_deposit_root() external pure returns (bytes32) {
        return bytes32(0);
    }

    function get_deposit_count() external pure returns (bytes memory) {
        return new bytes(8);
    }
}

contract P2pEth2DepositorTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockDepositContract private depositContract;
    P2pEth2Depositor private depositor;

    function setUp() public {
        vm.deal(address(this), 10000 ether);
        depositContract = new MockDepositContract();
        depositor = new P2pEth2Depositor(false, address(depositContract));
    }

    function testDeposit32EthWith0x01CredentialsPasses() public {
        _deposit(32 ether, 0x01);

        require(depositContract.depositsCount() == 1, "expected deposit");
        require(depositContract.lastAmount() == 32 ether, "wrong amount");
    }

    function testDeposit32EthWith0x02CredentialsPasses() public {
        _deposit(32 ether, 0x02);

        require(depositContract.depositsCount() == 1, "expected deposit");
        require(depositContract.lastAmount() == 32 ether, "wrong amount");
    }

    function testDeposit65EthWith0x02CredentialsPasses() public {
        _deposit(65 ether, 0x02);

        require(depositContract.depositsCount() == 1, "expected deposit");
        require(depositContract.lastAmount() == 65 ether, "wrong amount");
    }

    function testDeposit65EthWith0x01CredentialsReverts() public {
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256[] memory amounts
        ) = _singleDepositData(65 ether, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: large deposit cannot use 0x01"));
        depositor.deposit{value: 65 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);
    }

    function testDeposit65EthWithFuturePrefixCredentialsPasses() public {
        _deposit(65 ether, 0x03);

        require(depositContract.depositsCount() == 1, "expected deposit");
        require(depositContract.lastAmount() == 65 ether, "wrong amount");
    }

    function testMsgValueMismatchReverts() public {
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256[] memory amounts
        ) = _singleDepositData(32 ether, 0x01);

        vm.expectRevert(bytes("P2pEth2Depositor: ETH sent must equal sum of amounts"));
        depositor.deposit{value: 31 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);
    }

    function testAmountsLengthMismatchReverts() public {
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
        ) = _singleDepositData(32 ether, 0x01);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(bytes("P2pEth2Depositor: amount of parameters do no match"));
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);
    }

    function testSmallDepositBelow32EthPasses() public {
        _deposit(31 ether, 0x01);

        require(depositContract.depositsCount() == 1, "expected deposit");
        require(depositContract.lastAmount() == 31 ether, "wrong amount");
    }

    function testAmountAbove2048EthReverts() public {
        uint256 amount = 2048 ether + 1 wei;
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256[] memory amounts
        ) = _singleDepositData(amount, 0x02);

        vm.expectRevert(bytes("P2pEth2Depositor: amount is above maximum"));
        depositor.deposit{value: amount}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);
    }

    function testPauseUnpauseBehavior() public {
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256[] memory amounts
        ) = _singleDepositData(32 ether, 0x01);

        depositor.pause();
        vm.expectRevert();
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);

        depositor.unpause();
        depositor.deposit{value: 32 ether}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);

        require(depositContract.depositsCount() == 1, "expected deposit");
    }

    function testDirectEthTransferReverts() public {
        (bool success,) = address(depositor).call{value: 1 ether}("");

        require(!success, "direct transfer should revert");
    }

    function _deposit(uint256 amount, bytes1 withdrawalPrefix) internal {
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256[] memory amounts
        ) = _singleDepositData(amount, withdrawalPrefix);

        depositor.deposit{value: amount}(pubkeys, withdrawalCredentials, signatures, depositDataRoots, amounts);
    }

    function _singleDepositData(uint256 amount, bytes1 withdrawalPrefix)
        internal
        pure
        returns (
            bytes[] memory pubkeys,
            bytes[] memory withdrawalCredentials,
            bytes[] memory signatures,
            bytes32[] memory depositDataRoots,
            uint256[] memory amounts
        )
    {
        pubkeys = new bytes[](1);
        withdrawalCredentials = new bytes[](1);
        signatures = new bytes[](1);
        depositDataRoots = new bytes32[](1);
        amounts = new uint256[](1);

        pubkeys[0] = new bytes(48);
        withdrawalCredentials[0] = new bytes(32);
        withdrawalCredentials[0][0] = withdrawalPrefix;
        signatures[0] = new bytes(96);
        depositDataRoots[0] = bytes32(uint256(1));
        amounts[0] = amount;
    }
}
