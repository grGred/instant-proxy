import { ethers, waffle } from 'hardhat';
import { deployContractFixture } from './shared/fixtures';
import { Wallet } from '@ethersproject/wallet';
import { InstantProxy, TestERC20, TestSimulator, WETH9 } from '../typechain';
import { expect } from 'chai';
import { FIXED_CRYPTO_FEE } from './shared/consts';
import { BigNumber as BN, BigNumberish, ContractTransaction } from 'ethers';
const hre = require('hardhat');

const createFixtureLoader = waffle.createFixtureLoader;

// const envConfig = require('dotenv').config();
// const {
//
// } = envConfig.parsed || {};

describe('Instant Proxy Tests', () => {
    let wallet: Wallet, other: Wallet;
    let swapToken: TestERC20;
    let transitToken: TestERC20;
    let proxy: InstantProxy;
    let wnative: WETH9;
    // let simulator: TestSimulator;

    let loadFixture: ReturnType<typeof createFixtureLoader>;

    // async function callDex(
    //     data: BytesLike,
    //     {
    //         srcInputToken = swapToken.address,
    //         dstOutputToken = transitToken.address,
    //         integrator = ethers.constants.AddressZero,
    //         recipient = owner.address,
    //         srcInputAmount = consts.DEFAULT_AMOUNT_IN,
    //         dstMinOutputAmount = consts.MIN_TOKEN_AMOUNT,
    //         dstChainID = 228,
    //         router = routerCrossChain.address,
    //         gateway = routerCrossChain.address
    //     } = {},
    //     value?: BN
    // ): Promise<ContractTransaction> {
    //     if (value === undefined) {
    //         // call with tokens
    //         value = (
    //             await calcCryptoFees({
    //                 bridge,
    //                 integrator: integrator === ethers.constants.AddressZero ? undefined : integrator
    //             })
    //         ).totalCryptoFee;

    //         return bridge.routerCall(
    //             consts.DEFAULT_MESSAGE,
    //             {
    //                 srcInputToken,
    //                 srcInputAmount,
    //                 dstChainID,
    //                 dstOutputToken,
    //                 dstMinOutputAmount,
    //                 recipient,
    //                 integrator,
    //                 router
    //             },
    //             gateway,
    //             data,
    //             { value: value }
    //         );
    //     }

    //     value = (
    //         await calcCryptoFees({
    //             bridge,
    //             integrator: integrator === ethers.constants.AddressZero ? undefined : integrator
    //         })
    //     ).totalCryptoFee.add(srcInputAmount);
    //     return bridge.routerCallNative(
    //         consts.DEFAULT_MESSAGE,
    //         {
    //             srcInputToken,
    //             dstOutputToken,
    //             integrator,
    //             recipient,
    //             srcInputAmount,
    //             dstMinOutputAmount,
    //             dstChainID,
    //             router
    //         },
    //         data,
    //         { value: value }
    //     );
    // }

    before('create fixture loader', async () => {
        [wallet, other] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([wallet, other]);
    });

    beforeEach('deploy fixture', async () => {
        ({ proxy, swapToken, transitToken, wnative } = await loadFixture(deployContractFixture));
    });

    describe('#Tests', () => {
        describe('#funcName', () => {
            it('Should do smth', async () => {
                // console.log(await proxy.simulateTransfer("0x8f18dc399594b451eda8c5da02d0563c0b2d0f16", 10000));
                // const abi = [
                //     'AmntReceivedSubAmntExpected(uint256 amountReceived, uint256 amountExpected)'
                // ];
                // // const abi = ['function InsufficientBalance(uint256 available, uint256 required)'];

                // const interface1 = new ethers.utils.Interface(abi);
                // const error_data =
                //     '0x79235e56000000000000000000000000000000000000' +
                //     '0000000000000000000000000100000000000000000000' +
                //     '0000000000000000000000000000000000000100000000';

                // const decoded = interface1.decodeFunctionData(
                //     interface1.functions['AmntReceivedSubAmntExpected(uint256,uint256)'],
                //     error_data
                // );
                console.log('1');
                // console.log(
                //     'Insufficient balance for transfer. ' +
                //         `Needed ${decoded.required.toString()} but only ` +
                //         `${decoded.available.toString()} available.`
                // );
            });
        });
    });
});
