const Oracle = require("../../artifacts/contracts/ElkDexOracle.sol/ElkDexOracle.json");
const ERC20 = require("../../artifacts/contracts/interfaces/IElkERC20.sol/IElkERC20.json");
const FarmingRewardsAbi = require("../../artifacts/contracts/FarmingRewards.sol/FarmingRewards.json");
const ElkPairAbi = require("../../artifacts/contracts/interfaces/IElkPair.sol/IElkPair.json");

async function deployContractsDep() {
  const FujiElkDexFactory = "0x7941856ab590351ebc48fe9b68f17a3864ab6df5";
  const FujiElkOracle = "0x8D09759d54a17aa31987a68F24fAE2a4C41A3203";
  const RewardTokenAddress = "0x4F2Ef7f322eAA9a70Ec12FA53B47A39025f43DA9"; // MTK5
  const ElkTokenAddress = "0xeEeEEb57642040bE42185f49C52F7E9B38f8eeeE";

  const ElkDexOracle = new ethers.Contract(FujiElkOracle, Oracle.abi, ethers.provider);
  const RewardTokenContract = new ethers.Contract(RewardTokenAddress, ERC20.abi, ethers.provider);
  const ElkToken = new ethers.Contract(ElkTokenAddress, ERC20.abi, ethers.provider);

  // Don't forget to attach these to new address
  const FarmingRewards = new ethers.Contract(
    "0x0000000000000000000000000000000000000000",
    FarmingRewardsAbi.abi,
    ethers.provider,
  );
  const ElkPair = new ethers.Contract("0x0000000000000000000000000000000000000000", ElkPairAbi.abi, ethers.provider);

  const FactoryHelper = await (await ethers.getContractFactory("ElkFactoryHelper")).deploy();
  const FactoryHelperPermissioned = await (await ethers.getContractFactory("ElkFactoryHelperPermissioned")).deploy();

  const FarmFactory = await (
    await ethers.getContractFactory("ElkFarmFactory", {
      libraries: {
        ElkFactoryHelper: FactoryHelper.address,
        ElkFactoryHelperPermissioned: FactoryHelperPermissioned.address,
      },
    })
  ).deploy(ElkDexOracle.address);
  const FarmManager = await (await ethers.getContractFactory("FarmManager")).deploy(FarmFactory.address);

  await FarmFactory.setFee(ethers.utils.parseEther("0.001"));
  await FarmFactory.setManager(FarmManager.address);

  return {
    FarmFactory,
    FarmManager,
    RewardTokenContract,
    RewardTokenAddress,
    ElkToken,
    FarmingRewards,
    ElkPair,
  };
}

module.exports = {
  deployContracts,
};
