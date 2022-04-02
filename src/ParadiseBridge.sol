// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokensHelper} from "./lib/TokensHelper.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract ParadiseBridge is AccessControlEnumerable, ReentrancyGuard {
    error BridgeIsNotAvaliable();
    error InvalidTokenAddress();
    error InvalidBridgeAmount();
    error UnbridgeableTokens();
    error UnableToApproveBridge();
    error InvalidConfigList();

    struct BridgeableTokensConfig {
        bool enabled;
        bool burn;
        uint256 minBridgeAmount;
        uint256 maxBridgeAmount;
        uint256 bridgeFee;
    }

    struct BridgeApprovalConfig {
        bool enabled;
        bool transfer;
    }

    /**
     * @dev Submit a bridge request on chain
     */
    event BridgeToSubmitted(
        address indexed token,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 targetChain
    );

    /**
     * @dev Emit after bridging is complete
     */
    event BridgeToApproved(
        bytes32 indexed txhash,
        address indexed targetToken,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 targetChain
    );

    event TokensDeposit(uint256 indexed chainId, address indexed from, uint256 amount);

    bytes32 public constant BRIDGE_APPROVER_ROLE = keccak256("BRIDGE_APPROVER_ROLE");

    mapping(address => BridgeableTokensConfig) private _bridgeableTokens;
    BridgeableTokensConfig private _nativeTokensBridgeConfig;

    mapping(address => BridgeApprovalConfig) public bridgeApprovalConfig;
    bool public bridgeToNativeApprovalStatus;

    bool public bridgeIsRunning;

    modifier checkTokenAddress(address token) {
        if (!Address.isContract(token)) revert InvalidTokenAddress();
        _;
    }

    modifier needBridgeIsRunning() {
        if (!bridgeIsRunning) revert BridgeIsNotAvaliable();
        _;
    }

    modifier checkBridgeApprovalStatus(address token) {
        if (!bridgeApprovalConfig[token].enabled) revert UnableToApproveBridge();
        _;
    }

    modifier checkBridgeTokensConfig(uint256 amount, BridgeableTokensConfig memory config) {
        if (!config.enabled) revert UnbridgeableTokens();
        if (amount < config.minBridgeAmount || amount > config.maxBridgeAmount) revert InvalidBridgeAmount();
        _;
    }

    constructor(bool bridgeRunningStatus) {
        bridgeIsRunning = bridgeRunningStatus;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(BRIDGE_APPROVER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Get the current chain ID
     */
    function chainId() public view returns (uint256 id) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
    }

    /**
     * @notice Get the native tokens bridge config
     */
    function bridgeableTokens() public view returns (BridgeableTokensConfig memory config) {
        return _nativeTokensBridgeConfig;
    }

    /**
     * @notice Get the ERC20 tokens bridge config
     * @param token The ERC20 token address
     */
    function bridgeableTokens(address token)
        public
        view
        checkTokenAddress(token)
        returns (BridgeableTokensConfig memory config)
    {
        return _bridgeableTokens[token];
    }

    /**
     * @notice Bridging the ERC20 token to the target chain
     * @param token The ERC20 token address on the current chain
     * @param recipient The recipient address on the target chain
     * @param amount The bridge ERC20 tokens amount
     * @param targetChainId The target chain ID (can be found here: https://chainlist.org/)
     */
    function bridgeTokensTo(
        address token,
        address recipient,
        uint256 amount,
        uint256 targetChainId
    )
        external
        nonReentrant
        needBridgeIsRunning
        checkTokenAddress(token)
        checkBridgeTokensConfig(amount, _bridgeableTokens[token])
    {
        if (_bridgeableTokens[token].burn) {
            TokensHelper.safeBurnFrom(token, msg.sender, amount);
        } else {
            TokensHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        }
        emit BridgeToSubmitted(token, msg.sender, recipient, amount, chainId(), targetChainId);
    }

    /**
     * @notice Bridging the native token to the target chain
     * @param recipient The recipient address on the target chain
     * @param targetChainId The target chain ID (can be found here: https://chainlist.org/)
     */
    function bridgeNativeTokensTo(address recipient, uint256 targetChainId)
        external
        payable
        nonReentrant
        needBridgeIsRunning
        checkBridgeTokensConfig(msg.value, _nativeTokensBridgeConfig)
    {
        emit BridgeToSubmitted(address(0), msg.sender, recipient, msg.value, chainId(), targetChainId);
    }

    /**
     * @dev Approvers process bridge requests (to ERC20)
     * @param txHash The transaction hash of the bridge request from source chain
     * @param sourceChainId The chain id that made the bridge request
     * @param targetToken The address of the target token
     * @param recipient The recipient of tokens
     * @param amount The amount of tokens
     */
    function approveBridgeTo(
        bytes32 txHash,
        uint256 sourceChainId,
        address targetToken,
        address recipient,
        uint256 amount
    )
        external
        nonReentrant
        needBridgeIsRunning
        onlyRole(BRIDGE_APPROVER_ROLE)
        checkTokenAddress(targetToken)
        checkBridgeApprovalStatus(targetToken)
    {
        if (bridgeApprovalConfig[targetToken].transfer) {
            TokensHelper.safeTransfer(targetToken, recipient, amount);
        } else {
            TokensHelper.safeMint(targetToken, recipient, amount);
        }
        emit BridgeToApproved(txHash, targetToken, recipient, amount, sourceChainId, chainId());
    }

    /**
     * @dev Approvers process bridge requests (to native tokens)
     * @param txHash The transaction hash of the bridge request from source chain
     * @param sourceChainId The chain id that made the bridge request
     * @param recipient The recipient of tokens
     * @param amount The amount of tokens
     */
    function approveBridgeToNative(
        bytes32 txHash,
        uint256 sourceChainId,
        address recipient,
        uint256 amount
    ) external nonReentrant needBridgeIsRunning onlyRole(BRIDGE_APPROVER_ROLE) {
        if (!bridgeToNativeApprovalStatus) revert UnableToApproveBridge();
        TokensHelper.safeTransferNativeTokens(recipient, amount);
        emit BridgeToApproved(txHash, address(0), recipient, amount, sourceChainId, chainId());
    }

    function addBridgeableTokens(address[] memory addresses, BridgeableTokensConfig[] memory configs)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (addresses.length != configs.length) revert InvalidConfigList();
        for (uint256 i; i < addresses.length; i++) {
            if (!Address.isContract(addresses[i])) revert InvalidTokenAddress();
            _bridgeableTokens[addresses[i]] = configs[i];
        }
    }

    function setNativeTokensBridgeConfig(BridgeableTokensConfig memory config) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _nativeTokensBridgeConfig = config;
    }

    function addBridgeApprovalConfig(address[] memory addresses, BridgeApprovalConfig[] memory configs)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (addresses.length != configs.length) revert InvalidConfigList();
        for (uint256 i; i < addresses.length; i++) {
            if (!Address.isContract(addresses[i])) revert InvalidTokenAddress();
            bridgeApprovalConfig[addresses[i]] = configs[i];
        }
    }

    function setBridgeToNativeApprovalStatus(bool nativeApprovalStatus) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bridgeToNativeApprovalStatus = nativeApprovalStatus;
    }

    function setBridgeRunningStatus(bool bridgeRunningStatus) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bridgeIsRunning = bridgeRunningStatus;
    }

    function depositNativeTokens() external payable {
        emit TokensDeposit(chainId(), msg.sender, msg.value);
    }
}
