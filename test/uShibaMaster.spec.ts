import chai from 'chai'
import * as ethers from 'ethers'
import {deployContract, solidity} from 'ethereum-waffle'
import {expandTo18Decimals, getCreate2Address} from './shared/utilities'

import uShibaMaster from '../build/uShibaMaster.json'
import BEP20 from '../build/IBEP20.json'
import {MaxUint256} from 'ethers/constants'

chai.use(solidity)

describe('uShibaMaster', () => {
  const provider = new ethers.providers.JsonRpcProvider('https://data-seed-prebsc-1-s1.binance.org:8545')
  //  const provider = ethers.getDefaultProvider('rinkeby')
  const privateKey = ''
  const wallet = new ethers.Wallet(privateKey, provider)

  let overrides = {
    //        3022211
    gasLimit: 9999999
  }

  const uShibaMasterAddress = '0x1DC9e0e53F6Eb7b609297Ef7b453202425Af3C64'

  beforeEach(async () => {
    let gasPrice = await provider.getGasPrice()
    console.log(`current gas Price ${gasPrice}`)
    gasPrice = gasPrice.mul(3)
    console.log(`new gas Price ${gasPrice}`)
    overrides = Object.assign(overrides, {gasPrice: gasPrice.toNumber()})
  })
  it('poolLength', async () => {
    const uShibaToken = new ethers.Contract(uShibaMasterAddress, JSON.stringify(uShibaMaster.abi), provider).connect(
      wallet
    )
    const poolLength = await uShibaToken.poolLength()
    console.log(`poolLength ${poolLength}`)
  })

  it('massUpdatePools', async () => {
    const uShibaToken = new ethers.Contract(uShibaMasterAddress, JSON.stringify(uShibaMaster.abi), provider).connect(
      wallet
    )
    const tx = await uShibaToken.massUpdatePools()
    console.log(`massUpdatePools ${tx.hash}`)
    await tx.wait()
  })

  it('updatePool', async () => {
    const uShibaToken = new ethers.Contract(uShibaMasterAddress, JSON.stringify(uShibaMaster.abi), provider).connect(
      wallet
    )
    // const tx = await uShibaToken.updatePool('0x809142af759a8c39ab12f85ade543ed8bd3f164b')
    // 0x3dec41b6dd3876a5e08ebaafbcd7b3cca73885e2cc76fe2ddca8feb338cfe405
    const tx = await uShibaToken.updatePool('0x2A942b802258F50810d4914cF2E5c4f9446Da36a')

    console.log(`updatePool ${tx.hash}`)
    await tx.wait()
  })

  it('add', async () => {
    const uShibaToken = new ethers.Contract(uShibaMasterAddress, JSON.stringify(uShibaMaster.abi), provider).connect(
      wallet
    )
    const tx = await uShibaToken.add(1, '0x809142af759a8c39ab12f85ade543ed8bd3f164b', false, {
      ...overrides,
      value: 0
    })
    console.log(`add ${tx.hash}`)
    //  弄错了 0x16dd188d7f0ec52f567a993023bf46a69fb31e29e7bbeb345b414295e25e273d
    // ETH TCT 0x3b69a9b8578619e7c6273eab85df7e82df54cb08709b68955f2f6a654b042f41
    // 0xb921c053c60c5dd56d92e207d5616a0870334bfdca7e77e1fb2a20b5135314dc
    await tx.wait()
  })

  it('set', async () => {
    const uShibaToken = new ethers.Contract(uShibaMasterAddress, JSON.stringify(uShibaMaster.abi), provider).connect(
      wallet
    )
    const tx = await uShibaToken.set('0x2A942b802258F50810d4914cF2E5c4f9446Da36a', 0, false, {
      ...overrides,
      value: 0
    })
    console.log(`set ${tx.hash}`)
    await tx.wait()
    // 0x9c3346e7c831ffa4a6b66d52d95c043baff274cf245b4f31e725e1433379907e
  })
})
