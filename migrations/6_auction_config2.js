const FixedAuction = artifacts.require("FixedAuction");
const EnglishAuction = artifacts.require("EnglishAuction");
const ArtGeeNft = artifacts.require("ArtGeeNft");

const migration = async (deployer, network, accounts) => {
  await Promise.all([deployToken(deployer, network, accounts)])
}

async function deployToken(deployer, network, accounts) {
  const artGeeNft = await ArtGeeNft.deployed();
  const fixedAuction = await FixedAuction.deployed();
  const englishAuction = await EnglishAuction.deployed();
  console.log('addTransferList start');
  artGeeNft.addTransferList(fixedAuction.address)
  artGeeNft.addTransferList(englishAuction.address)
  console.log('addTransferList success');
  console.log('artGeeNft: '+artGeeNft.address);
  console.log('fixedAuction: '+fixedAuction.address);
  console.log('englishAuction: '+englishAuction.address);
}

module.exports = migration