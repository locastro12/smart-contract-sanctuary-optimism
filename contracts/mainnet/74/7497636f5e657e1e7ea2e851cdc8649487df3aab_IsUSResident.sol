/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-07
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

// Groth16 Proof struct
struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
}

contract ProofOfCountry {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }

    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x1dcfbcc68c706725d95cae80087f4f803f7c628fd2ebed0c8d8f1c08efb000a2), uint256(0x1db5c895af5af97da17f06a993745f82dc6c3f43b862de01bb499821a2f07f7f));
        vk.beta = Pairing.G2Point([uint256(0x14595f61ba4aede46e251c87d00e8f5ddd659e3a94f14212cabd8642e28f03b7), uint256(0x2ad520f86f05f729da4c87a6732a2b73b5594f54a3433ddbf9329a859717e893)], [uint256(0x12966aef85fa2cb49ba6c72aaf3b519a909369085de41a7a10db36f6aee9a333), uint256(0x2b2aa977f11a4b1d2fa1b43487a3b348fb78658b4948628ae8a0c77a27309607)]);
        vk.gamma = Pairing.G2Point([uint256(0x0e646c79b92eb81e771a8beedcf750922d68c4cae6e674f28386f05db695f087), uint256(0x2f32db257bd38e510b2c46905bf42ee017eb8dd3736ecf94a63ee388e9dcf7c6)], [uint256(0x2bced1358c17d910723e709aefed3c3b9c127401fbb5b8196023af37eb6924a6), uint256(0x200c899f19599e02ee93c8287a7120147c6f8e001e9c7f7e5c643fce1a2aa94a)]);
        vk.delta = Pairing.G2Point([uint256(0x1116bc1932e65897160357ba10be9222ec1e34adffa8b8c9182b60cac7752446), uint256(0x207f45a790597c02fd21413d5d9ed6bd4b633c18ead06295fe9a8b93562380d2)], [uint256(0x05de54e825005fa8bf89ded4db3448d013c2faa95f3e14e4f502ebb076b6ec42), uint256(0x04a769b3533c1f4394d7523639a81fb549d0f086313f93b605ada17b0d7aeaf5)]);
        vk.gamma_abc = new Pairing.G1Point[](7);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0a0b29d53e75e2681c6cf103f088f351971c06a78c1af4c2c3fad558bd480aba), uint256(0x014db04b3e5fbbd59699890460efd29b5df2491dcade336ed9e58f1920c9b091));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x0ab0d26e0b44acc3f6166a737f25c6b594f8ee0550b0b774a5fc1a9b1c90c2e5), uint256(0x2be4d4802073c03ab7a5160c0f1bfef2f1c8fb0ecfb61c2a2ddfa0f1d64b98f2));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x08539b6e4fa48392fa14e89394f52ff8ca375c23103bfc6f78af24152666cc57), uint256(0x16099e7289a9f2539a9d5abe3665ffaf7236de57ccb24cdff3e4cb8047709198));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x21e5733b57484e09646f512c1c0d95c6670d6701c7540b9487f4f08723c19bb8), uint256(0x11fb6e9d01ab0f58928f40f21da7beee62943aa3c2c5490100ffb6a09d8ce2e5));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x1ea9366f1bee313ec9786dc19facf5dccf3e47e23d9477e274b377e4272bceda), uint256(0x13b1db8802d9fc947ad2ab6ffce35e3e9b147ce6a79760886cefb4e9e4b0212e));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x186067a849502f2e7ce583156758d2aa6d10b98638374d897bd0ab1438f3e45d), uint256(0x2b777f559e2f11fe20903a6b6fe5808a73c93e278effadaad217701caae97063));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x151caaf5340893a1c7e92b6fcaa315046b38a29e5904b7f31088994a6554cf47), uint256(0x04ccd8e7e9a8637873c3fc75ae69afa761886cec6e78675f391ed008c20a0083));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[6] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](6);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
    // function verifyEncoded(Proof calldata proof, uint[] calldata input_) public view returns (bool r) {
    //     // (Proof memory proof, uint[25] memory input) = abi.decode(b, (Proof, uint[25]));
    //     uint[6] memory input;
    //     for (uint i = 0; i < 6; i++) {
    //         input[i] = input_[i];
    //     }
    //     return verifyTx(proof, input);
    // }
}


