const { utils } = require("ethers");
const { ethers, network } = require("hardhat");

let chainId = network.config.chainId;

const etherscan = {
  1: "https://etherscan.io/tx/",
  4: "https://rinkeby.etherscan.io/tx/",
};

class GasLogger {
  constructor() {
    this.totalGas = ethers.utils.parseEther("0");
    this.totalEth = ethers.utils.parseEther("0");
  }

  addDeployment = (tx) => {
    console.log("----- DEPLOYMENT INFO -----");

    if (tx.address) console.log("✏️  Deployed To: ", tx.address);
    if (tx.receipt.transactionHash) {
      console.log("✏️  Tx Hash: ", tx.receipt.transactionHash);
    }
    if (etherscan[chainId]) {
      console.log(`${etherscan[chainId]}${tx.receipt.transactionHash}`);
    }
    if (tx.receipt.type) console.log("✏️  Transaction Type: ", tx.receipt.type);

    if (tx.receipt.gasUsed) {
      console.log("⛽ Gas Consumed: ", tx.receipt.gasUsed.toString());
      this.totalGas.add(tx.receipt.gasUsed);
    }
    if (tx.receipt.effectiveGasPrice)
      console.log(
        "⛽ Gas Price: ",
        ethers.utils.formatUnits(tx.receipt.effectiveGasPrice, "gwei"),
        "gwei"
      );

    if (tx.receipt.effectiveGasPrice && tx.receipt.gasUsed) {
      console.log(
        "Ξ Cost: ",
        utils.formatEther(
          tx.receipt.effectiveGasPrice.mul(tx.receipt.gasUsed),
          "Ξ"
        )
      );
      this.totalEth.add(tx.receipt.effectiveGasPrice.mul(tx.receipt.gasUsed));
    }
    console.log();
  };

  addTransaction = (tx) => {
    console.log("----- TRANSACTION INFO -----");
    if (tx.transactionHash) {
      console.log("✏️  Tx Hash: ", tx.transactionHash);
    }
    if (etherscan[chainId]) {
      console.log(`${etherscan[chainId]}${tx.transactionHash}`);
    }
    console.log("✏️  Transaction Type: ", tx.type);
    console.log("⛽ Gas Consumed: ", tx.gasUsed.toString());
    console.log(
      "⛽ Gas Price: ",
      ethers.utils.formatUnits(tx.effectiveGasPrice, "gwei"),
      "gwei"
    );
    console.log(
      "Ξ Cost: ",
      utils.formatEther(tx.effectiveGasPrice.mul(tx.gasUsed)),
      "Ξ"
    );

    this.totalGas.add(tx.gasUsed);
    this.totalEth.add(tx.effectiveGasPrice.mul(tx.gasUsed));
    console.log();
  };

  addProxyDeployment = (tx) => {
    console.log("----- DEPLOYMENT INFO -----");

    if (tx.address) console.log("✏️  Proxy Deployed To: ", tx.address);
    if (tx.implementation)
      console.log("✏️  Implementation Deployed To: ", tx.implementation);
    if (tx.transactionHash) {
      console.log("✏️  Tx Hash: ", tx.transactionHash);
    }
    if (etherscan[chainId]) {
      console.log(`${etherscan[chainId]}${tx.transactionHash}`);
    }
    if (tx.receipt.gasUsed) {
      console.log("⛽ Gas Consumed: ", tx.receipt.gasUsed);
      this.totalGas.add(tx.receipt.gasUsed);
    }
    if (tx.receipt.effectiveGasPrice && tx.receipt.gasUsed)
      this.totalEth.add(tx.receipt.effectiveGasPrice.mul(tx.receipt.gasUsed));
    console.log();
  };

  printGas = (tx) => {
    console.log("----- Gas INFO -----");
    console.log("⛽ Gas Consumed: ", tx.receipt.gasUsed.toString());
    console.log("⛽ Gas Price: ", tx.receipt.effectiveGasPrice.toString());
    console.log(
      "Ξ Cost: ",
      utils.formatEther(tx.receipt.effectiveGasPrice.mul(tx.receipt.gasUsed)),
      "Ξ"
    );
    console.log();
  };

  printTotal = () => {
    console.log("----- Total Gas INFO -----");
    console.log("⛽ Total Gas Consumed: ", this.totalGas.toString());
    console.log("Total Ξ Cost: ", utils.formatEther(this.totalEth), "Ξ");
    console.log();
  };
}

module.exports = {
  GasLogger,
};
