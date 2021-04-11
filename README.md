### install

    yarn
    npm install @openzeppelin/contracts
    npm install @truffle/hdwallet-provider

### deploy

    truffle migration --network {network}


#### 铸造功能

    1. 无artId，创建 artId
    2. 添加NFT（edition，totalEdition，creator，assistants，uri）
    3. 若多版没铸造完，根据artId添加
    4. nft铸造完成后，只能先上架到artgee market并买卖一次才可以，market地址需要设置
    5. 设置baseUri
    6. 

    测试网络：rinkeby 
    DigitalSource   存储artId相关信息
    0xcb9f0f9EA6Df47B70395f11339dB68DB29109B9c
    ArtGeeNft       铸造的nft
    0x7c9D8016D78905CbaB4243c62aF2C7d81cFAcE82