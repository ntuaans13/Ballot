// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

// custom errors
error OnlyChairperson();
error ZeroAddress();
error AlreadyVoted();
error AlreadyHasRight();
error NoVotingRight();
error SelfDelegation();
error DelegationLimitExceed();
error DelegationLoop();
error DelegateHasNoRight();
error InvalidProposal();

contract Ballot {
    struct Voter {
        // uint weight;
        // bool voted;
        // address delegate;
        // uint vote; // index of the voted proposal
        uint64 weight;
        bool voted;
        uint64 vote;
        address delegate;
    }

    struct Proposal {
        bytes32 name;
        uint256 voteCount;
    }

    uint256 public constant MAX_DELEGATION_DEPTH = 10;

    event RightToVote(address indexed voter);
    event Delegated(address indexed from, address indexed to);
    event Voted(address indexed voter, uint256 indexed proposal, uint256 weight);
    event WinnerUpdated(uint256 indexed proposal, uint256 newVoteCount);

    address public chairperson;
    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    uint256 public winnerIndex;
    uint256 public winnerVoteCount;

    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        uint256 len = proposalNames.length;
        for (uint256 i = 0; i < len;) {
            proposals.push(Proposal({name: proposalNames[i], voteCount: 0}));
            unchecked {
                ++i;
            }
        }
    }

    function giveRightToVote(address voter) external {
        if (msg.sender != chairperson) revert OnlyChairperson();
        if (voter == address(0)) revert ZeroAddress();

        Voter storage v = voters[voter];
        if (v.voted) revert AlreadyVoted();
        if (v.weight > 0) revert AlreadyHasRight();
        v.weight = 1;

        emit RightToVote(voter);
    }

    function delegate(address to) external {
        Voter storage sender = voters[msg.sender];

        if (sender.weight == 0) revert NoVotingRight();
        if (sender.voted) revert AlreadyVoted();
        if (to == msg.sender) revert SelfDelegation();

        uint256 delegationCount;
        while (true) {
            if (delegationCount >= MAX_DELEGATION_DEPTH) revert DelegationLimitExceed();

            address next = voters[to].delegate;
            if (next == address(0)) break;
            to = next;
            delegationCount++;

            if (to == msg.sender) revert DelegationLoop();
        }

        Voter storage delegate_ = voters[to];
        if (delegate_.weight == 0) revert DelegateHasNoRight();

        sender.voted = true;
        sender.delegate = to;

        emit Delegated(msg.sender, to);

        if (delegate_.voted) {
            uint64 senderWeight = sender.weight;
            uint64 delegateVote = delegate_.vote;

            Proposal storage p = proposals[delegateVote];
            uint256 newCount = p.voteCount + senderWeight;
            p.voteCount = newCount;

            if (newCount > winnerVoteCount) {
                winnerIndex = delegateVote;
                winnerVoteCount = newCount;

                emit WinnerUpdated(delegateVote, newCount);
            }
        } else {
            delegate_.weight += sender.weight;
        }
    }

    function vote(uint256 proposal) external {
        Voter storage sender = voters[msg.sender];
        if (sender.weight == 0) revert NoVotingRight();
        if (sender.voted) revert AlreadyVoted();
        if (proposal >= proposals.length) revert InvalidProposal();

        sender.voted = true;
        sender.vote = uint64(proposal);

        uint64 senderWeight = sender.weight;
        Proposal storage p = proposals[proposal];
        uint256 newCount = p.voteCount + senderWeight;
        p.voteCount = newCount;

        emit Voted(msg.sender, proposal, senderWeight);

        if (newCount > winnerVoteCount) {
            winnerIndex = proposal;
            winnerVoteCount = newCount;

            emit WinnerUpdated(proposal, newCount);
        }
    }

    function winningProposal() external view returns (uint256) {
        return winnerIndex;
    }

    function winnerName() external view returns (bytes32 WinnerName) {
        WinnerName = proposals[winnerIndex].name;
    }
}