interface IRootsMinimal {
   function rootIsRecent(uint256 root) external view returns (bool isRecent);
}

interface IPaidProof {
    function setPrice(uint newPrice) external;
    function collectPayments() external;
    function allowIssuers(uint[] memory issuerAddresses) external;
    function revokeIssuers(uint[] memory issuerAddresses) external;
    function isValidIssuer(uint issuerAddress) external view returns (bool);
}

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract PaidProof is IPaidProof, Ownable {
    uint public price; // Price in ETH to use a function with the needsPayment modifier
    mapping(uint => bool) public allowedIssuers; // Whitelist of issuers

    constructor() {}

    function setPrice(uint newPrice) public onlyOwner {
            price = newPrice;
    }

    function collectPayments() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    modifier needsPayment() {
        require(msg.value >= price, "Missing payment");
        _;
    }

    function allowIssuers(uint[] memory issuerAddresses) public onlyOwner {
        uint8 i;
        for (i = 0; i < issuerAddresses.length; i++) {
            allowedIssuers[issuerAddresses[i]] = true;  
        }
    }

    function revokeIssuers(uint[] memory issuerAddresses) public onlyOwner {
        uint8 i;
        for (i = 0; i < issuerAddresses.length; i++) {
            allowedIssuers[issuerAddresses[i]] = false;  
        }            
    }

    function isValidIssuer(uint issuerAddress) public view returns (bool) {
        return allowedIssuers[issuerAddress];       
    }
}

interface IIsUSResident {
   function usResidency(address) external view returns (bool);
}

contract IsUSResident is PaidProof {
    
    mapping(address => bool) public usResidencyMapping; // e.g., 0x123... => true
    mapping(uint256 => bool) public masalaWasUsed;

    ProofOfCountry verifier; 
    IRootsMinimal roots;
    event USResidency(address userAddr, bool usResidency);

    // allow for backwards compatability by also accepting users who verified in the old contract
    bool legacySupport;
    IIsUSResident oldContract; 

    constructor(address roots_, uint[] memory issuers_, uint price_, address oldContract_) {
        roots = IRootsMinimal(roots_);
        verifier = new ProofOfCountry();
        allowIssuers(issuers_);
        setPrice(price_);
        
        if(oldContract_ != address(0)) {
            legacySupport = true;
            oldContract = IIsUSResident(oldContract_);
        }
    }

    function usResidency(address person) public view returns (bool) {
        return usResidencyMapping[person] || (legacySupport && oldContract.usResidency(person));
    }
    // It is useful to separate this from the prove() function which is changes state, so that somebody can call this off-chain as a view function.
    // Then, they can maintain their own off-chain list of footprints and verified address 
    function proofIsValid(Proof calldata proof, uint[6] calldata input) public view returns (bool isValid) {
        require(roots.rootIsRecent(input[0]), "The root provided was not found in the Merkle tree's recent root list");

        // Checking msg.sender no longer seems very necessary and prevents signature-free interactions. Without it, relayers can submit cross-chain transactions without the user signature. Thus, we are deprecating this check:
        // require(uint256(uint160(msg.sender)) == input[1], "Second public argument of proof must be your address");
        
        require(isValidIssuer(input[2]), "Proof must come from correct issuer's address"); 
        require(input[3] == 18450029681611047275023442534946896643130395402313725026917000686233641593164, "Footprint is made from the wrong salt"); //poseidon("IsFromUS")
        require(!masalaWasUsed[input[4]], "One person can only verify once");
        require(input[5] == 2, "Credentials do not have US as country code"); // 2 is prime that represents USA because USA is #2
        require(verifier.verifyTx(proof, input), "Failed to verify proof");
        return true;
    }

    /// @param proof PairingAndProof.sol Proof struct
    /// @param input The public inputs to the proof, in ZoKrates' format
    function prove(Proof calldata proof, uint[6] calldata input) public {
        require(proofIsValid(proof, input));
        masalaWasUsed[input[4]] = true;
        usResidencyMapping[address(uint160(input[1]))] = true; //
        emit USResidency(msg.sender, true);
    }

}