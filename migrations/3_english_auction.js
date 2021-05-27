const EnglishAuction = artifacts.require("EnglishAuction");
const ArtGeeNft = artifacts.require("ArtGeeNft");

const migration = async (deployer, network, accounts) => {
  await Promise.all([deployToken(deployer, network, accounts)])
}

async function deployToken(deployer, network, accounts) {
  const artGeeNft = await ArtGeeNft.deployed();
  console.log(`artGeeNft :${artGeeNft.address}`);
  await deployer.deploy(EnglishAuction,artGeeNft.address,accounts[0]);
  const englishAuction = await EnglishAuction.deployed();
  console.log('englishAuction success');
}

module.exports = migration