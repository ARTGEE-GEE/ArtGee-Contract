const FixedAuction = artifacts.require("FixedAuction");
const ArtGeeNft = artifacts.require("ArtGeeNft");

const migration = async (deployer, network, accounts) => {
  await Promise.all([deployToken(deployer, network, accounts)])
}

async function deployToken(deployer, network, accounts) {
  const artGeeNft = await ArtGeeNft.deployed();
  console.log(`artGeeNft :${artGeeNft.address}`);
  await deployer.deploy(FixedAuction,artGeeNft.address,accounts[0]);
  const fixedAuction = await FixedAuction.deployed();
  console.log('fixedAuction success');
}

module.exports = migration