import chai from 'chai'
import * as ethers from 'ethers'
import {deployContract, solidity} from 'ethereum-waffle'
import {expandTo18Decimals, getCreate2Address} from './shared/utilities'

import uShibaSwapRouter from '../build/uShibaSwapRouter.json'
import uShibaSwapPair from '@uShibaProject/uShiba-swap-core/build/uShibaSwapPair.json'
import uShibaToken from '../build/uShibaToken.json'
import uShibaMaster from '../build/uShibaMaster.json'
import BEP20 from '../build/IBEP20.json'
import {MaxUint256} from 'ethers/constants'
import {BigNumber} from 'ethers/utils'

chai.use(solidity)

describe('uShibaSwapRouter', () => {
  const provider = new ethers.providers.JsonRpcProvider('https://data-seed-prebsc-1-s1.binance.org:8545')
  //  const provider = ethers.getDefaultProvider('rinkeby')
  const privateKey = ''
  const wallet = new ethers.Wallet(privateKey, provider)

  let overrides = {
    //        3022211
    gasLimit: 9999999
  }

  const factoryAddress = '0x9A0615b24C8064F26A3030507c2B5f0DB7F975b4'
  const uShibaTokenAddress = '0xdf4c1992b2d1fb169652561a0c5943bfb18759f8'
  const uShibaMasterAddress = '0x1DC9e0e53F6Eb7b609297Ef7b453202425Af3C64'
  const wbnbAddress = '0x094616f0bdfb0b526bd735bf66eca0ad254ca81f'
  const routeAddress = '0x2A942b802258F50810d4914cF2E5c4f9446Da36a'
  const tctAddress = '0xEEa705FDCFe84775A22062043aef1D4cF90A6337'
  const faiAddress = '0x3be02b05ae44e52adfd51e85a30de209c4184051'

  beforeEach(async () => {
    let gasPrice = await provider.getGasPrice()
    console.log(`current gas Price ${gasPrice}`)
    gasPrice = gasPrice.mul(3)
    console.log(`new gas Price ${gasPrice}`)
    overrides = Object.assign(overrides, {gasPrice: gasPrice.toNumber()})
  })

  it('getCreate2Address', function() {
    let create2Address = getCreate2Address(
      '0x569f6163E8453f0d404D8cA3A06367094cF2c97D',
      ['0xc778417e063141139fce010982780140aa0cd5ab', '0xEEa705FDCFe84775A22062043aef1D4cF90A6337'],
      `0x${uShibaSwapPair.evm.bytecode.object}`
    )
    console.log(`${create2Address}`)
    // 0xdef8c40e2f47a2222fc4b7b2caba3bcf5fda57d9
  })

  it('init code hash', function() {
    const hash = ethers.utils.keccak256(`0x${uShibaSwapPair.evm.bytecode.object}`)
    console.log(hash)
    // 0x5ae9ee982df425710823a8b85d98fec3f9c2be462baf6fa6a220c2bd87385760
  })

  it('deployuShibaToken', async () => {
    console.log(`start deployContract uShibaToken`)
    const uShibaToken = await deployContract(wallet, uShibaToken, [], overrides)
    console.log(`contract uShibaToken address ${uShibaToken.address}`)
    console.log(`contract uShibaToken deploy transaction hash ${uShibaToken.deployTransaction.hash}`)
    await uShibaToken.deployed()
    console.log(`finish deployContract uShibaToken`)
    /**
     * start deployContract uShibaToken
     contract uShibaToken address 0xdf4c1992b2d1fb169652561a0c5943bfb18759f8
     contract uShibaToken deploy transaction hash 0xbe6d2ae5ef828346eead79ee8070371f0306f8fea7643687eb68e3d5a8ef9a8f
     finish deployContract uShibaToken
     */
  })

  it('deployuShibaMaster', async () => {
    console.log(`start deployContract uShibaMaster`)
    const devAddress = '0x1DC9e0e53F6Eb7b609297Ef7b453202425Af3C64'
    const uShibaStartBlock = new BigNumber(4).mul(new BigNumber(10).pow(17)) // 一块0.4个
    const startBlock = new BigNumber(1815200)
    const bonusEndBlock = startBlock.add(900000)
    const bonusBeforeBulkBlockSize = new BigNumber(30000)
    const bonusEndBulkBlockSize: BigNumber = bonusEndBlock.sub(startBlock)
    // 0.005
    const bonusBeforeCommonDifference = new BigNumber(300).mul(new BigNumber(10).pow(18)).div(bonusBeforeBulkBlockSize)
    console.log('bonusBeforeCommonDifference ' + bonusBeforeCommonDifference)
    // 0.0003 0.009
    const bonusEndCommonDifference = new BigNumber(150)
      .mul(30)
      .mul(new BigNumber(10).pow(18))
      .div(bonusEndBlock.sub(startBlock))
    const uShibaMaster = await deployContract(
      wallet,
      uShibaMaster,
      [
        uShibaTokenAddress,
        devAddress,
        uShibaStartBlock,
        startBlock,
        bonusEndBlock,
        bonusBeforeBulkBlockSize,
        bonusBeforeCommonDifference,
        bonusEndCommonDifference
      ],
      overrides
    )
    console.log(`contract uShibaMaster address ${uShibaMaster.address}`)
    console.log(`contract uShibaMaster deploy transaction hash ${uShibaMaster.deployTransaction.hash}`)
    await uShibaMaster.deployed()
    console.log(`finish deployContract uShibaMaster`)
    /**
     * start deployContract uShibaMaster
     contract uShibaMaster address 0x8fBb5d22Da828c453843435FBc5E83800d121560
     contract uShibaMaster deploy transaction hash 0x94f2b602942933ab729f83538e43efdcf33d5b41c3c3cf99068ef8ed75058971
     finish deployContract uShibaMaster

     // 0xaf0E97C1a44d8d2cB529301859c3a0cD3E8340f0
     */
  })

  it('deployuShibaSwapRouter', async () => {
    console.log(`start deployContract uShibaSwapRouter`)
    const uShibaSwapRouter = await deployContract(wallet, uShibaSwapRouter, [factoryAddress, wbnbAddress], overrides)
    console.log(`contract uShibaSwapRouter address ${uShibaSwapRouter.address}`)
    console.log(`contract uShibaSwapRouter deploy transaction hash ${uShibaSwapRouter.deployTransaction.hash}`)
    await uShibaSwapRouter.deployed()
    console.log(`finish deployContract uShibaSwapRouter`)
    /**
     * start deployContract uShibaSwapRouter
     contract uShibaSwapRouter address 0x9Dc6617335b1b3e8C5859004D783FD041C42320a
     contract uShibaSwapRouter deploy transaction hash 0x419919f03f9ac28a2b3e38e76984c263ef3b52ad2800b0e48698d779dd7ee2de
     finish deployContract uShibaSwapRouter

     */
  })

  it('transferuShibaTokenOwnershipTouShibaMaster', async () => {
    const uShibaToken = new ethers.Contract(uShibaTokenAddress, JSON.stringify(uShibaToken.abi), provider).connect(
      wallet
    )
    const tx = await uShibaToken.transferOwnership(uShibaMasterAddress, {
      ...overrides,
      value: 0
    })
    console.log(`transferuShibaTokenOwnershipTouShibaMaster ${tx.hash}`)
    await tx.wait()
    // 0x8dc1c3eb682efb9db7f3aa21284da0c47286a8b32e52ad85844be8c956bd86c2
  })
})
