pragma solidity ^0.6.2;

import "./owner/Operator.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IAgERC721.sol";

/// @title fixed auction
/// @author yzbbanban
/// @notice buy token
/// @dev 
contract FixedAuction is Operator{
    event Auction(uint256 indexed _auctionId, address _token, 
                    uint256 _tokenId, address _seller, 
                    uint256 _openingBid, uint256 _fixedPrice,uint256 startTime,uint32 _auctionStatus);
    event ReAuction(uint256 indexed _auctionId,
                    uint256 _openingBid, uint256 _fixedPrice, uint256 startTime,uint32 _auctionStatus);
    event LastParam(uint256 _limitTime, uint256 _extendTime, uint256 _reverseTime);
    event Bid(uint256 indexed _auctionId, address _bidder,
                uint256 _bidPrice, uint256 _bidCount,uint32 _auctionStatus);
    event Selling(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus);
    event Reverse(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus);
    event Fixed(uint256 indexed _auctionId, address _bidder, uint256 _bidPrice, uint32 _auctionStatus);
    event Cancel(uint256 indexed _auctionId, address _seller,uint256 _bidPrice, uint32 _auctionStatus);

    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;
    using SafeMath for uint256;

    mapping(uint256 => BidInfo) public bidInfos;
    uint256 public limitTime = 1 days;
    uint256 public extendTime = 15 minutes;
    uint256 public reverseTime = 5 days;
    
    uint256 public feePercent = 100; //10%
    uint256[] public artPercent = [200,100]; //first 20%; other time 10%
    uint256 public basePercent = 1000;
    address public platform;
    mapping(uint256 => bool) isNotFirstAuction;
    //my bids 
    mapping(address => uint256[]) myBidInfos;
    //my => auction id => index
    mapping(address => mapping(uint256 => uint256)) myBidInfoIndex;

    IAgERC721 artGee;

    uint256[] public artList;

    constructor(IAgERC721 _artGee) public{
        artGee = _artGee;
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
    
    function getMyArtList(address _owner) view public returns(uint256[] memory){
        return myBidInfos[_owner];
    }

    function getArtList() view public returns(uint256[] memory _artList){
        return artList;
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

    function setArtgee(IAgERC721 _artGee,address _platform) public onlyOwner(){
        artGee = _artGee;
        platform = _platform;
    }

    function auction(address _token, uint256 _tokenId, 
                    uint256 _openingBid,
                    uint256 _fixedPrice) public{
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();
        BidInfo storage bidInfo = bidInfos[auctionId];
        bidInfo.token = _token;
        bidInfo.tokenId = _tokenId;
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.bidPrice = _openingBid;
        bidInfo.fixedPrice = _fixedPrice;
        bidInfo.bidder = address(0);        
        bidInfo.bidCount = 0;
        uint256 t = block.timestamp;
        bidInfo.startTime = t;
        //1 day later
        bidInfo.expirationTime = t.add(limitTime);
        bidInfo.auctionStatus = 0;
        //add tokenId
        IERC721 ierc721 = IERC721(_token);
        ierc721.safeTransferFrom(msg.sender, address(this), _tokenId);
        // add my auction
        _addMyAuction(msg.sender,auctionId);
        emit Auction(auctionId,_token, _tokenId, msg.sender, _openingBid,_fixedPrice, t,0);
    }

    function reAuction(uint256 _auctionId, uint256 _openingBid, 
                    uint256 _fixedPrice) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        //must wait for auction over
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        require(block.timestamp > bidInfo.expirationTime, "Auction not over");
        //bidder has already reverse
        if(bidInfo.auctionStatus == 1){
            //sende coin to bidder
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
        }
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.bidPrice = _openingBid;
        bidInfo.fixedPrice = _fixedPrice;
        bidInfo.bidder = address(0);        
        uint256 t = block.timestamp;
        bidInfo.startTime = t;
        //1 day later
        bidInfo.expirationTime = t.add(limitTime);
        bidInfo.auctionStatus = 0;
        bidInfo.bidCount = 0;
        // remove bidder's auctionId
        _removeMyAuction(bidInfo.bidder, _auctionId);
        emit ReAuction(_auctionId, _openingBid, _fixedPrice, t,0);
    }

    function bid(uint256 _auctionId) payable public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(msg.sender != bidInfo.seller, "Seller can not bid");
        require(bidInfo.expirationTime < block.timestamp, "On auction");
        require(bidInfo.auctionStatus == 0, "Not on auction");
        uint256 nowBidPrice = bidInfo.bidPrice;
        //transfer to last bidder
        if(bidInfo.bidCount!=0){
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
        }
        require(msg.value > nowBidPrice, "Value error");
        //now time > expiration time then auction over
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
        emit Bid(_auctionId, msg.sender, nowBidPrice, bidInfo.bidCount, 1);
    }

    function getCurrentPrice(uint256 _auctionId) view public returns(uint256 _nowBidPrice){
        BidInfo memory bidInfo = bidInfos[_auctionId];
        return bidInfo.bidPrice;
    }
    
    //seller cancel
    function cancel(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        // must end
        require(bidInfo.expirationTime < block.timestamp, "On auction");
        require(bidInfo.auctionStatus == 0 || bidInfo.auctionStatus == 1, "Has bid");
        if(bidInfo.bidder != address(0)){
            //remove bidder list
            _removeMyAuction(bidInfo.bidder, _auctionId);
        }
        uint256 refund = 0;
        if(bidInfo.auctionStatus == 1){
            refund = bidInfo.bidPrice;
            //has bid send coin to bidder
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
            //remove seller list
            _removeMyAuction(bidInfo.seller, _auctionId);
        }
        IERC721 ierc721 = IERC721(bidInfo.token);
        ierc721.safeTransferFrom(address(this),msg.sender, bidInfo.tokenId);
        bidInfo.auctionStatus = 5;
        emit Cancel(_auctionId, bidInfo.seller, refund, 5);
    }

    //seller executor
    function sellingSettlementPrice(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(msg.sender == bidInfo.seller, "Not seller");
        require(bidInfo.expirationTime < block.timestamp, "On auction");
        require(bidInfo.auctionStatus == 1, "Not on bid");
        bidInfo.auctionStatus = 3;
        uint256 amount = bidInfo.bidPrice;
        //721 transfer current bidder , get bidder price
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
            bool isNotFirst = isNotFirstAuction[bidInfo.tokenId];
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
            isNotFirstAuction[bidInfo.tokenId] = true;
        }
        // to seller
        transferMain(bidInfo.seller, amount.sub(_fee).sub(_artistFee));
        emit Selling(_auctionId,bidInfo.bidder,amount.sub(_fee).sub(_artistFee),3);
    }

    //bidder execute
    function bidderReverse(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 1, "Reverse not on bid");
        // if bidder wanner his coin, current time must over than `reverseTime`
        require(bidInfo.expirationTime.add(reverseTime) <= block.timestamp, "Not on auction");
        require(msg.sender == bidInfo.bidder, "Not bidder");
        //coin send to bidder
        transferMain(msg.sender, bidInfo.bidPrice);
        bidInfo.auctionStatus = 2;
        emit Reverse(_auctionId, bidInfo.bidder, bidInfo.bidPrice,2);
    }

    //auction success bidder execute
    function fixedWithdraw(uint256 _auctionId) payable public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 1 || bidInfo.auctionStatus == 0, "Withdraw not on bid or on sell");
        require(bidInfo.expirationTime <= block.timestamp, "Not on auction");
        require(bidInfo.fixedPrice == msg.value,"Not fixed price");
        uint256 amount = bidInfo.fixedPrice;
        bidInfo.auctionStatus = 4;
        //721 transfer current bidder , get bidder price
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
            bool isNotFirst = isNotFirstAuction[bidInfo.tokenId];
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
            isNotFirstAuction[bidInfo.tokenId] = true;
        }
        // to seller
        transferMain(bidInfo.seller, amount.sub(_fee).sub(_artistFee));
        emit Fixed(_auctionId,bidInfo.bidder,amount.sub(_fee).sub(_artistFee),4);
    }

    function _addMyAuction(address _owner,uint256 _auctionId) internal{
        myBidInfoIndex[_owner][_auctionId] = myBidInfos[_owner].length;
        myBidInfos[_owner].push(_auctionId);
    }

    function _removeMyAuction(address _owner, uint256 _auctionId) internal{
        uint256 lastIndex = myBidInfos[_owner].length.sub(1);
        uint256 currentIndex = myBidInfoIndex[_owner][_auctionId];
        if(lastIndex != currentIndex){
            uint256 lastAuctionId = myBidInfos[_owner][lastIndex];
            myBidInfos[_owner][currentIndex] = lastAuctionId;
            myBidInfoIndex[_owner][lastAuctionId] = currentIndex;
        }
        myBidInfos[_owner].pop();
    }

    function transferMain(address _address, uint256 _value) internal{
        (bool res, ) = address(uint160(_address)).call{value:_value}("");
        require(res,"TRANSFER ETH ERROR");
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive () external payable {}
}