// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFtmStaking {
    function delegate(uint256 toValidatorID) external payable;
    function undelegate(uint256 toValidatorID, uint256 wrID, uint256 amount) external;
    function claimRewards(uint256 toValidatorID) external;
    function withdraw(uint256 toValidatorID, uint256 wrID) external;
    function pendingRewards(address delegator, uint256 toValidatorID) external view returns (uint256);
}

interface IYieldManager {
    function setAffiliate(address client, address sponsor) external;
    function getUserFactors(
        address user,
        uint typer
    ) external view returns (uint, uint, uint, uint);

    function getAffiliate(address client) external view returns (address);
}

contract FtmStakingImplementation is ReentrancyGuard {
    event Delegate(address indexed staker, uint amount, uint toValidatorID);
    event Undelegate(address indexed spender, uint amount, uint toValidatorID, uint wrID);
    event Withdraw(address indexed spender, uint amount, uint toValidatorID, uint wrID);
    event ClaimRewards(address indexed spender, uint amount, uint toValidatorID);
    event Deposited(address indexed sender, uint amount);
    event NewOwner(address indexed owner);
    event SponsorFee(address indexed sponsor, uint amount);
    event MgmtFee(address indexed factory, uint amount);
    event PerformanceFee(address indexed factory, uint amount);
    event SponsorPerformanceFee(address indexed sponsor, uint amount);

    using SafeERC20 for IERC20;
    address public owner;
    IFtmStakingFactory public factoryAddress;

    //validatorId => amount delegated/staked
    mapping(uint256 => uint256) public stake;
    mapping(uint256 => mapping(uint256 => uint256)) public unstakes;

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
        factoryAddress = IFtmStakingFactory(factoryAddress_);

        emit NewOwner(owner);
    }

    // only stake function needed
    function delegate(uint256 toValidatorID) external payable onlyOwner nonReentrant {
        require(msg.value > 0, "Cannot stake 0 token");

        stake[toValidatorID] += msg.value;

        IFtmStaking(IFtmStakingFactory(factoryAddress).getStakingContract()).delegate{value: msg.value}(toValidatorID);
        emit Delegate(owner, msg.value, toValidatorID);
    }

    function withdraw(uint256 toValidatorID, uint wrID) external onlyOwner nonReentrant {
        uint amount = unstakes[toValidatorID][wrID];
        require(amount > 0, "Cannot withdraw 0");
        stake[toValidatorID] -= amount;

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
        IFtmStaking(IFtmStakingFactory(factoryAddress).getStakingContract()).withdraw(toValidatorID, wrID);

        // send tokens
        payable(owner).transfer(amount - mgmtFee - sponsorFee);

        if (sponsor != address(0) && sponsorFee != 0) {
            payable(sponsor).transfer(sponsorFee);
            emit SponsorFee(sponsor, sponsorFee);
        }

        if (mgmtFee != 0) {
            payable(address(factoryAddress)).transfer(mgmtFee);
            emit MgmtFee (address(factoryAddress), mgmtFee);
        }

        emit Withdraw(owner, amount, toValidatorID, wrID);
    }

    // we need this as a public function callable by everyone
    function claimRewards(uint256 toValidatorID) external onlyOwner {
        uint amount = IFtmStaking(IFtmStakingFactory(factoryAddress).getStakingContract()).pendingRewards(address(this), toValidatorID);

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
        IFtmStaking(IFtmStakingFactory(factoryAddress).getStakingContract()).claimRewards(toValidatorID);

        // send tokens
        payable(owner).transfer(amount - perfFee - sPerfFee);

        if (perfFee != 0) {
            payable(address(factoryAddress)).transfer(perfFee);
            emit PerformanceFee(address(factoryAddress), perfFee);
        }

        if (sponsor != address(0) && sPerfFee != 0) {
            payable(sponsor).transfer(sPerfFee);
            emit SponsorPerformanceFee(sponsor, sPerfFee);
        }

        emit ClaimRewards(owner, amount, toValidatorID);
    }

    function undelegate(uint256 toValidatorID, uint256 wrID, uint256 amount) public onlyOwner {
        require(unstakes[toValidatorID][wrID] == 0, "wrID already exists");
        unstakes[toValidatorID][wrID] = amount;
        IFtmStaking(IFtmStakingFactory(factoryAddress).getStakingContract()).undelegate(toValidatorID, wrID, amount);
        emit Undelegate(owner, amount, toValidatorID, wrID);
    }

    function getStake(uint256 validatorID) public view returns (uint256) {
        return stake[validatorID];
    }

    /**
     * receive function to receive funds
    */
    receive() external payable {}
}

interface IFtmStakingFactory {
    function getYieldManager() external view returns(address);
    function getStakingContract() external view returns (address);
}
