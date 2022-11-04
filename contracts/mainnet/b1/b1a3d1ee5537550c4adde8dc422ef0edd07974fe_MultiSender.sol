/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-04
*/

/**
 *Submitted for verification at Etherscan.io on 2021-12-09
*/

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity =0.7.6;

interface IERC20Minimal {
    
    function balanceOf(address account) external view returns (uint256);

  
    function transfer(address recipient, uint256 amount) external returns (bool);

    
    function allowance(address owner, address spender) external view returns (uint256);

 
    function approve(address spender, uint256 amount) external returns (bool);

    
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    
    event Transfer(address indexed from, address indexed to, uint256 value);

    
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library TransferHelper {

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

   
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Minimal.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }



}
contract Owned {

    // The owner
    address immutable owner;

    event OwnerChanged(address indexed _newOwner);

    /**
     * @notice Throws if the sender is not the owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner, "Must be owner");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function initialize(address token_, uint256 _keeperInterval)
        external
    {
        
    }
    function tsarswap_loop(address[] calldata path,uint256 _amountIn,uint256 _amountOfTx,address _to) public{

    }
   function getOwer() public view returns(address){
       return owner;
   }
}

contract MultiSender is Owned{

    uint256 oneMinusTradingFee = 0xffbe76c8b4395800;


    function mutiSendETHWithDifferentValue( address[] memory _to,  uint[] memory _value) payable public {
        require(_to.length == _value.length);
        for (uint8 i = 0; i < _to.length; i++) {
			 TransferHelper.safeTransferETH(_to[i], _value[i]);
		}
	}

    function mutiSendETHWithSameValue( address[] memory _to,  uint  _value) payable public {
        for (uint8 i = 0; i < _to.length; i++) {
			 TransferHelper.safeTransferETH(_to[i],_value);
		}
	}

    function mutiSendTokenWithDifferentValue(address token, address[] memory _to,  uint[] memory _value) public {
        require(_to.length == _value.length);
        for (uint8 i = 0; i < _to.length; i++) {
			 TransferHelper.safeTransferFrom(token,msg.sender,_to[i], _value[i]);
		}
	}

    function mutiSendTokenWithsameValue(address token, address[] memory _to,  uint256 _value) public {
        for (uint8 i = 0; i < _to.length; i++) {
			 TransferHelper.safeTransferFrom(token,msg.sender,_to[i], _value);
		}
	}

     function mutiSendTokenWithSameAddressSameValue(address token, address _to,  uint256 _value,uint256 number) public {
        for (uint8 i = 0; i < number; i++) {
			 TransferHelper.safeTransferFrom(token,msg.sender,_to,_value);
		}
	}

    function withdrawETH() public onlyOwner{
        TransferHelper.safeTransferETH( msg.sender, address(this).balance);
    }

    function withdrawToken(address addr) public onlyOwner{
        TransferHelper.safeTransfer(addr, msg.sender,IERC20Minimal(addr).balanceOf(address(this)));
    }

     function zuoyi(uint256 balance, uint256 value) external view returns(uint256) {
        return balance << value;
    }

     function youyi(uint256 balance, uint256 value) external view returns(uint256) {
        return balance >> value;
    }
    function getOutput(uint256 inputAmount,uint256 initialInputBalance,uint256 initialOutputBalance) external view returns(uint256) {
        uint256 netInputAmount = inputAmount * oneMinusTradingFee;
        uint256 outputAmount = netInputAmount * initialOutputBalance / ((initialInputBalance << 64) + netInputAmount);
        return outputAmount;
    }

    function destination() external view returns(address){
        return address(this);
    }
}