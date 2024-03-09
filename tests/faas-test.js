const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { deployContracts } = require("./fixtures/deployContracts");
const { ethers } = require("hardhat");
const FarmArtifact = require("../artifacts/contracts/ElkV2FarmingRewards.sol/ElkV2FarmingRewards.json");
const ElkPairData = require("../artifacts/@elkdex/avax-exchange-contracts/contracts/elk-core/ElkPair.sol/ElkPair.json");

describe("Faas Test", function () {
  describe("Scenario 1", function () {
    let ElkDexOracle, FarmFactory, FarmManager, Token1, Token2, PairA;

    let farm, farmContract;

    before(async () => {
      let Tokens;

      ({ ElkDexOracle, FarmFactory, FarmManager, ElkFactory, Tokens } = await loadFixture(deployContracts));

      Token1 = Tokens["Token1"];
      Token2 = Tokens["Token2"];

      PairA = new ethers.Contract(
        await ElkFactory.getPair(Token1.target, Token2.target),
        ElkPairData.abi,
        ethers.provider,
      );
    });

    it("Should successfully create a farm with various combinations of fees.", async () => {
      const [deployer, ...Rest] = await ethers.getSigners();

      // deploy farm
      const coverageAmount = 0;
      const coverageVestingDuration = 0;
      const rewardTokenAddresses = [Token1.target, Token2.target];
      const rewardsDuration = 2592000;

      // random fee length and values
      let maxFee = 2000;
      let range = 2000000;
      let schedule = Math.floor(Math.random() * 10) + 1;

      let depositFeeBps = Math.floor(Math.random() * maxFee + 1);

      let withdrawalFeesBps = [];
      let withdrawalFeeSchedule = [];
      let lastSchedule = 0;
      let lastBps = 0;

      while (withdrawalFeeSchedule.length < schedule) {
        lastSchedule = Math.floor(Math.random() * (range - lastSchedule + 1) + lastSchedule);
        lastBps = Math.floor(Math.random() * (maxFee - lastBps + 1) + lastBps);

        if (withdrawalFeesBps.includes(lastBps) || withdrawalFeeSchedule.includes(lastSchedule)) {
          lastSchedule++;
          lastBps++;
        }

        withdrawalFeeSchedule.push(lastSchedule);
        withdrawalFeesBps.unshift(lastBps);

        if (lastBps == maxFee || lastSchedule == range) {
          break;
        }
      }

      await expect(
        FarmFactory.createNewRewards(
          ElkDexOracle.target,
          PairA.target,
          "0x0000000000000000000000000000000000000000",
          coverageAmount,
          coverageVestingDuration,
          rewardTokenAddresses,
          rewardsDuration,
          depositFeeBps,
          withdrawalFeesBps,
          withdrawalFeeSchedule,
        ),
      ).to.emit(FarmFactory, "ContractCreated");

      farm = await FarmFactory.getFarm(deployer.address, PairA.target);
      farmContract = new ethers.Contract(farm, FarmArtifact.abi, ethers.provider);

      expect(farm).to.be.a.properAddress;
    });

    it("Should deposit LP from multiple wallets - including the wallet the farm was created with.", async () => {
      const [deployer, ...Rest] = await ethers.getSigners();

      const rewards = [ethers.parseUnits("1000", "ether"), ethers.parseUnits("1000", "ether")];
      const duration = 2592000;

      // approve rewards and start farm to allow staking
      await Token1.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));
      await Token2.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));

      await expect(FarmManager.startEmission(farm, rewards, duration))
        .to.emit(farmContract, "RewardsEmissionStarted")
        .withArgs(rewards, duration);

      // stake half of LP
      let lpBalance = BigInt(((await PairA.balanceOf(deployer.address)) / BigInt(2)).toString());

      //stake LP from deployer wallet
      await PairA.connect(deployer).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
      await expect(farmContract.connect(deployer).stake(lpBalance)).to.emit(farmContract, "Staked");

      // random # between 1 and 18
      // Math.floor(Math.random() * ((y-x) + 1) + x)
      const rand = Math.floor(Math.random() * 19);

      // stake lp with a random amount of wallets
      for (let i = 0; i < rand; i++) {
        lpBalance = BigInt(((await PairA.balanceOf(Rest[i].address)) / BigInt(2)).toString());

        await PairA.connect(Rest[i]).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
        await expect(farmContract.connect(Rest[i]).stake(lpBalance)).to.emit(farmContract, "Staked");
      }
    });

    describe("Should do random operations.", function () {
      let ops = [0, 1, 2, 3, 4, 5];
      let selected;

      let lpBalance;

      while (ops.length) {
        let ts;
        let pf;

        selected = ops[Math.floor(Math.random() * ops.length)];

        switch (selected) {
          case 0:
            it("Should call getRewards() with multiple wallets.", async () => {
              const [deployer, ...Rest] = await ethers.getSigners();

              // get rewards with deployer wallet
              if (await farmContract.rewards(Token1.target, deployer.address)) {
                await expect(farmContract.connect(deployer).getRewards(deployer.address)).to.emit(
                  farmContract,
                  "RewardPaid",
                );
              } else {
                await farmContract.connect(deployer).getRewards(deployer.address);
              }

              // get rewards with all wallets
              await getRewards(Rest, farmContract, { TokenA: Token1, TokenB: Token2 });
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 1:
            it("Should withdrawl LP and deposit again with multple wallets.", async () => {
              const [deployer, ...Rest] = await ethers.getSigners();

              // withdrawl lp with deployer wallet
              lpBalance = await farmContract.balances(deployer.address);
              let withdrawlFee = await farmContract.withdrawalFee(deployer.address, lpBalance);

              await expect(farmContract.connect(deployer).withdraw(lpBalance))
                .to.emit(farmContract, "Withdrawn")
                .withArgs(deployer.address, lpBalance - withdrawlFee);

              // withdrawl lp with random wallets
              for (let i = 0; i < Rest.length; i++) {
                lpBalance = await farmContract.balances(Rest[i].address);

                if (lpBalance) {
                  withdrawlFee = await farmContract.withdrawalFee(Rest[i].address, lpBalance);

                  await expect(farmContract.connect(Rest[i]).withdraw(lpBalance))
                    .to.emit(farmContract, "Withdrawn")
                    .withArgs(Rest[i].address, lpBalance - withdrawlFee);
                }
              }

              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              if (ts < pf) {
                // deposit new lp with deployer wallet
                lpBalance = BigInt(((await PairA.balanceOf(deployer.address)) / BigInt(2)).toString());

                await PairA.connect(deployer).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
                await expect(farmContract.connect(deployer).stake(lpBalance)).to.emit(farmContract, "Staked");

                // random # between 1 and 18
                const rand2 = Math.floor(Math.random() * 19);

                // stake lp with a random amount of wallets
                for (let i = 0; i < rand2; i++) {
                  lpBalance = BigInt(((await PairA.balanceOf(Rest[i].address)) / BigInt(2)).toString());

                  await PairA.connect(Rest[i]).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
                  await expect(farmContract.connect(Rest[i]).stake(lpBalance)).to.emit(farmContract, "Staked");
                }
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 2:
            it("Should deposit LP and then getRewards()", async () => {
              const [deployer, ...Rest] = await ethers.getSigners();

              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              lpBalance = BigInt(((await PairA.balanceOf(deployer.address)) / BigInt(2)).toString());
              await PairA.connect(deployer).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));

              if (ts < pf) {
                // deposit new lp with deployer wallet
                await expect(farmContract.connect(deployer).stake(lpBalance)).to.emit(farmContract, "Staked");

                // random # between 1 and 18
                const rand = Math.floor(Math.random() * 19);

                // stake lp with a random amount of wallets
                for (let i = 0; i < rand; i++) {
                  lpBalance = BigInt(((await PairA.balanceOf(Rest[i].address)) / BigInt(2)).toString());

                  await PairA.connect(Rest[i]).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
                  await expect(farmContract.connect(Rest[i]).stake(lpBalance)).to.emit(farmContract, "Staked");
                }
              } else {
                // deposit new lp with deployer wallet - should revert because farm is not emitting
                await expect(farmContract.connect(deployer).stake(lpBalance)).to.be.reverted;
              }

              // get rewards with all wallets
              await getRewards(Rest, farmContract, { TokenA: Token1, TokenB: Token2 });

              // get rewards with deployer wallet
              if (await farmContract.rewards(Token1.target, deployer.address)) {
                await expect(farmContract.connect(deployer).getRewards(deployer.address)).to.emit(
                  farmContract,
                  "RewardPaid",
                );
              } else {
                // still call but event will not be emitted without rewards
                await farmContract.connect(deployer).getRewards(deployer.address);
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 3:
            it("Should start emissions.", async () => {
              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              // approve rewards and start farm to allow staking
              await Token1.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));
              await Token2.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));

              const rewards = [ethers.parseUnits("1000", "ether"), ethers.parseUnits("1000", "ether")];
              const duration = 2592000;

              // check if current block is after farm's period finish
              if (ts >= pf) {
                await expect(FarmManager.startEmission(farm, rewards, duration))
                  .to.emit(farmContract, "RewardsEmissionStarted")
                  .withArgs(rewards, duration);
              } else {
                // should revert because farm is emitting
                await expect(FarmManager.startEmission(farm, rewards, duration)).to.be.reverted;
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 4:
            it("Should stop emissions.", async () => {
              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              // check if current block is before farm's period finish
              if (ts <= pf) {
                await expect(FarmManager.stopEmission(farm)).to.emit(farmContract, "RewardsEmissionEnded");
              } else {
                // should revert because farm is not emitting
                await expect(FarmManager.stopEmission(farm)).to.be.reverted;
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 5:
            it("Should claim fees using FarmManager.", async () => {
              let fees = await farmContract.collectedFees();

              await expect(FarmManager.recoverFees(farm)).to.emit(farmContract, "FeesRecovered").withArgs(fees);
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          default:
            console.log("default");
            break;
        }
      }
    });
  });

  describe("Scenario 2", function () {
    let ElkDexOracle, FarmFactory, FarmManager, Token3, Token4, PairB;

    let farm, farmContract;

    before(async () => {
      let Tokens;

      ({ ElkDexOracle, FarmFactory, FarmManager, ElkFactory, Tokens } = await loadFixture(deployContracts));

      Token3 = Tokens["Token3"];
      Token4 = Tokens["Token4"];
      PairB = new ethers.Contract(
        await ElkFactory.getPair(Token3.target, Token4.target),
        ElkPairData.abi,
        ethers.provider,
      );
    });

    it("Should successfully create a farm using tokens with differing decimals.", async () => {
      const [deployer, ...Rest] = await ethers.getSigners();

      // deploy farm
      const coverageAmount = 0;
      const coverageVestingDuration = 0;
      const rewardTokenAddresses = [Token3.target, Token4.target]; // 18 dec and 6 dec
      const rewardsDuration = 2592000;
      const depositFeeBps = 100;
      const withdrawalFeesBps = [2000, 1000, 0];
      const withdrawalFeeSchedule = [648000, 1296000, 1944000];

      await expect(
        FarmFactory.createNewRewards(
          ElkDexOracle.target,
          PairB.target,
          "0x0000000000000000000000000000000000000000", // no coverage
          coverageAmount,
          coverageVestingDuration,
          rewardTokenAddresses,
          rewardsDuration,
          depositFeeBps,
          withdrawalFeesBps,
          withdrawalFeeSchedule,
        ),
      ).to.emit(FarmFactory, "ContractCreated");

      farm = await FarmFactory.getFarm(deployer.address, PairB.target);
      farmContract = new ethers.Contract(farm, FarmArtifact.abi, ethers.provider);

      expect(farm).to.be.a.properAddress;
    });

    it("Should deposit LP from multiple wallets - including the wallet the farm was created with.", async () => {
      const [deployer, ...Rest] = await ethers.getSigners();

      const rewards = [ethers.parseUnits("1000", "ether"), ethers.parseUnits("1000", "ether")];
      const duration = 2592000;

      // approve rewards and start farm to allow staking
      await Token3.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));
      await Token4.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));

      await expect(FarmManager.startEmission(farm, rewards, duration))
        .to.emit(farmContract, "RewardsEmissionStarted")
        .withArgs(rewards, duration);

      // stake half of LP
      let lpBalance = BigInt(((await PairB.balanceOf(deployer.address)) / BigInt(2)).toString());

      //stake LP from deployer wallet
      await PairB.connect(deployer).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
      await expect(farmContract.connect(deployer).stake(lpBalance)).to.emit(farmContract, "Staked");

      // random # between 1 and 18
      // Math.floor(Math.random() * ((y-x) + 1) + x)
      const rand = Math.floor(Math.random() * 19);

      // stake lp with a random amount of wallets
      for (let i = 0; i < rand; i++) {
        lpBalance = BigInt(((await PairB.balanceOf(Rest[i].address)) / BigInt(2)).toString());

        await PairB.connect(Rest[i]).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
        await expect(farmContract.connect(Rest[i]).stake(lpBalance)).to.emit(farmContract, "Staked");
      }
    });

    describe("Should do random operations.", function () {
      let ops = [0, 1, 2, 3, 4];
      let selected;

      let lpBalance;

      while (ops.length) {
        let ts;
        let pf;

        selected = ops[Math.floor(Math.random() * ops.length)];

        switch (selected) {
          case 0:
            it("Should call getRewards() with multiple wallets.", async () => {
              const [deployer, ...Rest] = await ethers.getSigners();

              // get rewards with deployer wallet
              if (await farmContract.rewards(Token3.target, deployer.address)) {
                await expect(farmContract.connect(deployer).getRewards(deployer.address)).to.emit(
                  farmContract,
                  "RewardPaid",
                );
              } else {
                // still call but event will not be emitted without rewards
                await farmContract.connect(deployer).getRewards(deployer.address);
              }

              // get rewards with all wallets
              await getRewards(Rest, farmContract, { TokenA: Token3, TokenB: Token4 });
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 1:
            it("Should withdrawl LP and deposit again with multple wallets.", async () => {
              const [deployer, ...Rest] = await ethers.getSigners();

              // withdrawl lp with deployer wallet
              lpBalance = await farmContract.balances(deployer.address);
              let withdrawlFee = await farmContract.withdrawalFee(deployer.address, lpBalance);

              await expect(farmContract.connect(deployer).withdraw(lpBalance))
                .to.emit(farmContract, "Withdrawn")
                .withArgs(deployer.address, lpBalance - withdrawlFee);

              // withdrawl lp with random wallets
              for (let i = 0; i < Rest.length; i++) {
                lpBalance = await farmContract.balances(Rest[i].address);

                if (lpBalance) {
                  withdrawlFee = await farmContract.withdrawalFee(Rest[i].address, lpBalance);

                  await expect(farmContract.connect(Rest[i]).withdraw(lpBalance))
                    .to.emit(farmContract, "Withdrawn")
                    .withArgs(Rest[i].address, lpBalance - withdrawlFee);
                }
              }

              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              if (ts < pf) {
                // deposit new lp with deployer wallet
                lpBalance = BigInt(((await PairB.balanceOf(deployer.address)) / BigInt(2)).toString());

                await PairB.connect(deployer).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
                await expect(farmContract.connect(deployer).stake(lpBalance)).to.emit(farmContract, "Staked");

                // random # between 1 and 18
                const rand2 = Math.floor(Math.random() * 19);

                // stake lp with a random amount of wallets
                for (let i = 0; i < rand2; i++) {
                  lpBalance = BigInt(((await PairB.balanceOf(Rest[i].address)) / BigInt(2)).toString());

                  await PairB.connect(Rest[i]).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
                  await expect(farmContract.connect(Rest[i]).stake(lpBalance)).to.emit(farmContract, "Staked");
                }
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 2:
            it("Should deposit LP and then getRewards()", async () => {
              const [deployer, ...Rest] = await ethers.getSigners();

              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              lpBalance = BigInt(((await PairB.balanceOf(deployer.address)) / BigInt(2)).toString());
              await PairB.connect(deployer).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));

              if (ts < pf) {
                // deposit new lp with deployer wallet
                await expect(farmContract.connect(deployer).stake(lpBalance)).to.emit(farmContract, "Staked");

                // random # between 1 and 18
                const rand = Math.floor(Math.random() * 19);

                // stake lp with a random amount of wallets
                for (let i = 0; i < rand; i++) {
                  lpBalance = BigInt(((await PairB.balanceOf(Rest[i].address)) / BigInt(2)).toString());

                  await PairB.connect(Rest[i]).approve(farm, ethers.parseUnits(lpBalance.toString(), "ether"));
                  await expect(farmContract.connect(Rest[i]).stake(lpBalance)).to.emit(farmContract, "Staked");
                }
              } else {
                // deposit new lp with deployer wallet - should revert because farm is not emitting
                await expect(farmContract.connect(deployer).stake(lpBalance)).to.be.reverted;
              }

              // get rewards with all wallets
              await getRewards(Rest, farmContract, { TokenA: Token3, TokenB: Token4 });

              // get rewards with deployer wallet
              if (await farmContract.rewards(Token3.target, deployer.address)) {
                await expect(farmContract.connect(deployer).getRewards(deployer.address)).to.emit(
                  farmContract,
                  "RewardPaid",
                );
              } else {
                // still call but event will not be emitted without rewards
                await farmContract.connect(deployer).getRewards(deployer.address);
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 3:
            it("Should start emissions.", async () => {
              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              // approve rewards and start farm to allow staking
              await Token3.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));
              await Token4.approve(FarmManager.target, ethers.parseUnits("1000", "ether"));

              const rewards = [ethers.parseUnits("1000", "ether"), ethers.parseUnits("1000", "ether")];
              const duration = 2592000;

              // check if current block is after farm's period finish
              if (ts >= pf) {
                await expect(FarmManager.startEmission(farm, rewards, duration))
                  .to.emit(farmContract, "RewardsEmissionStarted")
                  .withArgs(rewards, duration);
              } else {
                // should revert because farm is emitting
                await expect(FarmManager.startEmission(farm, rewards, duration)).to.be.reverted;
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          case 4:
            it("Should stop emissions.", async () => {
              ts = BigInt((await ethers.provider.getBlock("latest")).timestamp);
              pf = await farmContract.periodFinish();

              // check if current block is before farm's period finish
              if (ts <= pf) {
                await expect(FarmManager.stopEmission(farm)).to.emit(farmContract, "RewardsEmissionEnded");
              } else {
                // should revert because farm is not emitting
                await expect(FarmManager.stopEmission(farm)).to.be.reverted;
              }
            });

            ops = ops.filter((n) => {
              return n != selected;
            });
            break;

          default:
            console.log("default");
            break;
        }
      }
    });
  });
});

async function getRewards(Rest, farmContract, Tokens) {
  let tokenABalance;
  let tokenBBalance;
  let paidA;
  let paidB;
  let expA;
  let expB;

  const { TokenA, TokenB } = Tokens;

  for (let i = 0; i < Rest.length; i++) {
    // get wallet balance
    let earned = await farmContract.rewards(TokenA.target, Rest[i].address);

    if (earned) {
      // starting reference balances
      tokenABalance = await TokenA.balanceOf(Rest[i].address);
      tokenBBalance = await TokenB.balanceOf(Rest[i].address);

      // // save paid amount before get rewards is called
      // paidA = await farmContract.userRewardPerTokenPaid(TokenA.target, Rest[i].address)
      // paidB = await farmContract.userRewardPerTokenPaid(TokenB.target, Rest[i].address)

      paidA = await farmContract.earned(TokenA.target, Rest[i].address);
      paidB = await farmContract.earned(TokenB.target, Rest[i].address);

      await expect(farmContract.connect(Rest[i]).getRewards(Rest[i].address)).to.emit(farmContract, "RewardPaid");

      // // calculate expected reward amounts based on current rewardPerToken and previous paid amounts
      // expA = (Balance * (await farmContract.rewardPerToken(TokenA.target) - paidA)) /
      // BigInt(10) ** (await TokenA.decimals())

      // expB = (Balance * (await farmContract.rewardPerToken(TokenB.target) - paidB)) /
      // BigInt(10) ** (await TokenB.decimals())

      // expect((await TokenA.balanceOf(Rest[i].address)) - tokenABalance).to.be.equal(expA)
      // expect((await TokenB.balanceOf(Rest[i].address)) - tokenBBalance).to.be.equal(expB)

      expect((await TokenA.balanceOf(Rest[i].address)) - tokenABalance).to.be.greaterThanOrEqual(paidA);
      expect((await TokenB.balanceOf(Rest[i].address)) - tokenBBalance).to.be.greaterThanOrEqual(paidB);
    }
  }
}
