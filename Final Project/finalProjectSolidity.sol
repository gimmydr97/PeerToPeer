pragma solidity 0.8.1;
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
    
    //candidato
    struct Candidate {
        address payable cand;
        address payable coal;
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
    address [] coalitions;
    
    // Voting phase variables
    mapping(address => bytes32) envelopes;

    Conditions voting_condition;
    
    struct number{
        uint32 numV;
        uint amount_souls;
    }
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
        
         candidate_list = _candidate_list; 
         for(uint i=0; i < _candidate_list.length; i++ ){
               
                if(candidate_list[i].coal !=  0x0000000000000000000000000000000000000000)
                    if(coalition_list[candidate_list[i].coal] == 0x0){
                        coalition_list[candidate_list[i].coal] = 1;
                        coalitions.push(candidate_list[i].coal);
                    }
                    else
                        coalition_list[candidate_list[i].coal]++;
               
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
        
     /// @notice recalculate the caller's envelope to check if it's an honest voter
        _sent_envelope = compute_envelope(_sigil, _symbol, msg.value );
        require(_casted_envelope == _sent_envelope, "Sent envelope does not correspond to the one casted");
      
        votes[_symbol].amount_souls =  votes[_symbol].amount_souls + msg.value;
        votes[_symbol].numV = votes[_symbol].numV ++;
        tot_votes = tot_votes + msg.value;
        
     /// @notice update the souls structure with the voter data
        souls[msg.sender] = Refund({soul:msg.value, symbol:_symbol});
        voters.push(msg.sender);
     
     /// @notice increase the open envelopes
        voting_condition.envelopes_opened++;
        emit EnvelopeOpen(msg.sender, msg.value, _symbol);
    }
    
    /// @notice Either confirm or kick out the candidate. Refund the electors who voted for the losing outcome
    function mayor_or_sayonara() canCheckOutcome public {
        
        address payable probMayor = 0x0;
        for(uint32 i=0 ; i < coalitions.length ; i++ ){
            if (votes[coalitions[i]].amount_souls >= tot_votes/3){
                if (probMayor == 0x0) probMayor = coalitions[i];
                else {
                        if(votes[coalitions[i]].amount_souls > votes[probMayor].amount_souls) 
                            probMayor = coalitions[i];
                        if(votes[coalitions[i]].amount_souls == votes[probMayor].amount_souls){
                            escrow.transfer(address(this).balance);
                            emit Sayonara(escrow);
                        }
                }
            }
        }
        if (probMayor != 0x0){
            for(uint32 i=0; i < voters.length; i++ ){
                if(souls[voters[i]].symbol != probMayor){
                    address payable addRefunded = payable(address(voters[i]));
                    uint refound = souls[voters[i]].soul;
                    souls[voters[i]].soul = 0;
                    addRefunded.transfer(refound);
                 }
            probMayor.transfer(address(this).balance);
            emit NewMayor(probMayor);
            }
        }
        
        
        else{
            address [] storage winners;
            winners.push(coalitions[0]);
            for (uint32 i = 1; i < coalitions.length; i++ ){
                if(votes[coalitions[i]].amount_souls > votes[winners[0]].amount_souls){
                     winners = [];
                    winners.push(coalitions[i]);
                }   
                else if(votes[coalitions[i]].amount_souls == votes[winners[0]].amount_souls)
                    winners.push(coalitions[i]); 
            }
            for (uint32 i = 1; i < candidate_list.length; i++ ){
                if(votes[candidate_list[i]].amount_souls > votes[winners[0]].amount_souls){
                    winners = [];
                    winners.push(coalitions[i]);
                }   
                else if(votes[candidate_list[i]].amount_souls == votes[winners[0]].amount_souls)
                    winners.push(coalitions[i]); 
            }
            
            if(winners.length = 1){
               for(uint i=0; i < voters.length; i++ ){
                    if(souls[voters[i]].symbol != winners[0]){
                        address payable addRefunded = payable(address(voters[i]));
                        uint refound = souls[voters[i]].soul;
                        souls[voters[i]].soul = 0;
                        addRefunded.transfer(refound);
                    }
                }
                winners[0].transfer(address(this).balance);
                emit NewMayor(winners[0]); 
            }
            
            else {
                int max_vote_recived = votes[winners[0]].numV;
                address payable winner = winners[0];
                bool flag = false;
                for(uint i = 1 ; i < winners.length ; i++){
                    if(max_vote_recived - votes[winners[i]].numV < 0){
                        max_vote_recived = votes[winners[i]].numV;
                        winners = winners[i];
                        flag = false;
                    }
                    if(max_vote_recived - votes[winners[i]].numV == 0){
                        flag = true;
                    }
                }
                
                if (flag == true){
                    escrow.transfer(address(this).balance);
                    emit Sayonara(escrow);
                }
                
                else{
                     for(uint i=0; i < voters.length; i++ ){
                         if(souls[voters[i]].symbol != winner){
                            address payable addRefunded = payable(address(voters[i]));
                            uint refound = souls[voters[i]].soul;
                            souls[voters[i]].soul = 0;
                            addRefunded.transfer(refound);
                        }
                    }
         
                    winners.transfer(address(this).balance);
                    emit NewMayor(winner);
    
                }
                
                
            }
        }
    }
    
   
 
 
    /// @notice Compute a voting envelope
    /// @param _sigil (uint) The secret sigil of a voter
    /// @param _symbol (address) The voting preference
    /// @param _soul (uint) The soul associated to the vote
    function compute_envelope(uint _sigil, address _symbol, uint _soul) public view returns(bytes32) {
        bool flag = false;
        uint32 i = 0;
        while( !flag && i <= candidate_list.length){
            if (candidate_list[i].cand == _symbol) 
                flag = true;
        }
        require( flag && coalition_list[_symbol] == 0x0, "the candidate or the coalition is not present in the list ");
        return keccak256(abi.encode(_sigil, _symbol, _soul));
    }
    
}

