import { ethers, waffle } from 'hardhat';
import { deployContractFixture } from './shared/fixtures';
import { Wallet } from '@ethersproject/wallet';
import { InstantProxy, TestDEX, TestERC20, WETH9 } from '../typechain';
import { expect } from 'chai';
import { calcCryptoFees, calcTokenFees } from './shared/utils';
import { BigNumber as BN, ContractTransaction, BytesLike } from 'ethers';
import * as consts from './shared/consts';
import { balance } from '@openzeppelin/test-helpers';
const hre = require('hardhat');

const createFixtureLoader = waffle.createFixtureLoader;

describe('Instant Proxy Tests', () => {
    let wallet: Wallet, swapper: Wallet;
    let swapToken: TestERC20;
    let transitToken: TestERC20;
    let proxy: InstantProxy;
    let wnative: WETH9;
    let DEX: TestDEX;

    let loadFixture: ReturnType<typeof createFixtureLoader>;

    async function callDex(
        data: BytesLike,
        withFee: boolean,
        {
            router = DEX.address,
            srcInputToken = swapToken.address,
            srcInputAmount = consts.DEFAULT_AMOUNT_IN,
            dstOutputToken = transitToken.address,
            recipient = swapper.address,
            integrator = ethers.constants.AddressZero,
            dstMinOutputAmount = consts.MIN_TOKEN_AMOUNT
        } = {},
        value?: BN
    ): Promise<ContractTransaction> {
        // call with tokens
        if (value === undefined) {
            if (withFee === false) {
                return proxy.dexCall(
                    router,
                    srcInputToken,
                    srcInputAmount,
                    dstOutputToken,
                    recipient,
                    data
                );
            } else {
                value = (
                    await calcCryptoFees({
                        proxy,
                        integrator:
                            integrator === ethers.constants.AddressZero ? undefined : integrator
                    })
                ).totalCryptoFee;
                return proxy.dexCallWithFee(
                    router,
                    srcInputToken,
                    srcInputAmount,
                    dstOutputToken,
                    recipient,
                    integrator,
                    data,
                    { value: value }
                );
            }
        }
        // Native call
        if (withFee === false) {
            return proxy.dexCallNative(
                router,
                srcInputToken,
                srcInputAmount,
                dstOutputToken,
                recipient,
                data,
                { value }
            );
        } else {
            value = (
                await calcCryptoFees({
                    proxy,
                    integrator: integrator === ethers.constants.AddressZero ? undefined : integrator
                })
            ).totalCryptoFee.add(srcInputAmount);
            return proxy.dexCallNativeWithFee(
                router,
                srcInputToken,
                srcInputAmount,
                dstOutputToken,
                recipient,
                integrator,
                data,
                { value: value }
            );
        }
    }

    before('create fixture loader', async () => {
        [wallet, swapper] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([wallet, swapper]);
    });

    beforeEach('deploy fixture', async () => {
        ({ proxy, swapToken, transitToken, wnative, DEX } = await loadFixture(
            deployContractFixture
        ));
    });

    describe('Test call to routers', () => {
        describe('Calls without fees', () => {
            beforeEach('set approvals', async () => {
                proxy = proxy.connect(wallet);
                await transitToken.approve(proxy.address, ethers.constants.MaxUint256);
                await swapToken.approve(proxy.address, ethers.constants.MaxUint256);
            });

            it('Should execute a swap with tokens without fee', async () => {
                callDex();
            });
        });
    });
});
