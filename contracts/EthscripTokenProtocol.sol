// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8.0;


contract Ethscrip_Token is Ownable, ReentrancyGuard, ERC20{

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public onlyOwner nonReentrant{
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner nonReentrant{
        _burn(account, amount);
    }
}


contract EthscripTokenProtocol is Ownable, ReentrancyGuard{

    struct Ethscription{
        address owner;
        bytes32 e_id;
        bool isSplit;
    }
    mapping(bytes32 => Ethscription) public ethscriptions;

    struct EthscripToken {
        string name;
        uint256 eTotal;
        uint256 tAmount;
        address cAddress;
    }
    mapping(bytes32 => EthscripToken) public ethscripTokens;

    bytes32 public merkleRoot_og;
    address payable public receiver;
    uint256 public protocel_fee;

    event EthscripCategory(bytes32 indexed _mRoot, string _name, uint256 _eTotal, uint256 _tAmount);

    event EthscripInitializes(address indexed owner, bytes32 indexed _e_id, bool state);
    event EthscripToToken(address indexed owner, bytes32 _e_id, bool state, bytes32 indexed root, address indexed c_address); 
    event TokenToEthscrip(address indexed owner, bytes32 indexed _e_id, bool state); 
    event EthscripWithdrawn(address indexed owner, bytes32 indexed _e_id, bool state );

    event ethscriptions_protocol_TransferEthscription(address indexed recipient,bytes32 indexed ethscriptionId);

    constructor(address payable _receiver, bytes32 _merkleRoot_og) {
        receiver = _receiver;
        protocel_fee = 0.000 ether;
        merkleRoot_og = _merkleRoot_og;
    }

    function setReceiver(address payable _rec)external onlyOwner {
        receiver = _rec;
    }

    function setProtocel_fee(uint256 _fee)external onlyOwner {
        protocel_fee = _fee;
    }

    function setMerkleRoot_og(bytes32 _mRoot_og)external onlyOwner {
        merkleRoot_og = _mRoot_og;
    }

    function ethscripInitializes(bytes32 _e_id) private nonReentrant{
        require(ethscriptions[_e_id].owner == address(0), "Error: Order already exists");
        Ethscription memory newEthscrip = Ethscription(msg.sender, _e_id, false);
        ethscriptions[_e_id] = newEthscrip;

        emit EthscripInitializes(msg.sender, _e_id, false);
    }

    function ethscripCategory(bytes32 _mRoot, string memory _name, uint256 _eTotal, uint256 _tAmount)external onlyOwner {
        require(ethscripTokens[_mRoot].cAddress == address(0x0),"Error: Executed in a decentralized manner, no longer supports modifications ");
        
        ethscripTokens[_mRoot] = EthscripToken({
            name: _name,
            eTotal: _eTotal,
            tAmount: _tAmount,
            cAddress: ethscripTokens[_mRoot].cAddress
        });

        emit EthscripCategory(_mRoot, _name, _eTotal, _tAmount);
    }

    function ethscripToToken(bytes32 _e_id, bytes32[] calldata _merkleProof, bytes32 _root, bytes32[] calldata _merkleProof_og)external payable nonReentrant{
        require(ethscriptions[_e_id].owner == msg.sender, "Error: No permissions");
        require(MerkleProof.verify(_merkleProof, _root, _e_id) == true , "Error: Parameter error ");
        require(ethscripTokens[_root].eTotal != 0,"Error: Data error ");
        require(ethscriptions[_e_id].isSplit == false,"Error: The balance is insufficient ");
        uint256 protocel_fee_result = MerkleProof.verify(_merkleProof_og, merkleRoot_og, toBytes32(msg.sender)) == true ? (protocel_fee * 70 / 100) : (protocel_fee);
        require(msg.value >= protocel_fee_result, "Incorrect payment amount");
        receiver.transfer(msg.value);

        if(ethscripTokens[_root].cAddress == address(0x0)){
            Ethscrip_Token cToken = new Ethscrip_Token(ethscripTokens[_root].name,ethscripTokens[_root].name);
            ethscripTokens[_root].cAddress = address(cToken);
            cToken.mint(msg.sender, ethscripTokens[_root].tAmount);
            ethscriptions[_e_id].isSplit = true;
        }else{
            Ethscrip_Token cToken = Ethscrip_Token(ethscripTokens[_root].cAddress);
            cToken.mint(msg.sender, ethscripTokens[_root].tAmount);
            ethscriptions[_e_id].isSplit = true;
        }

        emit EthscripToToken(msg.sender, _e_id, true, _root, ethscripTokens[_root].cAddress);
    }


    function tokenToEthscrip(bytes32 _e_id, bytes32[] calldata _merkleProof, bytes32 _root, bytes32[] calldata _merkleProof_og )external payable nonReentrant{
            require(ethscriptions[_e_id].owner != address(0x0), "Error: No exist ");
            require(MerkleProof.verify(_merkleProof, _root, _e_id) == true , "Error: Parameter error ");
            require(ethscripTokens[_root].eTotal != 0,"Error: Data error ");
            require(ethscriptions[_e_id].isSplit == true,"Error: State error .");
             uint256 protocel_fee_result = MerkleProof.verify(_merkleProof_og, merkleRoot_og, toBytes32(msg.sender)) == true ? (protocel_fee * 70 / 100) : (protocel_fee);
            require(msg.value >= protocel_fee_result, "Incorrect payment amount");
            receiver.transfer(msg.value);

            Ethscrip_Token eToken = Ethscrip_Token(ethscripTokens[_root].cAddress);
            uint256 approveAmount = eToken.allowance(msg.sender,address(this));
            require(approveAmount >= ethscripTokens[_root].tAmount,"Error: approve error ");
            require(eToken.balanceOf(msg.sender) >= ethscripTokens[_root].tAmount,"Error: insufficient balance ");

            eToken.burn(msg.sender,ethscripTokens[_root].tAmount);

            ethscriptions[_e_id].isSplit = false;
            ethscriptions[_e_id].owner = address(0x0);
            emit ethscriptions_protocol_TransferEthscription(msg.sender,_e_id);
            emit TokenToEthscrip(address(0x0), _e_id, false);
    }

    function withdrawn(bytes32 _e_id) public nonReentrant{
        require(ethscriptions[_e_id].owner == msg.sender, "Error: No permissions");
        require(ethscriptions[_e_id].isSplit == false,"Error: State error .");

        ethscriptions[_e_id].owner = address(0x0);
        
        emit ethscriptions_protocol_TransferEthscription(msg.sender, _e_id);
        emit EthscripWithdrawn(address(0x0), _e_id, false);
    }

    function toBytes32(address addr) pure internal returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    fallback() external {
        bytes memory data = msg.data;
        if(data.length >= 32){
            bytes32 result;
            assembly {
                result := mload(add(data, 32))
            }
            ethscripInitializes(result);   
        }
    }

}
