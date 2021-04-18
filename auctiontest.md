### contract address

    platform: 0x1BECd17aB90562D53b810924a2DA430B91c277C1
    art: 0x092953003FAD455951e630EFCB310EAd21E25CDD
    assist: 0x36399f72BFC53211FE3527FD1F1d6657ac72c447
    english: 0xc4fbc90a46553Fa0e7F5963b76Fa2b8E755E4a7a

    owner: 0xDe773dF2FB2830104718b7c04c2d52a1C0AC8DD7
    to: 0xF00079382099f609DbC37F5A7EA04F14D4eAD67C

    10000000000000000
    15000000000000000
    100

### english auction test

    english: 0x14872823DC81564A5b7fB1aF1c983eb6c792d222
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

    测试：
    1. 卖家上架 
        a. 核对状态、设置开始时间、其他地址竞拍：未到时间显示没开始，到了时间设置价格正常拍卖  √
        b. 卖家地址重新上架：x
            a. 没有人拍卖可重新 √
            b. 已结束且没有到保留价可重新 退款+重新 √
            c. 已经取消不可重新上架 √
            d. 已经成功不可重新上架 √
            e. 正在拍卖不可重新上架 √
        c. 所有操作仅和卖家有关 √
    2. 拍卖
        a. 卖家不可以参与拍卖 √
        b. 买家不可重复拍卖（相邻两次）√
        c. 价格按照增幅计算，错误报错 √
        d. 拍卖会将上一个拍卖退回 √
        e. 拍卖时间到不可在拍卖 √
        f. 所有操作仅和买家相关，卖家不能操作 √
    3. 买家退款
        a. 拍卖时间到，并且到了退款时间（默认5天），并且状态仍为 1 的时候才可以执行 √
        b. 只有当前的买家才可执行 √
    4. 卖家取消（与卖家上架有重合，但是这个需要在结束时才启动）
        a. 若没有人参加拍卖（与时间无关），则可以随时取消，一但有人拍卖，则走b √
        b. 拍卖时间结束（时间维度），若有人拍卖则把金额退回，若买家自己已退回，则直接取回nft √
    5. 成交
        a. 卖家成交，买家报价高于保留价、且已到结束时间 √
        b. 买家成交，到保留价、且已结束 √
    问题：
        可以reauction
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