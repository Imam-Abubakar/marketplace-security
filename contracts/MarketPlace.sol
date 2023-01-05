//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract MarketPlace is Pausable, ERC721Holder,Ownable {
    
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 feeCut=5;
    uint private marketplaceBalance=0;
    
    IERC20 public acceptedToken;
    bytes4 public constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    
    constructor()  Ownable() {
        // require(_acceptedToken.isContract(), "The accepted token address must be a deployed contract");
        // acceptedToken = IERC20(_acceptedToken); address _acceptedToken
    }
    
    function setPaused(bool _setPaused) public onlyOwner {
        return (_setPaused) ? _pause() : _unpause();
    }
    
    struct Order {
        bytes32 orderId;
        address payable seller;
        uint256 askingPrice;
        uint256 expiryTime;
        address tokenAddress;
    }

    struct DirectOrder {
        bytes32 orderId;
        address payable seller;
        uint256 askingPrice;
        address tokenAddress;
    }
    
    struct Bid {
        bytes32 bidId;
        address payable bidder;
        uint256 bidPrice;
    }
    
    //            Events
    event OrderCreated(
        bytes32 orderId,
        address indexed seller,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 askingPrice
    );

    event FixPriceOrderUpdated(
        uint256 tokenId,
        uint256 newPrice
    );
    
    event DirectOrderCreated(
        bytes32 orderId,
        address indexed seller,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 askingPrice
        
    );

    event OrderUpdated(
        bytes32 orderId,
        uint tokenId,
        uint256 askingPrice
    );

    event OrderSuccessful(
        bytes32 orderId,
        uint tokenId,
        address indexed buyer,
        uint256 askingPrice
    );

    event DirectOrderSuccessful(
        bytes32 orderId,
        uint tokenId,
        address indexed buyer,
        uint256 price  
    );

    event OrderCancelled(bytes32 id, uint tokenId);

    event DirectOrderCancelled(bytes32 id, uint tokenId);

    
    event BidCreated(
      bytes32 id,
      address indexed tokenAddress,
      uint256 indexed tokenId,
      address indexed bidder,
      uint256 priceInWei
    );

    

    event BidAccepted(bytes32 id);
    event BidCancelled(bytes32 id);

