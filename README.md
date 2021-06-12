### install

    npm install @openzeppelin/contracts
    npm install @truffle/hdwallet-provider

	remix
	remixd -s /Users/wangban/Downloads/money/coin/other/artgee/ArtGee-Contract --remix-ide https://remix.ethereum.org

### deploy

    truffle migration --network {network} (--reset)

### metadate字段
	name			: a
	image			: ipfs://ipfs/Qmassss	（预览图）
	decription		: This is an a
	attributes
		trait_type 	:	Artist
		value		:	A
	properties
		preview_file 			(预览图)
			type			:	string
			description		:	ipfs://ipfs/Qmassss
		preview_file_type
			type			:	mimeType
			description		:	image/jpg
		created_time
			type			:	datetime
			description		:	2021-01-01T11:11:11.111111+00:00
		total_edition
			type			:	int
			description 	:	10
		preview_file2:			(全文件有视频则是视频)
			type			:	string
			description		:	ipfs://ipfs/Qmaaaaa
		preview_file2_type		
			type			:	mimeType
			description		:	video/mp4
		

## 铸造功能：

    1. 无artId，创建 artId
    2. 添加NFT（edition，totalEdition，creator，assistants，uri）
    3. 若多版没铸造完，根据artId添加
    4. nft铸造完成后，只能先上架到artgee market并买卖一次才可以，market地址需要设置
    5. 设置 baseUri
    6. 设置 market 地址
    7. 根据artId获取作品详情
    8. 进制艺术家（地址）再传作品和名单
    9. 暂停所有的创建、添加功能

### 铸造流程

