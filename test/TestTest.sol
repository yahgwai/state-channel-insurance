pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Test.sol";

contract TestTest {
    function testA() public {
        Test test = Test(DeployedAddresses.Test());

        uint expected = 5;

        Assert.equal(test.a(), expected, "a should initially equal 5");
    }

    function testACall() public {
        Test test = Test(DeployedAddresses.Test());

        Face face = Face(test.face());
        uint x = face.x(1);
        Assert.equal(face.b(), 6, "b should initially equal 6");
        Assert.equal(x, 7, "x should initially equal 7");
    }

    function testACallCall() public {
        Test test = Test(DeployedAddresses.Test());

        bool callThrough = test.callThrough();

        Assert.equal(callThrough, true, "call through should equal true");
    }

    // function testACall2() public {
    //     Test test = Test(DeployedAddresses.Test());

    //     uint256 callThrough = test.callThrough2();

    //     uint256 afterVal = test.face().b();

    //     Assert.equal(afterVal, 7, "after val should equal 7");
    // }

    function testCallForward() public {
        Test test = Test(DeployedAddresses.Test());

        // bytes faceOff = bytes(4)

        // 0xa56dfe4a

        test.callForward();


        ///uint256 afterVal = test.face().b();

        // Assert.equal(afterVal, 16, "after val should equal 7");
        Assert.equal(false, true, "after val should equal 7");
    }
}