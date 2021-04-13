pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAgERC721 is IERC721{

    function tokenArts(uint256 _tokenId) view external returns(
        uint256 artId,
        uint256 edition,
        uint256 totalEdition
    );

    function getSourceDigitalArt(uint256 _artId) view external returns(
                uint256 id,
                uint256 totalEdition,
                uint256 currentEdition,
                address creator,
                address[] memory assistants,
                uint256[] memory benefits,
                string memory uri
    );
}
