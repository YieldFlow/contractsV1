// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma experimental ABIEncoderV2;

import "./libraries/CloneLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @author YFLOW Team
/// @title AaveStakingFactory
/// @notice Factory contract to create new instances
contract FtmStakingFactory {
    using CloneLibrary for address;

    event NewFtmStaking(address ftmStaking, address client);
    event FactoryOwnerChanged(address newowner);
    event NewYieldManager(address newYieldManager);
    event NewFtmStakingImplementation(address newFtmStakingImplementation);
    event NewStakingContract(address stakingContract);
    event FeesWithdrawn(uint amount, address withdrawer);
    event NewSponsor(address sponsor, address client);

    address public factoryOwner;
    address public ftmImplementation;
    address public yieldManager;
    address public stakingContract;

    mapping(address => address) public stakingContractLookup;

    constructor(
        address _ftmImplementation,
        address _yieldManager,
        address _stakingContract
    )
    {
        require(_ftmImplementation != address(0), "No zero address for _ftmImplementation");
        require(_yieldManager != address(0), "No zero address for _yieldManager");

        factoryOwner = msg.sender;
        ftmImplementation = _ftmImplementation;
        yieldManager = _yieldManager;
        stakingContract = _stakingContract;

        emit FactoryOwnerChanged(factoryOwner);
        emit NewFtmStakingImplementation(ftmImplementation);
        emit NewYieldManager(yieldManager);
        emit NewStakingContract(stakingContract);
    }

    function ftmStakingMint(address sponsor)
    external
    returns(address ftm)
    {
        ftm = ftmImplementation.createClone();

        emit NewFtmStaking(ftm, msg.sender);
        stakingContractLookup[msg.sender] = ftm;

        IFtmStakingImplementation(ftm).initialize(
            msg.sender,
            address(this)
        );

        if (sponsor != address(0) && sponsor != msg.sender && IYieldManager(yieldManager).getAffiliate(msg.sender) == address(0)) {
            IYieldManager(yieldManager).setAffiliate(msg.sender, sponsor);
            emit NewSponsor(sponsor, msg.sender);
        }
    }

    /**
     * @dev gets the address of the yield manager
     *
     * @return the address of the yield manager
    */
    function getYieldManager() external view returns (address) {
        return yieldManager;
    }

    function getStakingContract() external view returns (address) {
        return stakingContract;
    }

    /**
     * @dev lets the owner change the current ftm implementation
     *
     * @param ftmImplementation_ the address of the new implementation
    */
    function newFtmStakingImplementation(address ftmImplementation_) external {
        require(msg.sender == factoryOwner, "Only factory owner");
        require(ftmImplementation_ != address(0), "No zero address for ftmImplementation_");

        ftmImplementation = ftmImplementation_;
        emit NewFtmStakingImplementation(ftmImplementation);
    }

    /**
     * @dev lets the owner change the current yieldManager_
     *
     * @param yieldManager_ the address of the new router
    */
    function newYieldManager(address yieldManager_) external {
        require(msg.sender == factoryOwner, "Only factory owner");
        require(yieldManager_ != address(0), "No zero address for yieldManager_");

        yieldManager = yieldManager_;
        emit NewYieldManager(yieldManager);
    }

    function newStakingContract(address stakingContract_) external {
        require(msg.sender == factoryOwner, "Only factory owner");
        require(stakingContract_ != address(0), "No zero address for stakingContract_");

        stakingContract = stakingContract_;
        emit NewStakingContract(stakingContract);
    }

    /**
     * @dev lets the owner change the ownership to another address
     *
     * @param newOwner the address of the new owner
    */
    function newFactoryOwner(address payable newOwner) external {
        require(msg.sender == factoryOwner, "Only factory owner");
        require(newOwner != address(0), "No zero address for newOwner");

        factoryOwner = newOwner;
        emit FactoryOwnerChanged(factoryOwner);
    }

    function getUserStakingContract(address staker) external view returns(address) {
        return stakingContractLookup[staker];
    }

    function withdrawRewardFees(
        address receiver,
        uint amount
    ) external  {
        require(msg.sender == factoryOwner, "Only factory owner");
        require(amount > 0, "Cannot withdraw 0");
        require(
            amount <= address(this).balance,
            "Cannot withdraw more than fees in the contract"
        );
        payable(receiver).transfer(amount);
        emit FeesWithdrawn(amount, receiver);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) public payable returns (bytes memory) {
        require(
            msg.sender == factoryOwner,
            "executeTransaction: Call must come from owner"
        );

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(
            success,
            "executeTransaction: Transaction execution reverted."
        );

        return returnData;
    }

    /**
     * receive function to receive funds
    */
    receive() external payable {}
}

interface IFtmStakingImplementation {
    function initialize(
        address owner_,
        address factoryAddress_
    ) external;
}

interface IYieldManager {
    function setAffiliate(address client, address sponsor) external;
    function getAffiliate(address client) external view returns (address);
}

