pragma solidity ^0.6.2;

import "./owner/Operator.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IAgERC721.sol";


/// @title English auction
/// @author yzbbanban
/// @notice buy token
/// @dev 
contract EnglishAuction is Operator{

    event Auction(uint256 indexed _auctionId, address _token, 
                    uint256 _tokenId,address _seller, 
                    uint256 _openingBid,uint256 _bidIncrements,uint256 _startTime, uint256 _expirationTime);
    event ReAuction(uint256 indexed _auctionId, address _token, 
                    uint256 _tokenId, address _seller, 
                    uint256 _openingBid, uint256 _bidIncrements, uint256 _startTime, uint256 _expirationTime);
    event LastParam(uint256 _extendTime, uint256 _reverseTime);
    event Bid(uint256 indexed _auctionId, address _bidder,
                uint256 _openingBid, uint256 _bidCount,uint _auctionStatus);
    event Selling(uint256 indexed _auctionId, address _bidder, uint256 _openingBid);
    event Reverse(uint256 indexed _auctionId, address _bidder, uint256 _openingBid, uint256 _auctionStatus);
    event Withdraw(uint256 indexed _auctionId, address _bidder, uint256 _openingBid);
    event Cancel(uint256 indexed _auctionId, address _seller, address _token, uint256 _tokenId);

    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;
    using SafeMath for uint256;

    mapping(uint256 => BidInfo) public bidInfos;
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


    constructor(IAgERC721 _artGee) public{
        artGee = _artGee;
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
        uint auctionStatus;// 0 init; 1 bid; 2 bidder reverse;3 seller finish; 4 bidder finish
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

    function setArtgee(IAgERC721 _artGee,address _platform) public onlyOwner(){
        artGee = _artGee;
        platform = _platform;
    }
    function setArtPercent(uint256[2] memory _artPercents) public onlyOwner(){
        artPercent[0] = _artPercents[0];
        artPercent[1] = _artPercents[1];
    }

    //seller
    function auction(address _token, uint256 _tokenId,
                    uint256 _openingBid, uint256 _bidIncrements,
                    uint256 _reservePrice, uint256 _startTime,uint256 _expirationTime
                     ) public{
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();
        BidInfo storage bidInfo = bidInfos[auctionId];
        bidInfo.token = _token;
        bidInfo.tokenId = _tokenId;
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.bidPrice = _openingBid;
        bidInfo.reservePrice = _reservePrice;
        bidInfo.bidder = address(0);        
        bidInfo.bidCount = 0;
        bidInfo.bidIncrements = _bidIncrements;
        bidInfo.startTime = _startTime;
        //1 day later
        bidInfo.expirationTime = _expirationTime;
        bidInfo.auctionStatus = 0;
        //add tokenId
        IERC721 ierc721 = IERC721(_token);
        ierc721.safeTransferFrom(msg.sender, address(this), _tokenId);
        // add my auction
        _addMyAuction(msg.sender,auctionId);
        emit Auction(auctionId,_token, _tokenId, msg.sender, _openingBid, _bidIncrements, _startTime,_expirationTime);
    }

    //seller
    function reAuction(uint256 _auctionId, 
                        uint256 _openingBid, uint256 _bidIncrements,
                        uint256 _reservePrice, uint256 _startTime, uint256 _expirationTime) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        //must wait for auction over
        require(block.timestamp > bidInfo.expirationTime, "Auction not over");
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        //bidder has already reverse
        if(bidInfo.auctionStatus == 1){
            //sende coin to bidder
            transferMain(bidInfo.bidder, bidInfo.bidPrice);
        }
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _openingBid;
        bidInfo.bidPrice = _openingBid;
        bidInfo.reservePrice = _reservePrice;
        bidInfo.bidder = address(0);        
        bidInfo.bidIncrements = _bidIncrements;
        bidInfo.startTime = _startTime;
        //1 day later
        bidInfo.expirationTime = _expirationTime;
        bidInfo.auctionStatus = 0;
        bidInfo.bidCount = 0;
        // remove bidder's auctionId
        _removeMyAuction(bidInfo.bidder, _auctionId);
        emit ReAuction(_auctionId, bidInfo.token, bidInfo.tokenId, msg.sender, _openingBid, _bidIncrements, _startTime,_expirationTime);
    }

    //bidder
    function bid(uint256 _auctionId) payable public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 0, "Not on auction");
        require(msg.sender != bidInfo.seller, "Seller can not bid");
        uint256 nowBidPrice = bidInfo.bidPrice;
        if(bidInfo.bidCount!=0){
            nowBidPrice = bidInfo.bidPrice.mul(bidInfo.bidIncrements.add(basePercent).div(basePercent));
        }
        require(msg.value == nowBidPrice, "Value error");
        //now time > expiration time then auction over
        require(block.timestamp <= bidInfo.expirationTime, "Auction over");
        //update price
        bidInfo.bidPrice = nowBidPrice;
        // expiration time - (startTime + 1day) => update expiration
        if(bidInfo.expirationTime.sub(block.timestamp) <= extendTime){
            bidInfo.expirationTime = block.timestamp.add(extendTime);
        }
        // add bidder auction id and remove seller auction id
        _removeMyAuction(bidInfo.bidder, _auctionId);
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
        uint256 nowBidPrice = bidInfo.bidPrice;
        if(bidInfo.bidCount!=0){
            nowBidPrice = bidInfo.bidPrice.mul(bidInfo.bidIncrements.add(basePercent)).div(basePercent);
        }
        return nowBidPrice;
    }
    
    //sell cancel
    function cancel(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(block.timestamp > bidInfo.expirationTime, "Auction not over");
        require(bidInfo.seller == msg.sender,"Not auction id seller");
        require(bidInfo.auctionStatus == 0, "Has bid");
        IERC721 ierc721 = IERC721(bidInfo.token);
        ierc721.safeTransferFrom(address(this),msg.sender, bidInfo.tokenId);
        emit Cancel(_auctionId, bidInfo.seller, bidInfo.token, bidInfo.tokenId);
    }

    //seller executor
    function sellingSettlementPrice(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 1, "Not on bid");
        require(bidInfo.expirationTime <= block.timestamp, "Not on auction");
        require(msg.sender == bidInfo.seller, "Not seller");
        bidInfo.auctionStatus = 3;
        uint256 amount = bidInfo.bidPrice;
        require(amount >= bidInfo.reservePrice,"Not over reserve price");
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
        emit Selling(_auctionId,bidInfo.bidder,amount.sub(_fee).sub(_artistFee));
    }

    //bidder execute
    function bidderReverse(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.bidPrice < bidInfo.reservePrice,"bid success");
        require(bidInfo.auctionStatus == 1, "Reverse not on bid");
        // if bidder wanner his coin, current time must over than `reverseTime`
        require(bidInfo.expirationTime.add(reverseTime) <= block.timestamp, "Not over reverse time");
        require(msg.sender == bidInfo.bidder, "Not bidder");
        //coin send to bidder
        transferMain(msg.sender, bidInfo.bidPrice);
        bidInfo.auctionStatus = 2;
        emit Reverse(_auctionId, bidInfo.bidder, bidInfo.bidPrice, 2);
    }

    //auction success bidder execute
    function withdraw(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 1, "Withdraw not on bid");
        require(bidInfo.expirationTime <= block.timestamp, "Not on auction");
        require(bidInfo.bidder == msg.sender,"Not bidder");
        uint256 amount = bidInfo.bidPrice;
        require(amount >= bidInfo.reservePrice,"Not over reserve price");
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
        emit Withdraw(_auctionId,bidInfo.bidder,amount.sub(_fee).sub(_artistFee));
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
}