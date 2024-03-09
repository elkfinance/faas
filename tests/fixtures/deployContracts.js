const Oracle = require("../../artifacts/contracts/ElkDexOracle.sol/ElkDexOracle.json");
const ERC20 = require("../../artifacts/contracts/interfaces/IElkERC20.sol/IElkERC20.json");
const FarmingRewardsAbi = require("../../artifacts/contracts/ElkV2FarmingRewards.sol/ElkV2FarmingRewards.json");
const ElkPairAbi = require("../../artifacts/contracts/interfaces/IElkPair.sol/IElkPair.json");

const { createERC20 } = require("./createERC20");
const { ethers } = require("hardhat");

async function deployContracts() {
  const { ElkFactory, Tokens, Tokens18, Tokens6, Pairs } = await createERC20();

  const ElkDexOracle = await ethers.deployContract("ElkDexOracle", [
    Tokens["Token1"].target,
    ElkFactory.target,
    86400,
    24,
  ]);
  await ElkDexOracle.waitForDeployment();

  const FactoryHelper = await ethers.deployContract("ElkV2FactoryHelper");
  await FactoryHelper.waitForDeployment();

  const FactoryHelperPermissioned = await ethers.deployContract("ElkV2FactoryHelperPermissioned");
  await FactoryHelperPermissioned.waitForDeployment();

  const FarmFactory = await ethers.deployContract(
    "ElkV2FarmFactory",
    [[ElkDexOracle.target], Tokens["Token1"].target],
    {
      libraries: {
        ElkV2FactoryHelper: FactoryHelper.target,
        ElkV2FactoryHelperPermissioned: FactoryHelperPermissioned.target,
      },
    },
  );

  await FarmFactory.waitForDeployment();

  const FarmManager = await ethers.deployContract("ElkV2FarmManager", [FarmFactory.target, 1]);
  await FarmManager.waitForDeployment();

  await FarmFactory.setFee(0);
  await FarmFactory.setManager(FarmManager.target);

  return {
    ElkDexOracle,
    FarmFactory,
    FarmManager,
    ElkFactory,
    Tokens,
    Tokens18,
    Tokens6,
    Pairs,
  };
}

module.exports = {
  deployContracts,
};
