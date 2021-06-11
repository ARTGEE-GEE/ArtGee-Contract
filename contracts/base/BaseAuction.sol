pragma solidity ^0.6.2;

import "../interfaces/IAgERC721.sol";
import "../owner/Operator.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract BaseAuction is Operator{
    using SafeMath for uint256;
    IAgERC721 public artGee;
    uint256 public feePercent = 100; //10%
    uint256[] public artPercent = [200,100]; //first 20%; other time 10%
    uint256 public basePercent = 1000;
    address public platform;
    mapping(address => mapping(uint256 => bool)) public isNotFirstAuction;
    //my bids 
    mapping(address => uint256[]) public myBidInfos;
    //my => auction id => index
    mapping(address => mapping(uint256 => uint256)) myBidInfoIndex;

    function getMyArtList(address _owner) view public returns(uint256[] memory){
        return myBidInfos[_owner];
    }

    function setArtgee(IAgERC721 _artGee,address _platform) public onlyOwner(){
        artGee = _artGee;
        platform = _platform;
    }
    function setArtPercent(uint256 _feePercent,uint256[2] memory _artPercents) public onlyOwner(){
        if(_feePercent!=0){
            feePercent = _feePercent;
        }
        artPercent[0] = _artPercents[0];
        artPercent[1] = _artPercents[1];
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
        (bool res, ) = address(uint160(_address)).call{value:_value, gas:20000}("");
        // require(res,"TRANSFER ETH ERROR");
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