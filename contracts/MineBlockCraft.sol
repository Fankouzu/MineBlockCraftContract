pragma solidity >=0.5.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";


contract Owner {
    address internal _owner;

    event OwnerSet(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not owner");
        _;
    }

    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(_owner, newOwner);
        _owner = newOwner;
    }

    function owner() public view returns (address) {
        return _owner;
    }
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

}


contract MBCUser is Owner {
    struct Profile {
        string Nickname;
        string Signature;
    }

    Profile[] public Profiles;

    mapping(uint256 => address) public IdToAddress;
    mapping(address => uint256) public AddressToId;
    mapping(address => address[]) internal Friend;

    uint256 public userCount;

    event eventNewUser(address indexed userAddress, uint256 indexed UserId);

    modifier isUser() {
        require(
            AddressToId[msg.sender] > 0 || isOwner(),
            "not registered"
        );
        _;
    }

    function _newUser(string memory _Nickname, string memory _Signature)
        internal
        returns (uint256 _userId)
    {
        Profiles.push(Profile(_Nickname, _Signature));
        uint256 UserId = Profiles.length - 1;

        IdToAddress[UserId] = msg.sender;
        AddressToId[msg.sender] = UserId;
        userCount++;

        emit eventNewUser(msg.sender, UserId);

        return UserId;
    }

    function newUser(string memory _Nickname, string memory _Signature)
        public
        returns (uint256 _userId)
    {
        require(
            AddressToId[msg.sender] == 0 && !isOwner(),
            "already registered"
        );
        return _newUser(_Nickname, _Signature);
    }

    function editProfile(string memory _Nickname, string memory _Signature)
        public
    {
        require(AddressToId[msg.sender] > 0, "not registered");
        uint256 UserId = AddressToId[msg.sender];
        Profiles[UserId] = Profile(_Nickname, _Signature);
    }

    function newProfile(string memory _Nickname, string memory _Signature)
        public
        returns (uint256 _userId)
    {
        require(!isOwner(), "you are owner");
        if (AddressToId[msg.sender] == 0) {
            return _newUser(_Nickname, _Signature);
        } else {
            editProfile(_Nickname, _Signature);
            return AddressToId[msg.sender];
        }
    }

    function getProfile(address _address) public view returns (Profile memory) {
        if (_address == owner()) {
            return Profiles[0];
        } else if (AddressToId[_address] > 0) {
            return Profiles[AddressToId[_address]];
        } else {
            return Profile("", "");
        }
    }
}


library Search {
    function indexOf(address[] storage self, address value)
        public
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] == value) return i;
        }
        return uint256(-1);
    }
}


contract MBCMessage is MBCUser {
    struct Message {
        uint256 time;
        string content;
        address fromUser;
        address toUser;
    }

    Message[] internal Messages;
    using Search for address[];

    mapping(address => mapping(address => uint256)) internal messageCount;
    mapping(address => address[]) internal messageList;

    event newMessage(
        address indexed fromUser,
        address indexed toUser,
        uint256 MessageId
    );

    function sendMsg(address _toUser, string memory _content) public {
        require(_toUser != msg.sender, "Can not send to yourself");
        //推入消息列表
        Messages.push(Message(block.timestamp, _content, msg.sender, _toUser));
        uint256 MessageId = Messages.length - 1;
        emit newMessage(msg.sender, _toUser, MessageId);
        if (messageList[msg.sender].indexOf(_toUser) == uint256(-1)) {
            messageList[msg.sender].push(_toUser);
        }
        if (messageList[_toUser].indexOf(msg.sender) == uint256(-1)) {
            messageList[_toUser].push(msg.sender);
        }

        messageCount[msg.sender][_toUser]++;
        messageCount[_toUser][msg.sender]++;
        delete MessageId;
        delete _content;
    }

    function getMessages(address _toUser)
        public
        view
        returns (Message[] memory)
    {
        Message[] memory result = new Message[](
            messageCount[msg.sender][_toUser]
        );

        uint256 counter = 0;
        for (uint256 i = 0; i < Messages.length; i++) {
            if (
                (Messages[i].fromUser == msg.sender &&
                    Messages[i].toUser == _toUser) ||
                (Messages[i].fromUser == _toUser &&
                    Messages[i].toUser == msg.sender)
            ) {
                result[counter] = Messages[i];
                counter++;
            }
        }
        return result;
    }

    function msgList() public view returns (address[] memory) {
        return messageList[msg.sender];
    }
}


contract MBCFriend is MBCUser, MBCMessage {
    event eventAddFriend(address indexed fromUser, address indexed toUser);

    function addFriend(address _toUser) public {
        require(!isFriends(_toUser), "already is your friend");
        Friend[msg.sender].push(_toUser);
        messageList[msg.sender].push(_toUser);
        emit eventAddFriend(msg.sender, _toUser);
    }

    function getFriends() public view returns (address[] memory) {
        return Friend[msg.sender];
    }

    function isFriends(address _toUser) public view returns (bool) {
        bool exists = false;
        for (uint256 i = 0; i < Friend[msg.sender].length; i++) {
            if (Friend[msg.sender][i] == _toUser) {
                exists = true;
            }
        }
        return exists;
    }
}

contract MBCCore is MBCFriend,Initializable {
    function initialize() public initializer {
        _owner = msg.sender;
        emit OwnerSet(address(0), _owner);
        _newUser("Fankouzu", "I'm admin");
    }
}
