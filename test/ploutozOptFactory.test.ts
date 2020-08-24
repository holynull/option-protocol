const { expectRevert, time } = require('@openzeppelin/test-helpers');
import { expect, assert } from 'chai';
import { PloutozOptFactoryContract, PloutozOptFactoryInstance, PloutozOptContractContract, PloutozOptContractInstance } from '../build/types/truffle-types';
// Load compiled artifacts
const PloutozOptFactory: PloutozOptFactoryContract = artifacts.require('PloutozOptFactory.sol');
const PloutozOptContract: PloutozOptContractContract = artifacts.require('PloutozOptContract.sol');
const truffleAssert = require('truffle-assertions');
const Web3Utils = require('web3-utils');
import { getUnixTime, addMonths, addSeconds, fromUnixTime } from 'date-fns';

contract('Ploutoz Option Contract Factory', accounts => {
    const creatorAddress = accounts[0];
    const firstOwnerAddress = accounts[1];

    // Rinkeby Addresses
    const factoryAddress = '0xBbe383201027b5406bf7D0C9aa97103f0a1dEc68';
    const oracleAddress = '0x27F545300F7b93c1c0184979762622Db043b0805';
    const uniswapRouter02Addr = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    const exchangeAddress = '0x4241b47f7Bd37E1b661dF94562424C960eAc58B3';

    // Mainnet Addresses
    // const factoryAddress = '0x8ac0369F69d956f4150013cA7ec07Ca69A01C9e6';
    // const oracleAddress = '0x27F545300F7b93c1c0184979762622Db043b0805';
    // const uniswapRouter02Addr = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    // const exchangeAddress = '0x4241b47f7Bd37E1b661dF94562424C960eAc58B3';

    let factory: PloutozOptFactoryInstance;

    const now = Date.now();
    const expiry = getUnixTime(addMonths(now, 3));
    const windowSize = expiry;

    before('set up factory contracts', async () => {
        factory = await PloutozOptFactory.at(factoryAddress);
    });
    // describe('#addAsset()', () => {
    //     it('should add an asset correctly', async () => {
    //         // Add the asset
    //         const result = await factory.addAsset(
    //             'DAI',
    //             '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359'
    //         );
    //         // check for proper event emitted
    //         truffleAssert.eventEmitted(result, 'AssetAdded', (ev: any) => {
    //             return (
    //                 ev.asset === Web3Utils.keccak256('DAI') &&
    //                 ev.addr === '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359'
    //             );
    //         });
    //         // check the supports Asset function
    //         const supported = await factory.supportsAsset('DAI');

    //         expect(supported).to.be.true;
    //     });

    //     it('should not add ETH', async () => {
    //         try {
    //             const result = await factory.addAsset(
    //                 'ETH',
    //                 '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359'
    //             );
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });

    //     it('fails if anyone but owner tries to add asset', async () => {
    //         try {
    //             await factory.addAsset(
    //                 'BAT',
    //                 '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359',
    //                 { from: factoryAddress }
    //             );
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });

    //     it('fails if an asset is added twice', async () => {
    //         try {
    //             // await util.setBlockNumberForward(8);
    //             await factory.addAsset(
    //                 'DAI',
    //                 '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359'
    //             );
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });

    //     it('should add a second asset correctly', async () => {
    //         // Add the asset
    //         const result = await factory.addAsset(
    //             'BAT',
    //             '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359'
    //         );
    //         // check for proper event emitted
    //         truffleAssert.eventEmitted(result, 'AssetAdded', (ev: any) => {
    //             return (
    //                 ev.asset === Web3Utils.keccak256('BAT') &&
    //                 ev.addr === '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359'
    //             );
    //         });
    //         // check the supports Asset function
    //         const supported = await factory.supportsAsset('BAT');

    //         expect(supported).to.be.true;
    //     });
    // });
    // describe('#changeAsset()', () => {
    //     it('should change an asset that exists correctly', async () => {
    //         const result = await factory.changeAsset(
    //             'BAT',
    //             '0xEd1af8c036fcAEbc5be8FcbF4a85d08F67Ce5Fa1'
    //         );
    //         // check for proper event emitted
    //         truffleAssert.eventEmitted(result, 'AssetChanged', (ev: any) => {
    //             return (
    //                 ev.asset === Web3Utils.keccak256('BAT') &&
    //                 ev.addr === '0xEd1af8c036fcAEbc5be8FcbF4a85d08F67Ce5Fa1'
    //             );
    //         });
    //     });

    //     it("fails if asset doesn't exist", async () => {
    //         try {
    //             const result = await factory.changeAsset(
    //                 'ZRX',
    //                 '0xEd1af8c036fcAEbc5be8FcbF4a85d08F67Ce5Fa1'
    //             );
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });

    //     it('fails if anyone but owner tries to change asset', async () => {
    //         try {
    //             await factory.changeAsset(
    //                 'BAT',
    //                 '0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359',
    //                 { from: firstOwnerAddress }
    //             );
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });
    // });

    // describe('#deleteAsset()', () => {
    //     it('should delete an asset that exists correctly', async () => {
    //         const result = await factory.deleteAsset('BAT');
    //         // check for proper event emitted
    //         truffleAssert.eventEmitted(result, 'AssetDeleted', (ev: any) => {
    //             return ev.asset === Web3Utils.keccak256('BAT');
    //         });
    //     });

    //     it("fails if asset doesn't exist", async () => {
    //         try {
    //             const result = await factory.deleteAsset('ZRX');
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });

    //     it('fails if anyone but owner tries to delete asset', async () => {
    //         try {
    //             await factory.deleteAsset('BAT', { from: firstOwnerAddress });
    //         } catch (err) {
    //             return;
    //         }
    //         truffleAssert.fails('should throw error');
    //     });
    // });


    describe('#createOptionsContract()', () => {
        it('should not allow to create an expired new options contract', async () => {
            const expiredExpiry = '1579111873';

            await expectRevert(
                factory.createOptionsContract(
                    'ETH',
                    -'18',
                    'ETH',
                    -'18',
                    '230.00',
                    -'18',
                    'eth',
                    expiredExpiry,
                    expiredExpiry,
                    { from: creatorAddress, gas: '4000000' }
                ),
                'Cannot create an expired option'
            );
        });

        it('should not allow to create a new options contract where windowSize is bigger than expiry', async () => {
            const bigWindowSize = getUnixTime(addSeconds(fromUnixTime(expiry), 1));

            await expectRevert(
                factory.createOptionsContract(
                    'ETH',
                    -'18',
                    'ETH',
                    -'18',
                    '230',
                    -'17',
                    'ETH',
                    expiry,
                    bigWindowSize,
                    { from: creatorAddress, gas: '4000000' }
                ),
                'Invalid _windowSize'
            );
        });

        it('should create a new options contract correctly', async () => {
            const result = await factory.createOptionsContract(
                'ETH',
                -'18',
                'ETH',
                -'18',
                '230',
                -'17',
                'ETH',
                expiry,
                windowSize,
                { from: creatorAddress, gas: '4000000' }
            );

            // Test that the Factory stores addresses of any new options contract added.
            const index = (
                await factory.getNumberOfOptionsContracts()
            ).toNumber();
            const lastAdded = await factory.optionsContracts(index - 1);

            truffleAssert.eventEmitted(
                result,
                'OptionsContractCreated',
                (ev: any) => {
                    return ev.addr === lastAdded;
                }
            );
        });
        it('anyone else should be able to create a second options contract correctly', async () => {
            const result = await factory.createOptionsContract(
                'ETH',
                -'18',
                'ETH',
                -'18',
                '230',
                -'17',
                'ETH',
                expiry,
                windowSize,
                { from: firstOwnerAddress, gas: '4000000' }
            );

            // Test that the Factory stores addresses of any new options contract added.
            const index = (
                await factory.getNumberOfOptionsContracts()
            ).toNumber();
            const lastAdded = await factory.optionsContracts(index - 1);

            truffleAssert.eventEmitted(
                result,
                'OptionsContractCreated',
                (ev: any) => {
                    return ev.addr === lastAdded;
                }
            );

            // Check the ownership
            const ownerFactory = await factory.owner();
            expect(ownerFactory).to.equal(creatorAddress);

            // TODO: check that the ownership of the options contract is the creator address
            const optionsContractAddr = result.logs[1].args[0];
            const optionContract: PloutozOptContractInstance = await PloutozOptContract.at(optionsContractAddr);

            const optionContractOwner = await optionContract.owner();
            expect(optionContractOwner).to.equal(creatorAddress);
        });
    });

});
