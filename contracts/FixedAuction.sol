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
                    uint256 _tokenId,address _seller, 
                    uint256 _value,uint256 _bidIncrements,uint256 startTime);
    event Bid(uint256 indexed _auctionId,address _bidder,
                uint256 _value, uint256 _bidCount,uint _auctionStatus);
    event Selling(uint256 _auctionId,address _bidder,uint256 _value);

    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;
    using SafeMath for uint256;

    mapping(uint256 => BidInfo) bidInfos;
    uint256 public limitTime = 1 days;
    uint256 public extendTime = 15 minutes;
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
        uint256 bidIncrements;
        uint256 bidPrice;//change
        uint256 bidCount;//change
        uint256 startTime;
        uint auctionStatus;// 0 init; 1 bid; 2 bidder finifsh;3 seller finish
        uint256 expirationTime;//change
    }

    function setArtgee(IAgERC721 _artGee,address _platform) public onlyOwner(){
        artGee = _artGee;
        platform = _platform;
    }

    function auction(address _token, uint256 _tokenId, uint256 _value,uint256 _bidIncrements) public{
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();
        BidInfo storage bidInfo = bidInfos[auctionId];
        bidInfo.token = _token;
        bidInfo.tokenId = _tokenId;
        bidInfo.seller = msg.sender;
        bidInfo.openingBid = _value;
        bidInfo.bidder = address(0);        
        bidInfo.bidIncrements = _bidIncrements;
        uint256 t = block.timestamp;
        bidInfo.startTime = t;
        //1 day later
        bidInfo.expirationTime = t.add(limitTime);
        //add tokenId
        IERC721 ierc721 = IERC721(_tokenId);
        ierc721.safeTransferFrom(msg.sender, address(this), _tokenId);
        // add my auction
        _addMyAuction(msg.sender,auctionId);
        emit Auction(auctionId,_token, _tokenId, msg.sender, _value, _bidIncrements, t);
    }

    function bid(uint256 _auctionId) payable public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 0, "Not on auction");
        require(msg.sender != bidInfo.seller, "Seller can not bid");
        uint256 nowBidPrice = bidInfo.bidPrice.mul(bidInfo.bidIncrements.add(1));
        require(msg.value == nowBidPrice, "Value error");
        //now time > expiration time then auction over
        require(block.timestamp <= bidInfo.expirationTime, "Auction over");
        //update price
        bidInfo.bidPrice = nowBidPrice;
        // expiration time - (startTime + 1day) => update expiration
        if(bidInfo.expirationTime.sub(bidInfo.startTime.add(limitTime)) <= extendTime){
            bidInfo.expirationTime = block.timestamp.add(limitTime);
        }
        // add bidder auction id and remove seller auction id
        _removeMyAuction(bidInfo.bidder, _auctionId);
        _addMyAuction(msg.sender,_auctionId);
        //reset bidder
        bidInfo.bidder = msg.sender;
        //add bid count

        bidInfo.bidCount = bidInfo.bidCount.add(1);
        emit Bid(_auctionId, msg.sender, nowBidPrice,bidInfo.bidCount,1);
    }

    function sellingSettlementPrice(uint256 _auctionId) public{
        BidInfo storage bidInfo = bidInfos[_auctionId];
        require(bidInfo.auctionStatus == 0, "Not on auction");
        require(msg.sender == bidInfo.seller, "Not seller");
        uint256 amount = bidInfo.bidPrice;
        bidInfo.auctionStatus = 3;
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
                        transferMain(creator,_artistFee.mul(benefits[index]).div(basePercent));
                    }else{
                        transferMain(creator,_artistFee.mul(benefits[index]).div(basePercent));
                    }
                }
            }
            isNotFirstAuction[bidInfo.tokenId] = true;
        }
        transferMain(bidInfo.seller, amount.sub(_fee).sub(_artistFee));
        emit Selling(_auctionId,bidInfo.bidder,amount.sub(_fee).sub(_artistFee));
    }

    function bidderReverse(uint256 _auctionId) public{
        
    }

    function withdraw(address _token, uint256 _tokenId) public{
        
    }

    function _addMyAuction(address _owner,uint256 _auctionId) public{
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