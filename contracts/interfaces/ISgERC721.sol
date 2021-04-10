pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISgERC721 is IERC721{
    
    function addAttr(uint256 _tokenId,uint256 _starlv, uint256 _atk,uint256 _exp,uint256 _lv,uint256 _worth,uint256 _bornTime) external;

    function getCardInfo(uint256 _tokenId) view external returns(uint256[4] memory _res);

    function getCardAtk() view external returns(uint256 _atk);

    function awardItem(address player,uint cardType) external returns (uint256);

    function cardTypes() view external returns(uint256[] memory cardTypes);
}
