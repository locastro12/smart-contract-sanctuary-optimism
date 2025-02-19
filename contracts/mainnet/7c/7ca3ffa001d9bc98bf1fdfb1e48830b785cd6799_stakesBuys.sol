/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-05
*/

pragma solidity ^0.6.0;

interface publicCalls {
  function GenesisDestroyAmountCount (  ) external view returns ( uint256 );
  function GenesisDestroyAmountCountSet ( uint256 _GenesisDestroyAmountCount ) external;
  function GenesisDestroyCountStake (  ) external view returns ( uint256 );
  function GenesisDestroyCountStakeSet ( uint256 _GenesisDestroyCountStake ) external;
  function GenesisDestroyed (  ) external view returns ( uint256 );
  function GenesisDestroyedSet ( uint256 _GenesisDestroyed ) external;
  function NormalAddressBuyPricePerMNE ( address ) external view returns ( uint256 );
  function NormalAddressBuyPricePerMNESet ( address _address, uint256 _NormalAddressBuyPricePerMNE ) external;
  function NormalAddressFeeCount (  ) external view returns ( uint256 );
  function NormalAddressFeeCountSet ( uint256 _NormalAddressFeeCount ) external;
  function NormalAddressSalesCount (  ) external view returns ( uint256 );
  function NormalAddressSalesCountSet ( uint256 _NormalAddressSalesCount ) external;
  function NormalAddressSalesPriceCount (  ) external view returns ( uint256 );
  function NormalAddressSalesPriceCountSet ( uint256 _NormalAddressSalesPriceCount ) external;
  function NormalBalanceImported (  ) external view returns ( uint256 );
  function NormalBalanceImportedSet ( uint256 _NormalBalanceImported ) external;
  function NormalImportedAmountCount (  ) external view returns ( uint256 );
  function NormalImportedAmountCountSet ( uint256 _NormalImportedAmountCount ) external;
  function allowAddressToDestroyGenesis ( address ) external view returns ( address );
  function allowAddressToDestroyGenesisSet ( address _address, address _allowAddressToDestroyGenesis ) external;
  function allowReceiveGenesisTransfers ( address ) external view returns ( bool );
  function allowReceiveGenesisTransfersSet ( address _address, bool _allowReceiveGenesisTransfers ) external;
  function allowed ( address, address ) external view returns ( uint256 );
  function allowedSet ( address _address, address _spender, uint256 _amount ) external;
  function amountOfGenesisToBuyStakes (  ) external view returns ( uint256 );
  function amountOfGenesisToBuyStakesSet ( address _from, uint256 _amountOfGenesisToBuyStakes ) external;
  function amountOfGenesisToTransferStakes (  ) external view returns ( uint256 );
  function amountOfGenesisToTransferStakesSet ( address _from, uint256 _amountOfGenesisToTransferStakes ) external;
  function amountOfMNEForToken (  ) external view returns ( uint256 );
  function amountOfMNEForTokenICO (  ) external view returns ( uint256 );
  function amountOfMNEForTokenICOSet ( address _from, uint256 _amountOfMNEForTokenICO ) external;
  function amountOfMNEForTokenSet ( address _from, uint256 _amountOfMNEForToken ) external;
  function amountOfMNEToBuyStakes (  ) external view returns ( uint256 );
  function amountOfMNEToBuyStakesSet ( address _from, uint256 _amountOfMNEToBuyStakes ) external;
  function amountOfMNEToTransferStakes (  ) external view returns ( uint256 );
  function amountOfMNEToTransferStakesSet ( address _from, uint256 _amountOfMNEToTransferStakes ) external;
  function availableBalance (  ) external view returns ( uint256 );
  function availableBalanceSet ( uint256 _availableBalance ) external;
  function balances ( address ) external view returns ( uint256 );
  function balancesSet ( address _address, uint256 _balances ) external;
  function buyStakeGenesisCount (  ) external view returns ( uint256 );
  function buyStakeGenesisCountSet ( uint256 _buyStakeGenesisCount ) external;
  function buyStakeMNECount (  ) external view returns ( uint256 );
  function buyStakeMNECountSet ( uint256 _buyStakeMNECount ) external;
  function ethFeeForSellerLevel1 (  ) external view returns ( uint256 );
  function ethFeeForSellerLevel1Set ( address _from, uint256 _ethFeeForSellerLevel1 ) external;
  function ethFeeForToken (  ) external view returns ( uint256 );
  function ethFeeForTokenICO (  ) external view returns ( uint256 );
  function ethFeeForTokenICOSet ( address _from, uint256 _ethFeeForTokenICO ) external;
  function ethFeeForTokenSet ( address _from, uint256 _ethFeeForToken ) external;
  function ethFeeToBuyLevel1 (  ) external view returns ( uint256 );
  function ethFeeToBuyLevel1Set ( address _from, uint256 _ethFeeToBuyLevel1 ) external;
  function ethFeeToUpgradeToLevel2 (  ) external view returns ( uint256 );
  function ethFeeToUpgradeToLevel2Set ( address _from, uint256 _ethFeeToUpgradeToLevel2 ) external;
  function ethFeeToUpgradeToLevel3 (  ) external view returns ( uint256 );
  function ethFeeToUpgradeToLevel3Set ( address _from, uint256 _ethFeeToUpgradeToLevel3 ) external;
  function ethPercentFeeGenesisExchange (  ) external view returns ( uint256 );
  function ethPercentFeeGenesisExchangeSet ( address _from, uint256 _ethPercentFeeGenesisExchange ) external;
  function ethPercentFeeNormalExchange (  ) external view returns ( uint256 );
  function ethPercentFeeNormalExchangeSet ( address _from, uint256 _ethPercentFeeNormalExchange ) external;
  function ethPercentStakeExchange (  ) external view returns ( uint256 );
  function ethPercentStakeExchangeSet ( address _from, uint256 _ethPercentStakeExchange ) external;
  function genesisAddressCount (  ) external view returns ( uint256 );
  function genesisAddressCountSet ( uint256 _genesisAddressCount ) external;
  function genesisAddressesForSaleLevel1Index ( address ) external view returns ( uint256 );
  function genesisAddressesForSaleLevel1IndexSet ( address _address, uint256 _genesisAddressesForSaleLevel1Index ) external;
  function genesisAddressesForSaleLevel2Index ( address ) external view returns ( uint256 );
  function genesisAddressesForSaleLevel2IndexSet ( address _address, uint256 _genesisAddressesForSaleLevel2Index ) external;
  function genesisAddressesForSaleLevel3Index ( address ) external view returns ( uint256 );
  function genesisAddressesForSaleLevel3IndexSet ( address _address, uint256 _genesisAddressesForSaleLevel3Index ) external;
  function genesisBuyPrice ( address ) external view returns ( uint256 );
  function genesisBuyPriceSet ( address _address, uint256 _genesisBuyPrice ) external;
  function genesisCallerAddress (  ) external view returns ( address );
  function genesisCallerAddressSet ( address _genesisCallerAddress ) external;
  function genesisInitialSupply ( address ) external view returns ( uint256 );
  function genesisInitialSupplySet ( address _address, uint256 _genesisInitialSupply ) external;
  function genesisRewardPerBlock (  ) external view returns ( uint256 );
  function genesisSalesCount (  ) external view returns ( uint256 );
  function genesisSalesCountSet ( uint256 _genesisSalesCount ) external;
  function genesisSalesPriceCount (  ) external view returns ( uint256 );
  function genesisSalesPriceCountSet ( uint256 _genesisSalesPriceCount ) external;
  function genesisSupplyPerAddress (  ) external view returns ( uint256 );
  function genesisTransfersCount (  ) external view returns ( uint256 );
  function genesisTransfersCountSet ( uint256 _genesisTransfersCount ) external;
  function initialBlockCount (  ) external view returns ( uint256 );
  function initialBlockCountPerAddress ( address ) external view returns ( uint256 );
  function initialBlockCountPerAddressSet ( address _address, uint256 _initialBlockCountPerAddress ) external;
  function initialBlockCountSet ( uint256 _initialBlockCount ) external;
  function isGenesisAddress ( address ) external view returns ( uint8 );
  function isGenesisAddressForSale ( address ) external view returns ( bool );
  function isGenesisAddressForSaleSet ( address _address, bool _isGenesisAddressForSale ) external;
  function isGenesisAddressSet ( address _address, uint8 _isGenesisAddress ) external;
  function isNormalAddressForSale ( address ) external view returns ( bool );
  function isNormalAddressForSaleSet ( address _address, bool _isNormalAddressForSale ) external;
  function level2ActivationsFromLevel1Count (  ) external view returns ( uint256 );
  function level2ActivationsFromLevel1CountSet ( uint256 _level2ActivationsFromLevel1Count ) external;
  function level3ActivationsFromDevCount (  ) external view returns ( uint256 );
  function level3ActivationsFromDevCountSet ( uint256 _level3ActivationsFromDevCount ) external;
  function level3ActivationsFromLevel1Count (  ) external view returns ( uint256 );
  function level3ActivationsFromLevel1CountSet ( uint256 _level3ActivationsFromLevel1Count ) external;
  function level3ActivationsFromLevel2Count (  ) external view returns ( uint256 );
  function level3ActivationsFromLevel2CountSet ( uint256 _level3ActivationsFromLevel2Count ) external;
  function maxBlocks (  ) external view returns ( uint256 );
  function mneBurned (  ) external view returns ( uint256 );
  function mneBurnedSet ( uint256 _mneBurned ) external;
  function normalAddressesForSaleIndex ( address ) external view returns ( uint256 );
  function normalAddressesForSaleIndexSet ( address _address, uint256 _normalAddressesForSaleIndex ) external;
  function overallSupply (  ) external view returns ( uint256 );
  function overallSupplySet ( uint256 _overallSupply ) external;
  function ownerGenesis (  ) external view returns ( address );
  function ownerGenesisBuys (  ) external view returns ( address );
  function ownerMain (  ) external view returns ( address );
  function ownerNormalAddress (  ) external view returns ( address );
  function ownerStakeBuys (  ) external view returns ( address );
  function ownerStakes (  ) external view returns ( address );
  function ownerTokenService (  ) external view returns ( address );
  function setOwnerGenesis (  ) external;
  function setOwnerGenesisBuys (  ) external;
  function setOwnerMain (  ) external;
  function setOwnerNormalAddress (  ) external;
  function setOwnerStakeBuys (  ) external;
  function setOwnerStakes (  ) external;
  function setOwnerTokenService (  ) external;
  function setupRunning (  ) external view returns ( bool );
  function setupRunningSet ( bool _setupRunning ) external;
  function stakeBalances ( address ) external view returns ( uint256 );
  function stakeBalancesSet ( address _address, uint256 _stakeBalances ) external;
  function stakeBuyPrice ( address ) external view returns ( uint256 );
  function stakeBuyPriceSet ( address _address, uint256 _stakeBuyPrice ) external;
  function stakeDecimals (  ) external view returns ( uint256 );
  function stakeDecimalsSet ( address _from, uint256 _stakeDecimals ) external;
  function stakeHoldersImported (  ) external view returns ( uint256 );
  function stakeHoldersImportedSet ( uint256 _stakeHoldersImported ) external;
  function stakeHoldersListIndex ( address ) external view returns ( uint256 );
  function stakeHoldersListIndexSet ( address _address, uint256 _stakeHoldersListIndex ) external;
  function stakeMneBurnCount (  ) external view returns ( uint256 );
  function stakeMneBurnCountSet ( uint256 _stakeMneBurnCount ) external;
  function stakeMneTransferBurnCount (  ) external view returns ( uint256 );
  function stakeMneTransferBurnCountSet ( uint256 _stakeMneTransferBurnCount ) external;
  function stakesForSaleIndex ( address ) external view returns ( uint256 );
  function stakesForSaleIndexSet ( address _address, uint256 _stakesForSaleIndex ) external;
  function tokenCreated ( address, uint256 ) external view returns ( address );
  function tokenCreatedSet ( address _address, address _tokenCreated ) external;
  function tokenICOCreated ( address, uint256 ) external view returns ( address );
  function tokenICOCreatedSet ( address _address, address _tokenICOCreated ) external;
  function totalMaxAvailableAmount (  ) external view returns ( uint256 );
  function totalMaxAvailableAmountSet ( uint256 _totalMaxAvailableAmount ) external;
  function totalPaidStakeHolders (  ) external view returns ( uint256 );
  function totalPaidStakeHoldersSet ( uint256 _totalPaidStakeHolders ) external;
  function transferStakeGenesisCount (  ) external view returns ( uint256 );
  function transferStakeGenesisCountSet ( uint256 _transferStakeGenesisCount ) external;
  function transferStakeMNECount (  ) external view returns ( uint256 );
  function transferStakeMNECountSet ( uint256 _transferStakeMNECount ) external;
}

