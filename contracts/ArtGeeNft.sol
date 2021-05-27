pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./util/StringUtils.sol";
import "./owner/Operator.sol";
import "./interfaces/IDigitalSource.sol";

/// @title artgee nft
/// @author yzbbanban
/// @notice finish create nft,add art id
/// @dev Explain to a developer any extra details
contract ArtGeeNft is ERC721, Operator, Pausable{

    event CreateArt(uint256 _artId, address _owner,uint256 _tokenId, 
                    uint256 _edition,uint256 _totalEdition,string _uri);
    event UpdateEdition(uint256 _artId, uint256 edition);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    using SafeMath for uint256;

    //tokenId => limitCount
    mapping(uint256 => uint256) public limitCount;
    // market => in transfer list
    mapping(address => bool) public transferList;

    IDigitalSource public iDigitalSource;

    mapping(address => bool) public blackList;

    //tokenId => TokenArt
    mapping(uint256 => TokenArt) public tokenArts;

    struct TokenArt {
        uint256 artId;
        uint256 edition;
        uint256 totalEdition;
    }

    uint32 public mTotalEdition = 10000;

     // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    mapping(address => bool) public miners;

    constructor(IDigitalSource _iDigitalSource) public ERC721("AAAA", "AAAA") {
        iDigitalSource = _iDigitalSource;
        super._setBaseURI("ipfs://ipfs/");
    }

    //get art detail by art id
    function getSourceDigitalArt(uint256 _artId) view public returns(
                uint256 id,
                uint256 totalEdition,
                uint256 currentEdition,
                address creator,
                address[] memory assistants,
                uint256[] memory benefits,
                string memory uri
    ){
        return iDigitalSource.getDigitalArt(_artId);
    }

    function tokensOfOwner(address _owner) view public returns(uint256[] memory _tokens){
        return _ownedTokens[_owner];
    }

    function addBlackList(address _black) public onlyOwner(){
        blackList[_black] = true;
    }

    function removeBlackList(address _black) public onlyOwner(){
        blackList[_black] = false;
    }

    function SetMTotalEdition(uint32 _mTotalEdition) public onlyOwner(){
        mTotalEdition = _mTotalEdition;
    }

    function addTransferList(address _transferAddr) public onlyOwner(){
        transferList[_transferAddr] = true;
    }

    function removeTransferList(address _transferAddr) public onlyOwner(){
        transferList[_transferAddr] = false;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner(){
        //ipfs://ipfs/
        super._setBaseURI(_baseURI);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //limit first transfer must sale on artgee market
        require(from == address(this)
                || limitCount[tokenId]>0
                || transferList[from]
                || transferList[to],
                "Limit first transfer must sale on artgee market");
        super.transferFrom(from, to, tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
        _addTransferLimit(tokenId);
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
        require(from == address(this)
                || limitCount[tokenId]>0
                || transferList[from]
                || transferList[to],
                "Limit first transfer must sale on artgee market");
        super.safeTransferFrom(from, to, tokenId, _data);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
        _addTransferLimit(tokenId);
    }

    function _addTransferLimit(uint256 _tokenId) internal{
        if(limitCount[_tokenId]==0){
            limitCount[_tokenId] = limitCount[_tokenId].add(1);
        }
    }

     /**
     * @dev create art
     *
     * @param _assistants assistant
     * @param _benefits benefits of assistants(contain creator,index 0)
     * @param _totalEdition total edition
     * @param _uri metadate
     * @param _count edition count
     */
    function createArt(address[] memory _assistants,uint256[] memory _benefits,uint256 _totalEdition,
                string memory _uri,
                uint256 _count) public whenNotPaused(){
        require(!blackList[msg.sender],"Creator is forbidden");
        if(_assistants.length>0){
            require(_assistants.length + 1 == _benefits.length,"Benefits length error");
            uint256 _totalPercent = 0;
            for (uint256 index = 0; index < _benefits.length; index++) {
                _totalPercent = _totalPercent.add(_benefits[index]);
            }
            require(_totalPercent == 1000,"Benefits error");
        }
        require(_totalEdition <= mTotalEdition,"Total edition overflow");
        //create art id
        uint256 _artId = iDigitalSource.createDigitalArt(
                                msg.sender,
                                _assistants, 
                                _benefits, 
                                _totalEdition, 
                                _uri);
        _createArt(_artId, _count,0,_totalEdition,_uri);
    }

    /**
     * @dev add art
     * @param _artId artid
     * @param _count tcount
     */
    function addArt(uint256 _artId, uint256 _count) public whenNotPaused(){
        require(!blackList[msg.sender],"Creator not approve");
         (,uint256 totalEdition,uint256 currentEdition,address creator,,,string memory uri)=iDigitalSource.getDigitalArt(_artId);
        require(msg.sender == creator ,"Not creator");
        _createArt(_artId, _count,currentEdition,totalEdition,uri);
    }

    function _createArt(uint256 _artId,
                        uint256 _count,
                        uint256 _currentEdition,
                        uint256 _totalEdition,string memory _uri)
        internal
    {
        require(_count.add(_currentEdition) <= _totalEdition, "Total supply exceeded.");
        for (uint256 index = 0; index < _count; index++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            uint256 _edition = _currentEdition.add(index).add(1);
            //bind artId
            TokenArt memory tokenArt = TokenArt(_artId,_edition,_totalEdition);
            //bind current info
            tokenArts[newItemId] = tokenArt;
            _mint(msg.sender, newItemId);
            //set metadata
            _setTokenURI(newItemId, _uri);
            _addTokenToAllTokensEnumeration(newItemId);
            _addTokenToOwnerEnumeration(msg.sender, newItemId);
            emit CreateArt(_artId, msg.sender, newItemId, 
                    _edition,_totalEdition,_uri);
        }
        iDigitalSource.increaseDigitalArtEdition(_artId, _count);
        //event
        emit UpdateEdition(_artId,_currentEdition.add(_count));
    }

    function burnItem(uint256 _id) public{
        require(super.ownerOf(_id) == msg.sender, "ERC721: burn of token that is not own"); // internal owner
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