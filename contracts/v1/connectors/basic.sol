pragma solidity ^0.7.0;

/**
 * @title ConnectBasic.
 * @dev Connector to deposit/withdraw assets.
 */

interface ERC20Interface {
    function allowance(address, address) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external;

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

interface AccountInterface {
    function isAuth(address _user) external view returns (bool);
}

interface MemoryInterface {
    function getUint(uint256 _id) external returns (uint256 _num);

    function setUint(uint256 _id, uint256 _val) external;
}

interface EventInterface {
    function emitEvent(
        uint256 _connectorType,
        uint256 _connectorID,
        bytes32 _eventCode,
        bytes calldata _eventData
    ) external;
}

contract Memory {
    /**
     * @dev InstaMemory Address.
     */
    address public immutable instaMemoryAddress;

    constructor(address _instaMemoryAddress) {
        instaMemoryAddress = _instaMemoryAddress;
    }

    /**
     * @dev Get Stored Uint Value From InstaMemory.
     * @param getId Storage ID.
     * @param val if any value.
     */
    function getUint(uint256 getId, uint256 val)
        internal
        returns (uint256 returnVal)
    {
        returnVal = getId == 0
            ? val
            : MemoryInterface(instaMemoryAddress).getUint(getId);
    }

    /**
     * @dev Store Uint Value In InstaMemory.
     * @param setId Storage ID.
     * @param val Value To store.
     */
    function setUint(uint256 setId, uint256 val) internal {
        if (setId != 0) MemoryInterface(instaMemoryAddress).setUint(setId, val);
    }

    /**
     * @dev Connector ID and Type.
     */
    function connectorID() public pure returns (uint256 _type, uint256 _id) {
        (_type, _id) = (1, 2);
    }
}

contract BasicResolver is Memory {
    event LogDeposit(
        address indexed erc20,
        uint256 tokenAmt,
        uint256 getId,
        uint256 setId
    );
    event LogWithdraw(
        address indexed erc20,
        uint256 tokenAmt,
        address indexed to,
        uint256 getId,
        uint256 setId
    );

    /**
     * @dev InstaEvent Address.
     */
    address public immutable instaEventAddress;

    constructor(address _instaEventAddress, address _instaMemoryAddress)
        Memory(_instaMemoryAddress)
    {
        instaEventAddress = _instaEventAddress;
    }

    /**
     * @dev ETH Address.
     */
    function getEthAddr() public pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev Deposit Assets To Smart Account.
     * @param erc20 Token Address.
     * @param tokenAmt Token Amount.
     * @param getId Get Storage ID.
     * @param setId Set Storage ID.
     */
    function deposit(
        address erc20,
        uint256 tokenAmt,
        uint256 getId,
        uint256 setId
    ) public payable {
        uint256 amt = getUint(getId, tokenAmt);
        if (erc20 != getEthAddr()) {
            ERC20Interface token = ERC20Interface(erc20);
            amt = amt == uint256(-1) ? token.balanceOf(msg.sender) : amt;
            token.transferFrom(msg.sender, address(this), amt);
        } else {
            require(
                msg.value == amt || amt == uint256(-1),
                "invalid-ether-amount"
            );
            amt = msg.value;
        }
        setUint(setId, amt);

        emit LogDeposit(erc20, amt, getId, setId);

        bytes32 _eventCode = keccak256(
            "LogDeposit(address,uint256,uint256,uint256)"
        );
        bytes memory _eventParam = abi.encode(erc20, amt, getId, setId);
        (uint256 _type, uint256 _id) = connectorID();
        EventInterface(instaEventAddress).emitEvent(
            _type,
            _id,
            _eventCode,
            _eventParam
        );
    }

    /**
     * @dev Withdraw Assets To Smart Account.
     * @param erc20 Token Address.
     * @param tokenAmt Token Amount.
     * @param to Withdraw token address.
     * @param getId Get Storage ID.
     * @param setId Set Storage ID.
     */
    function withdraw(
        address erc20,
        uint256 tokenAmt,
        address payable to,
        uint256 getId,
        uint256 setId
    ) public payable {
        require(
            AccountInterface(address(this)).isAuth(to),
            "invalid-to-address"
        );
        uint256 amt = getUint(getId, tokenAmt);
        if (erc20 == getEthAddr()) {
            amt = amt == uint256(-1) ? address(this).balance : amt;
            to.transfer(amt);
        } else {
            ERC20Interface token = ERC20Interface(erc20);
            amt = amt == uint256(-1) ? token.balanceOf(address(this)) : amt;
            token.transfer(to, amt);
        }
        setUint(setId, amt);

        emit LogWithdraw(erc20, amt, to, getId, setId);

        bytes32 _eventCode = keccak256(
            "LogWithdraw(address,uint256,address,uint256,uint256)"
        );
        bytes memory _eventParam = abi.encode(erc20, amt, to, getId, setId);
        (uint256 _type, uint256 _id) = connectorID();
        EventInterface(instaEventAddress).emitEvent(
            _type,
            _id,
            _eventCode,
            _eventParam
        );
    }
}

contract ConnectBasic is BasicResolver {
    constructor(address _instaEventAddress, address _instaMemoryAddress)
        public
        BasicResolver(_instaEventAddress, _instaMemoryAddress)
    {}

    string public constant name = "Basic-v1";
}