interface publicArrays {
  function Level1TradeHistoryAmountETH ( uint256 ) external view returns ( uint256 );
  function Level1TradeHistoryAmountETHFee ( uint256 ) external view returns ( uint256 );
  function Level1TradeHistoryAmountETHFeeLength (  ) external view returns ( uint256 len );
  function Level1TradeHistoryAmountETHFeeSet ( uint256 _Level1TradeHistoryAmountETHFee ) external;
  function Level1TradeHistoryAmountETHLength (  ) external view returns ( uint256 len );
  function Level1TradeHistoryAmountETHSet ( uint256 _Level1TradeHistoryAmountETH ) external;
  function Level1TradeHistoryAmountMNE ( uint256 ) external view returns ( uint256 );
  function Level1TradeHistoryAmountMNELength (  ) external view returns ( uint256 len );
  function Level1TradeHistoryAmountMNESet ( uint256 _Level1TradeHistoryAmountMNE ) external;
  function Level1TradeHistoryBuyer ( uint256 ) external view returns ( address );
  function Level1TradeHistoryBuyerLength (  ) external view returns ( uint256 len );
  function Level1TradeHistoryBuyerSet ( address _Level1TradeHistoryBuyer ) external;
  function Level1TradeHistoryDate ( uint256 ) external view returns ( uint256 );
  function Level1TradeHistoryDateLength (  ) external view returns ( uint256 len );
  function Level1TradeHistoryDateSet ( uint256 _Level1TradeHistoryDate ) external;
  function Level1TradeHistorySeller ( uint256 ) external view returns ( address );
  function Level1TradeHistorySellerLength (  ) external view returns ( uint256 len );
  function Level1TradeHistorySellerSet ( address _Level1TradeHistorySeller ) external;
  function Level2TradeHistoryAmountETH ( uint256 ) external view returns ( uint256 );
  function Level2TradeHistoryAmountETHFee ( uint256 ) external view returns ( uint256 );
  function Level2TradeHistoryAmountETHFeeLength (  ) external view returns ( uint256 len );
  function Level2TradeHistoryAmountETHFeeSet ( uint256 _Level2TradeHistoryAmountETHFee ) external;
  function Level2TradeHistoryAmountETHLength (  ) external view returns ( uint256 len );
  function Level2TradeHistoryAmountETHSet ( uint256 _Level2TradeHistoryAmountETH ) external;
  function Level2TradeHistoryAmountMNE ( uint256 ) external view returns ( uint256 );
  function Level2TradeHistoryAmountMNELength (  ) external view returns ( uint256 len );
  function Level2TradeHistoryAmountMNESet ( uint256 _Level2TradeHistoryAmountMNE ) external;
  function Level2TradeHistoryAvailableAmountMNE ( uint256 ) external view returns ( uint256 );
  function Level2TradeHistoryAvailableAmountMNELength (  ) external view returns ( uint256 len );
  function Level2TradeHistoryAvailableAmountMNESet ( uint256 _Level2TradeHistoryAvailableAmountMNE ) external;
  function Level2TradeHistoryBuyer ( uint256 ) external view returns ( address );
  function Level2TradeHistoryBuyerLength (  ) external view returns ( uint256 len );
  function Level2TradeHistoryBuyerSet ( address _Level2TradeHistoryBuyer ) external;
  function Level2TradeHistoryDate ( uint256 ) external view returns ( uint256 );
  function Level2TradeHistoryDateLength (  ) external view returns ( uint256 len );
  function Level2TradeHistoryDateSet ( uint256 _Level2TradeHistoryDate ) external;
  function Level2TradeHistorySeller ( uint256 ) external view returns ( address );
  function Level2TradeHistorySellerLength (  ) external view returns ( uint256 len );
  function Level2TradeHistorySellerSet ( address _Level2TradeHistorySeller ) external;
  function Level3TradeHistoryAmountETH ( uint256 ) external view returns ( uint256 );
  function Level3TradeHistoryAmountETHFee ( uint256 ) external view returns ( uint256 );
  function Level3TradeHistoryAmountETHFeeLength (  ) external view returns ( uint256 len );
  function Level3TradeHistoryAmountETHFeeSet ( uint256 _Level3TradeHistoryAmountETHFee ) external;
  function Level3TradeHistoryAmountETHLength (  ) external view returns ( uint256 len );
  function Level3TradeHistoryAmountETHSet ( uint256 _Level3TradeHistoryAmountETH ) external;
  function Level3TradeHistoryAmountMNE ( uint256 ) external view returns ( uint256 );
  function Level3TradeHistoryAmountMNELength (  ) external view returns ( uint256 len );
  function Level3TradeHistoryAmountMNESet ( uint256 _Level3TradeHistoryAmountMNE ) external;
  function Level3TradeHistoryAvailableAmountMNE ( uint256 ) external view returns ( uint256 );
  function Level3TradeHistoryAvailableAmountMNELength (  ) external view returns ( uint256 len );
  function Level3TradeHistoryAvailableAmountMNESet ( uint256 _Level3TradeHistoryAvailableAmountMNE ) external;
  function Level3TradeHistoryBuyer ( uint256 ) external view returns ( address );
  function Level3TradeHistoryBuyerLength (  ) external view returns ( uint256 len );
  function Level3TradeHistoryBuyerSet ( address _Level3TradeHistoryBuyer ) external;
  function Level3TradeHistoryDate ( uint256 ) external view returns ( uint256 );
  function Level3TradeHistoryDateLength (  ) external view returns ( uint256 len );
  function Level3TradeHistoryDateSet ( uint256 _Level3TradeHistoryDate ) external;
  function Level3TradeHistorySeller ( uint256 ) external view returns ( address );
  function Level3TradeHistorySellerLength (  ) external view returns ( uint256 len );
  function Level3TradeHistorySellerSet ( address _Level3TradeHistorySeller ) external;
  function MNETradeHistoryAmountETH ( uint256 ) external view returns ( uint256 );
  function MNETradeHistoryAmountETHFee ( uint256 ) external view returns ( uint256 );
  function MNETradeHistoryAmountETHFeeLength (  ) external view returns ( uint256 len );
  function MNETradeHistoryAmountETHFeeSet ( uint256 _MNETradeHistoryAmountETHFee ) external;
  function MNETradeHistoryAmountETHLength (  ) external view returns ( uint256 len );
  function MNETradeHistoryAmountETHSet ( uint256 _MNETradeHistoryAmountETH ) external;
  function MNETradeHistoryAmountMNE ( uint256 ) external view returns ( uint256 );
  function MNETradeHistoryAmountMNELength (  ) external view returns ( uint256 len );
  function MNETradeHistoryAmountMNESet ( uint256 _MNETradeHistoryAmountMNE ) external;
  function MNETradeHistoryBuyer ( uint256 ) external view returns ( address );
  function MNETradeHistoryBuyerLength (  ) external view returns ( uint256 len );
  function MNETradeHistoryBuyerSet ( address _MNETradeHistoryBuyer ) external;
  function MNETradeHistoryDate ( uint256 ) external view returns ( uint256 );
  function MNETradeHistoryDateLength (  ) external view returns ( uint256 len );
  function MNETradeHistoryDateSet ( uint256 _MNETradeHistoryDate ) external;
  function MNETradeHistorySeller ( uint256 ) external view returns ( address );
  function MNETradeHistorySellerLength (  ) external view returns ( uint256 len );
  function MNETradeHistorySellerSet ( address _MNETradeHistorySeller ) external;
  function StakeTradeHistoryBuyer ( uint256 ) external view returns ( address );
  function StakeTradeHistoryBuyerLength (  ) external view returns ( uint256 len );
  function StakeTradeHistoryBuyerSet ( address _StakeTradeHistoryBuyer ) external;
  function StakeTradeHistoryDate ( uint256 ) external view returns ( uint256 );
  function StakeTradeHistoryDateLength (  ) external view returns ( uint256 len );
  function StakeTradeHistoryDateSet ( uint256 _StakeTradeHistoryDate ) external;
  function StakeTradeHistoryETHFee ( uint256 ) external view returns ( uint256 );
  function StakeTradeHistoryETHFeeLength (  ) external view returns ( uint256 len );
  function StakeTradeHistoryETHFeeSet ( uint256 _StakeTradeHistoryETHFee ) external;
  function StakeTradeHistoryETHPrice ( uint256 ) external view returns ( uint256 );
  function StakeTradeHistoryETHPriceLength (  ) external view returns ( uint256 len );
  function StakeTradeHistoryETHPriceSet ( uint256 _StakeTradeHistoryETHPrice ) external;
  function StakeTradeHistoryMNEGenesisBurned ( uint256 ) external view returns ( uint256 );
  function StakeTradeHistoryMNEGenesisBurnedLength (  ) external view returns ( uint256 len );
  function StakeTradeHistoryMNEGenesisBurnedSet ( uint256 _StakeTradeHistoryMNEGenesisBurned ) external;
  function StakeTradeHistorySeller ( uint256 ) external view returns ( address );
  function StakeTradeHistorySellerLength (  ) external view returns ( uint256 len );
  function StakeTradeHistorySellerSet ( address _StakeTradeHistorySeller ) external;
  function StakeTradeHistoryStakeAmount ( uint256 ) external view returns ( uint256 );
  function StakeTradeHistoryStakeAmountLength (  ) external view returns ( uint256 len );
  function StakeTradeHistoryStakeAmountSet ( uint256 _StakeTradeHistoryStakeAmount ) external;
  function deleteGenesisAddressesForSaleLevel1 (  ) external;
  function deleteGenesisAddressesForSaleLevel2 (  ) external;
  function deleteGenesisAddressesForSaleLevel3 (  ) external;
  function deleteNormalAddressesForSale (  ) external;
  function deleteStakeHoldersList (  ) external;
  function deleteStakesForSale (  ) external;
  function genesisAddressesForSaleLevel1 ( uint256 ) external view returns ( address );
  function genesisAddressesForSaleLevel1Length (  ) external view returns ( uint256 len );
  function genesisAddressesForSaleLevel1Set ( address _genesisAddressesForSaleLevel1 ) external;
  function genesisAddressesForSaleLevel1SetAt ( uint256 i, address _address ) external;
  function genesisAddressesForSaleLevel2 ( uint256 ) external view returns ( address );
  function genesisAddressesForSaleLevel2Length (  ) external view returns ( uint256 len );
  function genesisAddressesForSaleLevel2Set ( address _genesisAddressesForSaleLevel2 ) external;
  function genesisAddressesForSaleLevel2SetAt ( uint256 i, address _address ) external;
  function genesisAddressesForSaleLevel3 ( uint256 ) external view returns ( address );
  function genesisAddressesForSaleLevel3Length (  ) external view returns ( uint256 len );
  function genesisAddressesForSaleLevel3Set ( address _genesisAddressesForSaleLevel3 ) external;
  function genesisAddressesForSaleLevel3SetAt ( uint256 i, address _address ) external;
  function normalAddressesForSale ( uint256 ) external view returns ( address );
  function normalAddressesForSaleLength (  ) external view returns ( uint256 len );
  function normalAddressesForSaleSet ( address _normalAddressesForSale ) external;
  function normalAddressesForSaleSetAt ( uint256 i, address _address ) external;
  function ownerGenesis (  ) external view returns ( address );
  function ownerGenesisBuys (  ) external view returns ( address );
  function ownerMain (  ) external view returns ( address );
  function ownerNormalAddress (  ) external view returns ( address );
  function ownerStakeBuys (  ) external view returns ( address );
  function ownerStakes (  ) external view returns ( address );
  function setOwnerGenesis (  ) external;
  function setOwnerGenesisBuys (  ) external;
  function setOwnerMain (  ) external;
  function setOwnerNormalAddress (  ) external;
  function setOwnerStakeBuys (  ) external;
  function setOwnerStakes (  ) external;
  function stakeHoldersList ( uint256 ) external view returns ( address );
  function stakeHoldersListAt ( uint256 i, address _address ) external;
  function stakeHoldersListLength (  ) external view returns ( uint256 len );
  function stakeHoldersListSet ( address _stakeHoldersList ) external;
  function stakesForSale ( uint256 ) external view returns ( address );
  function stakesForSaleLength (  ) external view returns ( uint256 len );
  function stakesForSaleSet ( address _stakesForSale ) external;
  function stakesForSaleSetAt ( uint256 i, address _address ) external;
}

