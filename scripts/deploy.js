const hre = require("hardhat");

async function main() {
  // const factoryInsantProxy = await hre.ethers.getContractFactory("InsantProxy");

  // const deployInsantProxy = await upgrades.deployProxy(factoryInsantProxy,);

  // await deployInsantProxy.deployed();

  // console.log("deployed to:", deployInsantProxy.address);

  // await new Promise(r => setTimeout(r, 10000));

  await hre.run("verify:verify", {
    address: "0xe7B538FA9268D22f9E9654c86B3061000a817f78",
    constructorArguments: [],
  });

  // const upgraded = await upgrades.upgradeProxy('0xe7B538FA9268D22f9E9654c86B3061000a817f78', factoryInsantProxy);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
