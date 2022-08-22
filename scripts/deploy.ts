import { ethers } from "hardhat";

async function main() {
  const TasksV1 = await ethers.getContractFactory("TasksV1");
  const tasksV1 = await TasksV1.deploy();

  await tasksV1.deployed();

  console.log(`TasksV1deployed to ${tasksV1.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
