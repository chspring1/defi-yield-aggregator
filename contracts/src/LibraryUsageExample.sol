// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 定义一个库
library CalculatorLibrary {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    
    function multiply(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    
    function percentage(uint256 amount, uint256 percent) internal pure returns (uint256) {
        return (amount * percent) / 100;
    }
}

// 合约1：直接调用库函数
contract DirectCallExample {
    function calculate(uint256 a, uint256 b) external pure returns (uint256) {
        // 直接调用库函数
        return CalculatorLibrary.add(a, b);
    }
    
    function calculateFee(uint256 amount) external pure returns (uint256) {
        // 直接调用
        return CalculatorLibrary.percentage(amount, 5); // 5%
    }
}

// 合约2：使用 using for 语法
contract UsingForExample {
    using CalculatorLibrary for uint256;
    
    function calculate(uint256 a, uint256 b) external pure returns (uint256) {
        // 使用 using for 语法，就像 a 有 add 方法一样
        return a.add(b);
    }
    
    function calculateFee(uint256 amount) external pure returns (uint256) {
        // 看起来像是 amount 的方法
        return amount.percentage(5);
    }
}

// 合约3：混合使用
contract MixedExample {
    using CalculatorLibrary for uint256;
    
    function complexCalculation(uint256 base, uint256 multiplier, uint256 feePercent) 
        external 
        pure 
        returns (uint256 result, uint256 fee) 
    {
        // 混合使用不同调用方式
        result = base.multiply(multiplier); // using for 方式
        fee = CalculatorLibrary.percentage(result, feePercent); // 直接调用方式
    }
}

// ❌ 错误示例：尝试继承库
// contract WrongExample is CalculatorLibrary { // 这会编译错误！
//     // ...
// }

// ❌ 错误示例：尝试实例化库
// contract AnotherWrongExample {
//     function wrong() external {
//         CalculatorLibrary calc = new CalculatorLibrary(); // 编译错误！
//     }
// }