interface genesisCalls {
  function AllowAddressToDestroyGenesis ( address _from, address _address ) external;
  function AllowReceiveGenesisTransfers ( address _from ) external;
  function BurnTokens ( address _from, uint256 mneToBurn ) external returns ( bool success );
  function RemoveAllowAddressToDestroyGenesis ( address _from ) external;
  function RemoveAllowReceiveGenesisTransfers ( address _from ) external;
  function RemoveGenesisAddressFromSale ( address _from ) external;
  function SetGenesisForSale ( address _from, uint256 weiPrice ) external;
  function TransferGenesis ( address _from, address _to ) external;
  function UpgradeToLevel2FromLevel1 ( address _address, uint256 weiValue ) external;
  function UpgradeToLevel3FromDev ( address _address ) external;
  function UpgradeToLevel3FromLevel1 ( address _address, uint256 weiValue ) external;
  function UpgradeToLevel3FromLevel2 ( address _address, uint256 weiValue ) external;
  function availableBalanceOf ( address _address ) external view returns ( uint256 Balance );
  function balanceOf ( address _address ) external view returns ( uint256 balance );
  function deleteAddressFromGenesisSaleList ( address _address ) external;
  function isAnyGenesisAddress ( address _address ) external view returns ( bool success );
  function isGenesisAddressLevel1 ( address _address ) external view returns ( bool success );
  function isGenesisAddressLevel2 ( address _address ) external view returns ( bool success );
  function isGenesisAddressLevel2Or3 ( address _address ) external view returns ( bool success );
  function isGenesisAddressLevel3 ( address _address ) external view returns ( bool success );
  function ownerGenesis (  ) external view returns ( address );
  function ownerGenesisBuys (  ) external view returns ( address );
  function ownerMain (  ) external view returns ( address );
  function ownerNormalAddress (  ) external view returns ( address );
  function ownerStakeBuys (  ) external view returns ( address );
  function ownerStakes (  ) external view returns ( address );
  function setGenesisAddress ( address _from, address _address ) external;
  function setGenesisAddressArray ( address _from, address[] calldata _addressList ) external;
  function setGenesisAddressDevArray ( address _from, address[] calldata _addressList ) external;
  function setGenesisCallerAddress ( address _caller ) external returns ( bool success );
  function setOwnerGenesisBuys (  ) external;
  function setOwnerMain (  ) external;
  function setOwnerNormalAddress (  ) external;
  function setOwnerStakeBuys (  ) external;
  function setOwnerStakes (  ) external;
  function stopSetup ( address _from ) external returns ( bool success );
  function BurnGenesisAddresses ( address _from, address[] calldata _genesisAddressesToBurn ) external;
}

