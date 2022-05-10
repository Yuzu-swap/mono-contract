// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./uniswapv2/UniswapV2Router02.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";
import "./uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./YuzuZap.sol";


interface IMiningFundCustomer {
    function subscribe(address _tokenAddress,uint256 _amount) external;
    function redeem(address _shareAddress, uint256 _amount) external;
}

interface IYUZUPark {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt;
    }
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function userInfo(uint256 _pid,address from) external view returns(UserInfo memory) ;
}


/*
interface IMiningFundFundMananger {
    function addLiquility()  external;
    function removeLiquility()  external;
    function depositLp()  external;
    function withdrawLp()  external;
    function harvestRewards()  external;
    function swap()  external;
}

interface IMiningFundContractAdmin {
    addFundManager()
    removeFundManager()
}
*/

contract StringConcator {
    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory  abcde = new string (_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (uint i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (uint i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (uint i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d) internal returns (string memory) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c) internal returns (string memory) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b) internal returns (string memory) {
        return strConcat(_a, _b, "", "", "");
    }
}
//ShareToken
contract ShareToken is ERC20,Ownable {
   constructor(string memory _name,string memory _symbol,uint8 _decimals) public ERC20(_name,_symbol){
       _setupDecimals(_decimals);
   }

   function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
      _mint(_to, _amount);
      return true;
   }

   function burn(address _from,uint256 _amount) public onlyOwner returns (bool) {
      _burn(_from, _amount);
      return true;
   }
}

contract  MiningFundShareTokenManage is Ownable, ReentrancyGuard,StringConcator
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    FundToken public token0;
    FundToken public token1;

    string constant tokenPrefix = "MiningFund-"; 

    event Subscribed(address from,address originTokenAddr,address fundTokenAddr,uint256 originTokenAmount,uint256 fundTokenAmount);
    event Redeemed(address from,address originTokenAddr,address fundTokenAddr,uint256 originTokenAmount,uint256 fundTokenAmount);

//    IUniswapV2Router02 public immutable routerContractIns;
//    IUniswapV2Factory public immutable factoryContractIns;
     // Stake order struct
    struct FundToken {
        ShareToken shareToken;
        IERC20 originToken;
        uint256 originArchorAmount;
    }
    constructor(address _tokenA, address _tokenB)  public{
        //routerContractIns = _routerIns;
        //factoryContractIns = IUniswapV2Factory(_routerIns.factory());
        
        (address token0Address,address token1Address) = UniswapV2Library.sortTokens(_tokenA, _tokenB);



        string memory token0Name = ERC20(token0Address).name();
        string memory token0Symbol = ERC20(token0Address).symbol();
        uint8 token0Decimals = ERC20(token0Address).decimals();

        string memory token1Name = ERC20(token1Address).name();
        string memory token1Symbol = ERC20(token1Address).symbol();
        uint8 token1Decimals = ERC20(token1Address).decimals();

        string memory newName0 = strConcat(tokenPrefix,token0Name);
        string memory newSymbol0 = strConcat(tokenPrefix,token0Symbol);

        string memory newName1 = strConcat(tokenPrefix,token1Name);
        string memory newSymbol1 = strConcat(tokenPrefix,token1Symbol);


        token0 = FundToken({
            shareToken:  new ShareToken(newName0,newSymbol0,token0Decimals),
            originToken: IERC20(token0Address),
            originArchorAmount: 0
        });

        token1 = FundToken({
            shareToken:  new ShareToken(newName1,newSymbol1,token1Decimals),
            originToken: IERC20(token1Address),
            originArchorAmount: 0
        });
    }


    function subscribe(address _originTokenAddress,uint256 _amount) virtual external nonReentrant
    {
        //mint share token
        _subscribe(_originTokenAddress,_amount);
    }

    function redeem(address _shareTokenAddress, uint256 _burnAmount) virtual external nonReentrant
    {
        _redeem(_shareTokenAddress,_burnAmount);
    }


    function originTokenBalance(address tokenAddr)  internal view returns (uint256){
       return IERC20(tokenAddr).balanceOf(address(this));
    }

    function _subscribe(address _originTokenAddress,uint256 _amount) virtual  internal {
        require(_amount >0 ,"subscribe amount must greater than zero");
        address shareTokenAddress;
        if( _originTokenAddress == address(token0.originToken)){
            shareTokenAddress = address(token0.shareToken);
            token0.originArchorAmount =  token0.originArchorAmount.add(_amount);
        }else if( _originTokenAddress == address(token1.originToken)){
            shareTokenAddress = address(token1.shareToken);
            token1.originArchorAmount = token1.originArchorAmount.add(_amount);
        }else{
            revert("invalid _originTokenAddress  ");
        }


        uint256 currShareTokenBalance = IERC20(shareTokenAddress).balanceOf(address(this));
        uint256 currOriginTokenBalance = originTokenBalance(_originTokenAddress);


        IERC20(_originTokenAddress).safeTransferFrom(msg.sender,address(this),_amount);

        uint256 realTransferdAmount  = originTokenBalance(_originTokenAddress) - currOriginTokenBalance;
        uint256 mintAmount;
        if(currOriginTokenBalance == 0 || currShareTokenBalance == 0){
            mintAmount = _amount;
        }else{
            mintAmount =  (realTransferdAmount  * currShareTokenBalance)/currOriginTokenBalance;
        }
        ShareToken(shareTokenAddress).mint(msg.sender,mintAmount);

        emit Subscribed(msg.sender,_originTokenAddress,shareTokenAddress,_amount,mintAmount);
        
    }
    
    function _redeem(address _shareTokenAddress, uint256 _burnAmount) virtual internal 
    {
        require(_burnAmount >0 ,"_redeem amount must greater than zero");
        address originTokenAddress;
        if( _shareTokenAddress == address(token0.shareToken)){
            originTokenAddress = address(token0.originToken);
        }else if( _shareTokenAddress == address(token1.shareToken)){
            originTokenAddress = address(token1.originToken);
        }else{
            revert("invalid _shareTokenAddress  ");
        }

        //burn share token
        uint256 currOriginTokenBalance = originTokenBalance(originTokenAddress);
        uint256 currShareTokenBalance = IERC20(_shareTokenAddress).totalSupply();

    
        uint256 redeemAmount = _burnAmount.mul(currOriginTokenBalance).div(currShareTokenBalance);

        ShareToken(_shareTokenAddress).burn(msg.sender,_burnAmount);


        // transfer back raw token
        IERC20(originTokenAddress).transfer(msg.sender,redeemAmount);

        if( _shareTokenAddress == address(token0.shareToken)){
            if(token0.originArchorAmount > redeemAmount ){
                token0.originArchorAmount =  token0.originArchorAmount.sub(redeemAmount);
            }else{
                token0.originArchorAmount = 0;
            }
        }else if( _shareTokenAddress == address(token1.shareToken)){
            if(token1.originArchorAmount > redeemAmount ){
                token1.originArchorAmount =  token1.originArchorAmount.sub(redeemAmount);
            }else{
                token1.originArchorAmount = 0;
            }
        }
        emit Redeemed(msg.sender,originTokenAddress,_shareTokenAddress,redeemAmount,_burnAmount);
    }
}







