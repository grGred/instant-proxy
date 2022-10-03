import { Fixture } from 'ethereum-waffle';
import { ethers, network, upgrades } from 'hardhat';
import { InstantProxy } from '../../typechain';
import { TestERC20 } from '../../typechain';
import { WETH9 } from '../../typechain';
import TokenJSON from '../../artifacts/contracts/test/TestERC20.sol/TestERC20.json';
import WETHJSON from '../../artifacts/contracts/test/WETH9.sol/WETH9.json';
import { expect } from 'chai';

const envConfig = require('dotenv').config();
const { NATIVE_POLYGON: TEST_NATIVE, SWAP_TOKEN_POLYGON: TEST_SWAP_TOKEN } = envConfig.parsed || {};

interface DeployContractFixture {
    proxy: InstantProxy;
    swapToken: TestERC20;
    wnative: WETH9;
}

export const deployContractFixtureInFork: Fixture<DeployContractFixture> = async function (
    wallets
): Promise<DeployContractFixture> {
    const swapTokenFactory = ethers.ContractFactory.fromSolidity(TokenJSON);
    let swapToken = swapTokenFactory.attach(TEST_SWAP_TOKEN) as TestERC20;
    swapToken = swapToken.connect(wallets[0]);

    const wnativeFactory = ethers.ContractFactory.fromSolidity(WETHJSON);
    let wnative = wnativeFactory.attach(TEST_NATIVE) as WETH9;
    wnative = wnative.connect(wallets[0]);

    const proxyFactory = await ethers.getContractFactory('InstantProxy');

    const proxy = (await upgrades.deployProxy(
        proxyFactory,
        [
            [
                '0x1111111254fb6c44bac0bed2854e76f90643097d',
                '0xE592427A0AEce92De3Edee1F18E0157C05861564',
                '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
                '0x89D6B81A1Ef25894620D05ba843d83B0A296239e',
                '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff'
            ]
        ],
        { initializer: 'initialize' }
    )) as InstantProxy;

    // part for seting storage
    const abiCoder = ethers.utils.defaultAbiCoder;

    const storageBalancePositionSwap = ethers.utils.keccak256(
        abiCoder.encode(['address'], [wallets[0].address]) +
            abiCoder.encode(['uint256'], [0]).slice(2, 66)
    );

    await network.provider.send('hardhat_setStorageAt', [
        swapToken.address,
        storageBalancePositionSwap,
        abiCoder.encode(['uint256'], [ethers.utils.parseEther('100000')])
    ]);

    expect(await swapToken.balanceOf(wallets[0].address)).to.eq(ethers.utils.parseEther('100000'));

    await network.provider.send('hardhat_setBalance', [
        wallets[0].address,
        '0x152D02C7E14AF6800000' // 100000 eth
    ]);

    return {
        proxy,
        swapToken,
        wnative
    };
};
