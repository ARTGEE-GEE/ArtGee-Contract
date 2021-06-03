const TestNft = artifacts.require("TestNft");

const migration = async (deployer, network, accounts) => {
  await Promise.all([deployToken(deployer, network, accounts)])
}

async function deployToken(deployer, network, accounts) {
  await deployer.deploy(TestNft);
}

module.exports = migration