contract stakesBuys
{
	
address public ownerMain = 0x0000000000000000000000000000000000000000;
address public updaterAddress = 0x0000000000000000000000000000000000000000;
function setUpdater() public {if (updaterAddress == 0x0000000000000000000000000000000000000000) updaterAddress = msg.sender; else revert();}
function updaterSetOwnerMain(address _address) public {if (tx.origin == updaterAddress) ownerMain = _address; else revert();}

function setOwnerMain() public {
	if (tx.origin == updaterAddress)
		ownerMain = msg.sender;
	else
		revert();
}

modifier onlyOwner(){
    require(msg.sender == ownerMain);
     _;
}

publicCalls public pc;
publicArrays public pa;
genesisCalls public gn;
	
constructor(address _publicCallsAddress, address _publicArraysAddress, address _genesisAddress) public {
setUpdater();
pc = publicCalls(_publicCallsAddress);
pc.setOwnerStakeBuys();
pa = publicArrays(_publicArraysAddress);
pa.setOwnerStakeBuys();
gn = genesisCalls(_genesisAddress);
gn.setOwnerStakeBuys();
}

function reloadGenesis(address _address) public
{
	if (msg.sender == updaterAddress)
	{
		gn = genesisCalls(_address);
		gn.setOwnerStakeBuys();
	}
	else revert();
}	

function reloadPublicCalls(address _address, uint code) public { if (!(code == 1234)) revert();  if (msg.sender == updaterAddress)	{pc = publicCalls(_address); pc.setOwnerStakeBuys();} else revert();}
function reloadPublicArrays(address _address, uint code) public { if (!(code == 1234)) revert();  if (msg.sender == updaterAddress)	{pa = publicArrays(_address); pa.setOwnerStakeBuys();} else revert();}

event Transfer(address indexed from, address indexed to, uint256 value);
event StakeTransfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed _owner, address indexed _spender, uint256 _value);
event GenesisAddressTransfer(address indexed from, address indexed to, uint256 supply);
event GenesisAddressSale(address indexed from, address indexed to, uint256 price, uint256 supply);
event GenesisBuyPriceHistory(address indexed from, uint256 price, uint8 genesisType);
event GenesisRemoveGenesisSaleHistory(address indexed from);
event AllowDestroyHistory(address indexed from, address indexed to);
event Level2UpgradeHistory(address indexed from);
event Level3UpgradeHistory(address indexed from);
event GenesisLevel1ForSaleHistory(address indexed from);
event NormalAddressForSaleHistory(address indexed from, uint price);
event NormalAddressRemoveSaleHistory(address indexed from);	
event NormalAddressSale(address indexed from, address indexed to, uint price, uint balance);
event RemoveStakeSale(address indexed from);
event StakeGenesisTransfer(address indexed from, address indexed to, uint value, uint amountGenesisToBurn);
event TransferStake(address indexed from, address indexed to, uint value); 
event LogStakeHolderSends(address indexed to, uint balance, uint amountToSend);
event LogFailedStakeHolderSends(address indexed to, uint balance, uint amountToSend);
event StakeGenesisSale(address indexed to, address indexed from, uint balance, uint amountGenesisToBurn, uint totalToSend);
event GenesisRemoveSaleHistory(address indexed from);
event RemoveAllowDestroyHistory(address indexed from);
event StakeMNETransfer(address indexed from, address indexed to, uint256 value, uint256 mneToBurn);
event StakeMNESale(address indexed to, address indexed from, uint256 value, uint256 mneToBurn, uint256 totalToSend);
event CreateTokenHistory(address indexed _owner, address indexed _address);
event CreateTokenICOHistory(address indexed _owner, address indexed _address);
event SetStakeForSaleHistory(address indexed _owner, uint256 priceInWei);
event Burn(address indexed _owner, uint256 _value);	

