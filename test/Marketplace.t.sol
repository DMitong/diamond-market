// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import {Test, console2} from "forge-std/Test.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "./helpers/MockNFT.sol";
import "./helpers/Helpers.sol";

contract Marketplace is
    Helpers // Setup
{
    ERC721Marketplace marketplace;
    TestNFT erc721;

    uint256 currentOrdersID;

    address user1;
    address user2;

    uint256 privKey1;
    uint256 privKey2;

    ERC721Marketplace.Order orderDetails;

    function setUp() public {
        marketplace = new ERC721Marketplace();
        erc721 = new TestNFT();

        // Create user accounts
        (user1, privKey1) = mkaddr("user1");
        (user2, privKey2) = mkaddr("user2");

        orderDetails = ERC721Marketplace.Order({
            tokenAddress: address(erc721),
            tokenID: 1,
            price: 1 ether,
            sig: "",
            deadline: 0,
            creator: address(0),
            isActive: false,
            isExecuted: false
        });

        erc721.mint(user1, 1);
    }

    // Tests
    function testOwnerCannotCreateOrder() public {
        orderDetails.creator = user2;
        switchSigner(user2);

        vm.expectRevert(ERC721Marketplace.NotOwner.selector);
        marketplace.createOrder(orderDetails);
    }

    function testNonApprovedNFT() public {
        switchSigner(user1);
        vm.expectRevert(ERC721Marketplace.NotApproved.selector);
        marketplace.createOrder(orderDetails);
    }

    function testMinPriceTooLow() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.price = 0;
        vm.expectRevert(ERC721Marketplace.MinPriceTooLow.selector);
        marketplace.createOrder(orderDetails);
    }

    function testMinDeadline() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        vm.expectRevert(ERC721Marketplace.DeadlineTooSoon.selector);
        marketplace.createOrder(orderDetails);
    }

    function testMinDuration() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(ERC721Marketplace.MinDurationNotMet.selector);
        marketplace.createOrder(orderDetails);
    }

    function testValidSig() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey2
        );
        vm.expectRevert(ERC721Marketplace.InvalidSignature.selector);
        marketplace.createOrder(orderDetails);
    }

    // EDIT ORDER
    function testEditNonValidOrder() public {
        switchSigner(user1);
        vm.expectRevert(ERC721Marketplace.OrderNotExistent.selector);
        marketplace.editOrder(1, 0, false);
    }

    function testEditOrderNotOwner() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey1
        );
        // vm.expectRevert(ERC721Marketplace.OrderNotExistent.selector);
        uint256 orderId = marketplace.createOrder(orderDetails);

        switchSigner(user2);
        vm.expectRevert(ERC721Marketplace.NotOwner.selector);
        marketplace.editOrder(orderId, 0, false);
    }

    function testEditOrder() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey1
        );
        uint256 orderId = marketplace.createOrder(orderDetails);
        marketplace.editOrder(orderId, 0.01 ether, false);

        ERC721Marketplace.Order memory t = marketplace.getOrder(orderId);
        assertEq(t.price, 0.01 ether);
        assertEq(t.isActive, false);
    }

    // EXECUTE ORDER
    function testFulfillNonValidOrder() public {
        switchSigner(user1);
        vm.expectRevert(ERC721Marketplace.OrderNotExistent.selector);
        marketplace.fulfillOrder(1);
    }

    function testFulfillExpiredOrder() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
    }

    function testFulfillOrderNotActive() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey1
        );
        uint256 orderId = marketplace.createOrder(orderDetails);
        marketplace.editOrder(orderId, 0.01 ether, false);
        switchSigner(user2);
        vm.expectRevert(ERC721Marketplace.OrderNotActive.selector);
        marketplace.fulfillOrder(orderId);
    }

    function testFulfillPriceNotMet() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey1
        );
        uint256 orderId = marketplace.createOrder(orderDetails);
        switchSigner(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721Marketplace.PriceNotMet.selector,
                orderDetails.price - 0.9 ether
            )
        );
        marketplace.fulfillOrder{value: 0.9 ether}(orderId);
    }

    function testFulfillPriceMismatch() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey1
        );
        uint256 orderId = marketplace.createOrder(orderDetails);
        switchSigner(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721Marketplace.PriceMismatch.selector,
                orderDetails.price
            )
        );
        marketplace.fulfillOrder{value: 1.1 ether}(orderId);
    }

    function testFulfill() public {
        switchSigner(user1);
        erc721.setApprovalForAll(address(marketplace), true);
        orderDetails.deadline = uint88(block.timestamp + 120 minutes);
        // orderDetails.price = 1 ether;
        orderDetails.sig = constructSig(
            orderDetails.tokenAddress,
            orderDetails.tokenID,
            orderDetails.price,
            orderDetails.deadline,
            orderDetails.creator,
            privKey1
        );
        uint256 orderId = marketplace.createOrder(orderDetails);
        switchSigner(user2);
        uint256 user1BalanceBefore = user1.balance;

        marketplace.fulfillOrder{value: orderDetails.price}(orderId);

        uint256 user1BalanceAfter = user1.balance;

        ERC721Marketplace.Order memory t = marketplace.getOrder(orderId);
        assertEq(t.price, 1 ether);
        assertEq(t.isActive, false);

        assertEq(t.isActive, false);
        assertEq(
            ERC721(orderDetails.tokenAddress).ownerOf(orderDetails.tokenID),
            user2
        );
        assertEq(user1BalanceAfter, user1BalanceBefore + orderDetails.price);
    }
}
