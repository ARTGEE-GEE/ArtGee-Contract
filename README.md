### install

    npm install @openzeppelin/contracts
    npm install @truffle/hdwallet-provider

### deploy

    truffle migration --network {network}


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

    测试网络：rinkeby 
    DigitalSource   存储artId相关信息
    0xA44E7Fe085c02f9620433a84984A564EAFa677D8
    ArtGeeNft       铸造的nft
    0x4E4e42640044094B1f6cDcF369DF66d5f03ad51B