function deleteStakeFromSaleList(address _address) private {
		uint lastIndex = pa.stakesForSaleLength() - 1;
		if (lastIndex > 0)
		{
			address lastIndexAddress = pa.stakesForSale(lastIndex);
			pc.stakesForSaleIndexSet(lastIndexAddress, pc.stakesForSaleIndex(_address));
			pa.stakesForSaleSetAt(pc.stakesForSaleIndex(_address), lastIndexAddress);
		}
		pc.stakesForSaleIndexSet(_address, 0);
		pa.deleteStakesForSale();
}

function addStakeHolder(address _address) private {
        pa.stakeHoldersListSet(_address);
		pc.stakeHoldersListIndexSet(_address, pa.stakeHoldersListLength() - 1);					
}

function deleteStakeHolder(address _address) private {
		uint lastIndex = pa.stakeHoldersListLength() - 1;
		if (lastIndex > 0)
		{
			address lastIndexAddress = pa.stakeHoldersList(lastIndex);
			pc.stakeHoldersListIndexSet(lastIndexAddress, pc.stakeHoldersListIndex(_address));
			pa.stakeHoldersListAt(pc.stakeHoldersListIndex(_address), lastIndexAddress);
		}
		pc.stakeHoldersListIndexSet(_address, 0);
		pa.deleteStakeHoldersList();
}

