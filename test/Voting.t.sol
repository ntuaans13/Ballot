// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Voting.sol";

contract votingTest is Test {
    Ballot ballot;

    event RightToVote(address indexed voter);
    event Delegated(address indexed from, address indexed to);
    event Voted(address indexed voter, uint indexed proposal, uint weight);
    event WinnerUpdated(uint indexed proposal, uint newVoteCount);

    address chairperson = address(this);
    address Alice = address(0x1);
    address Bob = address(0x2);
    address Clark = address(0x3);
    address Dean = address(0x4);

    function setUp() public {
        bytes32[] memory proposalNames;
        proposalNames[0] = "A";
        proposalNames[1] = "B";
        proposalNames[2] = "C";

        ballot = new Ballot(proposalNames);
    }

    function _giveRight(address Voter) internal {
        ballot.giveRightToVote(Voter);
    }

    function testInitialState() public {
        assertEq(ballot.chairperson(), chairperson);
        (uint64 weight, bool voted, uint64 vote, address delegate) = ballot.voters(chairperson);
        
        assertEq(weight, 1);
        assertFalse(voted);
        assertEq(vote, 0);
        assertEq(delegate, address(0));

        assertEq(ballot.winnerIndex(), 0);
        assertEq(ballot.winnerVoteCount(), 0);
    }

    function testGiveRightToVoteWorksAndEmitsEvent() public {
        vm.expectEmit(true, false, false, false, address(ballot));
        emit RightToVote(Alice);

        _giveRight(Alice);
        
        (uint64 weight,,,) = ballot.voters(Alice);
        assertEq(weight, 1);
    }

    function testGiveRightToVoteRevertsIfNotChairperson() public {
        vm.prank(Alice);
        vm.expectRevert(OnlyChairperson.selector);
        ballot.giveRightToVote(Bob);
    }

    function testGiveRightToVoteRevertsForZeroAddress() public {
        vm.expectRevert();
        ballot.giveRightToVote(address(0));
    }
}
