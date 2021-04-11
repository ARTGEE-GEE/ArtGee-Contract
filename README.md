### install

    npm install @openzeppelin/contracts
    npm install @truffle/hdwallet-provider

### deploy

    truffle migration --network {network} (--reset)


#### 铸造功能

    1. 无artId，创建 artId
    2. 添加NFT（edition，totalEdition，creator，assistants，uri）
    3. 若多版没铸造完，根据artId添加
    4. nft铸造完成后，只能先上架到artgee market并买卖一次才可以，market地址需要设置
    5. 设置 baseUri
    6. 设置 market 地址
    7. 根据artId获取作品详情
    8. 进制艺术家（地址）再传作品和名单
    9. 暂停所有的创建、添加功能


### 铸造合约

    测试网络：rinkeby(chainId:4)
    DigitalSource   存储artId相关信息（前端和后端调用用不到）
    0x59A94a3CB7b022Fc3228Af22ED7497ede254ff25
    ArtGeeNft       铸造的nft 
    0xb31E832570d906d7b57545EcD45B6B0Ace3657d4
    abi： 📎ArtGeeNft.json 在 build/contracts/ArtGeeNft.json 文件中

#### 后端数据日志

#### 初次创建NFT时

    1. 创建【艺术资源】
    CreateDigitalArt(
                    uint256 _artId, //艺术Id
                    address _creator, //创建者
                    address[] _assistants, //协作者
                    uint256[] _benefits, //分配比例：创建者+协作者
                    uint256 _totalEdition, //总版次
                    string _uri // metadata（唯一）
                    )
---                    
    2. 铸造nft
    CreateArt(
            uint256 _artId, //艺术Id
            address _creator, //创建者
            uint256 _tokenId, //nft id
            uint256 _edition, //此tokenId的版次
            uint256 _totalEdition,//此艺术id的总版次
            string _uri //metadata（唯一）
            )

#### 根据同一个艺术id添加版次
    
    1. 铸造nft（同上个一样）
    CreateArt(
            uint256 _artId, //艺术Id
            address _creator, //创建者
            uint256 _tokenId, //nft id
            uint256 _edition, //此tokenId的版次
            uint256 _totalEdition,//此艺术id的总版次
            string _uri //metadata（唯一）
            )

#### 前端铸造
    
##### call方法
    1. 根据tokenId 获取 nft 的metadata
    tokenURI(
            uint256 tokenId // nft 的唯一id 
            )
    返回值如：
    ipfs://ipfs/QmTiPcSaJmjB6ZEBWYQMm7keEHQXVm9XsBeeeSRUrft3qB
    请求后的结果为json，按照格式解析即可
   ---
    2. 根据 nft tokenId 获取 nft的版次信息及艺术Id
    tokenArts(
             uint256 tokenId // nft 的唯一id 
             )
    返回值如：
    {
    "artId": "10000", //艺术id
    "edition": "3", //版次信息
    "totalEdition":"10"//总版次
    }
  ---
    3. 根据艺术Id，获取nft作品的版次信息
    getSourceDigitalArt(
                        uint256 _artId //艺术id
                       )
    返回值如：
    {
    "id": "10000", //艺术id
    "assistants": [],//协作者
    "benefits": [],//艺术家与协作者的分成比例
    "creator": "0xDe773dF2FB2830104718b7c04c2d52a1C0AC8DD7",//艺术家，创建人
    "currentEdition": "3",//当前已铸造到的版次
    "totalEdition": "10",//总版次
    "uri": "QmTiPcSaJmjB6ZEBWYQMm7keEHQXVm9XsBeeeSRUrft3qB" //metadata（唯一）
    }
 ---
##### send方法
    
    1. 铸造合约方法
    createArt(
             address[] memory _assistants, //协作者，若无则填写: []
             uint256[] memory _benefits, //分配比例：创建者+协作者，数据精度 4 即 10%为 100
             uint256 _totalEdition, //总版次
            	string memory _uri, //metadata（唯一）
            	uint256 _count //铸造的数量
            ) 
 ---
 
    2. 根据艺术Id铸造（新增版次，若第一次没有把所有的版次创建完）
    addArt(
           uint256 _artId, //艺术Id
           uint256 _count //铸造的数量
           )
 ---
    注：
    1. 根据艺术id铸造，合约会判断是否creator，非次艺术家的艺术Id不可以创建
    2. 合约会判断铸造的本次数量不能大于总版次
    3. 前端调用前，最好也检查下想要铸造的数量是否超出目前的版次
    4. 后端监控日志，可以根据metadata的唯一uri来做唯一索引，metadata uri在合约中也是唯一，不可重复【创建】同样的（非新增版次）
   