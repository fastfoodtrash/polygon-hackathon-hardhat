import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: ["3d11665a90ffccf86bddc3669b39d03af2c1a6508349ab7f1191a4e4b25b4e37"]
    }
  },
  etherscan: {
    apiKey: "AKK4WJFTSY2AQKR2S9UNH7CJIYFFKKDSVQ",
  },
};

export default config;
