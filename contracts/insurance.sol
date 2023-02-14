/**
 * patient log in uploads the medical/lab test bill an submits its insurance ..the Hospital and the Lab_admin are notified about the update
 * Now as the request is uploaded the Lab admin and the hospital admin verifies it and sign the request
 * The event is emitted to the Lab admin and now Labadmimn calculates the amount and successfully transfers it to the patient_client
 * and mark the request as completed
 */
//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

/* Errors */
error Health_Insurance__OnlyAdmins();
error Health_Insurance__Record_withId_already_exists();
error Health_Insurance__Record_does_not_exists();
error Health_Insurance__Invalid_address();
error Health_Insurance__Only_admins_rAuthorised();
error Health_Insurance__cannot_sign_again();
error Health_Insurance__admins_signatures_maxed();
error Health_Insurance__admins_cannot_request();
error Health_Insurance__Request_notApproved();
error Health_Insurance__only_labAdmin();
error Health_Insurance__TransactionReverted();

contract Health_Insurance {
    enum Request_status {
        applied,
        pending,
        completed
    }

    struct Request {
        uint256 id;
        uint256 amount;
        uint256 signature_Count;
        string test_name;
        string hospital_name;
        uint256 date;
        bool isValue;
        address C_addr;
        mapping(address => uint256) signature;
    }
    /* State Variables */
    address private immutable i_hospital_admin;
    address private immutable i_lab_admin;
    mapping(uint256 => Request) public s_records;
    uint256[] private s_record_list;
    Request_status private s_status = Request_status.applied;

    /* Events */
    event Request_Created(
        uint256 indexed ID,
        string test_name,
        string indexed hospital_name,
        uint256 indexed amount
    );
    event Request_signed(
        uint256 indexed ID,
        string test_name,
        string indexed hospital_name,
        uint256 indexed amount
    );

    /* Modifiers */
    modifier ValidateRecord(uint256 id) {
        if (s_records[id].isValue)
            revert Health_Insurance__Record_withId_already_exists();
        _;
    }

    modifier SignRequest(uint256 id) {
        if (!s_records[id].isValue)
            revert Health_Insurance__Record_does_not_exists();
        if (s_records[id].C_addr == address(0))
            revert Health_Insurance__Invalid_address();
        if (s_records[id].C_addr == msg.sender)
            revert Health_Insurance__Only_admins_rAuthorised();
        if (s_records[id].signature[msg.sender] == 1)
            revert Health_Insurance__cannot_sign_again();
        if (!(s_records[id].signature_Count < 2))
            revert Health_Insurance__admins_signatures_maxed();
        _;
    }
    modifier OnlyAdmin() {
        if (msg.sender != i_hospital_admin && msg.sender != i_lab_admin)
            revert Health_Insurance__OnlyAdmins();
        _;
    }

    /* Constructor */
    constructor(address _addr) {
        i_hospital_admin = msg.sender;
        i_lab_admin = _addr;
    }

    /*
     * @dev this function is for Generating The request
     */
    function generateRequest(
        uint256 id,
        uint256 amount,
        string memory test_name,
        string memory hospital_name,
        uint256 date
    ) external ValidateRecord(id) {
        if (msg.sender == i_hospital_admin || msg.sender == i_lab_admin)
            revert Health_Insurance__admins_cannot_request();
        Request storage request = s_records[id];
        request.id = id;
        request.amount = amount;
        request.test_name = test_name;
        request.hospital_name = hospital_name;
        request.date = date;
        request.C_addr = msg.sender;
        request.signature_Count = 0;
        request.isValue = true;

        s_status = Request_status.pending;
        s_record_list.push(request.id);
        emit Request_Created(
            request.id,
            request.test_name,
            request.hospital_name,
            request.amount
        );
    }

    /* Approve Function */
    function approve_request(uint256 _id) external OnlyAdmin SignRequest(_id) {
        Request storage request = s_records[_id];
        request.signature[msg.sender] = 1;
        request.signature_Count++;

        if (request.signature_Count == 2)
            emit Request_signed(
                request.id,
                request.test_name,
                request.hospital_name,
                request.amount
            );
    }

    /* Get The Insurance amount  */
    function Get_insurance_money(uint256 id) external {
        Request storage request = s_records[id];
        if (
            request.signature_Count != 2 &&
            (s_status != Request_status.completed)
        ) revert Health_Insurance__Request_notApproved();
        if (msg.sender != i_lab_admin) revert Health_Insurance__only_labAdmin();
        uint256 amount = (request.amount / 10**18);
        (bool success, ) = payable(request.C_addr).call{value: amount}("");
        if (!success) revert Health_Insurance__TransactionReverted();
        s_status = Request_status.completed;
    }

    /*  View And pure Functions*/
    function Get_srecordsList() external view returns (uint256[] memory) {
        return s_record_list;
    }
}
