// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TasksV1 is Ownable {
    enum TaskActions { cancel, withdraw, applyTask, withdrawApp, start, 
        fail, submit, complete, dispute, resolve }
    enum TaskStatus { active, cancelled, started, completed, dispute, failed }

    event TaskCreation(uint256 taskId, Task task, address creator, string refId);
    event TaskUpdate(uint256 taskId, address sender, TaskActions action);

    struct Task { 
        // address paymentToken;
        uint256 createdTime;
        uint256 startTime;
        uint256 duration;
        uint256 salary;
        uint256 deposit;
        address creator;
        address provider;
        TaskStatus status;
        string jobDesc;
        string submission;
        string disputeResult;
    }

    struct TaskRating {
        uint8 creatorRating;
        uint8 providerRating;
        string commentForCreator;
        string commentForProvider;
    }

    // Task count should start from 1,
    // 0 represent empty task's taskId
    uint256 public taskCount = 1;
    mapping (address => uint256[]) public createdTasks;
    mapping (address => uint256[]) public provideredTasks;
    mapping (address => uint256[]) public appliedTasks;
    mapping (uint256 => address[]) public applicants;
    mapping (uint256 => Task) public tasks;
    mapping (uint256 => TaskRating) public tasksRating;

    uint32 unlockTime = 2592000;

    function updateUnlockTime (uint32 _unlockTime)
        external onlyOwner
    {
        unlockTime = _unlockTime;
    }

    function createTask(uint256 duration, string memory jobDesc, string calldata refId)
        external payable
    {
        address creator = msg.sender;
        Task memory task = Task(
            block.timestamp,
            0,
            duration,
            msg.value,
            msg.value,
            creator,
            address(0),
            TaskStatus.active,
            jobDesc,
            "",
            ""
        );

        uint256 taskId = taskCount;
        taskCount++;

        // Record for creator
        uint256[] storage currentTasks = createdTasks[creator];
        currentTasks.push(taskId);
        createdTasks[creator] = currentTasks;

        tasks[taskId] = task;

        emit TaskCreation(taskId, task, creator, refId);
    }

    function cancelTask(uint256 taskId) external {
        require(tasks[taskId].creator == msg.sender, "Not creator");
        require(tasks[taskId].status == TaskStatus.active, "Task not active");

        tasks[taskId].status = TaskStatus.cancelled;

        emit TaskUpdate(taskId, msg.sender, TaskActions.cancel);
    }

    function withdrawDeposit(uint256 taskId) external {
        require(tasks[taskId].creator == msg.sender, "Not creator");
        require(tasks[taskId].deposit > 0);
        require(
            tasks[taskId].status == TaskStatus.failed
            ||
            (tasks[taskId].status == TaskStatus.cancelled 
                && applicants[taskId].length == 0)
            || 
            (tasks[taskId].status == TaskStatus.cancelled
                && block.timestamp > tasks[taskId].createdTime + unlockTime)
        , "Cannot withdraw");

        uint256 valueToWithdraw = tasks[taskId].deposit;
        tasks[taskId].deposit = 0;
        payable(msg.sender).transfer(valueToWithdraw);

        emit TaskUpdate(taskId, msg.sender, TaskActions.withdraw);
    }

    function applyTask(uint256 taskId) external {
        require(tasks[taskId].status == TaskStatus.active,
            "Task not found");
        require(tasks[taskId].creator != msg.sender,
            "You are the creator");

        address[] storage currentApp = applicants[taskId];
        currentApp.push(msg.sender);
        applicants[taskId] = currentApp;

        uint256[] storage myApp = appliedTasks[msg.sender];
        myApp.push(taskId);
        appliedTasks[msg.sender] = myApp;

        emit TaskUpdate(taskId, msg.sender, TaskActions.applyTask);
    }

    function removeApplicantFromArr(uint256 taskId, address addr)
        internal returns(bool)
    {
        address[] storage taskApplicants = applicants[taskId];

        for (uint i = 0; i < taskApplicants.length; i++){
            if (taskApplicants[i] == addr) {
                delete taskApplicants[i];
                return true;
            }
        }

        return false;
    }

    function removeAppliedTasksFromArr(uint256 taskId, address addr)
        internal returns(bool)
    {
        uint256[] storage senderApplication = appliedTasks[addr];

        for (uint i = 0; i < senderApplication.length; i++){
            if (senderApplication[i] == taskId) {
                delete senderApplication[i];
                return true;
            }
        }

        return false;
    }

    function withdrawApplication(uint256 taskId) external {
        require(tasks[taskId].status == TaskStatus.active,
            "Task not found");
        
        removeApplicantFromArr(taskId, msg.sender);
        removeAppliedTasksFromArr(taskId, msg.sender);

        emit TaskUpdate(taskId, msg.sender, TaskActions.withdrawApp);
    }

    function startTask(uint256 taskId, address provider)
        external
    {
        require(tasks[taskId].status == TaskStatus.active,
            "Task not found");
        require(tasks[taskId].creator == msg.sender,
            "You are not the creator");
        require(checkAppliedTask(taskId, provider),
            "Provider did not apply this job");

        tasks[taskId].provider = provider;
        tasks[taskId].status = TaskStatus.started;
        tasks[taskId].startTime = block.timestamp;

        emit TaskUpdate(taskId, msg.sender, TaskActions.start);
    }

    function failTask(
        uint256 taskId,
        uint8 providerRating,
        string memory commentForProvider
    )
        external
    {
        require(tasks[taskId].status == TaskStatus.started,
            "Not on going task");
        require(tasks[taskId].creator == msg.sender,
            "You are not the creator");
        require(block.timestamp >
            tasks[taskId].startTime + tasks[taskId].duration,
            "Not ended");
        require(bytes(tasks[taskId].submission).length == 0,
            "Provider submitted");

        tasks[taskId].status = TaskStatus.failed;

        tasksRating[taskId].providerRating = providerRating;
        tasksRating[taskId].commentForProvider = commentForProvider;

        emit TaskUpdate(taskId, msg.sender, TaskActions.fail);
    }

    function submitResult(uint256 taskId, string memory submission)
        external
    {
        require(tasks[taskId].provider == msg.sender, "Not provider");
        require(tasks[taskId].status == TaskStatus.started, "Not started");

        tasks[taskId].submission = submission;

        emit TaskUpdate(taskId, msg.sender, TaskActions.submit);
    }

    function setTaskCompleted(
        uint256 taskId,
        uint8 providerRating,
        string memory commentForProvider
    )
        external
    {
        require(tasks[taskId].creator == msg.sender, "Not creator");
        require(tasks[taskId].status == TaskStatus.started, "Not started");
        require(providerRating >= 0 && providerRating <= 5,
            "Rating range should be 0 - 5");
        require(bytes(commentForProvider).length > 0,
            "Missing comment");

        tasks[taskId].status = TaskStatus.completed;
        
        tasksRating[taskId].providerRating = providerRating;
        tasksRating[taskId].commentForProvider = commentForProvider;

        uint256 valueToSend = tasks[taskId].deposit;
        tasks[taskId].deposit = 0;

        payable(tasks[taskId].provider).transfer(valueToSend);

        emit TaskUpdate(taskId, msg.sender, TaskActions.complete);
    }

    function rateCreator(
        uint256 taskId,
        uint8 creatorRating,
        string memory commentForCreator
    )
        external
    {
        require(tasks[taskId].provider == msg.sender, "Not provider");
        require(tasks[taskId].status == TaskStatus.completed, "Not completed");
        require(creatorRating >= 0 && creatorRating <= 5,
            "Rating range should be 0 - 5");
        require(bytes(commentForCreator).length > 0,
            "Missing comment");

        tasksRating[taskId].creatorRating = creatorRating;
        tasksRating[taskId].commentForCreator = commentForCreator;
    }

    function requestDispute(uint256 taskId)
        external
    {
        require(tasks[taskId].provider == msg.sender 
            || tasks[taskId].creator == msg.sender, "Not provider or creator");
        require(tasks[taskId].status == TaskStatus.started, "Not started");

        tasks[taskId].status = TaskStatus.dispute;

        emit TaskUpdate(taskId, msg.sender, TaskActions.dispute);
    }

    function resolveDispute(uint256 taskId, string memory prove,
        uint8 creatorPercentage, uint8 providerPercentage)
        external onlyOwner
    {
        require(creatorPercentage + providerPercentage == 100,
            "Percentage not correct");
        require(tasks[taskId].status == TaskStatus.dispute,
            "Not under disagreement");

        tasks[taskId].status = TaskStatus.completed;
        tasks[taskId].disputeResult = prove;
        
        uint256 valueToShare = tasks[taskId].deposit;
        tasks[taskId].deposit = 0;

        if (creatorPercentage > 0 && providerPercentage > 0) {
            uint256 creatorShare = valueToShare * creatorPercentage / 100;
            uint256 providerShare = valueToShare - creatorShare;
            payable(tasks[taskId].creator).transfer(creatorShare);
            payable(tasks[taskId].provider).transfer(providerShare);
        } else if (creatorPercentage == 100) {
            payable(tasks[taskId].creator).transfer(valueToShare);
        } else if (providerPercentage == 100) {
            payable(tasks[taskId].provider).transfer(valueToShare);
        }
        
        emit TaskUpdate(taskId, msg.sender, TaskActions.resolve);
    }

    function getActiveTasks(TaskStatus status)
        external view returns(Task[] memory)
    {
        uint activeTask = 0;
        // taskId index start from 1
        for (uint i = 1; i < taskCount; i++) {
            if (tasks[i].status == status)
                activeTask++;
        }
        
        Task[] memory taskList = new Task[](activeTask);
        uint counter = 0;
        for (uint i = 1; i < taskCount; i++) {
            if (tasks[i].status == status) {
                taskList[counter] = tasks[i];
                counter++;
            }
        }

        return taskList;
    }

    function getCreatedTask(address addr)
        external view returns(uint256[] memory)
    {
        return createdTasks[addr];
    }

    function getAppliedTask(address addr)
        external view returns(uint256[] memory)
    {
        return appliedTasks[addr];
    }

    function getApplicant(uint256 taskId)
        external view returns(address[] memory)
    {
        return applicants[taskId];
    }

    function checkAppliedTask(uint256 taskId, address addr)
        public view returns(bool)
    {
        address[] memory taskApplicant = applicants[taskId];
        for(uint i = 0; i < taskApplicant.length; i++) {
            if (taskApplicant[i] == addr) return true;
        }

        return false;
    }
}
