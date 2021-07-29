// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import '../interfaces/IKswapFactory.sol';
import '../libraries/SafeMath.sol';
import './KswapPair.sol';

contract KswapFactory is IKswapFactory {
    using SafeMathKswap for uint256;

    address public override feeTo;
    address public override feeToSetter;
    uint256 public override feeToRate;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(KswapPair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'Kswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Kswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Kswap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(KswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        KswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'KswapFactory: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'KswapFactory: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setFeeToRate(uint256 _rate) external override {
        require(msg.sender == feeToSetter, 'KswapFactory: FORBIDDEN');
        require(_rate > 0, 'KswapFactory: FEE_TO_RATE_OVERFLOW');
        feeToRate = _rate.sub(1);
    }
}
