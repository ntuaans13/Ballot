// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

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
    Ư

    struct Proposal {
        bytes32 name;
        uint voteCount;
    }

    uint constant MAX_Delegation_Depth = 10; 

    event RightToVote(address indexed voter);
    event Delegated(address indexed from, address indexed to);
    event Voted(address indexed voter, uint indexed proposal, uint weight);
    event WinnerUpdated(uint indexed proposal, uint newVoteCount);

    address public chairperson;
    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    uint public winnerIndex;
    uint public winnerVoteCount = 0;

    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        uint len = proposalNames.length;
        for(uint i = 0; i < len; i++) {
            proposals.push(Proposal({
                name : proposalNames[i],
                voteCount : 0
            }));
        }
    }

    function giveRightToVote(address voter) external {
        require(chairperson == msg.sender, "Only chairperson"); 
        require(voter != address(0));

        Voter storage v = voters[voter];
        require(!v.voted, "Already voted");
        require(v.weight == 0, "Already has right");
        v.weight = 1;
        
        emit RightToVote(voter);
    }

    function delegate(address to) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight > 0, "no right");
        require(!sender.voted, "already voted");
        require(to != msg.sender, "self");
        
        uint delegationCount;
        while(true) {
            require(delegationCount < MAX_Delegation_Depth);
            address next = voters[to].delegate;
            if(next == address(0)) break;
            to = next;
            delegationCount++;
            require(to != msg.sender, "Found loop in delegation");
        }

        Voter storage delegate_ = voters[to];
        require(delegate_.weight > 0, "delegate has no right");

        sender.voted = true;
        sender.delegate = to;

        emit Delegated(msg.sender, to);
        
        if (delegate_.voted) {
            uint64 senderWeight = sender.weight;
            uint64 delegateVote = delegate_.vote;

            Proposal storage p = proposals[delegateVote];
            uint newCount = p.voteCount + senderWeight;
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

    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight > 0);
        require(!sender.voted);

        sender.voted = true;
        sender.vote = uint64(proposal);

        uint64 senderWeight = sender.weight;
        Proposal storage p = proposals[proposal];
        uint newCount = p.voteCount + senderWeight;
        p.voteCount = newCount;

        emit Voted(msg.sender, proposal, senderWeight);

        if (newCount > winnerVoteCount) {
            winnerIndex = proposal;
            winnerVoteCount = newCount;

            emit WinnerUpdated(proposal, newCount);
        }
    }

    function winningProposal() external view returns(uint) {
        return winnerIndex;
    }

    function winnerName() external view returns (bytes32 WinnerName) {
        WinnerName = proposals[winnerIndex].name;
    }

}