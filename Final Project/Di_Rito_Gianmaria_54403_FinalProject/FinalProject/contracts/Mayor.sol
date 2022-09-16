pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

contract Mayor {
    
    // Structs, events, and modifiers
    
    // Store refund data
    struct Refund {
        uint soul;
        address symbol;
    }
    
    // Data to manage the confirmation
    struct Conditions {
        uint32 quorum;
        uint32 envelopes_casted;
        uint32 envelopes_opened;
    }
    
    //candidate
    struct Candidate {
        address payable cand;
        address payable coal;
    }
    //Data to manage the case in witch two or more candidates are the same souls
    struct number{
        uint32 numV;
        uint amount_souls;
    }
    event NewMayor(address _candidate);
    event Sayonara(address _escrow);
    event EnvelopeCast(address _voter);
    event EnvelopeOpen(address _voter, uint _soul, address _symbol);
    
    // Someone can vote as long as the quorum is not reached
    modifier canVote() {
        require(voting_condition.envelopes_casted < voting_condition.quorum, "Cannot vote now, voting quorum has been reached");
        _;   
    }
    
    // Envelopes can be opened only after receiving the quorum
    modifier canOpen() {
        require(voting_condition.envelopes_casted == voting_condition.quorum, "Cannot open an envelope, voting quorum not reached yet");
        _;
    }
    
    // The outcome of the confirmation can be computed as soon as all the casted envelopes have been opened
    modifier canCheckOutcome() {
        require(voting_condition.envelopes_opened == voting_condition.quorum, "Cannot check the winner, need to open all the sent envelopes");
        _;
    }
    
    // State attributes

    // Initialization variables
    Candidate [] public candidate_list;
    address payable public escrow;
    
    mapping(address=> uint32) coalition_list;
    address [] public  coalitions;
    
    // Voting phase variables
    mapping(address => bytes32) envelopes;

    Conditions voting_condition;
    
    //variable for keeping track of the vote and the soul received by each candidate and coalitions
    mapping(address => number) votes;
    uint public tot_votes;
    
    uint public current;
    
    // Refund phase variables
    mapping(address => Refund) souls;
    address [] voters;

    /// @notice The constructor only initializes internal variables
    /// @param _candidate_list (address) The address of the mayor candidate
    /// @param _escrow (address) The address of the escrow account
    /// @param _quorum (address) The number of voters required to finalize the confirmation
    constructor(Candidate [] memory _candidate_list, address payable _escrow, uint32 _quorum) public {
        
         for(uint i=0; i < _candidate_list.length; i++ ){
                candidate_list.push(_candidate_list[i]);
                // if the candidate is part of a coalition
                if(_candidate_list[i].coal !=  0x0000000000000000000000000000000000000000)
                    // if is a new coalition
                    if(coalition_list[_candidate_list[i].coal] == 0x0){
                        coalition_list[_candidate_list[i].coal] = 1;
                        
                    }
                    else{
                        coalition_list[_candidate_list[i].coal]++;
                        if(coalition_list[_candidate_list[i].coal] == 2)
                            coalitions.push(_candidate_list[i].coal);
                    }
               
            }
        
        escrow = _escrow;
        voting_condition = Conditions({quorum: _quorum, envelopes_casted: 0, envelopes_opened: 0});
    }

    /// @notice Store a received voting envelope
    /// @param _envelope The envelope represented as the keccak256 hash of (sigil, doblon, soul) 
    function cast_envelope(bytes32 _envelope) canVote public {
        
        if(envelopes[msg.sender] == 0x0) 
            voting_condition.envelopes_casted++;

        envelopes[msg.sender] = _envelope;
        emit EnvelopeCast(msg.sender);
    }
    
    /// @notice Open an envelope and store the vote information
    /// @param _sigil (uint) The secret sigil of a voter
    /// @param _symbol(address) The voting preference
    /// @dev The soul is sent as crypto
    /// @dev Need to recompute the hash to validate the envelope previously casted
    function open_envelope(uint _sigil, address _symbol) canOpen public payable {
        
        require(envelopes[msg.sender] != 0x0, "The sender has not casted any votes");
        
        bytes32 _casted_envelope = envelopes[msg.sender];
        bytes32 _sent_envelope = 0x0;
        
        //recalculate the caller's envelope to check if it's an honest voter
        _sent_envelope = compute_envelope(_sigil, _symbol, msg.value );
        require(_casted_envelope == _sent_envelope, "Sent envelope does not correspond to the one casted");
      
        //update the entry of the _symbol with the soul and the vote sended by the voter 
        votes[_symbol].amount_souls =  votes[_symbol].amount_souls + msg.value;
        votes[_symbol].numV = votes[_symbol].numV + 1;
        tot_votes = tot_votes + msg.value;
        
        //update the souls structure with the voter data
        souls[msg.sender] = Refund({soul:msg.value, symbol:_symbol});
        voters.push(msg.sender);
     
        //increase the open envelopes
        voting_condition.envelopes_opened++;
        current = address(this).balance;
        emit EnvelopeOpen(msg.sender, msg.value, _symbol);
    }
    
    /// @notice Either confirm or kick out the candidate. Refund the electors who voted for the losing outcome
    function mayor_or_sayonara() canCheckOutcome public {
        //coalitions: case in which a coalition has soul> = 1/3 of the total soul 
        address payable probMayor = 0x0000000000000000000000000000000000000000;
        bool flag = false;
        for(uint32 i=0 ; i < coalitions.length ; i++ ){
            if (votes[coalitions[i]].amount_souls >= tot_votes/3){
                //case of first coalition 
                if (probMayor == 0x0000000000000000000000000000000000000000) 
                        probMayor = address(uint160(coalitions[i]));
                else {
                    //case where a coalition has a higher amount of soul than the previous probMayor
                        if(votes[coalitions[i]].amount_souls > votes[probMayor].amount_souls) 
                            probMayor = address(uint160(coalitions[i]));
                    //case in which two coalitions have soul> = 1/3 of the total and have equal amount of soul
                        else if(votes[coalitions[i]].amount_souls == votes[probMayor].amount_souls){
                            flag = true;
                        }
                }
            }
        }
        
        if (probMayor != 0x0000000000000000000000000000000000000000){
            // case where there is only one coalition with> 1/3 soul and higher soul count than the other coalitions
            // all those who did not vote for the winning coalition are refounded
            // and the winning coalition is announced as mayor
            if(flag == false){
                for(uint32 i=0; i < voters.length; i++ ){
                    if(souls[voters[i]].symbol != probMayor){
                        address payable addRefunded = address(uint160(voters[i]));
                        uint refound = souls[voters[i]].soul;
                        souls[voters[i]].soul = 0;
                        addRefunded.transfer(refound);
                    }
                }
                probMayor.transfer(address(this).balance);
                emit NewMayor(probMayor);
            }
            // case where two coalitions have soul> = 1/3 of the total and have equal amount of soul
            // all the balance of the contract ends up in the escrow account and everyone loses
            else{
                escrow.transfer(address(this).balance);
                emit Sayonara(escrow);
            }
         
        }
        
        // case where there is no coalition with soul> 1/3 of total souls
        // therefore the elections proceed normally with the coalitions that are considered as normal participants
        else{
            address[] memory winners = new address[](coalitions.length + candidate_list.length);
            uint pari = 0;
            // to look for possible winners we first inspect the coalitions 
            for (uint32 i = 0; i < coalitions.length; i++ ){
                // if it is the first element we check
                if (pari == 0){
                     winners[pari] = coalitions[i];
                     pari++;
                }
                // if we find one with greater soul than those in the array of possible winners
                // we put it in the first position and reset the other positions
                if(votes[coalitions[i]].amount_souls > votes[winners[0]].amount_souls){
                    pari = 0;
                    winners = azzera(winners);
                    winners[pari] = coalitions[i];
                    pari++;
                } 
                // if we find one with soul equal to those present in the array of possible winners
                // we put it in the next position in the array
                else if(votes[coalitions[i]].amount_souls == votes[winners[0]].amount_souls){
                         winners[pari] = coalitions[i]; 
                         pari++;
                }
            }
           // We continue by scanning all individual candidates, in the same way
            for (uint32 i = 0; i < candidate_list.length; i++ ){
                
                if (pari == 0){
                     winners[pari] = candidate_list[i].cand;
                     pari++;
                }
                if(votes[candidate_list[i].cand].amount_souls > votes[winners[0]].amount_souls){
                    pari = 0;
                    winners = azzera(winners);
                    winners[pari] = candidate_list[i].cand;
                    pari++;
                }   
                else if(votes[candidate_list[i].cand].amount_souls == votes[winners[0]].amount_souls){
                        winners[pari] = candidate_list[i].cand; 
                        pari++;
                }
            }
             // if there is only one candidate in the array then 
             // only one candidate (single or coalition) has more soul counts than all the others
            if(pari == 1){
                // let's go make a refund for all those who didn't vote for him and elect the new mayor
               for(uint i=0; i < voters.length; i++ ){
                    if(souls[voters[i]].symbol != winners[0]){
                        address payable addRefunded = address(uint160(voters[i]));
                        uint refound = souls[voters[i]].soul;
                        souls[voters[i]].soul = 0;
                        addRefunded.transfer(refound);
                    }
                }
                address(uint160(winners[0])).transfer(address(this).balance);
                emit NewMayor(winners[0]); 
            }
            // otherwise in the array there are more candidates (singles or coalitions) with soul obtained the same
            // and in this case we will look at the number of votes received by the latter to decide the winner
            else {
                // we set the first element of the winners array as winner
                int max_vote_recived = votes[winners[0]].numV;
                address payable winner = address(uint160(winners[0]));
                flag = false;
                
                for(uint i = 1 ; i < pari ; i++){
                   // if the current element of the array has a number of votes greater than winner update winner
                    if( votes[winners[i]].numV > max_vote_recived){
                        max_vote_recived = votes[winners[i]].numV;
                        winner = address(uint160(winners[i]));
                        flag = false;
                    }
                    // if the current element of the array has a number of votes equal to winner set the flag to true
                    if(max_vote_recived == votes[winners[i]].numV){
                        flag = true;
                    }
                }
                // if the flag is true then it means that in the array winner (where all elements have the same number of souls)
                // there are at least two candidates with the highest number of votes among all who are in this array
                // then you will have to adopt the escrow rule
                if (flag == true){
                    escrow.transfer(address(this).balance);
                    emit Sayonara(escrow);
                }
                
                // otherwise, only one candidate in the winners array has more votes than the others
                // then there will be a mayor resulting in a refound for those who didn't vote for him
                else{
                     for(uint i=0; i < voters.length; i++ ){
                         if(souls[voters[i]].symbol != winner){
                            address payable addRefunded = address(uint160(voters[i]));
                            uint refound = souls[voters[i]].soul;
                            souls[voters[i]].soul = 0;
                            addRefunded.transfer(refound);
                        }
                    }
                    winner.transfer(address(this).balance);
                    emit NewMayor(winner);
    
                }
                
                
            }
        }
    }
    
   
 
 
    /// @notice Compute a voting envelope
    /// @param _sigil (uint) The secret sigil of a voter
    /// @param _symbol (address) The voting preference
    /// @param _soul (uint) The soul associated to the vote
    function compute_envelope(uint _sigil, address _symbol, uint _soul) public pure returns(bytes32) {
        
        return keccak256(abi.encode(_sigil, _symbol, _soul));
    }

    function azzera(address[] memory array) public pure returns(address[] memory){
        for(uint i = 0; i < array.length; i++){
            array[i] = 0x0000000000000000000000000000000000000000;
        }
        return array;
    }
    function getCandidates() public view returns(address[] memory){
        address[] memory cand = new address[](candidate_list.length);
        for(uint i = 0; i < candidate_list.length; i++){
            cand[i] = candidate_list[i].cand;
        }
        return cand;
    }

    function getCoalitions() public view returns(address[] memory){
        return coalitions;
    }

    /*function getVotationGasConsumption(address[] memory cands, address[] memory coals ) public view 
                                                                    returns(uint[] memory){
        uint[] memory gasArray = new uint[](cands.length+coals.length);

        for(uint i = 0; i < cands.length; i++){
            gasArray[i] = cands[i].balance;
        }
        for(uint i = 0; i < coals.length; i++){
            gasArray[cands.length+i] = coals[i].balance;
        }
        
        return gasArray;
    }*/
}

