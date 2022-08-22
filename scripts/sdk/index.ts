import { AlchemyWeb3 } from '@alch/alchemy-web3';
import Web3 from 'web3';
import { CONTRACT_ADDRESS } from './const';
const TasksV1Json = require('./TasksV1.json');

enum TaskStatus { active = 0, cancelled = 1, started = 2, completed = 3, dispute = 4, failed = 5 }

interface TaskProps {
  createdTime: number;
  startTime: number;
  duration: number;
  salary: number;
  deposit: number;
  creator: string;
  provider: string;
  status: TaskStatus;
  jobDesc: string;
  submission: string;
  disputeResult: string;
}

interface TaskRatingProps {
  creatorRating: number; // 1 - 5
  providerRating: number; // 1 - 5
  commentForCreator: string;
  commentForProvider: string;
}


class TasksV1 {
  private web3;
  private contract;

  constructor(web3: Web3 | AlchemyWeb3) {
    this.web3 = web3;
    this.contract = new web3.eth.Contract(TasksV1Json.abi, CONTRACT_ADDRESS);
  }

  /**
   * Create a new job on chain with deposit
   * @param address : method caller address
   * @param salary : $MATIC value in wei (18 * 0)
   * @param duration : How long (in second) for the provider to complete the task
   * @param jobDesc : Job description link on IPFS
   */
  public async createTask(address: string, salary: number, duration: number, jobDesc: string) {
    const params = {
      from: address,
      value: salary
    }
    return this.contract.methods.createTask(duration, jobDesc).send(params);
  }

  /**
   * * (Task Creator only)
   * Cancel task on chain if not started yet
   * Deposit refund should call `withdrawDeposit`
   * @param taskId 
   */
  public async cancelTask(taskId: number) {
    return this.contract.methods.cancelTask(taskId).send();
  }

  /**
   * * (Task Creator only)
   * Withdraw deposit if [Inactive + no one apply] or [Inactive + 7 days after]
   * @param taskId 
   */
  public async withdrawDeposit(taskId: number) {
    return this.contract.methods.withdrawDeposit(taskId).send();;
  }

  /**
   * Apply for a task and wait on pending list
   * @param taskId 
   */
  public async applyTask(taskId: number) {
    return this.contract.methods.applyTask(taskId).send();
  }

  /**
   * * (Task Provider only)
   * @param taskId 
   */
  public async withdrawApplication(taskId: number) {
    return this.contract.methods.withdrawApplication(taskId).send();
  }

  /**
   * * (Task Creator only)
   * If a provider cannot complete task within duration aftet started
   * creator can call the method to set a task fail and get refund.
   * No dispute allowed after failing, if provider want to submit dispute,
   * he need to submit result
   * @param taskId 
   * @param providerRating : 0 - 5 rating 
   * @param commentForProvider
   */
  public async failTask(taskId: number, providerRating: number, commentForProvider: string) {
    return this.contract.methods.failTask(taskId, providerRating, commentForProvider);
  }

  /**
   * * (Task Creator only)
   * Pick a provider to start the task
   * @param taskId 
   * @param provider : Provider address on `getApplicant` list
   */
  public async startTask(taskId: number, provider: string) {
    return this.contract.methods.startTask(taskId, provider).send();;
  }

  /**
   * * (Task Provider only)
   * @param taskId 
   * @param submission : IPFS url for task submission prove
   */
  public async submitResult(taskId: number, submission: string) {
    return this.contract.methods.submitResult(taskId, submission).send();;
  }

  /**
   * * (Task Creator only)
   * Set task complete and send all the fund to the provider
   * @param taskId 
   * @param providerRating : 0 - 5
   * @param commentForProvider : any string
   */
  public async setTaskCompleted(taskId: number, providerRating: number, commentForProvider: string) {
    return this.contract.methods.setTaskCompleted(
      taskId, providerRating, commentForProvider).send();;
  }

  /**
   * * (Task Provider only)
   * After task is completed provider can rate creator
   * @param taskId 
   * @param creatorRating 
   * @param commentForCreator 
   * @returns 
   */
  public async rateCreator(taskId: number, creatorRating: number, commentForCreator: string) {
    return this.contract.methods.rateCreator(
      taskId, creatorRating, commentForCreator).send();;
  }


  /**
   * * (Task Provider only)
   * Set task to dispute mode due to disagreement
   * @param taskId 
   */
  public async requestDispute(taskId: number) {
    return this.contract.methods.requestDispute(taskId).send();;
  }

  /**
   * * (Contract Owner ony)
   * Resolve dispute by owner, need to set the prove and percentage
   * of share to each party, percentage sum must be 100%
   * @param taskId 
   * @param prove : IPFS url for the dispute prove
   * @param creatorPercentage 
   * @param providerPercentage 
   */
  public async resolveDispute(
    taskId: number,
    prove: string,
    creatorPercentage: number,
    providerPercentage: number
  ): Promise<void> {
    if (creatorPercentage + providerPercentage !== 100)
      throw new Error("Percentage sum not equal to 100");
    return this.contract.methods.resolveDispute(
      taskId, prove, creatorPercentage, providerPercentage).send();
  }

  /**
   * Get all the active task on chain
   * @param taskId 
   */
    public async getActiveTasks(taskId: number): Promise<TaskProps[]> {
      return this.contract.methods.getActiveTasks(taskId).call();
    }

  /**
   * Get all created task from specific address
   * @param address 
   */
  public async getCreatedTask(address: string): Promise<number> {
    return this.contract.methods.getCreatedTask(address).call();
  }

  /**
   * Get all applied task from specific address
   * @param address 
   */
  public async getAppliedTask(address: string): Promise<number> {
    return this.contract.methods.getAppliedTask(address).call();
  }

  /**
   * Get all applicants address from task
   * @param taskId 
   */
  public async getApplicant(taskId: number): Promise<string> {
    return this.contract.methods.getApplicant(taskId).call();
  }

  /**
   * Check does an address applied a task
   * @param address 
   */
  public async checkAppliedTask(address: string): Promise<boolean> {
    return this.contract.methods.getApplicant(address).call();
  }

  public async taskCount() {
    return (await this.contract.methods.taskCount()) - 1;
  }

  public async createdTasks(address: string) {
    return this.contract.methods.createdTasks(address);
  }

  public async provideredTasks(address: string) {
    return this.contract.methods.provideredTasks(address);
  }

  public async appliedTasks(address: string) {
    return this.contract.methods.appliedTasks(address);
  }

  public async applicants(taskId: number) {
    return this.contract.methods.applicants(taskId);
  }

  public async tasks(taskId: number) {
    return this.contract.methods.tasks(taskId);
  }

  public async tasksRating(taskId: number) {
    return this.contract.methods.tasksRating(taskId);
  }
}

export default TasksV1;