function BuyStakeMNE(address _from, address _address, uint256 _msgvalue) public onlyOwner returns (uint256 _mneToBurn, uint256 _feesToPayToSeller){
	if (pc.stakeBuyPrice(_from) > 0) revert('(pc.stakeBuyPrice(_from) > 0)');
	if (!(_from != _address)) revert('(!(_from != _address))');
	if (!(pc.stakeBuyPrice(_address) > 0)) revert('(!(pc.stakeBuyPrice(_address) > 0))');
	if (!(pc.stakeBalances(_address) > 0)) revert('(!(pc.stakeBalances(_address) > 0))');
	
	if (pc.isGenesisAddressForSale(_from)) revert('(pc.isGenesisAddressForSale(_from))');
	
	if (pc.isNormalAddressForSale(_from)) revert('(pc.isNormalAddressForSale(_from))');
	
	uint256 mneToBurn = pc.amountOfMNEToBuyStakes() * pc.stakeBalances(_address) * 100 / pc.stakeDecimals();
	if (mneToBurn < pc.amountOfMNEToBuyStakes())
		mneToBurn = pc.amountOfMNEToBuyStakes();	
	if (!(gn.availableBalanceOf(_from) >= mneToBurn)) revert('(!(gn.availableBalanceOf(_from) >= mneToBurn))');	
	
	uint256 feesToPayToContract = 0;
	uint256 feesToPayToSeller = pc.stakeBuyPrice(_address);
	uint256 feesGeneralToPayToContract = (feesToPayToContract + feesToPayToSeller) * pc.ethPercentStakeExchange() / 100;
		
	uint256 totalToSend = feesToPayToContract + feesToPayToSeller + feesGeneralToPayToContract;
	
	if  (totalToSend == 0) revert('(totalToSend == 0)');
	if (!(_msgvalue == totalToSend)) revert('(!(_msgvalue == totalToSend))');
	
	deleteStakeFromSaleList(_address);
	uint256 _value = pc.stakeBalances(_address);
	uint256 _valueFrom = pc.stakeBalances(_from);
	pc.stakeBalancesSet(_from, _valueFrom + _value); 
	pc.stakeBalancesSet(_address, 0); 
	emit TransferStake(_address, _from, _value); 	
	pc.stakeBuyPriceSet(_address, 0);
	pc.stakeMneBurnCountSet(pc.stakeMneBurnCount() + mneToBurn);
	pc.buyStakeMNECountSet(pc.buyStakeMNECount() + 1);	

    if (pc.stakeBalances(_address) == 0)
		deleteStakeHolder(_address);	
	
	if (pc.stakeHoldersListIndex(_from) == 0)
		addStakeHolder(_from);
	
	emit StakeMNESale(_from, _address, _value, mneToBurn, totalToSend);
	
	pa.StakeTradeHistorySellerSet(_address);
	pa.StakeTradeHistoryBuyerSet(_from);
	pa.StakeTradeHistoryStakeAmountSet(_value);
	pa.StakeTradeHistoryETHPriceSet(totalToSend);
	pa.StakeTradeHistoryETHFeeSet(feesGeneralToPayToContract);
	pa.StakeTradeHistoryMNEGenesisBurnedSet(mneToBurn);
	pa.StakeTradeHistoryDateSet(now);
	
	return (mneToBurn, feesToPayToSeller);
}

