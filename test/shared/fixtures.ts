import { Fixture } from 'ethereum-waffle';
import { ethers, network, upgrades } from 'hardhat';
import { InstantProxy } from '../../typechain';
import { TestERC20 } from '../../typechain';
import { TestDex } from '../../typechain';
import { WETH9 } from '../../typechain';
import { expect } from 'chai';
import { MAX_TOKEN_AMOUNT, MIN_TOKEN_AMOUNT } from './consts';

interface DeployContractFixture {
    proxy: InstantProxy;
    swapToken: TestERC20;
    transitToken: TestERC20;
    wnative: WETH9;
}

export const deployContractFixture: Fixture<DeployContractFixture> = async function (
    wallets
): Promise<DeployContractFixture> {
    const swapTokenFactory = await ethers.getContractFactory('TestERC20');
    let swapToken = (await swapTokenFactory.deploy()) as TestERC20;
    swapToken = swapToken.connect(wallets[0]);

    let transitToken = (await swapTokenFactory.deploy()) as TestERC20;
    transitToken = transitToken.connect(wallets[0]);

    const wnativeFactory = await ethers.getContractFactory('WETH9');
    let wnative = (await wnativeFactory.deploy()) as WETH9;
    wnative = wnative.connect(wallets[0]);

    const DEXFactory = await ethers.getContractFactory('TestDEX');
    const DEX = (await DEXFactory.deploy()) as TestDEX;

    const proxyFactory = await ethers.getContractFactory('InstantProxy');

    const proxy = (await upgrades.deployProxy(proxyFactory, [
        [DEX.address],
        [transitToken.address, swapToken.address],
        [MIN_TOKEN_AMOUNT, MIN_TOKEN_AMOUNT],
        [MAX_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT]
    ])) as InstantProxy;

    // // part for seting storage
    // const abiCoder = ethers.utils.defaultAbiCoder;

    // const storageBalancePositionSwap = ethers.utils.keccak256(
    //     abiCoder.encode(['address'], [wallets[0].address]) +
    //         abiCoder.encode(['uint256'], [0]).slice(2, 66)
    // );

    // await network.provider.send('hardhat_setStorageAt', [
    //     swapToken.address,
    //     storageBalancePositionSwap,
    //     abiCoder.encode(['uint256'], [ethers.utils.parseEther('100000')])
    // ]);

    // await network.provider.send('hardhat_setStorageAt', [
    //     transitToken.address,
    //     storageBalancePositionSwap,
    //     abiCoder.encode(['uint256'], [ethers.utils.parseEther('100000')])
    // ]);

    expect(await swapToken.balanceOf(wallets[0].address)).to.eq(ethers.utils.parseEther('100000000000'));
    expect(await transitToken.balanceOf(wallets[0].address)).to.eq(
        ethers.utils.parseEther('100000000000')
    );

    await network.provider.send('hardhat_setBalance', [
        DEX.address,
        '0x152D02C7E14AF6800000' // 100000 eth
    ]);

    await transitToken.transfer(DEX.address, ethers.utils.parseEther('100'));
    await swapToken.transfer(DEX.address, ethers.utils.parseEther('100'));

    return {
        proxy,
        swapToken,
        transitToken,
        wnative
    };
};
