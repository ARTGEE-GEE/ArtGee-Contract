### english auction test
    platform: 0x1BECd17aB90562D53b810924a2DA430B91c277C1
    art: 0x092953003FAD455951e630EFCB310EAd21E25CDD
    assist: 0x36399f72BFC53211FE3527FD1F1d6657ac72c447
    english: 0xc4fbc90a46553Fa0e7F5963b76Fa2b8E755E4a7a

    owner: 0xDe773dF2FB2830104718b7c04c2d52a1C0AC8DD7
    to: 0xF00079382099f609DbC37F5A7EA04F14D4eAD67C

    10000000000000000
    15000000000000000
    100

    1. 上架：auction

    2. 拍卖：bid
        截止拍卖小于15 min 顺延 15min

    3. 卖家主动结算：seller for

    4. 拍卖者结算：bidder withdraw

    5. 拍卖者取回拍卖资金（未到保留价）bidder reserve
        
    6. 作品流拍重新上架（没有人拍卖、未到保留价）re auction

    7. 卖家取消拍卖（没有人拍卖、未到保留价）seller cancel

    8. 查看拍卖信息 bidInfos

    9. 拍卖完成后可自由交易 nft transfer test

    10. 状态检查

### fiexed auction test

    1. 上架：auction

    2. 拍卖：bid 、 fixed withdraw
        截止拍卖小于15 min 顺延 15min
        使用一口价，则直接成交

    3. 卖家主动结算：seller for

    4. 拍卖者结算（只要有人参与拍卖，可直接结算）：bidder withdraw

    5. 拍卖者取回拍卖资金（结束后需等待5天）bidder reserve
        
    6. 作品流拍重新上架（没有人拍卖、卖家不想结算）re auction

    7. 卖家取消拍卖（没有人拍卖、卖家不想结算）seller cancel

    8. 查看拍卖信息 bidInfos

    9. 拍卖完成后可自由交易 nft transfer test

    10. 状态检查