contract  MiningFundLPManageV2 is MiningFundShareTokenManage{

    IUniswapV2Router02 public immutable routerContractIns;
    IUniswapV2Factory public immutable factoryContractIns;

    ERC20 public immutable lpToken;
    IYuzuZap public immutable zapIns;
    IYUZUPark public immutable yuzuParkIns;
    uint256 public immutable  poolId;


    modifier selfOrOwner() {
        require(msg.sender == address(this)|| msg.sender == owner() , "Self: caller is not the self");
        _;
    }



    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    constructor(address _token0, address _token1,address _routerAddress,address _zapAddress,address _yuzuParkAddress,uint256 _poolId) public MiningFundShareTokenManage(_token0,_token1)
    {
        IUniswapV2Router02 _routerContractIns = IUniswapV2Router02(_routerAddress);
        IUniswapV2Factory _factoryContractIns = IUniswapV2Factory(_routerContractIns.factory());
        ERC20 _lpToken = ERC20(_factoryContractIns.getPair(_token0,_token1));

        // assign
        routerContractIns = _routerContractIns;
        factoryContractIns =  _factoryContractIns;
        lpToken = _lpToken;
        zapIns = IYuzuZap(_zapAddress);
        yuzuParkIns = IYUZUPark(_yuzuParkAddress);
        poolId = _poolId;



        _approveTokenIfNeeded(_token0,_routerAddress);
        _approveTokenIfNeeded(_token1,_routerAddress);
        _approveTokenIfNeeded(_token0,_zapAddress);
        _approveTokenIfNeeded(_token1,_zapAddress);
        _approveTokenIfNeeded(address(_lpToken),_routerAddress);
        _approveTokenIfNeeded(address(_lpToken),_yuzuParkAddress);

    }


    function exec(Call[] memory calls) public onlyOwner 
    {
        for (uint i = 0; i < calls.length; i++) {
            (bool success, ) = calls[i].to.call{value:calls[i].value}(calls[i].data);
		    string memory strIndex = Strings.toString(i);
            string memory errMsg = strConcat(strIndex, " call failed ");
            require(success, errMsg);
        }
    }


    function _approveTokenIfNeeded(address token, address to) private {
        if (IERC20(token).allowance(address(this), address(to)) == 0) {
            IERC20(token).safeApprove(to, type(uint).max);
        }
    }


    function zapRewards(address[] memory rewardTokens) external nonReentrant selfOrOwner
    {
        yuzuParkIns.withdraw(poolId,0);
        for(uint i=0; i<  rewardTokens.length; i++ ){
            uint256 rewardBalance = ERC20(rewardTokens[i]).balanceOf(address(this));
            _approveTokenIfNeeded(rewardTokens[i],address(zapIns));
            zapIns.zapInToken(rewardTokens[i], rewardBalance , address(lpToken), address(routerContractIns), address(this));
        }

        uint256 lpBalance = lpToken.balanceOf(address(this));
        yuzuParkIns.deposit(poolId,lpBalance);
        
    }

    function withdrawRewards() external nonReentrant selfOrOwner
    {
        yuzuParkIns.withdraw(poolId,0);
    }




    function unstakeAll() public nonReentrant selfOrOwner{
        uint256 myLpBalance = yuzuParkIns.userInfo(poolId,address(this)).amount;
        if(myLpBalance > 0){
            yuzuParkIns.withdraw(poolId,myLpBalance);
            routerContractIns.removeLiquidity(address(token0.originToken),address(token1.originToken),myLpBalance,0,0,address(this),block.timestamp + 60);
        }
    }


    function stakeAll() public nonReentrant selfOrOwner{
        uint256 originToken0Balance  = token0.originToken.balanceOf(address(this));
        uint256 originToken1Balance  = token1.originToken.balanceOf(address(this));
        if(originToken0Balance > 0 && originToken1Balance > 0  ){
            (,,uint256 lpBalance )  = routerContractIns.addLiquidity(address(token0.originToken),address(token1.originToken),originToken0Balance,originToken1Balance,0,0,address(this),block.timestamp + 60);
            yuzuParkIns.deposit(poolId,lpBalance);
        }
    }
}


