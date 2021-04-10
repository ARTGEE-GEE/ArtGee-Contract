pragma solidity ^0.6.0;


interface IDigitalSource {

    function getArtIds() view external returns(uint256[] memory);

    function createDigitalArt(
                address _creator, 
                address[] memory _assistants, 
                uint256[] memory _benefits,
                uint256 _totalEdition, 
                string memory _uri) external returns (uint256);

    function increaseDigitalArtEdition(
                uint256 _artId, 
                uint256 _count) external;

    function getDigitalCreator(uint256 _artId) view external returns(
                address[] memory creators,
                uint256[] memory benefits);

    function getDigitalArt(uint256 _artId) view external returns(
                uint256 id,
                uint256 totalEdition,
                uint256 currentEdition,
                address creator,
                address[] memory assistants,
                uint256[] memory benefits,
                string memory uri
    );
}