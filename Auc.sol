// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Auctions {
    
    address public Owner;
    MyToken token;
    // address token;
    
    constructor(address token_add) {
        Owner = msg.sender;
        token = MyToken(token_add);
        // token = ERC20(address(this));
    }

    struct Account {
        uint ethBalance;
        mapping(address=>uint) tokenBalance;
        bool exists;
        Offer checkoffer;
    }

    struct Offer {
        address seller;
        address tokenAddress;
        uint tokenAmount;
        uint tokenPrice;
        uint time;
    }

    struct Bid {
        address token;
        uint amount;
        uint maxPrice;
        bytes32 BidHash;
    }

    struct ShowBid{
        bytes32 BidHash;
    }

    uint Offer_Id = 1;

    mapping(address=>Account) public Acc;
    mapping(uint=>Offer) public Acc_Offer;
    mapping(bytes32=>Bid) private blindedBids;
    mapping(address=>ShowBid) public showBid;

    address [] public Accounts;
    Offer[] public Offers;

    uint[] public Store_Offer_Id;


    event AccountCreated(address indexed account);
    event Deposit(address indexed account, address indexed token, uint256 amount);
    event Withdrawal(address indexed token, address indexed account, uint256 amount);
    event OfferCreated(uint256 indexed id, address indexed seller, address indexed tokenAddress, uint256 tokenAmount, uint256 price);
    event OfferPriceReduced(uint indexed id, uint tokenAmount);

    event OfferWithdrawn(uint256 indexed id);
    event BidCreated(address indexed buyer, address indexed tokenAddress, uint256 tokenAmount, uint256 maxPrice);
    event BidOpened(uint256 indexed id);
    event BidWithdrawn(uint256 indexed id);
    event Matched(uint256 indexed offerId, uint256 indexed bidId, uint256 tokenAmount, uint256 price);


    function Mint_Token(address _add,uint _amount) public {
        require(msg.sender == Owner,"You are not the owner of the contract");
        token.mint(_add , _amount);
    }

    function Created_Account() public {
        require(Acc[msg.sender].exists != true,"Account has already exists");
        Accounts.push(msg.sender);
        Acc[msg.sender].exists = true;
        emit AccountCreated(msg.sender);
        // uint balance = balanceOf(msg.sender);
        // require(balance > 0,"Must have non-zero token balance");
        // Acc[msg.sender].tokenBalance[_contract] = balance;
        // balanceOf(msg.sender);
    }

    function depositETH() public payable {
        require(Acc[msg.sender].exists == true,"First create your account");
        require(msg.value > 0,"Must provide non-zero ETH amount");
        Acc[msg.sender].ethBalance += msg.value;

        emit Deposit(msg.sender,address(this),msg.value);
    }

    function depositToken(address _contract,uint amount) public {
        require(Acc[msg.sender].exists == true, "First create your account");
        require(amount > 0,"Must provide non-zero token amount");
        // ERC20 token = ERC20(_contract);
        token.transferFrom(msg.sender,_contract,amount);
        Acc[msg.sender].tokenBalance[_contract] +=amount;

        emit Deposit(msg.sender,_contract,amount);
        // require(_transfer(address(this),amount));
    }

    function withdrawETH(uint amount) public {
        require(amount > 0, "Must provide non-zero ETH amount");
        require(Acc[msg.sender].ethBalance >= amount,"Insufficient ETH balance");
        Acc[msg.sender].ethBalance -= amount;
        payable(msg.sender).transfer(amount);

        emit Withdrawal(address(this),msg.sender,amount);
        // require(buyerAccounts[msg.sender].ethBalance >= amount, "Insufficient ETH balance");
    }

    function withdrawToken(address _contract,uint amount) public {
        require(amount > 0, "Must provide non-zero token amount");
        require(Acc[msg.sender].tokenBalance[_contract] >= amount, "Insufficient token balance");
        token.transfer(msg.sender,amount);
        Acc[msg.sender].tokenBalance[_contract] -= amount;

        emit Withdrawal(_contract,msg.sender,amount);
    }

    function Check_balance(address _token) view public returns(uint) {
        return token.balanceOf(_token);
    }

    function createOffer (address _tokenContract,uint _tokenAmount,uint _price) public {
        // require(Acc[msg.sender].tokenBalance[_tokenContract] >= _tokenAmount ,"Incficient")
        require(_tokenAmount > 0, "Must provide non-zero token amount");
        require(_price > 0 , "Must provide non-zero price");
        require(Acc[msg.sender].tokenBalance[_tokenContract] >= _tokenAmount , "Insufficient token balance");
        Acc_Offer[Offer_Id] = Offer({seller : msg.sender,tokenAddress:_tokenContract,tokenAmount:_tokenAmount,tokenPrice:_price,time:block.timestamp});
        Store_Offer_Id.push(Offer_Id);
        emit OfferCreated(Offer_Id,msg.sender,_tokenContract,_tokenAmount,_price);
        Offer_Id++;
        // Offers.push(OfferId,msg.sender,_tokenContract,_tokenAmount,_price);
        // Acc[msg.sender].checkoffer
    }

    function Reduce (uint _id,uint _newTokenprice) public {
        require(Acc_Offer[_id].tokenPrice > _newTokenprice , "New price must be lower than existing offer price.");
        Acc_Offer[_id].tokenPrice = _newTokenprice;
        emit OfferPriceReduced(_id,_newTokenprice);
    }

    function withdrawOffer (uint _Id) public {
        require(msg.sender == Acc_Offer[_Id].seller,"First create your offer");
        delete Acc_Offer[_Id];
        emit OfferWithdrawn(_Id);
    }

    function createBlindedBid( address _token,uint256 _amount,uint256 _maxPrice) public {
        bytes32 bidId = keccak256(abi.encodePacked(msg.sender,_token,_amount,_maxPrice));
        blindedBids[bidId] = Bid(_token,_amount,_maxPrice,bidId);
        showBid[msg.sender].BidHash = bidId;
        emit BidCreated(msg.sender,_token,_amount,_maxPrice);
        // event BidCreated(uint256 indexed id, bytes32 hash, address indexed buyer, address indexed tokenAddress, uint256 tokenAmount, uint256 maxPrice);
    }

    function showBidAddress () view public returns(bytes32) {
        return showBid[msg.sender].BidHash;
    }


    function MatchBid (bytes32 _h,address _tokenAddress) public payable {
        for(uint i=1;i<=Store_Offer_Id.length;i++){
            require(Acc_Offer[i].tokenPrice == blindedBids[_h].maxPrice, "Not Match Any Offer");
            uint Pay_amount = blindedBids[_h].maxPrice * blindedBids[_h].amount;
            uint Token = blindedBids[_h].amount;

            address receiver = msg.sender;
            address Eth_receiver = Acc_Offer[i].seller;
            
            Acc[Eth_receiver].tokenBalance[_tokenAddress] -= Token;
            Acc[receiver].tokenBalance[_tokenAddress] += Token;

            Acc[receiver].ethBalance -= Pay_amount;
            Acc[Eth_receiver].ethBalance += Pay_amount;



            // token.transfer(receiver,Token);
            // payable(Eth_receiver).transfer(Pay_amount);

            // Acc_Offer[i].tokenAmount -= Token;
            // uint bal =  token.balanceOf(msg.sender);
            // bal += Token;
        }
    }
}
