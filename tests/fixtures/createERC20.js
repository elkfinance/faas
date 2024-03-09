const { ethers } = require("hardhat");

function pairwise(list) {
  if (list.length < 2) {
    return [];
  }
  let first = list[0],
    rest = list.slice(1),
    pairs = rest.map(function (x) {
      return [first, x];
    });
  return pairs.concat(pairwise(rest));
}

async function createERC20() {
  const [deployer, ...Rest] = await ethers.getSigners();

  const ElkFactory = await ethers.deployContract("ElkFactory", [deployer.address]);
  await ElkFactory.waitForDeployment();

  const dec18 = 3;
  const dec6 = 1;

  let Tokens18 = {};
  let Tokens6 = {};

  for (let i = 1; i < dec18 + 1; i++) {
    let Token = await ethers.deployContract("TestERC20", ["Token" + i.toString(), "T" + i.toString(), 18]);
    await Token.waitForDeployment();
    Tokens18["Token" + i.toString()] = Token;
  }

  for (let i = dec18 + 1; i < dec18 + dec6 + 1; i++) {
    let Token = await ethers.deployContract("TestERC20", ["Token" + i.toString(), "T" + i.toString(), 6]);
    await Token.waitForDeployment();
    Tokens6["Token" + i.toString()] = Token;
  }

  let Tokens = { ...Tokens18, ...Tokens6 };

  const ElkRouter = await ethers.deployContract("ElkRouter", [ElkFactory.target, Object.values(Tokens)[0].target]);
  await ElkRouter.waitForDeployment();

  let Pairs = pairwise(Object.keys(Tokens));
  Pairs = Pairs.map((pair) => {
    return [Tokens[pair[0]], Tokens[pair[1]]];
  });

  let v = ethers.parseUnits("500", "ether");
  let w = ethers.parseUnits("50", "ether");
  let x = ethers.parseUnits("40", "ether");

  Pairs.map(async (pair) => {
    let TokenA = pair[0];
    let TokenB = pair[1];

    await TokenA.approve(ElkRouter.target, v);
    await TokenB.approve(ElkRouter.target, v);

    await ElkRouter.addLiquidity(
      TokenA.target,
      TokenB.target,
      w,
      w,
      x,
      x,
      deployer.address,
      (await ethers.provider.getBlock("latest")).timestamp + 1000,
    );

    Rest.map(async (wallet) => {
      await TokenA.transfer(wallet.address, v);
      await TokenB.transfer(wallet.address, v);

      await TokenA.connect(wallet).approve(ElkRouter.target, v);
      await TokenB.connect(wallet).approve(ElkRouter.target, v);

      await ElkRouter.connect(wallet).addLiquidity(
        TokenA.target,
        TokenB.target,
        w,
        w,
        x,
        x,
        wallet.address,
        (await ethers.provider.getBlock("latest")).timestamp + 1000,
      );
    });
  });

  return {
    ElkFactory,
    Tokens,
    Tokens18,
    Tokens6,
    Pairs,
  };
}

module.exports = {
  createERC20,
};
