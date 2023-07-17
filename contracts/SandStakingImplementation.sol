// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISandStaking {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function earned(address account) external view returns (uint256);
}

interface IYieldManager {
    function setAffiliate(address client, address sponsor) external;
    function getUserFactors(
        address user,
        uint typer
    ) external view returns (uint, uint, uint, uint);

    function getAffiliate(address client) external view returns (address);
}

contract SandStakingImplementation is ReentrancyGuard {
    event Staked(address indexed staker, uint amount);
    event Withdraw(address indexed spender, uint amount);
    event GetRewards(address indexed spender, uint amount);
    event Deposited(address indexed sender, uint amount);
    event NewOwner(address indexed owner);
    event SponsorFee(address indexed sponsor, uint amount);
    event MgmtFee(address indexed factory, uint amount);
    event PerformanceFee(address indexed factory, uint amount);
    event SponsorPerformanceFee(address indexed sponsor, uint amount);

    using SafeERC20 for IERC20;
    address public owner;
    ISandStakingFactory public factoryAddress;

    // only owner modifier
    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    // only owner view
    function _onlyOwner() private view {
        require(msg.sender == owner || msg.sender == address(factoryAddress), "Only the contract owner may perform this action");
    }

    constructor() {
        // Don't allow implementation to be initialized.
        owner = address(1);
    }

    function initialize(
        address owner_,
        address factoryAddress_
    ) external
    {
        require(owner == address(0), "already initialized");
        require(factoryAddress_ != address(0), "factory can not be null");
        require(owner_ != address(0), "owner cannot be null");

        owner = owner_;
        factoryAddress = ISandStakingFactory(factoryAddress_);

        emit NewOwner(owner);
    }

    // only stake function needed
    function stake(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Cannot stake 0 token");

        IERC20(ISandStakingFactory(factoryAddress).getStakingToken()).safeTransferFrom(
            owner,
            address(this),
            amount
        );

        IERC20(ISandStakingFactory(factoryAddress).getStakingToken()).approve(ISandStakingFactory(factoryAddress).getStakingContract(), amount);

        ISandStaking(ISandStakingFactory(factoryAddress).getStakingContract()).stake(amount);
        emit Staked(owner, amount);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Cannot withdraw 0");

        // get user stats
        (, , uint val3,) = IYieldManager(factoryAddress.getYieldManager()).getUserFactors(
            owner,
            0
        );

        uint mgmtFee = (val3 * amount) / 100 / 100;
        uint sponsorFee;

        // get sponsor
        address sponsor = IYieldManager(factoryAddress.getYieldManager()).getAffiliate(owner);
        // get sponsor stats
        if (sponsor != address(0)) {
            (, uint sval2,, ) = IYieldManager(factoryAddress.getYieldManager())
            .getUserFactors(sponsor, 1);
            sponsorFee = (mgmtFee * sval2) / 100 / 100;
            mgmtFee -= sponsorFee;
        }

        //withdraw
        ISandStaking(ISandStakingFactory(factoryAddress).getStakingContract()).withdraw(amount);

        // send tokens
        IERC20(ISandStakingFactory(factoryAddress).getStakingToken()).transfer(
            owner,
            amount - mgmtFee - sponsorFee
        );

        if (sponsor != address(0) && sponsorFee != 0) {
            IERC20(ISandStakingFactory(factoryAddress).getStakingToken()).transfer(sponsor, sponsorFee);
            emit SponsorFee(sponsor, sponsorFee);
        }

        if (mgmtFee != 0) {
            IERC20(ISandStakingFactory(factoryAddress).getStakingToken()).transfer(address(factoryAddress), mgmtFee);
            emit MgmtFee(address(factoryAddress), mgmtFee);
        }

        emit Withdraw(owner, amount);
    }

    // we need this as a public function callable by everyone
    function getReward() external onlyOwner {
        // get earned amount
        uint amount = ISandStaking(ISandStakingFactory(factoryAddress).getStakingContract()).earned(address(this));

        (, uint val2,,) = IYieldManager(factoryAddress.getYieldManager()).getUserFactors(
            owner,
            0
        );

        uint perfFee = (val2 * amount) / 100 / 100;
        uint sPerfFee;

        address sponsor = IYieldManager(factoryAddress.getYieldManager()).getAffiliate(owner);

        // get sponsor stats
        if (sponsor != address(0)) {
            (uint sval1,,,) = IYieldManager(factoryAddress.getYieldManager())
            .getUserFactors(sponsor, 1);
            sPerfFee = (perfFee * sval1)  / 100 / 100;
            perfFee -= sPerfFee;
        }

        // get reward
        ISandStaking(ISandStakingFactory(factoryAddress).getStakingContract()).getReward();

        // send tokens
        IERC20(ISandStakingFactory(factoryAddress).getRewardToken()).transfer(owner, amount - perfFee - sPerfFee);

        if (perfFee != 0) {
            IERC20(ISandStakingFactory(factoryAddress).getRewardToken()).transfer(address(factoryAddress), perfFee);
            emit PerformanceFee(address(factoryAddress), perfFee);
        }

        if (sponsor != address(0) && sPerfFee != 0) {
            IERC20(ISandStakingFactory(factoryAddress).getRewardToken()).transfer(sponsor, sPerfFee);
            emit SponsorPerformanceFee(sponsor, sPerfFee);
        }

        emit GetRewards(owner, amount);
    }
}

interface ISandStakingFactory {
    function getYieldManager() external view returns(address);
    function getRewardToken() external view returns (address);
    function getStakingToken() external view returns (address);
    function getStakingContract() external view returns (address);
}
