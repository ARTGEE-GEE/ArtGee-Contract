pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IAgERC721.sol";
import './base/BaseAuction.sol';
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title English auction
/// @author yzbbanban
/// @notice buy token
/// @dev 
contract EnglishAuction is BaseAuction, Pausable, ReentrancyGuard {

    event Auction(uint256 indexed _auctionId, address _token, uint256 _tokenId,address _seller, 
                    uint256 _openingBid,uint256 _bidIncrements,uint256 _startTime, uint256 _expirationTime,
                    uint32 _auctionStatus);
    event ReAuction(uint256 indexed _auctionId,uint256 _bidPrice,uint256 _openingBid, uint256 _bidIncrements,
                    uint256 _startTime, uint256 _expirationTime,uint32 _auctionStatus);
    event LastParam(uint256 _extendTime, uint256 _reverseTime);
    event Bid(uint256 indexed _auctionId, address _bidder,uint256 _bidPrice, uint256 _bidCount,uint256 _expirationTime,uint32 _auctionStatus);
    event Selling(uint256 indexed _auctionId, address _seller, address _bidder, uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);
    event Reverse(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);
    event Withdraw(uint256 indexed _auctionId, address _seller, address _bidder, uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);
    event Cancel(uint256 indexed _auctionId, address _seller,uint256 _bidPrice, uint32 _auctionStatus, uint256 _bidCount);

    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;
    using SafeMath for uint256;

    mapping(uint256 => BidInfo) public bidInfos;
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
        uint256 reservePrice;
        uint256 bidIncrements;
        uint256 bidPrice;//change
        uint256 bidCount;//change
        uint256 startTime;
        uint32 auctionStatus;// 0 init; 1 bid; 2 bidder reverse;3 seller finish; 4 bidder finish 5 seller cancel
        uint256 expirationTime;//change
    }

    function setReverseTime(uint256 _extendTime, uint256 _reverseTime) public onlyOwner(){
        emit LastParam(extendTime, reverseTime);
        if(_extendTime != 0){
            extendTime = _extendTime;
        }
        if(_reverseTime != 0){
            reverseTime = _reverseTime;
        }
    }

    //seller
    function auction(address _token, uint256 _tokenId,
                    uint256 _openingBid, uint256 _bidIncrements,
                    uint256 _reservePrice, uint256 _startTime,uint256 _expirationTime
                     ) public nonReentrant whenNotPaused{
        require(_expirationTime >= block.timestamp && _expirationTime > _startTime,"Time error");
        require(_reservePrice >= _openingBid, "Price error");
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();
        BidInfo storage bidInfo = bidInfos[auctionId];
        bidInfo.token = _token;
        bidInfo.tokenId = _tokenId;
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.reservePrice = _reservePrice;
        bidInfo.bidIncrements = _bidIncrements;
        bidInfo.startTime = _startTime;
        //1 day later
        bidInfo.expirationTime = _expirationTime;
        _initAuction(bidInfo);
        //add tokenId
        IERC721 ierc721 = IERC721(_token);
        ierc721.safeTransferFrom(msg.sender, address(this), _tokenId);
        // add my auction
        _addMyAuction(msg.sender,auctionId);
        artList.push(auctionId);
        emit Auction(auctionId,_token, _tokenId, msg.sender, _openingBid, 
                    _bidIncrements, _startTime,_expirationTime,0);
    }

    //seller
    function reAuction(uint256 _auctionId, 
                        uint256 _openingBid, uint256 _bidIncrements,
                        uint256 _reservePrice, uint256 _startTime, uint256 _expirationTime) public nonReentrant whenNotPaused{
        require(_expirationTime >= block.timestamp && _expirationTime > _startTime,"Time error");
        require(_reservePrice >= _openingBid, "Price error");
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(bidInfo.auctionStatus != 5,"Seller has been canceled");
        //bid price must < reverse price
        require(bidInfo.bidPrice < bidInfo.reservePrice,"Bid success");
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        //bidder has already reverse
        uint256 refund = 0;
        if(bidInfo.auctionStatus == 1){
            //must wait for auction over
            require(block.timestamp > bidInfo.expirationTime, "Auction not over");
            //sende coin to bidder
            refund = bidInfo.bidPrice;
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
            // remove bidder's auctionId
            _removeMyAuction(bidInfo.bidder, _auctionId);
        }
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.reservePrice = _reservePrice;
        bidInfo.bidIncrements = _bidIncrements;
        bidInfo.startTime = _startTime;
        //1 day later
        bidInfo.expirationTime = _expirationTime;
        _initAuction(bidInfo);     
        emit ReAuction(_auctionId, refund,
                        _openingBid, _bidIncrements, _startTime,_expirationTime,0);
    }

    //bidder
    function bid(uint256 _auctionId) payable public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(block.timestamp >= bidInfo.startTime,"Auction not start");
        //now time > expiration time then auction over
        require(block.timestamp <= bidInfo.expirationTime, "Auction over");
        require(bidInfo.auctionStatus == 0 || bidInfo.auctionStatus == 1, "Not on auction");
        require(msg.sender != bidInfo.seller, "Seller can not bid");
        require(msg.sender != bidInfo.bidder, "Bidder can not repeat bid");
        uint256 nowBidPrice = bidInfo.bidPrice;
        //transfer to last bidder
        if(bidInfo.bidCount!=0){
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
            nowBidPrice = bidInfo.bidPrice.add(bidInfo.bidIncrements);
        }else{
            nowBidPrice = bidInfo.openingBid;
        }
        require(msg.value == nowBidPrice, "Value error");
        //update price
        bidInfo.bidPrice = nowBidPrice;
        // expiration time - (startTime + 1day) => update expiration
        if(bidInfo.expirationTime.sub(block.timestamp) <= extendTime){
            bidInfo.expirationTime = block.timestamp.add(extendTime);
        }
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
        emit Bid(_auctionId, msg.sender, nowBidPrice, bidInfo.bidCount,bidInfo.expirationTime, 1);
    }
    
    function getCurrentPrice(uint256 _auctionId) view public returns(uint256 _nowBidPrice){
        BidInfo memory bidInfo = bidInfos[_auctionId];
        uint256 nowBidPrice = bidInfo.bidPrice;
        if(bidInfo.bidCount!=0){
            nowBidPrice = bidInfo.bidPrice.add(bidInfo.bidIncrements);
        }
        return nowBidPrice;
    }
    
    //sell cancel
    function cancel(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(bidInfo.seller == msg.sender,"Not auction id seller");    
        require(bidInfo.bidPrice < bidInfo.reservePrice,"Bid success");
        //init ,has bidded, bidder has reverse
        uint32 nowStatus = bidInfo.auctionStatus;
        require(nowStatus == 0 || nowStatus == 1 || nowStatus == 2, "Auction cancel or success");
        uint256 refund = 0;
        if(nowStatus == 1){
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
        emit Cancel(_auctionId, bidInfo.seller, refund, 5,bidInfo.bidCount);
    }

    //seller executor
    function sellingSettlementPrice(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(msg.sender == bidInfo.seller, "Not seller");
        require(bidInfo.auctionStatus == 1, "Not on bid");
        require(bidInfo.expirationTime < block.timestamp, "On auction");
        bidInfo.auctionStatus = 3;
        uint256 amount = bidInfo.bidPrice;
        require(amount >= bidInfo.reservePrice,"Not over reserve price");
        //721 transfer current bidder , get bidder price
        uint256 am = _share(_auctionId, bidInfo, amount);
        emit Selling(_auctionId,bidInfo.seller,bidInfo.bidder,am,3,bidInfo.bidCount);
    }

    //bidder execute
    function bidderReverse(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(msg.sender == bidInfo.bidder, "Not bidder");
        require(bidInfo.bidPrice < bidInfo.reservePrice,"Bid success");
        // if bidder wanner his coin, current time must over than `reverseTime`
        require(bidInfo.auctionStatus == 1, "Reverse must on bid");
        require(bidInfo.expirationTime.add(reverseTime) <= block.timestamp, "Not over reverse time");
        //coin send to bidder
        transferMain(msg.sender, bidInfo.bidPrice);
        bidInfo.auctionStatus = 2;
        //remove bidder list
        _removeMyAuction(bidInfo.bidder, _auctionId);
        emit Reverse(_auctionId, bidInfo.bidder, bidInfo.bidPrice, 2,bidInfo.bidCount);
    }

    //auction success bidder execute
    function withdraw(uint256 _auctionId) public nonReentrant whenNotPaused{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.token != address(0),"Bid not exist");
        require(bidInfo.bidder == msg.sender,"Not bidder");
        require(bidInfo.auctionStatus == 1, "Withdraw not on bid");
        require(bidInfo.expirationTime < block.timestamp, "On auction");
        uint256 amount = bidInfo.bidPrice;
        require(amount >= bidInfo.reservePrice,"Not over reserve price");
        bidInfo.auctionStatus = 4;
        //721 transfer current bidder , get bidder price
        uint256 am = _share(_auctionId, bidInfo, amount);
        emit Withdraw(_auctionId,bidInfo.seller,bidInfo.bidder,am,4,bidInfo.bidCount);
    }

    function setPaused() public onlyOwner(){
        super._pause();
    }

    function setUnpaused() public onlyOwner(){
        super._unpause();
    }

    function _share(uint256 _auctionId, BidInfo storage bidInfo,uint256 _price) internal returns(uint256 _amount){
        uint256 amount = _price;
        IERC721 ierc721 = IERC721(bidInfo.token);
        ierc721.safeTransferFrom(address(this), bidInfo.bidder, bidInfo.tokenId);
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
        // to seller
        transferMain(bidInfo.seller, amount.sub(_fee).sub(_artistFee));
        //remove seller list
        _removeMyAuction(bidInfo.seller, _auctionId);
        //remove bidder list
        _removeMyAuction(bidInfo.bidder, _auctionId);
        return amount.sub(_fee).sub(_artistFee);
    }

    function _initAuction(BidInfo storage bidInfo) internal {
        bidInfo.bidPrice = 0;
        bidInfo.auctionStatus = 0;
        bidInfo.bidCount = 0;
        bidInfo.bidder = address(0);  
    }
}