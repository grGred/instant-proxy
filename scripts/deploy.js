const hre = require("hardhat");

async function main() {
  // const factoryInsantProxy = await hre.ethers.getContractFactory("InsantProxy");

  // const deployInsantProxy = await upgrades.deployProxy(factoryInsantProxy, [
  //   [
  //     '0x1111111254fb6c44bac0bed2854e76f90643097d',
  //     '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  //     '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
  //     '0x89D6B81A1Ef25894620D05ba843d83B0A296239e',
  //     '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff'
  //   ]
  // ]);

  // await deployInsantProxy.deployed();

  // console.log("deployed to:", deployInsantProxy.address);

  // await new Promise(r => setTimeout(r, 10000));

  // await hre.run("verify:verify", {
  //   address: "0xe7B538FA9268D22f9E9654c86B3061000a817f78",
  //   constructorArguments: [ [] ],
  // });

  // const upgraded = await upgrades.upgradeProxy('0xD2e468685b4389c4e6aDbF8C6C9d1a3f5A00df83', factoryInsantProxy);

  // verify implementation
  // await hre.run("verify:verify", {
  //   address: '0xC92C82CFf373ADb385f92f67A9A19A113cDc681B',
  //   constructorArguments: [],
  // });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
