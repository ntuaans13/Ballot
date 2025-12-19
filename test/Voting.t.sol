// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Voting.sol";

contract votingTest is Test {
    Ballot ballot;

    event RightToVote(address indexed voter);
    event Delegated(address indexed from, address indexed to);
    event Voted(address indexed voter, uint256 indexed proposal, uint256 weight);
    event WinnerUpdated(uint256 indexed proposal, uint256 newVoteCount);

    address chairperson = address(this);
    address Alice = address(0x1);
    address Bob = address(0x2);
    address Clark = address(0x3);
    address Dean = address(0x4);

    function setUp() public {
        bytes32[] memory proposalNames = new bytes32[](3);
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

    // GiveRightToVote
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
        vm.expectRevert(ZeroAddress.selector);
        ballot.giveRightToVote(address(0));
    }

    function testGiveRightToVoteRevertsIfAlreadyVoted() public {
        _giveRight(Alice);
        vm.prank(Alice);
        ballot.vote(0);

        vm.expectRevert(AlreadyVoted.selector);
        ballot.giveRightToVote(Alice);
    }

    function testGiveRightToVoteRevertAlreadyHasRight() public {
        _giveRight(Alice);
        vm.expectRevert(AlreadyHasRight.selector);
        ballot.giveRightToVote(Alice);
    }

    //vote
    function testVoteIncreaseVotesCountAndUpdateWinner() public {
        _giveRight(Alice);
        vm.prank(Alice);
        ballot.vote(1);

        (uint64 weightA, bool votedA, uint64 voteA, address delegateA) = ballot.voters(Alice);
        assertEq(weightA, 1);
        assertTrue(votedA);
        assertEq(voteA, 1);
        assertEq(delegateA, address(0));

        (, uint256 voteCount) = ballot.proposals(1);
        assertEq(voteCount, 1);

        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 1);
    }

    function testVoteEmitsEvent() public {
        _giveRight(Alice);
        vm.expectEmit(true, true, false, true, address(ballot));
        emit Voted(Alice, 1, 1);

        vm.expectEmit(true, false, false, true, address(ballot));
        emit WinnerUpdated(1, 1);

        vm.prank(Alice);
        ballot.vote(1);
    }

    function testVoteRevertsIfNoRight() public {
        vm.prank(Alice);
        vm.expectRevert(NoVotingRight.selector);
        ballot.vote(1);
    }

    function testVoteRevertsIfAlreadyVoted() public {
        _giveRight(Alice);
        vm.prank(Alice);
        ballot.vote(1);

        vm.prank(Alice);
        vm.expectRevert(AlreadyVoted.selector);
        ballot.vote(2);
    }

    function testVoteRevertsInvalidProposal() public {
        _giveRight(Alice);
        vm.prank(Alice);
        vm.expectRevert(InvalidProposal.selector);
        ballot.vote(3);
    }

    // Delegate
    function testDelegateToUnvotedVoterAccumulatesWeight() public {
        _giveRight(Alice);
        _giveRight(Bob);

        (uint64 weightA,,,) = ballot.voters(Alice);
        (uint64 weightB,,,) = ballot.voters(Bob);
        assertEq(weightA, 1);
        assertEq(weightB, 1);

        vm.expectEmit(true, true, false, false, address(ballot));
        emit Delegated(Alice, Bob);

        vm.prank(Alice);
        ballot.delegate(Bob);

        (, bool votedA,, address delegateA) = ballot.voters(Alice);
        assertTrue(votedA);
        assertEq(delegateA, Bob);

        (uint64 weightB2,,,) = ballot.voters(Bob);
        assertEq(weightB2, 2);
    }

    function testDelegateToVotedVoterAddsVotesAndUpdatesWinner() public {
        _giveRight(Alice);
        _giveRight(Bob);

        vm.prank(Alice);
        ballot.vote(1);

        (, uint256 voteCountBefore) = ballot.proposals(1);
        assertEq(voteCountBefore, 1);
        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 1);

        vm.prank(Bob);
        ballot.delegate(Alice);

        (, uint256 voteCountAfter) = ballot.proposals(1);
        assertEq(voteCountAfter, 2);
        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 2);
    }

    function testDelegateRevertsIfNoVotingRight() public {
        vm.prank(Alice);
        vm.expectRevert(NoVotingRight.selector);
        ballot.delegate(Bob);
    }

    function testDelegateRevertsIfAlreadyVoted() public {
        _giveRight(Alice);
        vm.prank(Alice);
        ballot.vote(0);

        vm.prank(Alice);
        vm.expectRevert(AlreadyVoted.selector);
        ballot.delegate(Bob);
    }

    function testDelegateRevertsIfSelfDelegate() public {
        _giveRight(Alice);
        vm.prank(Alice);
        vm.expectRevert(SelfDelegation.selector);
        ballot.delegate(Alice);
    }

    function testDelegateRevertsOnLoop() public {
        _giveRight(Alice);
        _giveRight(Bob);

        vm.prank(Alice);
        ballot.delegate(Bob);

        vm.prank(Bob);
        vm.expectRevert(DelegationLoop.selector);
        ballot.delegate(Alice);
    }

    function testDelegateRevertsDelegationLimitExceed() public {
        uint256 depth = ballot.MAX_DELEGATION_DEPTH();
        address[] memory chain = new address[](depth + 1);
        for (uint256 i = 0; i <= depth; ++i) {
            chain[i] = address(uint160(0x100 + i));
            _giveRight(chain[i]);
        }
        for (uint256 i = 0; i < depth; ++i) {
            vm.prank(chain[i]);
            ballot.delegate(chain[i + 1]);
        }

        _giveRight(Alice);
        vm.prank(Alice);
        vm.expectRevert(DelegationLimitExceed.selector);
        ballot.delegate(chain[0]);
    }

    // winner
    function testWiningProposalAndWinnerName() public {
        _giveRight(Alice);
        _giveRight(Bob);
        _giveRight(Clark);

        vm.prank(Alice);
        ballot.vote(0);
        vm.prank(Bob);
        ballot.vote(1);
        vm.prank(Clark);
        ballot.vote(1);

        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 2);
        bytes32 name = ballot.winnerName();
        assertEq(name, bytes32("B"));
    }

    // fuzz test
}
