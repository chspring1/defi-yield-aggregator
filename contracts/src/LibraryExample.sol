// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathLibrary
 * @dev 数学运算库示例
 */
library MathLibrary {
    /**
     * @dev 安全加法，防止溢出
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "MathLibrary: addition overflow");
        return c;
    }
    
    /**
     * @dev 计算百分比
     */
    function percentage(uint256 amount, uint256 percent) internal pure returns (uint256) {
        return (amount * percent) / 100;
    }
    
    /**
     * @dev 私有函数示例
     */
    function _validateInput(uint256 value) private pure returns (bool) {
        return value > 0;
    }
}

/**
 * @title StringLibrary  
 * @dev 字符串处理库示例
 */
library StringLibrary {
    /**
     * @dev 将 uint256 转换为字符串
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    /**
     * @dev 连接两个字符串
     */
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}

/**
 * @title LibraryExample
 * @dev 演示如何使用库的合约
 */
contract LibraryExample {
    // 使用 using for 语法
    using MathLibrary for uint256;
    using StringLibrary for uint256;
    using StringLibrary for string;
    
    uint256 public totalValue;
    string public message;
    
    /**
     * @dev 直接调用库函数
     */
    function directCall(uint256 a, uint256 b) external pure returns (uint256) {
        return MathLibrary.safeAdd(a, b);
    }
    
    /**
     * @dev 使用 using for 语法调用
     */
    function usingForCall(uint256 a, uint256 b) external {
        totalValue = a.safeAdd(b); // 等价于 MathLibrary.safeAdd(a, b)
    }
    
    /**
     * @dev 链式调用示例
     */
    function chainedCall(uint256 value) external {
        // 将数字转换为字符串，然后连接
        string memory valueStr = value.toString();
        // 使用 abi.encodePacked 连接字符串
        message = string(abi.encodePacked("Value: ", valueStr));
    }
    
    /**
     * @dev 计算费用示例
     */
    function calculateFee(uint256 amount, uint256 feePercent) external pure returns (uint256) {
        return MathLibrary.percentage(amount, feePercent);
    }
}