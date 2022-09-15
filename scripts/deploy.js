const hre = require("hardhat");

async function main() {
  const factoryInsantProxy = await hre.ethers.getContractFactory("InsantProxy");

  const deployInsantProxy = await upgrades.deployProxy(factoryInsantProxy,);

  await deployInsantProxy.deployed();

  console.log("deployed to:", deployInsantProxy.address);

  await new Promise(r => setTimeout(r, 10000));

    await hre.run("verify:verify", {
    address: '0x4bad00ab533ef43b8aa70bc17352bd852675136f',
    constructorArguments: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
