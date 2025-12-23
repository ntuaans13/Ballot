// SPDX-License-Identifier: GPL-3.0
pragma solidity ^ 0.8.20;

import "forge-std/Test.sol";
import "../src/Ballot.sol";

contract VotingInvariantTest is Test {
    Ballot ballot;
    address[] internal actors;

    function setUp() public {
        bytes32[] memory proposalNames = new bytes32[](3);
        proposalNames[0] = bytes32("A");
        proposalNames[1] = bytes32("B");
        proposalNames[2] = bytes32("C");

        ballot = new Ballot(proposalNames);
        
        actors = new address[](3);
        for(uint i = 0; i < 3; ) {
            actors[i] = address(uint160(0x1 + i));
            unchecked {
                ++i;
            }
        }

        for(uint i = 0; i < actors.length; ) {
            ballot.giveRightToVote(actors[i]);
            unchecked {
                ++i;
            }
        }
    }

    // helper
    function _randomScenario(uint seed) internal {
        uint numActors = actors.length;
        uint numProposals = 3;
        for(uint i = 0; i < numActors; ) {
            address voter = actors[i];
            uint action = uint(keccak256(abi.encode(seed, i, "action"))) % 2;
            
            (, bool voted, ,) = ballot.voters(voter);
            if(voted) {
                unchecked {
                    ++i;
                }
                continue;
            }

            if(action == 0) {
                uint proposalIndex = uint(keccak256(abi.encode(seed, i, "proposal"))) % numProposals;
                vm.prank(voter);
                ballot.vote(proposalIndex);
            } else {
                address to = actors[(i + 1) % numActors];
                vm.prank(voter);
                try ballot.delegate(to){}
                catch {}
            }

            unchecked {
                ++i;
            }
        }
    }

    function _computeMaxVotes() internal view returns(uint maxIndex, uint maxVotes) {
        uint numProposals = 3;
        for(uint i = 0; i < numProposals; ) {
            (, uint votes) = ballot.proposals(i);
            if(votes > maxVotes) {
                maxVotes = votes;
                maxIndex = i;
            }
            unchecked {
                ++i;
            }
        }
    }

    // invariant tests
    function testInvariant_WinnerIndexAlwaysValid(uint seed) public {
        _randomScenario(seed);
        
        uint numProposals = 3;
        assertLt(ballot.winnerIndex(), numProposals);
    }
    
    function testInvariant_VotedVoterHasRight(uint seed) public {
        _randomScenario(seed);
        
        for(uint i = 0; i < actors.length; ) {
            (uint64 weight, bool voted, ,) = ballot.voters(actors[i]);
            if(voted) {
                assertGt(weight, 0);
            }
            unchecked {
                ++i;
            }
        }
    }

    function testInvariant_WinnerMatchesMax(uint seed) public {
        _randomScenario(seed);

        (uint maxIndex, uint maxVotes) = _computeMaxVotes();
        assertEq(ballot.winnerIndex(), maxIndex);
        assertEq(ballot.winnerVoteCount(), maxVotes);
    }
}