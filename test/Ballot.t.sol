// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Ballot.sol";

contract BallotTest is Test {
    Ballot ballot;

    event RightToVote(address indexed voter);
    event Delegated(address indexed from, address indexed to);
    event Voted(address indexed voter, uint256 indexed proposal, uint256 weight);
    event WinnerUpdated(uint256 indexed proposal, uint256 newVoteCount);

    address chairperson = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    address clark = address(0x3);
    address dean = address(0x4);

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
        emit RightToVote(alice);

        _giveRight(alice);

        (uint64 weight,,,) = ballot.voters(alice);
        assertEq(weight, 1);
    }

    function testGiveRightToVoteRevertsIfNotChairperson() public {
        vm.prank(alice);
        vm.expectRevert(OnlyChairperson.selector);
        ballot.giveRightToVote(bob);
    }

    function testGiveRightToVoteRevertsForZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        ballot.giveRightToVote(address(0));
    }

    function testGiveRightToVoteRevertsIfAlreadyVoted() public {
        _giveRight(alice);
        vm.prank(alice);
        ballot.vote(0);

        vm.expectRevert(AlreadyVoted.selector);
        ballot.giveRightToVote(alice);
    }

    function testGiveRightToVoteRevertAlreadyHasRight() public {
        _giveRight(alice);
        vm.expectRevert(AlreadyHasRight.selector);
        ballot.giveRightToVote(alice);
    }

    //vote
    function testVoteIncreaseVotesCountAndUpdateWinner() public {
        _giveRight(alice);
        vm.prank(alice);
        ballot.vote(1);

        (uint64 weightA, bool votedA, uint64 voteA, address delegateA) = ballot.voters(alice);
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
        _giveRight(alice);
        vm.expectEmit(true, true, false, true, address(ballot));
        emit Voted(alice, 1, 1);

        vm.expectEmit(true, false, false, true, address(ballot));
        emit WinnerUpdated(1, 1);

        vm.prank(alice);
        ballot.vote(1);
    }

    function testVoteRevertsIfNoRight() public {
        vm.prank(alice);
        vm.expectRevert(NoVotingRight.selector);
        ballot.vote(1);
    }

    function testVoteRevertsIfAlreadyVoted() public {
        _giveRight(alice);
        vm.prank(alice);
        ballot.vote(1);

        vm.prank(alice);
        vm.expectRevert(AlreadyVoted.selector);
        ballot.vote(2);
    }

    function testVoteRevertsInvalidProposal() public {
        _giveRight(alice);
        vm.prank(alice);
        vm.expectRevert(InvalidProposal.selector);
        ballot.vote(3);
    }

    // Delegate
    function testDelegateToUnvotedVoterAccumulatesWeight() public {
        _giveRight(alice);
        _giveRight(bob);

        (uint64 weightA,,,) = ballot.voters(alice);
        (uint64 weightB,,,) = ballot.voters(bob);
        assertEq(weightA, 1);
        assertEq(weightB, 1);

        vm.expectEmit(true, true, false, false, address(ballot));
        emit Delegated(alice, bob);

        vm.prank(alice);
        ballot.delegate(bob);

        (, bool votedA,, address delegateA) = ballot.voters(alice);
        assertTrue(votedA);
        assertEq(delegateA, bob);

        (uint64 weightB2,,,) = ballot.voters(bob);
        assertEq(weightB2, 2);
    }

    function testDelegateToVotedVoterAddsVotesAndUpdatesWinner() public {
        _giveRight(alice);
        _giveRight(bob);

        vm.prank(alice);
        ballot.vote(1);

        (, uint256 voteCountBefore) = ballot.proposals(1);
        assertEq(voteCountBefore, 1);
        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 1);

        vm.prank(bob);
        ballot.delegate(alice);

        (, uint256 voteCountAfter) = ballot.proposals(1);
        assertEq(voteCountAfter, 2);
        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 2);
    }

    function testDelegateRevertsIfNoVotingRight() public {
        vm.prank(alice);
        vm.expectRevert(NoVotingRight.selector);
        ballot.delegate(bob);
    }

    function testDelegateRevertsIfAlreadyVoted() public {
        _giveRight(alice);
        vm.prank(alice);
        ballot.vote(0);

        vm.prank(alice);
        vm.expectRevert(AlreadyVoted.selector);
        ballot.delegate(bob);
    }

    function testDelegateRevertsIfSelfDelegate() public {
        _giveRight(alice);
        vm.prank(alice);
        vm.expectRevert(SelfDelegation.selector);
        ballot.delegate(alice);
    }

    function testDelegateRevertsOnLoop() public {
        _giveRight(alice);
        _giveRight(bob);

        vm.prank(alice);
        ballot.delegate(bob);

        vm.prank(bob);
        vm.expectRevert(DelegationLoop.selector);
        ballot.delegate(alice);
    }

    function testDelegateRevertsDelegationLimitExceed() public {
        uint256 depth = ballot.MAX_DELEGATION_DEPTH();
        address[] memory chain = new address[](depth + 1);
        for (uint256 i = 0; i <= depth;) {
            chain[i] = address(uint160(0x100 + i));
            _giveRight(chain[i]);
            unchecked {
                ++i;
            }
        }
        for (uint256 i = 0; i < depth;) {
            vm.prank(chain[i]);
            ballot.delegate(chain[i + 1]);
            unchecked {
                ++i;
            }
        }

        _giveRight(alice);
        vm.prank(alice);
        vm.expectRevert(DelegationLimitExceed.selector);
        ballot.delegate(chain[0]);
    }

    // winner
    function testWiningProposalAndWinnerName() public {
        _giveRight(alice);
        _giveRight(bob);
        _giveRight(clark);
        _giveRight(dean);

        vm.prank(alice);
        ballot.vote(1);
        vm.prank(bob);
        ballot.vote(2);
        vm.prank(clark);
        ballot.vote(2);
        vm.prank(dean);
        ballot.vote(1);

        assertEq(ballot.winnerIndex(), 1);
        assertEq(ballot.winnerVoteCount(), 2);
        bytes32 name = ballot.winnerName();
        assertEq(name, bytes32("B"));
    }

    // fuzz test
    function testFuzzManyVotersVoteForSameProposals(uint256 n) public {
        uint256 numVoters = uint256(bound(n, 1, 20));
        for (uint256 i = 0; i < numVoters;) {
            address voter = address(uint160(0x100 + i));
            _giveRight(voter);

            vm.prank(voter);
            ballot.vote(0);
            unchecked {
                ++i;
            }
        }
        (, uint256 voteCount) = ballot.proposals(0);
        assertEq(voteCount, numVoters);
        assertEq(ballot.winnerIndex(), 0);
        assertEq(ballot.winnerVoteCount(), numVoters);
    }
}
