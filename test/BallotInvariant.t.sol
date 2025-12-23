// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Ballot.sol";

contract BallotInvariantTest is Test {
    Ballot ballot;
    address[] internal actors;

    function setUp() public {
        bytes32[] memory proposalNames = new bytes32[](3);
        proposalNames[0] = bytes32("A");
        proposalNames[1] = bytes32("B");
        proposalNames[2] = bytes32("C");

        ballot = new Ballot(proposalNames);

        actors = new address[](3);
        for (uint256 i = 0; i < 3;) {
            actors[i] = address(uint160(0x1 + i));
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < actors.length;) {
            ballot.giveRightToVote(actors[i]);
            unchecked {
                ++i;
            }
        }
    }

    // helper
    function _randomScenario(uint256 seed) internal {
        uint256 numActors = actors.length;
        uint256 numProposals = 3;
        for (uint256 i = 0; i < numActors;) {
            address voter = actors[i];
            uint256 action = uint256(keccak256(abi.encode(seed, i, "action"))) % 2;

            (, bool voted,,) = ballot.voters(voter);
            if (voted) {
                unchecked {
                    ++i;
                }
                continue;
            }

            if (action == 0) {
                uint256 proposalIndex = uint256(keccak256(abi.encode(seed, i, "proposal"))) % numProposals;
                vm.prank(voter);
                ballot.vote(proposalIndex);
            } else {
                address to = actors[(i + 1) % numActors];
                vm.prank(voter);
                try ballot.delegate(to) {} catch {}
            }

            unchecked {
                ++i;
            }
        }
    }

    function _computeMaxVotes() internal view returns (uint256 maxIndex, uint256 maxVotes) {
        uint256 numProposals = 3;
        for (uint256 i = 0; i < numProposals;) {
            (, uint256 votes) = ballot.proposals(i);
            if (votes > maxVotes) {
                maxVotes = votes;
                maxIndex = i;
            }
            unchecked {
                ++i;
            }
        }
    }

    // invariant tests
    function testInvariant_WinnerIndexAlwaysValid(uint256 seed) public {
        _randomScenario(seed);

        uint256 numProposals = 3;
        assertLt(ballot.winnerIndex(), numProposals);
    }

    function testInvariant_VotedVoterHasRight(uint256 seed) public {
        _randomScenario(seed);

        for (uint256 i = 0; i < actors.length;) {
            (uint64 weight, bool voted,,) = ballot.voters(actors[i]);
            if (voted) {
                assertGt(weight, 0);
            }
            unchecked {
                ++i;
            }
        }
    }

    function testInvariant_WinnerMatchesMax(uint256 seed) public {
        _randomScenario(seed);

        (uint256 maxIndex, uint256 maxVotes) = _computeMaxVotes();
        assertEq(ballot.winnerIndex(), maxIndex);
        assertEq(ballot.winnerVoteCount(), maxVotes);
    }
}
