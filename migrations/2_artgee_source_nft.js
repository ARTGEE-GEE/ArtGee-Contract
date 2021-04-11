const DigitalSource = artifacts.require("DigitalSource");
const ArtGeeNft = artifacts.require("ArtGeeNft");

const migration = async (deployer, network, accounts) => {
  await Promise.all([deployToken(deployer, network, accounts)])
}

async function deployToken(deployer, network, accounts) {
  await deployer.deploy(DigitalSource);
  const digitalSource = await DigitalSource.deployed();
  await deployer.deploy(ArtGeeNft,digitalSource.address);
  const artGeeNft = await ArtGeeNft.deployed();
  console.log(`transferOperator to:${artGeeNft.address}`);
  await digitalSource.transferOperator(artGeeNft.address);
  console.log('transfer success');
}

module.exports = migration