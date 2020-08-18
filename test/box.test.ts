import { accounts, contract } from '@openzeppelin/test-environment';
import { expect } from 'chai';

// Load compiled artifacts
const Box = contract.fromArtifact('Box');
const Auth = contract.fromArtifact('Auth');

// Start test block
describe('Box', function () {
    const [owner] = accounts;

    beforeEach(async function () {
        // Deploy a new Box contract for each test

    });

    // Test case
    it('retrieve returns a value previously stored', async function () {
        // Store a value - recall that only the owner account can do this!
        let auth = await Auth.new({ from: owner });
        let box = await Box.new(auth.address, { from: owner });
        await box.store(42, { from: owner });
        let result = await box.retrieve();
        expect((result).toString()).to.equal('42');

        // Test if the returned value is the same one
        // Note that we need to use strings to compare the 256 bit integers
    });
});