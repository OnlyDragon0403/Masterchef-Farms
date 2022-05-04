const { inputToConfig } = require("@ethereum-waffle/compiler");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

let dai_factory, mai_factory;
describe("MasterChefFarms test", function () {
  beforeEach(async function() {
    [owner , addr1] = await ethers.getSigners();
    // let's assume factorys and routers for dai and mai exist 
    dai_factory, mai_factory;
    const factory_contract = await ethers.getContractFactory("UniswapV2Factory");
    dai_factory = await factory_contract.deploy("0x0");
    console.log("dai", dai_factory);
    mai_factory = await factory_contract.deploy("0x0");
    
  })
  
  describe('UniswapV2Factory', () => {
    console.log("dai", dai_factory);
  })
});
