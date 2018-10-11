pragma solidity ^0.4.24;

contract Test {
    uint public a;
    Face public face;
    constructor(uint _a) public {
        a = _a;
        face = new Face(_a);
    }

    event Data0(address datum);
    function callThrough() public returns(bool) {
        // emit Data0(address(this));
        //bytes4 off = bytes4(keccak256("x(uint256)"));
        bool result = address(face).delegatecall(bytes4(keccak256("x(uint256)")), 1);
        return result;
    }

    function callForward() public returns(bool) {
        bytes memory data = abi.encodePacked(bytes4(keccak256("y(uint256)")), uint256(4));


        bool result = address(face).call(data);
        return result;
    }



    function callThrough2() public returns (uint256 response) {
        address dest = address(face);
        bytes4 callData4 = bytes4(keccak256("y()"));
        //uint gas = gasleft();

        assembly {
            let returnSize := 32
            // calldatacopy(0xff, 0, calldatasize)
            let off := delegatecall(gas, dest, 4, 4, 0, 0)
            //switch _retval case 0 { revert(0,0) } default { return(0, returnSize) }
        }
    }

    event Data2(bool success);

    function guessWork() public {
        bool success = delegatedFwd(address(face), "0xa56dfe4a");
        emit Data2(success);
    }


    event Data4(bytes4 data);
    function delegatedFwd(address _dst, bytes _calldata) public returns(bool b) {
        bytes4 callData4 = bytes4(keccak256("y(uint256)"));
        emit Data4(callData4);

        bytes memory jar = bytes(abi.encodePacked(callData4, uint256(10)));

        assembly {
            b := call(sub(gas, 10000), _dst, 0, add(jar, 0x20), mload(jar), 0, 0)
        }
    }
}

contract Face {
    uint public b;
    constructor(uint _b) public {
        b = _b + 1;
    }

    event Data1(address datum);

    event Hit(uint a);
    event Hitter(uint a);

    function x(uint a) public returns(uint) {
        // emit Data1(address(this))
        emit Hit(0);
        return a + b;
    }

    function y(uint256 a) public {
        // emit Data1(address(this))
        emit Hit(1);
        emit Hitter(a);
        b = b + a; 
    }

    function() public payable {
        emit Hit(2);
        b = b + 2;
    }
}