contract  MiningFundLPManageV3 is MiningFundLPManageV2{

    event Rebalanced(uint256 originToken0Amount,uint256 originToken1Amount,uint256 shareToken0Amount,uint256 shareToken1Amount ,uint256 lpToken0Balance,uint256 lpToken1Balance);

    constructor(address _token0, address _token1,address _routerAddress,address _zapAddress,address _yuzuParkAddress,uint256 _poolId) public MiningFundLPManageV2(_token0, _token1, _routerAddress, _zapAddress, _yuzuParkAddress, _poolId)
    {
    }


    function redeem(address _shareAddress, uint256 _amount) override external 
    {
        this.unstakeAll();
        _redeem(_shareAddress,_amount);
        this.stakeAll();
    }

    function subscribe(address _originTokenAddress,uint256 _amount)  override external 
    {
        this.unstakeAll();
        _subscribe(_originTokenAddress,_amount);
        this.stakeAll();
    }

    function rebalance() public nonReentrant selfOrOwner {
        (uint256 originToken0BalanceInLp, uint256 originToken1BalanceInLp,uint256 lpToken0Balance,uint256 lpToken1Balance) = this.balanceInStake();
        uint256 originToken0Balance = token0.originToken.balanceOf(address(this));
        uint256 originToken1Balance = token1.originToken.balanceOf(address(this));
        token0.originArchorAmount =  originToken0BalanceInLp + originToken0Balance;
        token1.originArchorAmount =  originToken1BalanceInLp + originToken1Balance;

        uint256 currShareToken0Balance = token0.shareToken.totalSupply();
        uint256 currShareToken1Balance = token1.shareToken.totalSupply();

        emit Rebalanced(token0.originArchorAmount , token1.originArchorAmount,currShareToken0Balance,currShareToken1Balance,lpToken0Balance,lpToken1Balance);
    }

    
     function balanceInStake() public view  returns( uint256,uint256,uint256 ,uint256 ) {
        uint256 myLpBalance = yuzuParkIns.userInfo(poolId,address(this)).amount;
        uint256 totalLp = lpToken.totalSupply();
        uint256 lpToken0Balance =  token0.originToken.balanceOf(address(lpToken));
        uint256 lpToken1Balance =  token1.originToken.balanceOf(address(lpToken));

        return (lpToken0Balance.mul(myLpBalance).div(totalLp),lpToken1Balance.mul(myLpBalance).div(totalLp),lpToken0Balance,lpToken1Balance);
    }


    function staticsInfos() public view  returns( uint256 originToken0Total ,uint256  currShareToken0Balance,uint256 originToken0ArchorAmount,uint256 originToken1Total ,uint256 currShareToken1Balance ,uint256 originToken1ArchorAmount ) {
        (uint256 originToken0BalanceInLp, uint256 originToken1BalanceInLp, ,) = this.balanceInStake();
        uint256 originToken0Balance = token0.originToken.balanceOf(address(this));
        uint256 originToken1Balance = token1.originToken.balanceOf(address(this));


        originToken0Total = originToken0BalanceInLp + originToken0Balance;
        originToken1Total = originToken1BalanceInLp + originToken1Balance;


        currShareToken0Balance = token0.shareToken.totalSupply();
        currShareToken1Balance = token1.shareToken.totalSupply();

        originToken0ArchorAmount = token0.originArchorAmount;
        originToken1ArchorAmount= token1.originArchorAmount;

    }

}







