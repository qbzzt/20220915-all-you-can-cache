#! /usr/local/bin/node

const ethers = require("ethers")
const fs = require("fs")
require('dotenv').config()


const rpcProvider = new ethers.providers.JsonRpcProvider(process.env.OPTIMISM_GOERLI_URL)
const hdNode = ethers.utils.HDNode.fromMnemonic(process.env.MNEMONIC)
const privateKey = hdNode.derivePath(ethers.utils.defaultPath).privateKey
const wallet = new ethers.Wallet(privateKey, rpcProvider)

const wormJSON = JSON.parse(fs.readFileSync("../out/WORM.sol/WORM.json"))


const WormFactory = new ethers.ContractFactory(wormJSON.abi, wormJSON.bytecode, wallet)
const worm = WormFactory.attach("0xD34335b1d818ceE54e3323D3246bD31d94E6a78a")

const main = async () => {  
    const func = await worm.WRITE_ENTRY_CACHED() 

    // Need a new key every time
    const key = await worm.encodeVal(Number(new Date()))
    const val = await worm.encodeVal("0x600D")

    // Write an entry
    const calldata = func + key.slice(2) + val.slice(2)
    const tx = await worm.populateTransaction.writeEntryCached()
    tx.data = calldata
    sentTx = await wallet.sendTransaction(tx)

    const txHash = sentTx.hash 

    console.log(`Calldata: \n  ${calldata}`)
    console.log(`  0x  func  ff<- write to cache | ^key (present time)^                       | ^value (cached)`)

    const x = await sentTx.wait()

    console.log(`Write transaction: https://goerli-optimism.etherscan.io/tx/${txHash}\n`)


    // Read the entry just written
    const realKey = '0x' + key.slice(4)  // remove the FF flag
    const entryRead = await worm.readEntry(realKey)
    console.log(`Key: ${realKey}`)
    console.log(`Entry read from the contract:`)
    console.log(`  Value ${entryRead._value.toHexString()}`)
    console.log(`  Written by: https://goerli-optimism.etherscan.io/address/${entryRead._writtenBy}`)
    console.log(`  At block: ${entryRead._writtenAtBlock}`)
}     // main

main().then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })