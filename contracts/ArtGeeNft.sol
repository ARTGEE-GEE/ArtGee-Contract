pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./util/StringUtils.sol";
import "./owner/Operator.sol";
import "./interfaces/IDigitalSource.sol";

contract ArtGeeNft is ERC721,Operator{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    using SafeMath for uint256;

    IDigitalSource public iDigitalSource;

    //tokenId => TokenArt
    mapping(uint256 => TokenArt) public tokenArts;

    struct TokenArt {
        uint256 artId;
        uint256 edition;
    }

     // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    mapping(address => bool) public miners;

    mapping(uint256 => string) public names;

    modifier onlyMiner(){
        require(miners[msg.sender],"Not miner");
        _;
    }

    constructor(IDigitalSource _iDigitalSource) public ERC721("AAAA", "AAAA") {
        iDigitalSource = _iDigitalSource;
    }

    function tokensOfOwner(address _owner) view public returns(uint256[] memory _tokens){
        return _ownedTokens[_owner];
    }

    function addMiner(address _miner) public onlyOwner(){
        miners[_miner] = true;
    }

    function removeMiner(address _miner) public onlyOwner(){
        miners[_miner] = false;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner(){
        super._setBaseURI(_baseURI);
    }

     /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        super.transferFrom(from, to, tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
      _safeTransferFrom(from,to,tokenId,"");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
      _safeTransferFrom(from,to,tokenId,_data);
    }

    function _safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) internal {
      super.safeTransferFrom(from, to, tokenId, _data);
      _removeTokenFromOwnerEnumeration(from, tokenId);
      _addTokenToOwnerEnumeration(to, tokenId);
    }

    //todo
    function createArt(address[] memory _assistants,uint256[] memory _benefits,uint256 _totalEdition,
                string memory _uri,
                uint256 _count) public{
        uint256 _artId = iDigitalSource.createDigitalArt(
                                msg.sender,
                                _assistants, 
                                _benefits, 
                                _totalEdition, 
                                _uri);
        _addItem(msg.sender, _artId, _count);
    }

    //todo
    function addArt(uint256 _artId, uint256 _count) public{
        _addItem(msg.sender, _artId, _count);
    }

    function _addItem(address _creator,uint256 _artId,uint256 _count)
        internal
    {
        (uint256 id,
        uint256 totalEdition,
        uint256 currentEdition,
        address creator,,,string memory uri)=iDigitalSource.getDigitalArt(_artId);
        require(msg.sender == creator ,"Not creator");
        require(_count.add(currentEdition) <= totalEdition, "Total supply exceeded.");
        string memory tokenURI = StringUtils.strConcat("ipfs://ipfs/", uri);
        for (uint256 index = 0; index < _count; index++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            uint256 _edition = currentEdition.add(index).add(1);
            //bind artId
            TokenArt memory tokenArt = TokenArt(_artId,_edition);
            //bind current info
            tokenArts[newItemId] = tokenArt;
            _mint(_creator, newItemId);
            _setTokenURI(newItemId, tokenURI);
            _addTokenToAllTokensEnumeration(newItemId);
            _addTokenToOwnerEnumeration(_creator, newItemId);
        }
        iDigitalSource.increaseDigitalArtEdition(_artId, _count);
        //event
    }

    function burnItem(uint256 _id) public onlyMiner(){
        _burn(_id);
        _removeTokenFromOwnerEnumeration(ownerOf(_id), _id);
        // Since tokenId will be deleted, we can clear its slot in _ownedTokensIndex to trigger a gas refund
        _ownedTokensIndex[_id] = 0;
        _removeTokenFromAllTokensEnumeration(_id);
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

     /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _ownedTokens[from].length.sub(1);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        _ownedTokens[from].pop();

        // Note that _ownedTokensIndex[tokenId] hasn't been cleared: it still points to the old slot (now occupied by
        // lastTokenId, or just over the end of the array if the token was the last one).
        delete _ownedTokensIndex[tokenId];
    }

     /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length.sub(1);
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        _allTokens.pop();
        _allTokensIndex[tokenId] = 0;
    }
}