//



contract  MiningFundLPManageV4 is MiningFundLPManageV2{

    event Rebalanced(uint256 originToken0Amount,uint256 originToken1Amount,uint256 shareToken0Amount,uint256 shareToken1Amount ,uint256 lpToken0Balance,uint256 lpToken1Balance);

    constructor(address _token0, address _token1,address _routerAddress,address _zapAddress,address _yuzuParkAddress,uint256 _poolId) public MiningFundLPManageV2(_token0, _token1, _routerAddress, _zapAddress, _yuzuParkAddress, _poolId)
    {
    }


   

    function subscribe(address _originTokenAddress,uint256 _amount) override external nonReentrant
    {
        //mint share token
        _subscribe(_originTokenAddress,_amount);
    }

    function redeem(address _shareTokenAddress, uint256 _burnAmount) override external nonReentrant
    {
        _redeem(_shareTokenAddress,_burnAmount);
    }


  

    function originTokenEffectiveTotalAmount(address tokenAddr)   internal view returns (uint256){
        if( tokenAddr == address(token0.originToken) ){
            return token0.originArchorAmount;
        }else{
            return token1.originArchorAmount;
        }
    }

    function _subscribe(address _originTokenAddress,uint256 _amount) override internal {
        require(_amount >0 ,"subscribe amount must greater than zero");
        address shareTokenAddress;
        if( _originTokenAddress == address(token0.originToken)){
            shareTokenAddress = address(token0.shareToken);
            token0.originArchorAmount =  token0.originArchorAmount.add(_amount);
        }else if( _originTokenAddress == address(token1.originToken)){
            shareTokenAddress = address(token1.shareToken);
            token1.originArchorAmount = token1.originArchorAmount.add(_amount);
        }else{
            revert("invalid _originTokenAddress  ");
        }


        uint256 currShareTokenBalance = IERC20(shareTokenAddress).balanceOf(address(this));

        uint256 currOriginTokenBalance = originTokenBalance(_originTokenAddress);
        IERC20(_originTokenAddress).safeTransferFrom(msg.sender,address(this),_amount);
        uint256 realTransferdAmount  = originTokenBalance(_originTokenAddress) - currOriginTokenBalance;

        uint256 currOriginTokenAmount = originTokenEffectiveTotalAmount(_originTokenAddress);


        uint256 mintAmount;
        if(currOriginTokenBalance == 0 || currShareTokenBalance == 0){
            mintAmount = _amount;
        }else{
            mintAmount =  (realTransferdAmount  * currShareTokenBalance)/currOriginTokenAmount;
        }
        ShareToken(shareTokenAddress).mint(msg.sender,mintAmount);

        emit Subscribed(msg.sender,_originTokenAddress,shareTokenAddress,_amount,mintAmount);
        
    }
    
    function _redeem(address _shareTokenAddress, uint256 _burnAmount) override internal 
    {
        require(_burnAmount >0 ,"_redeem amount must greater than zero");
        address originTokenAddress;
        if( _shareTokenAddress == address(token0.shareToken)){
            originTokenAddress = address(token0.originToken);
        }else if( _shareTokenAddress == address(token1.shareToken)){
            originTokenAddress = address(token1.originToken);
        }else{
            revert("invalid _shareTokenAddress  ");
        }

        //burn share token
        uint256 currOriginTokenBalance = originTokenEffectiveTotalAmount(originTokenAddress);
        uint256 currShareTokenBalance = IERC20(_shareTokenAddress).totalSupply();

    
        uint256 redeemAmount = _burnAmount.mul(currOriginTokenBalance).div(currShareTokenBalance);

        ShareToken(_shareTokenAddress).burn(msg.sender,_burnAmount);


        // transfer back raw token
        IERC20(originTokenAddress).transfer(msg.sender,redeemAmount);

        if( _shareTokenAddress == address(token0.shareToken)){
            if(token0.originArchorAmount > redeemAmount ){
                token0.originArchorAmount =  token0.originArchorAmount.sub(redeemAmount);
            }else{
                token0.originArchorAmount = 0;
            }
        }else if( _shareTokenAddress == address(token1.shareToken)){
            if(token1.originArchorAmount > redeemAmount ){
                token1.originArchorAmount =  token1.originArchorAmount.sub(redeemAmount);
            }else{
                token1.originArchorAmount = 0;
            }
        }
        emit Redeemed(msg.sender,originTokenAddress,_shareTokenAddress,redeemAmount,_burnAmount);
    }

}
