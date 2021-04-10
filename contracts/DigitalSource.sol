pragma solidity ^0.6.0;

import "./owner/Operator.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DigitalSource is Operator{

    //artid  => art work detail
    mapping(uint256 => DigitalArt) digitalArts;
    using Counters for Counters.Counter;
    Counters.Counter private _artIds;

    uint256[] public artIds;

    struct DigitalArt{
        uint256 id;
        uint256 totalEdition;
        uint256 currentEdition;
        address creator;
        address[] assistants;
        uint256[] benefits;
        string uri;
    }

    function getArtIds() view public returns(uint256[] memory){
        return artIds;
    }

    function createDigitalArt(
                address _creator, 
                address[] memory _assistants, 
                uint256[] memory _benefits,
                uint256 _totalEdition, 
                string memory _uri) external returns (uint256){
        _artIds.increment();
        uint256 artId = _artIds.current();
        DigitalArt storage digitalArt = digitalArts[artId];
        digitalArt.creator = _creator;
        digitalArt.assistants = _assistants;
        digitalArt.benefits = _benefits;
        digitalArt.uri = _uri;
        digitalArt.currentEdition = 0;
    }

    function increaseDigitalArtEdition(
                uint256 _artId, 
                uint256 _count)  external {
        DigitalArt storage digitalArt = digitalArts[_artId];
        digitalArt.currentEdition = digitalArt.currentEdition + _count;
    }

    function getDigitalCreator(uint256 _artId) view external returns(
                address[] memory creators,
                uint256[] memory benefits) {
        DigitalArt storage digitalArt = digitalArts[_artId];            
        creators[0] = digitalArt.creator;
        for (uint256 index = 0; index < digitalArt.assistants.length; index++) {
            creators[index+1] = digitalArt.assistants[index];
        }
        benefits = digitalArt.benefits;
    }

    function getDigitalArt(uint256 _artId) view external returns(
                uint256 id,
                uint256 totalEdition,
                uint256 currentEdition,
                address creator,
                address[] memory assistants,
                uint256[] memory benefits,
                string memory uri
    ){
        DigitalArt memory digitalArt = digitalArts[_artId];    
        return (digitalArt.id,
                digitalArt.totalEdition,
                digitalArt.currentEdition,
                digitalArt.creator,
                digitalArt.assistants,
                digitalArt.benefits,
                digitalArt.uri);
    }
}