![image](https://github.com/k1ic/ArtGee-Contract/blob/develop/image/zblc.png)

### 铸造合约

    测试网络：rinkeby(chainId:4)
    DigitalSource   存储artId相关信息（前端和后端调用用不到）
    0x3FC3422fC999a5a2D552fEB72bA8026256FdfB5A
    ArtGeeNft       铸造的nft （铸造使用此合约）
    0xBF9cEb21Ac5D1ca86F1F33cF41BddEF56EED5418
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

>
                 
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
    传 send： 
    from  //当前签名地址

#### 前端铸造
    
##### call方法
    1. 根据tokenId 获取 nft 的metadata
    tokenURI(
            uint256 tokenId // nft 的唯一id 
            )
    返回值如：
    ipfs://ipfs/QmTiPcSaJmjB6ZEBWYQMm7keEHQXVm9XsBeeeSRUrft3qB
    请求后的结果为json，按照格式解析即可
   
   >
   
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
  
  >
  
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
	
	4. 获取是否可以自由交易（必须在一口价或英式拍买卖过才可以）
	limitCount(
				uint256 _tokenId //tokenId
			)
	返回值：0 不可以；1可以交易

##### send方法
    
    1. 铸造合约方法
    createArt(
             address[] memory _assistants, //协作者，若无则填写: []
             uint256[] memory _benefits, //分配比例：创建者+协作者，数据精度 3 即 10%为 100, 2.5% 为 25
             uint256 _totalEdition, //总版次
            	string memory _uri, //metadata（唯一）
            	uint256 _count //铸造的数量
            ) 
 >
 
    2. 根据艺术Id铸造（新增版次，若第一次没有把所有的版次创建完）
    addArt(
           uint256 _artId, //艺术Id
           uint256 _count //铸造的数量
           )
 
 >
 
    注：
    1. 根据艺术id铸造，合约会判断是否creator，非次艺术家的艺术Id不可以创建
    2. 合约会判断铸造的本次数量不能大于总版次
    3. 前端调用前，最好也检查下想要铸造的数量是否超出目前的版次
    4. 后端监控日志，可以根据metadata的唯一uri来做唯一索引，metadata uri在合约中也是唯一，不可重复【创建】同样的（非新增版次）

      
---
   
## 交易

拍卖状态： 
0 初始状态; 1 拍卖; 2 买家退款; 3 卖家结算; 4 买家结算；5 卖家取消

	在拍卖之前，前端需要调用nft的setApproveForAll()方法，授权
	
	授权：send()方法
	setApprovalForAll(
					address operator //交易合约: 如：0x1A73D28b3395905e746FFd6f5D98293b1Df775a5
					bool _approved //true
					)
	获取授权状态：call()方法
	isApprovedForAll(
					address owner //自己的地址
					address operator //交易合约
					)


### 英式拍：
	EnglishAuction: 
	1. ****0xEC922D78CC11A5971efEaE8e4c5d7c1462010251**** (作废，此价格使用的是增幅)
	2. 0x96b9a71a1BebeE58248b2F610F0656E406823381 （价格使用增量）
	abi： 📎EnglishAuction.json 在 build/contracts/EnglishAuction.json 文件中

	可配置参数：
	1. artgee nft合约（用于给 artgee 平台的nft分润）、平台合约（收取平台手续费）
	2. 拍卖首次销售和二次销售的百分比，平台收取的手续费
	3. 时间参数：
		低于 15min 补偿15min 的时间参数；
		拍卖最终低于保留价，用户可退回资金的时间 5天后的时间参数；
	
#### 后端日志

	含有 indexed 的数据在topic中解析
	
	1. 上架拍卖
		Auction(
				uint256 indexed _auctionId, //拍卖id
				address _token, //token
	                  uint256 _tokenId, //tokenId
	                  address _seller, //卖家(藏家)
	                  uint256 _openingBid, //起拍价，精度为 1e18 
	                  uint256 _bidIncrements, //增量（在上一次的叫价基础上）精度为 1e18
	                  uint256 _startTime, // 开始时间 时间戳，秒级
	                  uint256 _expirationTime, //结束时间，秒级
	                  uint256 _auctionStatus // 上架状态：0
	                  )
	2. 重新上架
		ReAuction(
				uint256 indexed _auctionId, //拍卖id
				uint256 _bidPrice, //退回价格，若有则退回，没有则为0
                    	uint256 _openingBid, //起拍价，精度为 1e18 
                    	uint256 _bidIncrements, //增量（在上一次的叫价基础上）精度为 1e18
                    	uint256 _startTime, // 开始时间 时间戳，秒级
                    	uint256 _expirationTime, //结束时间，秒级
                    	uint256 _auctionStatus // 拍卖状态：0
                    	)
	3. 拍卖
		Bid(
			uint256 indexed _auctionId, //拍卖id
			address _bidder, // 当前买家
                	uint256 _bidPrice, // 当前叫价
                	uint256 _bidCount, // 已拍卖次数
                	uint256 _expirationTime, //结束时间，秒级
                	uint32 _auctionStatus // 拍卖状态：1
                	);
	4. 卖家主动结算
		Selling(
				uint256 indexed _auctionId, //拍卖id
				address _seller, //卖家
				address _bidder,  // 成交人
				uint256 _bidPrice, // 结算价
				uint32 _auctionStatus, // 拍卖状态：3
				uint256 _bidCount //已拍卖次数
				)
	5. 买家退款
		Reverse(
				uint256 indexed _auctionId, //拍卖id
				address _bidder,  // 成交人
				uint256 _bidPrice,  // 结算价
				uint32 _auctionStatus, // 拍卖状态：2
				uint256 _bidCount //已拍卖次数
				);
	6. 买家结算
		Withdraw(
				uint256 indexed _auctionId, //拍卖id
				address _seller, //卖家
				address _bidder, // 成交人
				uint256 _bidPrice, // 结算价
				uint32 _auctionStatus, // 拍卖状态：4
				uint256 _bidCount //已拍卖次数
				)
	7. 卖家（藏家）取消
		Cancel(
				uint256 indexed _auctionId, //拍卖id
				address _seller, // 卖家
	                  uint256 _bidPrice, //退回价格，若没有需要退回则为0
	                  uint32 _auctionStatus, // 拍卖状态5
					  uint256 _bidCount //已拍卖次数
	                  )


#### 前端调用

##### send方法 
			
	1. 上架
		auction(
				address _token,   //nft 合约地址 
								//如artgee nft：0x662064f5B7A9eFAd3Cd27499d907214e6f78d65F
				uint256 _tokenId, //nft token id
                    	uint256 _openingBid, //起拍价，精度为 1e18 
                    						//如：1.1 eth 则填写 1100000000000000000
                    	uint256 _bidIncrements, //增量（在上一次的叫价基础上）精度为 1e18
                    	uint256 _reservePrice, //保留价，精度为 1e18 
                    	uint256 _startTime, // 开始时间 时间戳，秒级
                    	uint256 _expirationTime //结束时间，秒级
                     )
            	传 send： 
            	from  //当前签名地址
>		
		
	2. 拍卖
		bid(
			uint256 _auctionId  //拍卖id
			)
		传 send： 
		from  //当前签名地址
		value //当前价格，精度为 1e18 如：1.1 eth 则填写 1100000000000000000

>

	3. 卖家主动结算
		sellingSettlementPrice(
							uint256 _auctionId //拍卖id
							)
		传 send： 
		from  //当前签名地址
>
	
	
	4. 买家结算
		withdraw(
				uint256 _auctionId //拍卖id
				)
		传 send： 
		from  //当前签名地址

>

	5. 买家取回拍卖资金（未到保留价）
		bidderReverse(
					uint256 _auctionId //拍卖id
					)
		传 send： 
		from  //当前签名地址

>		

	6. 作品流拍重新上架（没有人拍卖或未到保留价）
		reAuction(
				uint256 _auctionId,  //拍卖id
                        uint256 _openingBid,  //起拍价，精度为 1e18 
                        uint256 _bidIncrements, //增量（在上一次的叫价基础上）精度为 1e18
                        uint256 _reservePrice, //保留价，精度为 1e18 
                        uint256 _startTime, // 开始时间 时间戳，秒级
                        uint256 _expirationTime //结束时间，秒级
                        )

>

	7. 卖家取消拍卖，退回买家的币（没有人参与拍卖或未到保留价）
		cancel(
				uint256 _auctionId  //拍卖id
				)
		传 send： 
		from  //当前签名地址
		
##### call方法

	1. 根据 _auctionId 获取拍卖详情
		bidInfos(
				uint256 _auctionId //拍卖id
				)
		返回值：
		address: token //如：0x662064f5B7A9eFAd3Cd27499d907214e6f78d65F
		uint256: tokenId  //如：8
		address: seller //卖家（藏家）如：0xDe773dF2FB2830104718b7c04c2d52a1C0AC8DD7
		address: bidder //当前买家 如：0xF00079382099f609DbC37F5A7EA04F14D4eAD67C
		uint256: openingBid //起拍价 精度1e18 如：10000000000000000
		uint256: reservePrice //保留价 精度1e18 如：11000000000000000
		uint256: bidIncrements //增量 精度为1e18 如：11000000000000000
		uint256: bidPrice //当前叫价 精度1e18 如：12100000000000000
		uint256: bidCount //已叫次数 如：3
		uint256: startTime //开始时间 时间戳秒级 如：1618489901
		uint256: auctionStatus //拍卖状态： 0 初始状态; 1 拍卖; 2 买家退款;3 卖家结算; 4 买家结算；5 卖家取消
		uint256: expirationTime //结束时间 时间戳秒级 如：1618491150
	
>
	
	2. 获取拍卖的当前价格
		getCurrentPrice(
						uint256 _auctionId //拍卖id
						)
		返回值：
		uint256: _nowBidPrice 当前价格 精度1e18： 12100000000000000

>
		
	3. 获取“我的”拍卖列表，如：可撤销、可退款、可结算，已结算、已撤销、重新上架的不保存
		getMyArtList(
					address _owner // 地址
					)
		返回值：
		uint256[] 如:  [1,2,3,4,5,6]

>		
		
	4. 获取所有的拍卖列表（包括已完成的等）
		getArtList()
		返回值：
		uint256[] 如:  [1,2,3,4,5,6]
	5. 获取买家可退款的延期时间
		reverseTime()
		返回值：
		432000 //秒级
	6. 	获取叫价的超时时间，如叫价时间到结束时间不足15min则，增加15min
		extendTime()
		返回值：
		900 //秒级

---

### 一口价:
	FixedAuction: 0x0F1064086f4585e2D361F6Ba8C8532170Eddf299
	abi： 📎FixedAuction.json 在 build/contracts/FixedAuction.json 文件中

	可配置参数：
	1. artgee nft合约（用于给 artgee 平台的nft分润）、平台合约（收取平台手续费）
	2. 拍卖首次销售和二次销售的百分比，平台收取的手续费
	3. 时间参数：
		结束时间：当有第一个人叫价后，24h结束的时间参数；
		低于 15min 补偿15min 的时间参数；
		拍卖最终低于保留价，用户可退回资金的时间 5天后的时间参数；

#### 后端日志

	1. 上架拍卖
		Auction(uint256 indexed _auctionId, //拍卖id
				address _token, //token
	                  uint256 _tokenId, //tokenId
	                  address _seller,  //卖家(藏家)
	                  uint256 _openingBid, //起拍价，精度为 1e18 
	                  uint256 _fixedPrice, //一口价，精度1e18
	                  uint32 _auctionStatus // 上架状态：0
	                  );
	                    
	 2. 重新上架
	 	ReAuction(uint256 indexed _auctionId, //拍卖id
	                    uint256 _openingBid,  //起拍价，精度为 1e18 
	                    uint256 _fixedPrice,  //一口价，精度1e18 
	                    uint32 _auctionStatus // 上架状态：0
	                    );
	                    
	 3.  拍卖 
	 	Bid(uint256 indexed _auctionId, //拍卖id
	 		address _bidder, //买家
	            uint256 _bidPrice, //叫价，精度为 1e18 
	            uint256 _bidCount, //当前次数
	            uint256 _startTime, //开始时间
	            uint256 _expirationTime,//超时时间
	            uint32 _auctionStatus, //拍卖状态：1
	            );
	            
	  4. 卖家主动结算
	  	 Selling(uint256 indexed _auctionId, //拍卖id
	  	 		address _bidder, //买家
	  	 		uint256 _bidPrice, //结算价格
	  	 		uint32 _auctionStatus // 拍卖状态：3
				uint256 _bidCount //已拍卖次数
	  	 		);
	  	 		
	  5. 买家退款
	  	Reverse(uint256 indexed _auctionId, //拍卖id
	  			address _bidder, //买家
	  			uint256 _bidPrice, //退款价格
	  			uint32 _auctionStatus, // 拍卖状态：2
				uint256 _bidCount //已拍卖次数
	  			);
	  			
	  6. 买家结算(一口价)
	  	Fixed(uint256 indexed _auctionId, //拍卖id
			address _bidder, //买家
			uint256 _bidPrice, //结算价格 去除手续费
			uint32 _auctionStatus, // 拍卖状态：4
			uint256 _bidCount //已拍卖次数
			);
			
	   7.  卖家（藏家）取消
	   	Cancel(uint256 indexed _auctionId, //拍卖id
			address _seller, //卖家
			uint256 _bidPrice,  //退回价格，若没有需要退回则为0
			uint32 _auctionStatus,  // 拍卖状态5
			uint256 _bidCount //已拍卖次数
			);	
   
#### 前端调用

##### send方法
	
	1. 上架拍卖
		auction(address _token,  //token
				uint256 _tokenId,  //tokenId
	                  uint256 _openingBid, //起始价
	                  uint256 _fixedPrice //一口价
	                  )
            	传 send： 
            from  //当前签名地址
           
 >
	
	2. 重新上架
		reAuction(uint256 _auctionId, //拍卖id
				uint256 _openingBid, //起始价
                    	uint256 _fixedPrice //一口价
                    	) 
            传 send： 
            from  //当前签名地址

>	
	
	3. 叫价拍卖
		bid(
			uint256 _auctionId //拍卖id
			) 
		传 send： 
		from  //当前签名地址
	 	value //当前价格 精度1e18（只要大于上一笔价格，小于一口价即可）
>
            
	4. 卖家取消拍卖
		cancel(uint256 _auctionId //拍卖id
				)
	5. 卖家结算
		sellingSettlementPrice(uint256 _auctionId ////拍卖id)
		传 send： 
		from  //当前签名地址
		
	6. 买家退款（当超过结束时间加上规定的延期时间）
		bidderReverse(uint256 _auctionId)
		传 send： 
		from  //当前签名地址
		
	7. 买家一口价
		fixedWithdraw(uint256 _auctionId)
		
		传 send： 
		from  //当前签名地址
 		value //一口价价格 精度1e18
	
#### call 方法

	1. 根据 _auctionId 获取拍卖详情
		bidInfos(
				uint256 _auctionId //拍卖id
				)
		返回值：
		address: token //如：0x662064f5B7A9eFAd3Cd27499d907214e6f78d65F
		uint256: tokenId  //如：8
		address: seller //卖家（藏家）如：0xDe773dF2FB2830104718b7c04c2d52a1C0AC8DD7
		address: bidder //当前买家 如：0xF00079382099f609DbC37F5A7EA04F14D4eAD67C
		uint256: openingBid //起拍价 精度1e18 如：10000000000000000
		uint256: fixedPrice //一口价 精度1e18 如：16000000000000000
		uint256: bidPrice //当前叫价 精度1e18 如：12100000000000000
		uint256: bidCount //已叫次数 如：3
		uint256: startTime //开始时间 时间戳秒级 如：1618489901
		uint256: auctionStatus //拍卖状态： 0 初始状态; 1 拍卖; 2 买家退款;3 卖家结算; 4 买家结算；5 卖家取消
		uint256: expirationTime //结束时间 时间戳秒级 如：1618491150

	>
	
	2. 获取拍卖的当前价格
		getCurrentPrice(
						uint256 _auctionId //拍卖id
						)
		返回值：
		uint256: _nowBidPrice 当前价格 精度1e18： 12100000000000000

>
		
	3. 获取“我的”拍卖列表，只保留可执行的，如：可撤销、可退款、可结算，已结算、已撤销、重新上架的不保存
		getMyArtList(
					address _owner // 地址
					)
		返回值：
		uint256[] 如:  [1,2,3,4,5,6]

>		
		
	4. 获取所有的拍卖列表（包括已完成的等）
		getArtList()
		返回值：
		uint256[] 如:  [1,2,3,4,5,6]

>

	5. 获取买家可退款的延期时间
		reverseTime()
		返回值：
		432000 //秒级

>		
		
	6. 	获取叫价的超时时间，如叫价时间到结束时间不足15min则，增加15min
		extendTime()
		返回值：
		900 //秒级

>
	
	7. 获取开启拍卖后的延期时间 如：上架后开拍后24小时结束
		limitTime


### TEST

	NFT : 0xE16c4dF6Dd9d59cdB5856FD19B63c02247CF3Bc2


### 正式网

	DigitalSource: 0xB1CE6B4cfBd45f1B47A6CFC0cB890131Ed148E52
	artGeeNft: 0x82b648B75862d2B91410a70dBE1236A95a06D3D9
	fixedAuction: 0x424ac434017de5F4e7F9586D6896922b0BA4aACc
	englishAuction: 0x47439d34E6ad9038Eb3f681D802a6E2B4920DE7b