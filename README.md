# Option Protocol

# Rikeby addresses

```
Ploutoz Oracle: 0x9796F90D18F289381f3DBaa6123cdccD2F8AB70d
Ploutoz Factory: 0x1335380779CE4d246C862D6D66CB6A8551ab3a2c
Ploutoz Exchange: 0xda7CA0C409c4E56894E2A9485d4165c9B7c1c6D3
Uniswap Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
Uniswap Router01: 0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
Uniswap Router02: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
COMP Oracle: 0x332b6e69f21acdba5fb3e8dac56ff81878527e06

```

# First Option Contract

```
# admin @ 192 in ~/ploutoz/code/option-protocol on git:master o [16:27:10] C:1
$ npx oz send-tx
? Pick a network rinkeby
? Pick an instance PloutozOptFactory at 0x1335380779CE4d246C862D6D66CB6A8551ab3a2c
? Select which function createOptionsContract(_symbol: string, _name: string, _collateralType: string, _collateralExp: int32, _underlyingType: string, _underlyingExp: int32, _strikePrice: uint256, _s
trikeExp: int32, _strikeAsset: string, _expiry: uint256, _windowSize: uint256)
? _symbol: string: oEthc call 400.00 2020/8/29
? _name: string: oEthc call 400.00 2020/8/29
? _collateralType: string: ETH
? _collateralExp: int32: -18
? _underlyingType: string: USDC
? _underlyingExp: int32: -6
? _strikePrice: uint256: 250
? _strikeExp: int32: -11
? _strikeAsset: string: ETH
? _expiry: uint256: 1598690040000
? _windowSize: uint256: 1598344440000
✓ Transaction successful. Transaction hash: 0xafea4da6ccb7dae59c0d1e2c8d1c49b5f654d5c2daf2c441a6963e0e9233e0c3
Events emitted: 
 - OptionsContractCreated(0xF83A5e34891670637bE3B592d8eDa1ba54e8013f)
```