//                Mappings
    mapping(address => mapping(uint256 => Order)) public orderByTokenId;  
    mapping(address => mapping(uint256 => Bid)) public bidByOrderId;       
    mapping(address => mapping(uint256 => DirectOrder)) public DirectorderByTokenId;  

    mapping(uint => bool) private firstTransfer;

    function setFeeCut(uint256 _newCut) public onlyOwner {
        // uint256 test = _newCut % 10;
        require(_newCut > 0, "Fee cannot be less than 1%");
        feeCut = _newCut;
    }
   
    function createOrder(address _tokenAddress, uint256 _tokenId, uint256 _askingPrice) public whenNotPaused {
        
        _createOrder( _tokenAddress,  _tokenId,  _askingPrice);
    }

    function newOwner(address _new) public onlyOwner{
        transferOwnership(_new);
    }
    
    function cancelOrder(address _tokenAddress, uint256 _tokenId) public whenNotPaused {
        
        Order memory order = orderByTokenId[_tokenAddress][_tokenId];
        
        require(order.seller == msg.sender || msg.sender == owner(), "Marketplace: unauthorized sender");
        
         Bid memory bid = bidByOrderId[_tokenAddress][_tokenId];

         require(bid.bidId == 0, "Marketplace: This auction has active bids");
         
         
         _cancelOrder(order.orderId,  _tokenAddress,  _tokenId,  msg.sender);
    
    }

    function cancelFixPriceOrder(address _tokenAddress, uint256 _tokenId) public whenNotPaused {
        
        DirectOrder memory order = DirectorderByTokenId[_tokenAddress][_tokenId];
        
        require(order.seller == msg.sender || msg.sender == owner(), "Marketplace: unauthorized sender");
        
         
         _cancelFixPriceOrder(order.orderId,  _tokenAddress,  _tokenId,  msg.sender);
    
    }

    function updateOrder(address _tokenAddress, uint256 _tokenId, uint256 _askingPrice) public whenNotPaused {
        
        Order memory order = orderByTokenId[_tokenAddress][_tokenId];
        require(order.orderId != 0, "Markeplace: Order not yet published");
        require(order.seller == msg.sender, "Markeplace: sender is not allowed");
        Bid memory bid = bidByOrderId[_tokenAddress][_tokenId];
        require(bid.bidId == 0, "Marketplace: This auction has active bids on it so it can't be updated");

        require(_askingPrice > 0, "Marketplace: Price should be bigger than 0");
        
        orderByTokenId[_tokenAddress][_tokenId].askingPrice = _askingPrice;
       
        emit OrderUpdated(order.orderId, _tokenId, _askingPrice);
    }


    function updateFixPriceOrder(address _tokenAddress, uint256 _tokenId, uint256 _newPrice) public whenNotPaused{
        
        DirectOrder memory directOrder = DirectorderByTokenId[_tokenAddress][_tokenId];
        require(directOrder.orderId != 0, "Marketplace: This tokenID is not on fix price sale yet");
        require(directOrder.seller == msg.sender, "Marketplace: sender is not allowed");
        require(_newPrice > 0, "Marketplace: New price must be greater than zero");
        DirectorderByTokenId[_tokenAddress][_tokenId].askingPrice = _newPrice;
        emit FixPriceOrderUpdated(_tokenId, _newPrice);
    }


    // function getDirectOrderPrice(address _tokenAddress, uint256 _tokenId) public view whenNotPaused returns (uint256)
    // {
    //     DirectOrder memory directorder = DirectorderByTokenId[_tokenAddress][_tokenId];
    //     return directorder.askingPrice;
    // }

    
    
    // function safeExecuteOrder(address _tokenAddress, uint256 _tokenId, uint _askingPrice) public  whenNotPaused {
        
        
    //     Order memory order = _getValidOrder(_tokenAddress, _tokenId);
        
    //     require(order.askingPrice == _askingPrice, "Marketplace: invalid price");
    //     require(order.seller != msg.sender, "Marketplace: unauthorized sender");
        
    //    (order.seller).transfer(_askingPrice);
        
        
    //     Bid memory bid = bidByOrderId[_tokenAddress][_tokenId];
        
    //     if(bid.bidId !=0 ) {
    //         _cancelBid(bid.bidId, _tokenAddress, _tokenId, bid.bidder, bid.bidPrice);
    //     }
        
    //     _executeOrder(order.orderId, msg.sender,  _tokenAddress,  _tokenId,  _askingPrice);

        
    // }
    
    function safePlaceBid(address _tokenAddress, uint256 _tokenId) payable public whenNotPaused {
        Order memory order = orderByTokenId[_tokenAddress][_tokenId];
        require( order.seller != msg.sender, "Marketplace: The owner of NFT cannot place bid itself");
        _createBid( _tokenAddress,  _tokenId, msg.value);
    }
    
    // function cancelBid(address _tokenAddress, uint256 _tokenId) public whenNotPaused {
        
    //     Bid memory bid = bidByOrderId[_tokenAddress][_tokenId];
    //     require(bid.bidder == msg.sender || msg.sender == owner(), "Marketplace: Unauthorized sender");
        
    //     _cancelBid(bid.bidId, _tokenAddress, _tokenId, bid.bidder, bid.bidPrice);
    // }

 
    function acceptDirectSellOrder(address _tokenAddress, uint256 _tokenId) payable public whenNotPaused 
    {
        DirectOrder memory directorder = DirectorderByTokenId[_tokenAddress][_tokenId];
        require(directorder.orderId != 0, "Marketplace: This order doesn't exist");
        require(directorder.seller != msg.sender, "Marketplace: Can't sell to owner");
        require(directorder.askingPrice == msg.value, "Marketplace: Less amount sent to buy");

        uint256 finalAmountAfterMarketplaceFee = directorder.askingPrice - ((directorder.askingPrice*feeCut)/100);
        marketplaceBalance += ((directorder.askingPrice*feeCut)/100);

        uint256 amountAfterRoyaltyCut;
        bool royaltyIntention  = IERC721(_tokenAddress).royaltyInfoIntention(_tokenId);
        if(royaltyIntention) // First owner wants Royalties
        {
            if(firstTransfer[_tokenId] != false)
            {
            // First Transfer
            firstTransfer[_tokenId] = false; 

            delete DirectorderByTokenId[_tokenAddress][_tokenId];
            directorder.seller.transfer(finalAmountAfterMarketplaceFee); 

            }
            else
            {
            address payable firstOwnerAddress  = IERC721(_tokenAddress).royaltyInfoOwner(_tokenId);
            uint256 percentage = IERC721(_tokenAddress).royaltyInfoPercentage(_tokenId);


            // uint256 percentage = royaltyInformation[_tokenId].royalty;
            uint256 royaltyAmount = ((finalAmountAfterMarketplaceFee*percentage)/100);
            amountAfterRoyaltyCut = finalAmountAfterMarketplaceFee - ((finalAmountAfterMarketplaceFee*percentage)/100);

            delete DirectorderByTokenId[_tokenAddress][_tokenId];

            firstOwnerAddress.transfer(royaltyAmount); 

            

            directorder.seller.transfer(amountAfterRoyaltyCut);


            }
        }
        else // The first owner doesn't want Royalties
        {
            delete DirectorderByTokenId[_tokenAddress][_tokenId];
            directorder.seller.transfer(finalAmountAfterMarketplaceFee); // Full amount is sent to seller instead
        }

        bool isLocked = IERC721(_tokenAddress).isContentLocked(_tokenId);
        if(isLocked)
        {
            IERC721(_tokenAddress).flipContentLockedStatus(_tokenId);
        }
        IERC721(_tokenAddress).safeTransferFrom(address(this), msg.sender, _tokenId);
        emit DirectOrderSuccessful(directorder.orderId, _tokenId,  msg.sender, msg.value);
    }
    
    
    /* */
    function acceptBidandExecuteOrder(address _tokenAddress, uint256 _tokenId, uint256 _bidPrice) public whenNotPaused {
        
        Order memory order = orderByTokenId[_tokenAddress][_tokenId];
        require(order.orderId != 0, "Marketplace: No order auction exists for this tokenID");
        require(order.expiryTime < block.timestamp, "Marketplace: Auction hasn't ended yet");

        Bid memory bid = bidByOrderId[_tokenAddress][_tokenId];

        require(order.seller == msg.sender || bid.bidder == msg.sender, "Marketplace: Unauthorized sender");
        require(bid.bidPrice == _bidPrice, "Markeplace: invalid bid price");
        
        
        delete bidByOrderId[_tokenAddress][_tokenId];
        
        emit BidAccepted(bid.bidId);
        uint256 finalAmountAfterMarketplaceFee = bid.bidPrice - ((bid.bidPrice*feeCut)/100);
        marketplaceBalance += ((bid.bidPrice*feeCut)/100);

        bool royaltyIntention  = IERC721(_tokenAddress).royaltyInfoIntention(_tokenId);

        if(royaltyIntention) // Wants royalties
        {
            if(firstTransfer[_tokenId] != false) // The first owner is selling it so it's a first sale
            {
                firstTransfer[_tokenId] = false;
                delete orderByTokenId[_tokenAddress][_tokenId];
                order.seller.transfer(finalAmountAfterMarketplaceFee);
            }
            else // Re-Sale
            {
                address payable firstOwnerAddress  = IERC721(_tokenAddress).royaltyInfoOwner(_tokenId);
                uint256 percentage = IERC721(_tokenAddress).royaltyInfoPercentage(_tokenId);

                uint256 royaltyAmount = ((finalAmountAfterMarketplaceFee*percentage)/100);
                uint256 amountAfterRoyaltyCut = finalAmountAfterMarketplaceFee - ((finalAmountAfterMarketplaceFee*percentage)/100);

                firstOwnerAddress.transfer(royaltyAmount);

                order.seller.transfer(amountAfterRoyaltyCut);
            }
        }
        else // Doesn't want royalties
        {
            delete orderByTokenId[_tokenAddress][_tokenId];
            order.seller.transfer(finalAmountAfterMarketplaceFee);
        }
       _executeOrder(order.orderId, bid.bidder,  _tokenAddress,  _tokenId,  _bidPrice);
    }

    function createDirectSellOrder(address _tokenAddress, uint256 _tokenId, uint256 _askingPrice) public whenNotPaused returns(bool){
        IERC721 tokenRegistry = IERC721(_tokenAddress);
         
        address tokenOwner = tokenRegistry.ownerOf(_tokenId);

        require(tokenOwner == msg.sender,"Marketplace: Only the asset owner can create orders");
        require(_askingPrice > 0, "Marketplace : The price must be greater than zero");

        tokenRegistry.safeTransferFrom(tokenOwner,address(this), _tokenId);

        bytes32 _directOrderId = keccak256(abi.encodePacked(block.timestamp,_tokenAddress,_tokenId, _askingPrice));

        DirectorderByTokenId[_tokenAddress][_tokenId] = DirectOrder({
            orderId: _directOrderId,
            seller: payable(msg.sender),
            tokenAddress: _tokenAddress,
            askingPrice: _askingPrice
            
        });

        emit DirectOrderCreated(_directOrderId,msg.sender,_tokenAddress,_tokenId,_askingPrice);
        return true;
    }
    
    function _createOrder(address _tokenAddress, uint256 _tokenId, uint256 _askingPrice) internal   {
        
        
         IERC721 tokenRegistry = IERC721(_tokenAddress);
        address tokenOwner = tokenRegistry.ownerOf(_tokenId);
        
        require(tokenOwner == msg.sender,"Marketplace: Only the asset owner can create orders");
        require(_askingPrice > 0, "Marketplace: Reserve price must be greater than zero");

        tokenRegistry.safeTransferFrom(tokenOwner,address(this), _tokenId);

        bytes32 _orderId = keccak256(abi.encodePacked(block.timestamp,_tokenAddress,_tokenId, _askingPrice));
        orderByTokenId[_tokenAddress][_tokenId] = Order({
            orderId: _orderId,
            seller: payable(msg.sender),
            tokenAddress: _tokenAddress,
            askingPrice: _askingPrice,
            expiryTime:0
        });
        
        emit OrderCreated(_orderId,msg.sender,_tokenAddress,_tokenId,_askingPrice);
    }

    function _createBid(address _tokenAddress, uint256 _tokenId,  uint256 value)  internal   {
    
        Order memory order = orderByTokenId[_tokenAddress][_tokenId];
        require(order.orderId != 0, "Marketplace: asset not published");
        
        Bid memory bid = bidByOrderId[_tokenAddress][_tokenId];
        
        if(bid.bidId != 0) { // Not first bid
            require(order.expiryTime >= block.timestamp, "Marketplace: Auction ended");
            if(block.timestamp.add(15 minutes) > order.expiryTime) // If this bid came in last 15 minutes of Auction, reset timer to 15 minutes.
            {
                orderByTokenId[_tokenAddress][_tokenId].expiryTime = block.timestamp.add(15 minutes);
            }
            
                uint256 validBid = bid.bidPrice + ((bid.bidPrice * 10)/100);
                require(value >= validBid, "Marketplace: bid price should be 10% higher than last bid");
        
            _cancelBid(bid.bidId,_tokenAddress,_tokenId,bid.bidder,bid.bidPrice);
            
        } else // First bid
        {
            require(value >= order.askingPrice, "Marketplace: bid should be > reserve price");
            orderByTokenId[_tokenAddress][_tokenId].expiryTime =  block.timestamp.add(1 days); // 1 day auction time
        }
        bytes32 bidId = keccak256(abi.encodePacked(block.timestamp, msg.sender, order.orderId, value));
        
        bidByOrderId[_tokenAddress][_tokenId] = Bid({
            bidId: bidId,
            bidder: payable(msg.sender),
            bidPrice: value
            // expiryTime: _expiryTime
        });
         emit BidCreated(bidId,_tokenAddress,_tokenId,msg.sender,value);
}

        function _executeOrder(bytes32 _orderId, address _buyer, address _tokenAddress, uint256 _tokenId, uint256 _askingPrice) internal {
            
            bool isLocked = IERC721(_tokenAddress).isContentLocked(_tokenId);
            if(isLocked)
            {
                IERC721(_tokenAddress).flipContentLockedStatus(_tokenId);
            }
            
            IERC721(_tokenAddress).safeTransferFrom(address(this), _buyer, _tokenId);
            
            emit OrderSuccessful(_orderId,_tokenId, _buyer, _askingPrice);
        }

        function _getValidOrder(address _tokenAddress, uint256 _tokenId) internal view returns (Order memory order) {
            order = orderByTokenId[_tokenAddress][_tokenId];
            
            require(order.orderId != 0, "Marketplace: asset not published");
            // require(order.expiryTime >= block.timestamp, "Marketplace: order expired");
        }

        function _cancelBid(bytes32 _bidId, address _tokenAddress, uint256 _tokenId, address  payable _bidder, uint256 _escrowAmount) internal {
            delete bidByOrderId[_tokenAddress][_tokenId];
    
          _bidder.transfer(_escrowAmount);
            // acceptedToken.safeTransfer(_bidder, _escrowAmount);
    
            emit BidCancelled(_bidId);
        }
    
    
        function _cancelOrder(bytes32 _orderId, address _tokenAddress, uint256 _tokenId, address _seller) internal {
            
            delete orderByTokenId[_tokenAddress][_tokenId];
            IERC721(_tokenAddress).safeTransferFrom(address(this), _seller, _tokenId);
            
            emit OrderCancelled(_orderId, _tokenId);
        }

        function _cancelFixPriceOrder(bytes32 _orderId, address _tokenAddress, uint256 _tokenId, address _seller) internal {
            
            delete DirectorderByTokenId[_tokenAddress][_tokenId];
            IERC721(_tokenAddress).safeTransferFrom(address(this), _seller, _tokenId);
            
            emit DirectOrderCancelled(_orderId, _tokenId);
        }

        function getMarketplaceBalance() public view onlyOwner returns(uint){
            return marketplaceBalance;
        }
    
       function _requireERC721(address _tokenAddress) internal view returns (IERC721) {
            require(
                _tokenAddress.isContract(),
                "The NFT Address should be a contract"
            );
            require(
                IERC721(_tokenAddress).supportsInterface(_INTERFACE_ID_ERC721),
                "The NFT contract has an invalid ERC721 implementation"
            );
            return IERC721(_tokenAddress);
        }
        function balance() public view onlyOwner returns(uint256){
            return marketplaceBalance;
        }

        function getFunds( address payable _receiverAddress, uint256 _amount) public onlyOwner {
            require(_amount > 0, "Marketplace: Amount must be greater than zero");
            require(_amount < marketplaceBalance, "Marketplace: Not enough balance" );
            // require(_receiverAddress != address(0), "Marketplace: The receiver address is invalid");
            marketplaceBalance = marketplaceBalance - _amount;
            payable(_receiverAddress).transfer(_amount);
        }   
}