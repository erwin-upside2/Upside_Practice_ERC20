// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract ERC20 {
    string public name;
    string public symbol;
    uint public decimals;   // 토큰의 소수점 자리수
    uint public totalSupply;  // 총 공급량

    // EIP712 구현에 필요한 변수
    bytes32 public immutable DOMAIN_SEPARATOR;  // 체인ID, 컨트랙트 주소 포함한 도메인 구분자
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"); // permit 함수의 파라미터를 정의한 해시
    
    address public owner;
    bool public paused;

    mapping(address owner => uint amount) public balances;  // 각 주소가 보유한 토큰의 수량
    mapping(address owner => mapping(address spender => uint amount)) public allowances; // 위임한 토큰 수량
    mapping(address => uint256) public nonces;  // 재사용 공격 막기 위한 주소별 논스 값

    // ERC20 표준에서 정의한 이벤트들
    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
        totalSupply = 100 ether;
        balances[msg.sender] = 100 ether;
        owner = msg.sender;

        // EIP712 도메인 구분자 설정, 체인 ID와 주소를 포함해서 다른 체인이나 컨트랙트와 구분함
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    // 함수 호출자가 컨트랙트 소유자인지 확인
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    // 컨트랙트가 정지 상태가  아닌지 확인
    modifier whenNotPaused() {
        require(!paused, "TOKEN_PAUSED");
        _;
    }

    // EIP-712 서명 검증을 위한 해시 생성 함수, 도메인 구분자와 구조체 해시를 조합해서 최종 해시 생성
    function _toTypedDataHash(bytes32 structHash) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function pause() public onlyOwner {  // 토큰 전송 멈춤
        paused = true;
    }

    function unpause() public onlyOwner {  // 토큰 전송 재개
        paused = false;
    }

    // EIP-2612 permit 함수, 가스비 없이 서명만으로 토큰 사용 권한을 설정함
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,      // v, r, s는 서명을 위한 값
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "PERMIT_EXPIRED");

        bytes32 structHash = keccak256(              //EIP-712 서명을 위한 해시 생성
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner], deadline)
        );
        bytes32 hash = _toTypedDataHash(structHash);

        address signer = ecrecover(hash, v, r, s);   // 서명자 주소 확인
        require(signer == owner, "INVALID_SIGNER");

        nonces[owner]++;                    // 논스 값 증가 및 권한 ㅇ설정
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    // 잔액 조회
    function balanceOf(address owner) public view returns (uint) {
        return balances[owner];
    }

    function transfer(
        address to,
        uint amount
    ) public whenNotPaused returns (bool success) {
        address owner = msg.sender;
        require(balances[owner] >= amount);

        balances[owner] -= amount;
        balances[to] += amount;

        emit Transfer(owner, to, amount);
        return true;
    }

    function approve(
        address spender,
        uint amount
    ) public whenNotPaused returns (bool success) {
        address owner = msg.sender;
        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public whenNotPaused returns (bool success) {
        address spender = msg.sender;
        require(allowances[from][spender] >= amount);
        require(balances[from] >= amount);

        allowances[from][spender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint) {
        return allowances[owner][spender];
    }
}