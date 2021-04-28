pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IAgERC721.sol";
import './base/BaseAuction.sol';
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title fixed auction
/// @author yzbbanban
/// @notice buy token
/// @dev 
contract FixedAuction is BaseAuction, Pausable, ReentrancyGuard{
    event Auction(uint256 indexed _auctionId, address _token, 
                    uint256 _tokenId, address _seller, 
                    uint256 _openingBid, uint256 _fixedPrice,uint32 _auctionStatus);
    event ReAuction(uint256 indexed _auctionId,
                    uint256 _openingBid, uint256 _fixedPrice,uint32 _auctionStatus);
    event LastParam(uint256 _limitTime, uint256 _extendTime, uint256 _reverseTime);
    event Bid(uint256 indexed _auctionId, address _bidder,
                uint256 _bidPrice, uint256 _bidCount,uint256 _startTime, uint256 _expirationTime,uint32 _auctionStatus);
    event Selling(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);
    event Reverse(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);
    event Fixed(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);
    event Cancel(uint256 indexed _auctionId, address _seller,uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);

    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;
    using SafeMath for uint256;

    mapping(uint256 => BidInfo) public bidInfos;
    uint256 public limitTime = 1 days;
    uint256 public extendTime = 15 minutes;
    uint256 public reverseTime = 5 days;
    
    constructor(IAgERC721 _artGee, address _platform) public{
        artGee = _artGee;
        platform = _platform;
    }

    struct BidInfo{
        address token;
        uint256 tokenId;
        address seller;
        address bidder;//change
        uint256 openingBid;
        uint256 fixedPrice;
        uint256 bidPrice;//change
        uint256 bidCount;//change
        uint256 startTime;
        uint32 auctionStatus;// 0 init; 1 bid; 2 bidder reverse;3 seller finish; 4 bidder finish 5 seller cancel
        uint256 expirationTime;//change
    }

    function setReverseTime(uint256 _limitTime,uint256 _extendTime, uint256 _reverseTime) public onlyOwner(){
        emit LastParam(limitTime, extendTime, reverseTime);
        if(_limitTime != 0){
            limitTime = _limitTime;
        }
        if(_extendTime != 0){
            extendTime = _extendTime;
        }
        if(_reverseTime != 0){
            reverseTime = _reverseTime;
        }
    }

    function auction(address _token, uint256 _tokenId, 
                    uint256 _openingBid,
                    uint256 _fixedPrice) public nonReentrant whenNotPaused{
        require(_openingBid < _fixedPrice,"Opening bid price must lower than fixedPrice");
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();
        BidInfo storage bidInfo = bidInfos[auctionId];
        bidInfo.token = _token;
        bidInfo.tokenId = _tokenId;
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.fixedPrice = _fixedPrice;
         _initAuction(bidInfo);
        //add tokenId
        IERC721 ierc721 = IERC721(_token);
        ierc721.safeTransferFrom(msg.sender, address(this), _tokenId);
        // add my auction
        _addMyAuction(msg.sender,auctionId);
        artList.push(auctionId);
        emit Auction(auctionId,_token, _tokenId, msg.sender, _openingBid,_fixedPrice, 0);
    }

    function reAuction(uint256 _auctionId, uint256 _openingBid, 
                    uint256 _fixedPrice) public nonReentrant whenNotPaused{
        require(_openingBid < _fixedPrice,"Opening bid price must lower than fixedPrice");
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        uint32 nowStatus = bidInfo.auctionStatus;
        require(nowStatus != 5,"Seller has been canceled");
        require(nowStatus != 3 || nowStatus != 4,"Auction success");
        //must wait for auction over
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        //bidder has already reverse
        if(nowStatus == 1){
            require(block.timestamp > bidInfo.expirationTime, "Auction not over");
            //sende coin to bidder
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
            //remove bidder's auctionId
            _removeMyAuction(bidInfo.bidder, _auctionId);
        }
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.fixedPrice = _fixedPrice;
        _initAuction(bidInfo);
        emit ReAuction(_auctionId, _openingBid, _fixedPrice, 0);
    }

    function bid(uint256 _auctionId) payable public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(block.timestamp >= bidInfo.startTime,"Auction not start");
        //now time > expiration time then auction over
        require(bidInfo.auctionStatus == 0 || bidInfo.auctionStatus == 1, "Not on auction");
        require(msg.sender != bidInfo.seller, "Seller can not bid");
        require(msg.sender != bidInfo.bidder, "Bidder can not repeat bid");
        uint256 t = block.timestamp;
        uint256 nowBidPrice = msg.value;
        //transfer to last bidder
        if(bidInfo.bidCount != 0){
            require(block.timestamp <= bidInfo.expirationTime, "Auction over");
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
            require(nowBidPrice > bidInfo.bidPrice, "Value error");
            // expiration time - (startTime + 1day) => update expiration
            if(bidInfo.expirationTime.sub(block.timestamp) <= extendTime){
                bidInfo.expirationTime = block.timestamp.add(extendTime);
            }
        }else{
            require(nowBidPrice >= bidInfo.openingBid, "Value error");
            bidInfo.startTime = t;
            //1 day later
            bidInfo.expirationTime = t.add(limitTime);
        }
        require(msg.value < bidInfo.fixedPrice, "Over fixed price");
        //update price
        bidInfo.bidPrice = nowBidPrice;
        
        // add bidder auction id and remove seller auction id
        if(bidInfo.bidder != address(0)){
            _removeMyAuction(bidInfo.bidder, _auctionId);
        }
        _addMyAuction(msg.sender,_auctionId);
        //reset bidder
        bidInfo.bidder = msg.sender;
        //add bid count
        bidInfo.auctionStatus = 1;
        bidInfo.bidCount = bidInfo.bidCount.add(1);
        emit Bid(_auctionId, msg.sender, nowBidPrice, bidInfo.bidCount,t,bidInfo.expirationTime, 1);
    }

    function getCurrentPrice(uint256 _auctionId) view public returns(uint256 _nowBidPrice){
        BidInfo memory bidInfo = bidInfos[_auctionId];
        return bidInfo.bidPrice;
    }
    
    //seller cancel
    function cancel(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        uint32 nowStatus = bidInfo.auctionStatus;
        require(nowStatus == 0 || nowStatus == 1 || nowStatus == 2, "Auction cancel or success");
        uint256 refund = 0;
        if(nowStatus == 1){
            // must end
            require(bidInfo.expirationTime < block.timestamp, "On auction");
            refund = bidInfo.bidPrice;
            //has bid send coin to bidder
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
            //remove seller list
            _removeMyAuction(bidInfo.seller, _auctionId);
            //remove bidder list
            _removeMyAuction(bidInfo.bidder, _auctionId);
        }
        IERC721 ierc721 = IERC721(bidInfo.token);
        ierc721.safeTransferFrom(address(this),msg.sender, bidInfo.tokenId);
        bidInfo.auctionStatus = 5;
        emit Cancel(_auctionId, bidInfo.seller, refund, 5, bidInfo.bidCount);
    }

    //seller executor
    function sellingSettlementPrice(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(msg.sender == bidInfo.seller, "Not seller");
        require(bidInfo.auctionStatus == 1, "Not on bid");
        bidInfo.auctionStatus = 3;
        uint256 amount = _share(_auctionId,bidInfo,bidInfo.bidPrice);
        emit Selling(_auctionId,bidInfo.bidder,amount,3,bidInfo.bidCount);
    }

    //bidder execute
    function bidderReverse(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(msg.sender == bidInfo.bidder, "Not bidder");
        // if bidder wanner his coin, current time must over than `reverseTime`
        require(bidInfo.auctionStatus == 1, "Reverse must on bid");
        require(bidInfo.expirationTime.add(reverseTime) <= block.timestamp, "Not over reverse time");
        //coin send to bidder
        transferMain(msg.sender, bidInfo.bidPrice);
        bidInfo.auctionStatus = 2;
        _removeMyAuction(bidInfo.bidder, _auctionId);
        emit Reverse(_auctionId, bidInfo.bidder, bidInfo.bidPrice,2,bidInfo.bidCount);
    }

    //auction success bidder execute
    function fixedWithdraw(uint256 _auctionId) payable public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(bidInfo.auctionStatus == 1 || bidInfo.auctionStatus == 0, "Withdraw not on bid or on sell");
        if(bidInfo.bidCount != 0){
            require(bidInfo.expirationTime >= block.timestamp, "Not on auction");
        }
        if(bidInfo.auctionStatus == 1){
            //send to last bidder
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
        }
        require(bidInfo.fixedPrice == msg.value,"Not fixed price");
        bidInfo.auctionStatus = 4;
        bidInfo.bidPrice = bidInfo.fixedPrice;
        uint256 amount = _share(_auctionId,bidInfo,bidInfo.fixedPrice);
        // to seller
        bidInfo.bidder = msg.sender;
        emit Fixed(_auctionId,bidInfo.bidder,amount,4,bidInfo.bidCount);
    }

    function setPaused() public onlyOwner(){
        super._pause();
    }

    function setUnpaused() public onlyOwner(){
        super._unpause();
    }

    function _share(uint256 _auctionId, BidInfo storage bidInfo, uint256 _price) internal returns(uint256 _amount){
        uint256 amount = _price;
        //721 transfer current bidder , get bidder price
        IERC721 ierc721 = IERC721(bidInfo.token);
        ierc721.safeTransferFrom(address(this), msg.sender, bidInfo.tokenId);
        //fee to platform
        uint256 _fee = amount.mul(feePercent).div(basePercent);
        uint256 _artistFee = 0; 
        transferMain(platform,_fee);
        //artist share in the benefit 
        if(address(artGee) == bidInfo.token){
            (uint256 artId,,)=artGee.tokenArts(bidInfo.tokenId);
            (,,,address creator,
                address[] memory assistants,
                uint256[] memory benefits,)=artGee.getSourceDigitalArt(artId);
            bool isNotFirst = isNotFirstAuction[bidInfo.token][bidInfo.tokenId];
            //first time 20% to artist,other time 10% 
            _artistFee = amount.mul(isNotFirst ? artPercent[1]:artPercent[0]).div(basePercent);
            if(assistants.length == 0){
                //send to creator
                transferMain(creator,_artistFee);
            }else{
                //send to creator and other assistant
                for (uint256 index = 0; index < benefits.length; index++) {
                    if(index==0){
                        // to creator
                        transferMain(creator,_artistFee.mul(benefits[index]).div(basePercent));
                    }else{
                        // to assistants
                        transferMain(assistants[index-1],_artistFee.mul(benefits[index]).div(basePercent));
                    }
                }
            }
            isNotFirstAuction[bidInfo.token][bidInfo.tokenId] = true;
        }
        transferMain(bidInfo.seller, amount.sub(_fee).sub(_artistFee));
        _removeMyAuction(bidInfo.seller, _auctionId);
        //remove bidder list
        _removeMyAuction(bidInfo.bidder, _auctionId);
        return amount.sub(_fee).sub(_artistFee);
    }

    function _initAuction(BidInfo storage bidInfo) internal {
        bidInfo.bidPrice = 0;
        bidInfo.bidder = address(0);        
        bidInfo.bidCount = 0;
        bidInfo.startTime = 0;
        bidInfo.expirationTime = 0;
        bidInfo.auctionStatus = 0; 
    }
}