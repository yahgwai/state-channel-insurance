pragma solidity ^0.4.23;
/// TODO: test what happens with msg.value in callForward

contract Insurance {
    address owner;
    uint excess;
    uint freeCapital;

    // TODO: replace these with a mappint(bytes32 => struct)
    // contraining, {status, amount, expiry}
    mapping (bytes32 => uint) requests;
    mapping (bytes32 => uint) premiums;
    mapping (bytes32 => uint) accepted;
    mapping (bytes32 => uint) claimsInProgress;

    // TODO: increase this, also make it constant - needs to be measured against 'compensate'
    uint compensationExtraGas = 42000;

    // TODO: add all events
    event Deposit(address depositer, uint amount);
    event Withdraw(uint amount, uint freeCapital);
    event RequestCover(address requester, address stateChannel, address application, uint expiryTimestamp, uint coverAmount, uint premiumAmount);
    event WithdrawRequest(address requester, address stateChannel, address application, uint expiryTimestamp);
    event AcceptCover(address requester, address stateChannel, address application, uint expiryTimestamp, uint freeCapital);
    event Claim(address requester, address stateChannel, address application, uint expiryTimestamp);
    event Compensate(address requester, address stateChannel, address application, uint expiryTimestamp, uint refund, bytes callData);
    event ExpireCover(address requester, address stateChannel, address application, uint expiryTimestamp, uint amount, uint freeCapital);

    constructor(uint _excess) public {
        owner = msg.sender;
        excess = _excess;
    }

    // owner can deposit and retrive funds
    function() public payable {
        freeCapital += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint amount) public {
        require(msg.sender == owner, "Only owner can withdraw.");
        require(amount >= freeCapital, "Withdrawal amount greater than free capital.");
        msg.sender.transfer(amount);
        emit Withdraw(amount, freeCapital);
    }

    function requestCover(address stateChannel, address application, uint expiryTimestamp, uint coverAmount) public payable {
        // create a request for this user/stateChannel/application
        // TODO: can cover be requested multiple times? if so just increase the value of the request?
        // TODO: include value in this hash?
        // TODO: consider other replays
        bytes32 coverId = keccak256(abi.encodePacked(msg.sender, stateChannel, application, expiryTimestamp));
        requests[coverId] = coverAmount;
        premiums[coverId] = msg.value;
        emit RequestCover(msg.sender, stateChannel, application, expiryTimestamp, coverAmount, msg.value);
    }

    function withdrawRequest(address stateChannel, address application, uint expiryTimestamp) public {
        bytes32 coverId = keccak256(abi.encodePacked(msg.sender, stateChannel, application, expiryTimestamp));
        uint value = premiums[coverId];

        // delete the record and refund the value
        delete requests[coverId];
        delete premiums[coverId];
        msg.sender.transfer(value);
        emit WithdrawRequest(msg.sender, stateChannel, application, expiryTimestamp);
    }

    function acceptCover(address requester, address stateChannel, address application, uint expiryTimestamp) public {
        require(msg.sender == owner, "Only the owner can except cover.");
        // the insurer has verified the cover request, and has decided to accept it
        // TODO: what happends when lookup doesnt exist

        // accept it and remove the request
        bytes32 coverId = keccak256(abi.encodePacked(requester, stateChannel, application, expiryTimestamp));
        uint coverAmount = requests[coverId];
        // collect the premium
        freeCapital += premiums[coverId];
        
        // can the insurer cover this amount
        require(freeCapital >= coverAmount, "Not enough free capital to accept cover.");
        
        // remove the capital required for the cover, this can only be returned after the expiry date
        freeCapital -= coverAmount;

        // accept the cover
        accepted[coverId] = coverAmount;

        // remove the request, and premium record
        delete requests[coverId];
        delete premiums[coverId];

        emit AcceptCover(requester, stateChannel, application, expiryTimestamp, freeCapital);
    }

    // TODO: sure up this whole contract - currently we can do things like
    // TODO: claim after the cover has run out - this isnt a problem since they have their
    // TODO: cover revoked at any time - but it should still be stopped for ease of use and understanding

    // pay the excess, and set a claim
    function claim(address stateChannel, address application, uint expiryTimestamp) public payable {
        // calculate the cover to ensure that a user can only claim their own cover
        bytes32 coverId = keccak256(abi.encodePacked(msg.sender, stateChannel, application, expiryTimestamp));
        // TODO: message formatting
        require(msg.value > excess, "Excess not paid.");

        claimsInProgress[coverId] = accepted[coverId];
        delete accepted[coverId];

        emit Claim(msg.sender, stateChannel, application, expiryTimestamp);
    }


    // TODO: work out the costs in this function
    function compensate(address stateChannel, address application, uint expiryTimestamp, bytes callData) public {
        // measure gas usage
        uint startGas = gasleft();
        
        // forward the call
        application.call(callData);
        
        // does the sender have a claim in progress?
        // TODO: keep this inside or outside the gas measurement
        bytes32 coverId = keccak256((abi.encodePacked(msg.sender, stateChannel, application, expiryTimestamp)));
        uint remainingWei = claimsInProgress[coverId];

        // the amount to claim is the amount used so far + some overhead (eg. initial transaction, and final send)
        // TODO: safe math
        uint gasClaim = (startGas - gasleft()) + compensationExtraGas;
        uint weiClaim = gasClaim * tx.gasprice;
        // find the amount to refund from the claim
        uint refundWei;
        if(remainingWei > weiClaim) refundWei = weiClaim;
        else refundWei = remainingWei;

        // reduce the current claim
        claimsInProgress[coverId] -= refundWei;

        // make the refund
        msg.sender.transfer(refundWei);

        emit Compensate(msg.sender, stateChannel, application, expiryTimestamp, refundWei, callData);
    }

    // anybody can expire a cover
    function expireCover(address requester, address stateChannel, address application, uint expiryTimestamp) public {
        bytes32 coverId = keccak256((abi.encodePacked(requester, stateChannel, application, expiryTimestamp)));
        require(expiryTimestamp > now, "Cover has not expired.");

        // TODO: safe math
        uint amount = accepted[coverId] + claimsInProgress[coverId];
        delete accepted[coverId];
        delete claimsInProgress[coverId];
        
        freeCapital += amount;

        emit ExpireCover(requester, stateChannel, application, expiryTimestamp, amount, freeCapital);
    }
}