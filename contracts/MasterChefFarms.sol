pragma solidity 0.6.12;
//SPDX-License-Identifier: MIT
import "hardhat/console.sol";
import "./libs/ERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IMasterChefV2.sol";
import "./interfaces/IUniswapV2Factory.sol";

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}


library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

library UniswapV2Library {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        if (factory == 0xE7Fb3e833eFE5F9c441105EB65Ef8b261266423B){
            pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'f187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3' // init code hash
            ))));
        }else{
            pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
        }
        
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

contract MasterChefFarms {
    mapping(uint256 => address) public routerAddress;
    mapping(uint256 => address) public factoryAddress;
    mapping(uint256 => address) public masterchefAddress;
    mapping(address => mapping(address => uint)) public userStakingAmounts;
    uint256 public lastFeePercantege;
    address public owner;
    address public platformOwner;

    constructor(
        uint256[] memory _protocolIds,
        address[] memory _routers,
        address[] memory _factories,
        address[] memory _chefs,
        address _platformOwner
    ) public {
        require(
            _protocolIds.length == _routers.length &&
                _protocolIds.length == _factories.length &&
                _protocolIds.length == _chefs.length,
            "Parameters not equal length"
        );

        for (uint256 i; i < _protocolIds.length; ++i) {
            routerAddress[_protocolIds[i]] = _routers[i];
            factoryAddress[_protocolIds[i]] = _factories[i];
            masterchefAddress[_protocolIds[i]] = _chefs[i];
        }
        owner = msg.sender;
        platformOwner = _platformOwner;
    }

    function depositFunds(address _tokenAddress, uint256 _amount)
        external
        onlyOwner
    {
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawFunds(address _tokenAddress, uint256 _amount)
        external
        onlyOwner
    {
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    function setPlatformOwner(address _platformOnwer) external onlyPlatform {
        platformOwner = _platformOnwer;
    }

    function getAmountsOut(
        uint256 _protocolId,
        uint256 _amountIn,
        address[] calldata _path
    ) external view returns (uint256[] memory amounts) {
        amounts = IUniswapV2Router02(routerAddress[_protocolId]).getAmountsOut(
            _amountIn,
            _path
        );
        return amounts;
    }

    function swapTokenforToken(
        uint256 _protocolId,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address to
    ) external {
        IERC20(_path[0]).approve(routerAddress[_protocolId], 1e18);
        IUniswapV2Router02(routerAddress[_protocolId]).swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                _path,
                to,
                block.timestamp + 600
            );
    }

    function swapETHforToken(
        uint256 _protocolId,
        uint256 _amountOutMin,
        address[] calldata _path,
        address to
    ) external payable {
        IERC20(_path[0]).approve(routerAddress[_protocolId], _amountOutMin);
        IUniswapV2Router02(routerAddress[_protocolId]).swapETHForExactTokens{value: msg.value}(
            _amountOutMin,
            _path,
            to,
            block.timestamp + 3600
        );
    }

    function addLiquidity(
        uint256 _protocolId,
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address to
    ) external onlyPlatform {
        IUniswapV2Router02(routerAddress[_protocolId]).addLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin,
            to,
            block.timestamp + 600
        );
    }

    function addLiquidityETH(
        uint256 _protocolId,
        address _token,
        uint256 _amountTokenDesired,
        uint256 _amountTokenMin,
        uint256 _amountETHMin
    ) external onlyPlatform {
        IUniswapV2Router02(routerAddress[_protocolId]).addLiquidityETH(
            _token,
            _amountTokenDesired,
            _amountTokenMin,
            _amountETHMin,
            address(this),
            block.timestamp + 600
        );
    }

    function removeLiquidity(
        uint256 _protocolId,
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external onlyPlatform {
        IUniswapV2Router02(routerAddress[_protocolId]).removeLiquidity(
            _tokenA,
            _tokenB,
            _liquidity,
            _amountAMin,
            _amountBMin,
            address(this),
            block.timestamp + 600
        );
    }

    function removeLiquidityETH(
        uint256 _protocolId,
        address _token,
        uint256 _liquidity,
        uint256 _amountTokenMin,
        uint256 _amountETHMin
    ) external onlyPlatform {
        IUniswapV2Router02(routerAddress[_protocolId]).removeLiquidityETH(
            _token,
            _liquidity,
            _amountTokenMin,
            _amountETHMin,
            address(this),
            block.timestamp + 600
        );
    }

    
    function getWETH(uint256 _protocolId) external view returns (address weth) {
        return IUniswapV2Router02(routerAddress[_protocolId]).WETH();
    }
    function getPair(uint256 _protocolId, address tokenA, address tokenB) external view returns (address pairAddress) {
        return IUniswapV2Factory(factoryAddress[_protocolId]).getPair(tokenA, tokenB);
    }
    function getChefAddress(uint256 _protocolId) external view returns (address chefAddress) {
        return masterchefAddress[_protocolId];
    }



    function safeTransfer(
        uint256 _protocolId,
        address token,
        uint amount
    ) external {
        console.log("Safe Transfer:", amount);
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        ERC20(token).approve(address(IUniswapV2Router02(routerAddress[_protocolId])), amount);
    }

    function getAmount(
        uint256 _protocolId,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) public view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(IUniswapV2Router02(routerAddress[_protocolId]).factory(), tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'Chef Farms Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'Chef Farms Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    //get user's staking amount
    function getUserStakingAmount(address stakingAddress, address userAddress) public view returns (uint){
        return userStakingAmounts[stakingAddress][userAddress];
    }
    //set user's staking amount
    function getUserStakingAmount(address stakingAddress, address userAddress, uint amount) public {
        userStakingAmounts[stakingAddress][userAddress] = userStakingAmounts[stakingAddress][userAddress] + amount;
    }
    function stake(uint256 protocolId, uint256 amount) external {
        IMasterChefV2(masterchefAddress[protocolId]).stake(amount);
    }
    //Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyPlatform() {
        require(msg.sender == platformOwner);
        _;
    }

    //Events
    event DepositedToFarm(uint256 indexed _protocolID, uint256 indexed _farmID);
    event withdrawnFromFarm(
        uint256 indexed _protocolID,
        uint256 indexed _farmID
    );
}
