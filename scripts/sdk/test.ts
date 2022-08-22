import { createAlchemyWeb3 } from '@alch/alchemy-web3';
import TasksV1 from './index';

function main() {
  const web3 = createAlchemyWeb3("https://polygon-mumbai.g.alchemy.com/v2/4zT5OXCL8Kwzu0NHZGB_0e98ZR0lnWmd");
  // const taskV1 = new TasksV1(web3);
}