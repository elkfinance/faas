const hre = require("hardhat");
const { expect } = require("chai");
const FarmFactoryArtifact = require("../artifacts/contracts/ElkFarmFactory.sol/ElkFarmFactory.json");
const FarmArtifact = require("../artifacts/contracts/FarmingRewards.sol/FarmingRewards.json");
const FarmManagerArtifact = require("../artifacts/contracts/FarmManager.sol/FarmManager.json");
const ERC20 = require("../artifacts/contracts/interfaces/IElkERC20.sol/IElkERC20.json");
// const ElkPair = require('../artifacts/@elkdex/eth-exchange-contracts/contracts/elk-core/IElkPair.sol/IElkPair.json')
const { Signer } = require("ethers");

//Fee for singlestake and farmingrewards

describe("FaaS Test", function () {
  const _elkToken = "0xeEeEEb57642040bE42185f49C52F7E9B38f8eeeE";

  const _lpTokenAddress = "0x8b131B34fa09D3A76D9833085258D8a014124719"; // Elk-USDC pair
  // const _lpTokenAddress = "0x4084E79Fcd4ce5b4A747377CAa78115537d32bd7"; // avax testnet ELP Usdc-Elk

  const _coverageTokenAddress = _elkToken;
  const _coverageAmount = hre.ethers.utils.parseEther("1");
  const _coverageVestingDuration = 2592000;

  const _rewardsTokenAddresses = [_elkToken, "0xc7198437980c041c805A1EDcbA50c1Ce5db95118"]; // Elk / USDT
  // const _rewardsTokenAddresses = [_elkToken, "0xF200EB39C792Cb6e5e1920683b76cBc1892c4CCB"];  // Elk / USDT avax testnet

  const _rewardsDuration = 2592000;
  const _depositFeeBps = 100;
  const _withdrawalFeesBps = [2000, 1000, 0];
  const _withdrawalFeesSchedule = [648000, 1296000, 1944000];

  const _reward = hre.ethers.utils.parseEther("1");

  before(async function () {
    const ElkAvaxFactory = "0x091d35d7F63487909C863001ddCA481c6De47091";
    const AvaxWeth = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"; //WAVAX

    // // avax test net addresses
    // const ElkAvaxFactory = "0x7941856Ab590351EBc48FE9b68F17A3864aB6Df5";
    // const AvaxWeth = "0xd00ae08403B9bbb9124bB305C09058E32C39A48c"; //WAVAX-Testnet

    const windowSize = 86400;
    const granulatiry = 24;

    this.OracleFactory = await hre.ethers.getContractFactory("ElkDexOracle");
    this.Oracle = await this.OracleFactory.deploy(AvaxWeth, ElkAvaxFactory, windowSize, granulatiry);
    this.oracleDeployed = await this.Oracle.deployed();

    this.FarmingRewardsFactory = await hre.ethers.getContractFactory("FarmingRewards");
    this.FarmingRewards = await this.FarmingRewardsFactory.deploy(
      this.Oracle.address,
      _lpTokenAddress,
      _coverageTokenAddress,
      _coverageAmount,
      _coverageVestingDuration,
      _rewardsTokenAddresses,
      _rewardsDuration,
      _depositFeeBps,
      _withdrawalFeesBps,
      _withdrawalFeesSchedule,
    );
    this.deployed = await this.FarmingRewards.deployed();
  });

  describe("Setup", function () {
    it("Should return a successful confirmation of Oracle deployment", function () {
      expect(this.oracleDeployed.deployTransaction.confirmations).to.equal(1);
      expect(hre.ethers.utils.isAddress(this.oracleDeployed.deployTransaction.creates)).to.be.true;
    });

    it("Should return a successful confirmation of FarmingRewards deployment", function () {
      expect(this.deployed.deployTransaction.confirmations).to.equal(1);
      expect(hre.ethers.utils.isAddress(this.deployed.deployTransaction.creates)).to.be.true;
    });
  });

  describe("FaaS", function () {
    before(async function () {
      // Need to get an account that has the stakingToken, rewardToken, and Elk Token to pay the creation fee.
      // Check balances, and change the account and tokens as needed.

      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0x58f937C1075eB9c466cBBac8FC02314ea99408Af"],
      });

      // await hre.network.provider.request({
      //   method: 'hardhat_impersonateAccount',
      //   params: ["0x6bc5Fc9d0D908eF8444A7d8f6A7E1A7050A82084"]
      // });

      //test net elk account: 0x6bc5Fc9d0D908eF8444A7d8f6A7E1A7050A82084

      this.account = hre.ethers.provider.getSigner("0x58f937C1075eB9c466cBBac8FC02314ea99408Af");

      // this.account = hre.ethers.provider.getSigner("0x6bc5Fc9d0D908eF8444A7d8f6A7E1A7050A82084"); // testnet

      this.elkTokenContract = new hre.ethers.Contract(_elkToken, ERC20.abi, hre.ethers.provider);

      this.currentBlock = await hre.ethers.provider.getBlockNumber();
      this.newContracts = [];

      this.FactoryHelper = await (await hre.ethers.getContractFactory("ElkFactoryHelper")).deploy();

      this.FactoryHelperPermissioned = await (
        await hre.ethers.getContractFactory("ElkFactoryHelperPermissioned")
      ).deploy();

      this.FarmFactory = await (
        await hre.ethers.getContractFactory("ElkFarmFactory", {
          libraries: {
            ElkFactoryHelper: this.FactoryHelper.address,
            ElkFactoryHelperPermissioned: this.FactoryHelperPermissioned.address,
          },
        })
      ).deploy();

      this.FarmManager = await (await hre.ethers.getContractFactory("FarmManager")).deploy(this.FarmFactory.address);

      this.rewardsTokenContract = new hre.ethers.Contract(
        "0xc7198437980c041c805A1EDcbA50c1Ce5db95118",
        ERC20.abi,
        hre.ethers.provider,
      );

      this.FarmManagerInstance = this.FarmManager.connect(this.account);

      // Set fee to something tiny
      await this.FarmFactory.setFee(1000000);
    });

    it("Should return a successful confirmation of FactoryHelper deployment", async function () {
      expect(this.FactoryHelper.deployTransaction.confirmations).to.equal(1);
      expect(hre.ethers.utils.isAddress(this.FactoryHelper.address)).to.be.true;
    });

    it("Should return a successful confirmation of FarmFactory deployment", async function () {
      expect(this.FarmFactory.deployTransaction.confirmations).to.equal(1);
      expect(hre.ethers.utils.isAddress(this.FarmFactory.address)).to.be.true;
    });

    it("Should return a successful confirmation of FarmManager deployment", async function () {
      expect(this.FarmManager.deployTransaction.confirmations).to.equal(1);
      expect(hre.ethers.utils.isAddress(this.FarmManager.address)).to.be.true;
    });

    it("Should successfully set the farmManager address in the FarmFactory contract", async function () {
      await this.FarmFactory.setManager(this.FarmManager.address);
      let returnedAddress = await this.FarmFactory.farmManager();
      expect(returnedAddress).to.equal(this.FarmManager.address);
    });

    describe("FarmingRewards contract creation through FarmFactory", function () {
      before(function () {
        let FarmFactoryContract = new hre.ethers.Contract(this.FarmFactory.address, FarmFactoryArtifact.abi);
        this.FarmFactoryInstance = FarmFactoryContract.connect(this.account);
      });

      describe("Calling createNewRewards", function () {
        before(async function () {
          this.feeToBePaid = BigInt(await this.FarmFactory.fee());

          // approve the farmFactory to pay fee from sending account
          this.elkContractInstance = this.elkTokenContract.connect(this.account);
          await this.elkContractInstance.approve(this.FarmFactory.address, this.feeToBePaid);
        });

        it("Should pay the fee and create a new FarmingRewards contract using createNewRewards", async function () {
          let startingBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));

          // create the new contract through the farmFactory
          let newContractTx = await this.FarmFactoryInstance.createNewRewards(
            this.Oracle.address,
            _lpTokenAddress,
            _coverageTokenAddress,
            _coverageAmount,
            _coverageVestingDuration,
            _rewardsTokenAddresses,
            _rewardsDuration,
            _depositFeeBps,
            _withdrawalFeesBps,
            _withdrawalFeesSchedule,
          );

          let endingBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));

          expect(newContractTx.confirmations).to.equal(1);
          expect(endingBalance).to.equal(startingBalance - this.feeToBePaid);
        });

        it("Should emit an event with the new contract address", async function () {
          let eventFilter = this.FarmFactory.filters.ContractCreated();
          let events = await this.FarmFactory.queryFilter(eventFilter, this.currentBlock - 10);
          let FFInterface = new hre.ethers.utils.Interface(FarmFactoryArtifact.abi);
          let parsedEvents = events.map((event) => FFInterface.parseLog(event));
          for (let i = 0; i < parsedEvents.length; i++) {
            if (this.newContracts.includes(parsedEvents[i].args._newContract)) {
              continue;
            }
            this.newContracts.push(parsedEvents[i].args._newContract);
            expect(hre.ethers.utils.isAddress(parsedEvents[i].args._newContract)).to.be.true;
          }
        });
      });

      describe("New Contract Interaction", function () {
        before(function () {
          this.newContract = this.FarmingRewards.attach(this.newContracts[0]);
        });

        it("Should set the owner of the newly created contract to the FarmManager address", async function () {
          let newContract = this.FarmingRewards.attach(this.newContracts[0]);
          newOwner = await newContract.owner();
          expect(newOwner).to.equal(this.FarmManager.address);
        });

        it("Should store the created contracts in FaaS contract, acccessed though getFarm", async function () {
          let getFarm = await this.FarmFactory.getFarm(this.account._address, _lpTokenAddress);
          expect(getFarm).to.equal(this.newContracts[0]);
        });

        it("Should store the creator for each farm, acccessed though getCreator", async function () {
          let getCreator = await this.FarmFactory.getCreator(this.newContracts[0]);
          expect(getCreator).to.equal(this.account._address);
        });

        it("Should be able to access functions in newly created contract", async function () {
          let newContract = this.FarmingRewards.attach(this.newContracts[0]);
          let newLpToken = await newContract.lpToken();
          let newTotalSupply = await newContract.totalSupply();
          expect(newLpToken).to.equal(_lpTokenAddress);
          expect(newTotalSupply).to.equal(0);
        });

        describe("Starting Emissions", function () {
          before(async function () {
            let rewardsTokenInstance = this.rewardsTokenContract.connect(this.account);
            let elkTokenInstance = this.elkTokenContract.connect(this.account);

            // account for decimals of token
            let rewardDecimals = await rewardsTokenInstance.decimals();
            this.normalizedReward = BigInt(_reward / 10 ** (18 - rewardDecimals));

            let elkDecimals = await elkTokenInstance.decimals();
            this.normalizedElk = BigInt(_reward / 10 ** (18 - elkDecimals));

            // need to approve token for FarmingRewards contract to spend
            await rewardsTokenInstance.approve(this.newContract.address, this.normalizedReward);
            await elkTokenInstance.approve(this.newContract.address, this.normalizedElk);

            // need to send rewards to newly created farm contract
            await rewardsTokenInstance.transfer(this.newContract.address, this.normalizedReward);
            await elkTokenInstance.transfer(this.newContract.address, this.normalizedElk);
          });

          it("Should be able to send rewards and start emissions when called from creator account", async function () {
            // start emissions called from creator
            await this.FarmManagerInstance.startEmission(
              this.newContract.address,
              [this.normalizedElk, this.normalizedReward],
              2592000,
            ); // reward tokens need to be in correct order

            let eventFilter = this.newContract.filters.RewardsEmissionStarted();
            let events = await this.newContract.queryFilter(eventFilter, this.currentBlock - 10);
            let FRInterface = new hre.ethers.utils.Interface(FarmArtifact.abi);
            let parsedEvents = events.map((event) => FRInterface.parseLog(event));

            let returnedReward = parsedEvents[0].args._rewards;

            expect(returnedReward.length).to.equal(_rewardsTokenAddresses.length);
            expect(returnedReward[0]).to.equal(_reward);
          });
        });

        describe("Stopping emissions", function () {
          it("Should be able to stop rewards when called from creator account", async function () {
            let startingRewardAccountBalance = BigInt(await this.rewardsTokenContract.balanceOf(this.account._address));
            let startingElkAccountBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));
            let rewardRate = BigInt(await this.newContract.rewardRates(this.rewardsTokenContract.address));
            let rewardElkRate = BigInt(await this.newContract.rewardRates(this.elkTokenContract.address));
            let periodFinish = await this.newContract.periodFinish();

            await this.FarmManagerInstance.stopEmission(this.newContract.address); // Stop the emissions from creator account address

            let timestamp = BigInt(
              (await hre.ethers.provider.getBlock(await hre.ethers.provider.getBlockNumber())).timestamp,
            ); // must get after call to contract to simulate time passing
            let remaining = BigInt(periodFinish) - BigInt(timestamp);

            let expectedRewardBalance = startingRewardAccountBalance + rewardRate * remaining;
            let expectedElkBalance = startingElkAccountBalance + rewardElkRate * remaining;

            let endingRewardAccountBalance = BigInt(await this.rewardsTokenContract.balanceOf(this.account._address));
            let endingElkAccountBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));

            expect(endingRewardAccountBalance).to.equal(expectedRewardBalance);
            expect(endingElkAccountBalance).to.equal(expectedElkBalance);
          });
        });

        describe("Add Reward Token", function () {
          before(async function () {
            this.newContract = this.FarmingRewards.attach(this.newContracts[0]);

            // add WAVAX as a reward token
            this.tokenToAdd = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
            await this.FarmManagerInstance.addRewardToken(this.newContract.address, this.tokenToAdd);
          });

          it("Should be able to add new reward tokens", async function () {
            expect(await this.newContract.rewardTokenAddresses(this.tokenToAdd)).to.be.true;
          });
        });
      });
    });

    describe("Changing ownership", function () {
      it("Should change ownership of a farm in FarmFactory when called from FarmFactory owner", async function () {
        let ownerAccount = await hre.ethers.getSigner();

        // calling from the owner of FarmFactory
        await this.FarmFactory.overrideOwnership(this.newContracts[0]);

        let returnedFarmAddress = await this.FarmFactory.getFarm(ownerAccount.address, _lpTokenAddress);
        let returnedCreator = await this.FarmFactory.getCreator(this.newContracts[0]);

        expect(returnedFarmAddress).to.equal(this.newContracts[0]);
        expect(returnedCreator).to.equal(ownerAccount.address);
      });
    });

    describe("No Coverage", function () {
      before(async function () {
        let FarmFactoryContract = new hre.ethers.Contract(this.FarmFactory.address, FarmFactoryArtifact.abi);
        this.FarmFactoryInstance = FarmFactoryContract.connect(this.account);
        this.feeToBePaid = BigInt(await this.FarmFactory.fee());
        // approve the farmFactory to pay fee from sending account
        this.elkContractInstance = this.elkTokenContract.connect(this.account);
        await this.elkContractInstance.approve(this.FarmFactory.address, this.feeToBePaid);
      });

      it("Should pay the fee and create a new FarmingRewards contract without a coverage token", async function () {
        let startingBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));
        const second_lp = "0x6A0c03c0B933875DAf767BB90584bA696B713243"; // AVAX-ELK

        // create the new contract through the farmFactory
        let newContractTx = await this.FarmFactoryInstance.createNewRewards(
          this.Oracle.address,
          second_lp,
          "0x0000000000000000000000000000000000000000",
          0,
          86400,
          _rewardsTokenAddresses,
          _rewardsDuration,
          _depositFeeBps,
          _withdrawalFeesBps,
          _withdrawalFeesSchedule,
        );

        let endingBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));

        expect(newContractTx.confirmations).to.equal(1);
        expect(endingBalance).to.equal(startingBalance - this.feeToBePaid);
      });
    });

    describe("Permissioned Farms", function () {
      before(async function () {
        this.FarmFactoryInstance = this.FarmFactory.connect(this.account);
        this.feeToBePaid = BigInt(await this.FarmFactory.fee());
        // approve the farmFactory to pay fee from sending account
        this.elkContractInstance = this.elkTokenContract.connect(this.account);
        await this.elkContractInstance.approve(this.FarmFactory.address, this.feeToBePaid);
      });

      it("Should pay the fee and create a new FarmingRewardsPermissioned contract", async function () {
        let startingBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));
        const second_lp = "0x6A0c03c0B933875DAf767BB90584bA696B713243"; // AVAX-ELK

        // create the new contract through the farmFactory
        let newContractTx = await this.FarmFactoryInstance.createNewPermissonedRewards(
          this.Oracle.address,
          second_lp,
          "0x0000000000000000000000000000000000000000",
          0,
          86400,
          _rewardsTokenAddresses,
          _rewardsDuration,
          _depositFeeBps,
          _withdrawalFeesBps,
          _withdrawalFeesSchedule,
        );

        let endingBalance = BigInt(await this.elkTokenContract.balanceOf(this.account._address));

        expect(newContractTx.confirmations).to.equal(1);
        expect(endingBalance).to.equal(startingBalance - this.feeToBePaid);
      });

      it("Should emit an event with the new contract address", async function () {
        let eventFilter = this.FarmFactory.filters.ContractCreated();
        let events = await this.FarmFactory.queryFilter(eventFilter, this.currentBlock - 10);
        let FFInterface = new hre.ethers.utils.Interface(FarmFactoryArtifact.abi);
        let parsedEvents = events.map((event) => FFInterface.parseLog(event));
        for (let i = 0; i < parsedEvents.length; i++) {
          if (this.newContracts.includes(parsedEvents[i].args._newContract)) {
            continue;
          }
          this.newContracts.push(parsedEvents[i].args._newContract);
          expect(hre.ethers.utils.isAddress(parsedEvents[i].args._newContract)).to.be.true;
        }

        it("Should be able to set farm permissions from FarmManager", async function () {
          let FarmManagerInstance = this.FarmManager.connect(this.account);
          let PermissionedFactory = await hre.ethers.ContractFactory("FarmingRewardsPermissioned");
          let FarmingRewardsPermissioned = PermissionedFactory.attach(this.newContracts[2]);

          // permit self to stake
          await FarmManagerInstance.setAddressPermission(this.account._address, true, this.newContracts[2]);

          let permitted = await FarmingRewardsPermissioned.permittedAddresses(this.account._address);

          expect(permitted).to.be.true;
        });
      });
    });
  });
});