function BuyStakeGenesis(address _from, address payable _address, address[] memory _genesisAddressesToBurn, uint256 _msgvalue) public onlyOwner returns (uint256 _feesToPayToSeller){
	if (pc.stakeBuyPrice(_from) > 0) revert('(pc.stakeBuyPrice(_from) > 0)');
	if (!(_from != _address)) revert('(!(_from != _address))');
	if (!(pc.stakeBuyPrice(_address) > 0)) revert('(!(pc.stakeBuyPrice(_address) > 0))');
	if (!(pc.stakeBalances(_address) > 0)) revert('(!(pc.stakeBalances(_address) > 0))');	
	uint256 _amountGenesisToBurn = pc.amountOfGenesisToBuyStakes() * pc.stakeBalances(_address) * 100 / pc.stakeDecimals();
	if (_amountGenesisToBurn < pc.amountOfGenesisToBuyStakes())
		_amountGenesisToBurn = pc.amountOfGenesisToBuyStakes();
	if (_genesisAddressesToBurn.length < _amountGenesisToBurn) revert('(_genesisAddressesToBurn.length < _amountGenesisToBurn)');
	
	uint256 feesToPayToContract = 0;
	uint256 feesToPayToSeller = pc.stakeBuyPrice(_address);
	uint256 feesGeneralToPayToContract = (feesToPayToContract + feesToPayToSeller) * pc.ethPercentStakeExchange() / 100;
		
	uint256 totalToSend = feesToPayToContract + feesToPayToSeller + feesGeneralToPayToContract;
	
	if  (totalToSend == 0) revert('(totalToSend == 0)');
	if (!(_msgvalue == totalToSend)) revert('(!(_msgvalue == totalToSend))');
	
	gn.BurnGenesisAddresses(_from, _genesisAddressesToBurn);
	
	uint256 _value = pc.stakeBalances(_address);
	uint256 _valueFrom = pc.stakeBalances(_from);
	pc.stakeBalancesSet(_from, _valueFrom + _value); 
	pc.stakeBalancesSet(_address, 0); 
	emit TransferStake(_address, _from, _value); 	
	pc.stakeBuyPriceSet(_address, 0);
	pc.buyStakeGenesisCountSet(pc.buyStakeGenesisCount() + 1);
	deleteStakeFromSaleList(_address);
	
	if (pc.stakeBalances(_address) == 0)
		deleteStakeHolder(_address);	
	
	if (pc.stakeHoldersListIndex(_from) == 0)
		addStakeHolder(_from);
	
	emit StakeGenesisSale(_from, _address, _value, _amountGenesisToBurn, totalToSend);
	
	pa.StakeTradeHistorySellerSet(_address);
	pa.StakeTradeHistoryBuyerSet(_from);
	pa.StakeTradeHistoryStakeAmountSet(_value);
	pa.StakeTradeHistoryETHPriceSet(totalToSend);
	pa.StakeTradeHistoryETHFeeSet(feesGeneralToPayToContract);
	pa.StakeTradeHistoryMNEGenesisBurnedSet(_amountGenesisToBurn);
	pa.StakeTradeHistoryDateSet(now);
	
	return feesToPayToSeller;
}
}