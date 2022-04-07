// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokensHelper} from "./lib/TokensHelper.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract ParadiseBridge is AccessControlEnumerable, ReentrancyGuard {
    /**
     * @dev Token bridging configuration
     */
    struct BridgeableTokensConfig {
        // Whether to allow this token into the bridge.
        bool enabled;
        // When the token enters the bridge, choose to `burn` (true) or `transfer to the bridge` (false).
        bool burn;
        // After deducting fee, the bridge amount needs to be greater than the minimum value.
        uint256 minBridgeAmount;
        // Maximum amount to bridge.
        uint256 maxBridgeAmount;
        // Bridge fee, set by administrator.
        uint256 bridgeFee;
    }

    /**
     * @dev Rules for Approving Token Bridging
     */
    struct BridgeApprovalConfig {
        // whether to allow this token to be approved for bridging.
        bool enabled;
        // When bridging, the target token will be `transferred` (true) or `mint by the contract` (false).
        bool transfer;
    }

    /**
     * @dev The token contract is on the specified chain
     */
    struct TokensOnChain {
        // Token contract address
        address token;
        // Specified chain ID
        uint256 chainId;
    }

    /**
     * @dev Submit a bridge request on source chain
     * @param token The token address on the source chain.
     * @param sender The bridge request sender.
     * @param recipient The token recipients on the target chain.
     * @param amount The amount (after deduction of fee) of tokens the receiver should receive.
     * @param fees The fee charged by the bridge.
     * @param sourceChain Bridging from chain ID.
     * @param targetChain Bridging to chain ID.
     */
    event BridgeToSubmitted(
        address indexed token,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 fees,
        uint256 sourceChain,
        uint256 targetChain
    );

    /**
     * @dev Emit on target chain after bridging is complete
     * @param txhash The transaction hash of the bridge request submitted on the source chain.
     * @param targetToken The token address on the target chain.
     * @param recipient The token recipients on the target chain.
     * @param amount The amount of tokens the receiver should receive.
     * @param sourceChain Bridging from chain ID.
     * @param targetChain Bridging to chain ID.
     */
    event BridgeToApproved(
        bytes32 indexed txhash,
        address indexed targetToken,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 targetChain
    );

    /**
     * @dev Emit when the native token is deposited on the bridge
     * @param chainId The chain id where the bridge contract is located.
     * @param amount Deposit amount.
     */
    event TokensDeposit(uint256 indexed chainId, address indexed from, uint256 amount);

    /**
     * @dev Emit when fee recipient changes
     */
    event FeeRecipientChanged(address indexed newRecipient);

    /**
     * @dev Emit when bridge running status changes
     */
    event BridgeRunningStatusChanged(bool indexed newRunningStatus);

    /**
     * @dev Emit when token bridge fee updated
     */
    event BridgeFeeUpdated(address indexed token, uint256 newFee);

    bytes32 public constant BRIDGE_APPROVER_ROLE = keccak256("BRIDGE_APPROVER_ROLE");

    mapping(bytes32 => BridgeableTokensConfig) private _bridgeableTokens;
    mapping(address => BridgeApprovalConfig) public bridgeApprovalConfig;

    /**
     * @dev The address of the fee recipient
     */
    address public feeRecipient;

    /**
     * @notice Is bridge currently available
     */
    bool public bridgeIsRunning;

    /**
     * @notice Whether bridge currently charges fee (global setting)
     */
    bool public globalFeeStatus;

    modifier checkTokenAddress(address token) {
        require(Address.isContract(token), "invalid token address");
        _;
    }

    modifier needBridgeIsRunning() {
        require(bridgeIsRunning, "bridge is not running");
        _;
    }

    modifier checkBridgeApprovalStatus(address token) {
        require(bridgeApprovalConfig[token].enabled, "token is not approved");
        _;
    }

    modifier checkArrayLength(uint256 lenA, uint256 lenB) {
        require(lenA == lenB, "arrays should equal in length");
        _;
    }

    constructor(
        bool _bridgeRunningStatus,
        bool _globalFeeStatus,
        address _feeRecipient
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(BRIDGE_APPROVER_ROLE, DEFAULT_ADMIN_ROLE);

        _setBridgeRunningStatus(_bridgeRunningStatus);
        globalFeeStatus = _globalFeeStatus;

        _setFeeRecipient(_feeRecipient);
    }

    /**
     * @dev Encode token address with chainId
     */
    function _encodeTokenWithChainId(address _token, uint256 _chainId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token, _chainId));
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
     * @notice Get the tokens bridge config
     * @param token The token address (zero is native token)
     * @param targetChainId The id of target chain
     */
    function bridgeableTokens(address token, uint256 targetChainId)
        public
        view
        returns (BridgeableTokensConfig memory config)
    {
        BridgeableTokensConfig memory _tokenConfig = _bridgeableTokens[_encodeTokenWithChainId(token, targetChainId)];
        if (!globalFeeStatus) {
            _tokenConfig.bridgeFee = 0;
        }
        return _tokenConfig;
    }

    function _setBridgeRunningStatus(bool newRunningStatus) internal {
        bridgeIsRunning = newRunningStatus;
        emit BridgeRunningStatusChanged(newRunningStatus);
    }

    /**
     * @dev Check token address
     * zero address is native token
     */
    function _checkTokenAddress(address token) internal view {
        require(token == address(0) || Address.isContract(token), "invalid token address");
    }

    function _setFeeRecipient(address newRecipient) internal {
        require(newRecipient != address(0) && newRecipient != address(this), "invalid fees recipient");
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(newRecipient);
    }

    function _setBridgeFee(
        address _token,
        uint256 _chainId,
        uint256 newFee
    ) internal {
        BridgeableTokensConfig storage _tokenConfig = _bridgeableTokens[_encodeTokenWithChainId(_token, _chainId)];
        if (_tokenConfig.bridgeFee == newFee) return;

        require(
            (newFee < _tokenConfig.maxBridgeAmount) &&
                ((_tokenConfig.maxBridgeAmount - newFee) >= _tokenConfig.minBridgeAmount),
            "invalid fee config"
        );
        _tokenConfig.bridgeFee = newFee;

        emit BridgeFeeUpdated(_token, newFee);
    }

    /**
     * @notice Bridging the ERC20 token to the target chain
     * @param token The ERC20 token address on the current chain.
     * @param recipient The recipient address on the target chain.
     * @param amount The bridge ERC20 tokens amount.
     * @param targetChainId The target chain ID (can be found here: https://chainlist.org/).
     */
    function bridgeTokensTo(
        address token,
        address recipient,
        uint256 amount,
        uint256 targetChainId
    ) external nonReentrant needBridgeIsRunning checkTokenAddress(token) {
        require(recipient != address(0), "invalid recipient");

        BridgeableTokensConfig storage _tokenConfig = _bridgeableTokens[_encodeTokenWithChainId(token, targetChainId)];

        require(_tokenConfig.enabled, "token is not bridgeable");
        require(amount > _tokenConfig.bridgeFee, "bridge amount should be greater than fees");

        if (globalFeeStatus && _tokenConfig.bridgeFee > 0) {
            TokensHelper.safeTransferFrom(token, msg.sender, feeRecipient, _tokenConfig.bridgeFee);
            amount -= _tokenConfig.bridgeFee;
        }

        require(
            (amount >= _tokenConfig.minBridgeAmount) && (amount <= _tokenConfig.maxBridgeAmount),
            "invalid bridge amount range"
        );

        if (_tokenConfig.burn) {
            TokensHelper.safeBurnFrom(token, msg.sender, amount);
        } else {
            TokensHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        }

        emit BridgeToSubmitted(token, msg.sender, recipient, amount, _tokenConfig.bridgeFee, chainId(), targetChainId);
    }

    /**
     * @notice Bridging the native token to the target chain
     * @param recipient The recipient address on the target chain.
     * @param targetChainId The target chain ID (can be found here: https://chainlist.org/).
     */
    function bridgeNativeTokensTo(address recipient, uint256 targetChainId)
        external
        payable
        nonReentrant
        needBridgeIsRunning
    {
        require(recipient != address(0), "invalid recipient");

        uint256 amount = msg.value;
        BridgeableTokensConfig storage _tokenConfig = _bridgeableTokens[
            _encodeTokenWithChainId(address(0), targetChainId)
        ];

        require(_tokenConfig.enabled, "token is not bridgeable");
        require(amount > _tokenConfig.bridgeFee, "bridge amount should be greater than fees");

        if (globalFeeStatus && _tokenConfig.bridgeFee > 0) {
            TokensHelper.safeTransferNativeTokens(feeRecipient, _tokenConfig.bridgeFee);
            amount -= _tokenConfig.bridgeFee;
        }

        require(
            (amount >= _tokenConfig.minBridgeAmount) && (amount <= _tokenConfig.maxBridgeAmount),
            "invalid bridge amount range"
        );

        emit BridgeToSubmitted(
            address(0),
            msg.sender,
            recipient,
            amount,
            _tokenConfig.bridgeFee,
            chainId(),
            targetChainId
        );
    }

    /**
     * @dev Approvers process bridge requests (to ERC20)
     * @param txHash The transaction hash of the bridge request from source chain.
     * @param sourceChainId The chain id that made the bridge request.
     * @param targetToken The address of the target token.
     * @param recipient The recipient of tokens.
     * @param amount The amount of tokens.
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
        onlyRole(BRIDGE_APPROVER_ROLE)
        needBridgeIsRunning
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
     * @param txHash The transaction hash of the bridge request from source chain.
     * @param sourceChainId The chain id that made the bridge request.
     * @param recipient The recipient of tokens.
     * @param amount The amount of tokens.
     */
    function approveBridgeToNative(
        bytes32 txHash,
        uint256 sourceChainId,
        address recipient,
        uint256 amount
    ) external nonReentrant onlyRole(BRIDGE_APPROVER_ROLE) needBridgeIsRunning checkBridgeApprovalStatus(address(0)) {
        TokensHelper.safeTransferNativeTokens(recipient, amount);
        emit BridgeToApproved(txHash, address(0), recipient, amount, sourceChainId, chainId());
    }

    /**
     * @dev Configure bridgeable tokens
     */
    function addBridgeableTokens(TokensOnChain[] memory tokensOnChain, BridgeableTokensConfig[] memory configs)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        checkArrayLength(tokensOnChain.length, configs.length)
    {
        for (uint256 i; i < tokensOnChain.length; i++) {
            _checkTokenAddress(tokensOnChain[i].token);
            if (configs[i].maxBridgeAmount == 0) {
                configs[i].maxBridgeAmount = type(uint256).max;
            }
            require(configs[i].maxBridgeAmount > configs[i].minBridgeAmount, "invalid bridge amount limit");
            _bridgeableTokens[_encodeTokenWithChainId(tokensOnChain[i].token, tokensOnChain[i].chainId)] = configs[i];
        }
    }

    /**
     * @dev Configure bridgeable tokens fees
     */
    function setBridgeFees(TokensOnChain[] memory tokensOnChain, uint256[] memory fees)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        checkArrayLength(tokensOnChain.length, fees.length)
    {
        for (uint256 i; i < tokensOnChain.length; i++) {
            _checkTokenAddress(tokensOnChain[i].token);
            _setBridgeFee(tokensOnChain[i].token, tokensOnChain[i].chainId, fees[i]);
        }
    }

    /**
     * @dev Configure approval of bridgeable tokens
     */
    function addBridgeApprovalConfig(address[] memory tokenAddresses, BridgeApprovalConfig[] memory configs)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        checkArrayLength(tokenAddresses.length, configs.length)
    {
        for (uint256 i; i < tokenAddresses.length; i++) {
            _checkTokenAddress(tokenAddresses[i]);
            bridgeApprovalConfig[tokenAddresses[i]] = configs[i];
        }
    }

    /**
     * @dev Set bridge global status
     * @param bridgeRunningStatus The new bridge running status.
     */
    function setBridgeRunningStatus(bool bridgeRunningStatus) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBridgeRunningStatus(bridgeRunningStatus);
    }

    /**
     * @dev Deposit native tokens to bridge
     */
    function depositNativeTokens() external payable {
        emit TokensDeposit(chainId(), msg.sender, msg.value);
    }

    /**
     * @dev Set a new fee recipient
     * @param newRecipient The new recipient address.
     */
    function setFeeRecipient(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeRecipient(newRecipient);
    }

    /**
     * @dev Set a new global fee status
     * @param newFeeStatus The new fee status.
     */
    function setGlobalFeeStatus(bool newFeeStatus) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalFeeStatus = newFeeStatus;
    }
}
