pragma solidity =0.6.6;

import '@uShibaProject/uShiba-swap-core/contracts/interfaces/IuShibaSwapFactory.sol';
import '@uShibaProject/uShiba-swap-lib/contracts/utils/TransferHelper.sol';

import './interfaces/IuShibaSwapRouter.sol';
import './libraries/uShibaSwapLibrary.sol';
import '@uShibaProject/uShiba-swap-lib/contracts/math/SafeMath.sol';
import '@uShibaProject/uShiba-swap-lib/contracts/token/BEP20/IBEP20.sol';
import './interfaces/IWBNB.sol';

contract uShibaSwapRouter is IuShibaSwapRouter {
    using SafeMath for uint256;
    address public immutable override factory;
    address public immutable override WBNB;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'uShibaSwapRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WBNB) public {
        factory = _factory;
        WBNB = _WBNB;
    }

    receive() external payable {
        assert(msg.sender == WBNB); // only accept BNB via fallback from the WBNB contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IuShibaSwapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IuShibaSwapFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = uShibaSwapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = uShibaSwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'uShibaSwapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = uShibaSwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'uShibaSwapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = uShibaSwapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IuShibaSwapPair(pair).mint(to);
    }

    function addLiquidityBNB(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountBNB,
            uint256 liquidity
        )
    {
        (amountToken, amountBNB) = _addLiquidity(
            token,
            WBNB,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountBNBMin
        );
        address pair = uShibaSwapLibrary.pairFor(factory, token, WBNB);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWBNB(WBNB).deposit{value: amountBNB}();
        assert(IWBNB(WBNB).transfer(pair, amountBNB));
        liquidity = IuShibaSwapPair(pair).mint(to);
        // refund dust bnb, if any
        if (msg.value > amountBNB) TransferHelper.safeTransferBNB(msg.sender, msg.value - amountBNB);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = uShibaSwapLibrary.pairFor(factory, tokenA, tokenB);
        IuShibaSwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IuShibaSwapPair(pair).burn(to);
        (address token0, ) = uShibaSwapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'uShibaSwapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'uShibaSwapRouter: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityBNB(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountBNB) {
        (amountToken, amountBNB) = removeLiquidity(
            token,
            WBNB,
            liquidity,
            amountTokenMin,
            amountBNBMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWBNB(WBNB).withdraw(amountBNB);
        TransferHelper.safeTransferBNB(to, amountBNB);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = uShibaSwapLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IuShibaSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityBNBWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountBNB) {
        address pair = uShibaSwapLibrary.pairFor(factory, token, WBNB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IuShibaSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountBNB) = removeLiquidityBNB(token, liquidity, amountTokenMin, amountBNBMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityBNBSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountBNB) {
        (, amountBNB) = removeLiquidity(token, WBNB, liquidity, amountTokenMin, amountBNBMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IBEP20(token).balanceOf(address(this)));
        IWBNB(WBNB).withdraw(amountBNB);
        TransferHelper.safeTransferBNB(to, amountBNB);
    }

    function removeLiquidityBNBWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountBNB) {
        address pair = uShibaSwapLibrary.pairFor(factory, token, WBNB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IuShibaSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountBNB = removeLiquidityBNBSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountBNBMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = uShibaSwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? uShibaSwapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IuShibaSwapPair(uShibaSwapLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = uShibaSwapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'uShibaSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            uShibaSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = uShibaSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'uShibaSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            uShibaSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactBNBForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WBNB, 'uShibaSwapRouter: INVALID_PATH');
        amounts = uShibaSwapLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'uShibaSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWBNB(WBNB).deposit{value: amounts[0]}();
        assert(IWBNB(WBNB).transfer(uShibaSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactBNB(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WBNB, 'uShibaSwapRouter: INVALID_PATH');
        amounts = uShibaSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'uShibaSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            uShibaSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWBNB(WBNB).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferBNB(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForBNB(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WBNB, 'uShibaSwapRouter: INVALID_PATH');
        amounts = uShibaSwapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'uShibaSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            uShibaSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWBNB(WBNB).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferBNB(to, amounts[amounts.length - 1]);
    }

    function swapBNBForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WBNB, 'uShibaSwapRouter: INVALID_PATH');
        amounts = uShibaSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'uShibaSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        IWBNB(WBNB).deposit{value: amounts[0]}();
        assert(IWBNB(WBNB).transfer(uShibaSwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust bnb, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferBNB(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = uShibaSwapLibrary.sortTokens(input, output);
            IuShibaSwapPair pair = IuShibaSwapPair(uShibaSwapLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IBEP20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = uShibaSwapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? uShibaSwapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to);
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            uShibaSwapLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'uShibaSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactBNBForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) {
        require(path[0] == WBNB, 'uShibaSwapRouter: INVALID_PATH');
        uint256 amountIn = msg.value;
        IWBNB(WBNB).deposit{value: amountIn}();
        assert(IWBNB(WBNB).transfer(uShibaSwapLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'uShibaSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForBNBSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WBNB, 'uShibaSwapRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            uShibaSwapLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IBEP20(WBNB).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'uShibaSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWBNB(WBNB).withdraw(amountOut);
        TransferHelper.safeTransferBNB(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public virtual override pure returns (uint256 amountB) {
        return uShibaSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public virtual override pure returns (uint256 amountOut) {
        return uShibaSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public virtual override pure returns (uint256 amountIn) {
        return uShibaSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        virtual
        override
        view
        returns (uint256[] memory amounts)
    {
        return uShibaSwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        virtual
        override
        view
        returns (uint256[] memory amounts)
    {
        return uShibaSwapLibrary.getAmountsIn(factory, amountOut, path);
    }
}
