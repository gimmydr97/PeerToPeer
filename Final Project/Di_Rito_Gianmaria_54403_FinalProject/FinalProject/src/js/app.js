App = {

    contracts: {},
    web3Provider: null,             // Web3 provider
    url: 'http://localhost:8545',   // Url for web3
    account: '0x0',                 // current ethereum account

    init: function() {

        return App.initWeb3();
    },

    /* initialize Web3 */
    initWeb3: function() {
        
        // console.log(web3);
        
        if(typeof web3 != 'undefined') {
//            App.web3Provider = web3.currentProvider;
//            web3 = new Web3(web3.currentProvider);
            App.web3Provider = window.ethereum; // !! new standard for modern eth browsers (2/11/18)
            web3 = new Web3(App.web3Provider);
            try {
                    ethereum.enable().then(async() => {
                        console.log("DApp connected to Metamask");
                    });
            }
            catch(error) {
                console.log(error);
            }
        } else {
            App.web3Provider = new Web3.providers.HttpProvider(App.url); // <==
            web3 = new Web3(App.web3Provider);
        }

        return App.initContract();
    },

    /* Upload the contract's abstractions */
    initContract: function() {

        // Get current account
        web3.eth.getCoinbase(function(err, account) {
            if(err == null) {
                App.account = account;
                if(App.account != null){
                    $("#lds-spinner").hide();
                    $("#container").show();
                }
                $("#accountId").html("Your address: " + account);
                
            }
        });

        // Load content's abstractions
        $.getJSON("Mayor.json").done(function(c) {
            App.contracts["Mayor"] = TruffleContract(c);
            App.contracts["Mayor"].setProvider(App.web3Provider);

            return App.listenForEvents();
        });
    },

    listenForEvents: function() {

        App.contracts["Mayor"].deployed().then(async (instance) => {

            // web3.eth.getBlockNumber(function (error, block) {
                // click is the Solidity event
                instance.EnvelopeCast().on('data', function (event) {
                    $("#eventIdsend").html("envelope has been sent");
                    console.log("envelope has been sent");
                    console.log(event);
                    // If event has parameters: event.returnValues.valueName
                });

                instance.EnvelopeOpen().on('data', function (event) {
                    $("#eventIdopen").html("envelope has been  opened");
                    console.log("envelope has been openend");
                    console.log(event);
                    // If event has parameters: event.returnValues.valueName
                });

                instance.NewMayor().on('data', function (event) {
                    $("#eventIdmos").html("new mayor: " + event.returnValues._candidate);
                    console.log("new mayor");
                    console.log(event)
                    // If event has parameters: event.returnValues.valueName
                });

                instance.Sayonara().on('data', function (event) {
                    $("#eventIdmos").html("sayonara");
                    console.log("sayonara");
                    console.log(event);
                    // If event has parameters: event.returnValues.valueName
                });
            // });
        });

        return App.render();
    },

    render: function() {

        App.contracts["Mayor"].deployed().then(async(instance) =>{

            
            const candidates = await instance.getCandidates.call();
            const coalitions = await instance.getCoalitions.call();
          /*console.log(candidates);
            console.log(coalitions);*/

            var select = document.getElementById('select_candidates');
            for(var i = 1 ; i <= candidates.length;i++){
                var option = '<option value="'+i+'">' + candidates[i-1] +'</option>';
                select.insertAdjacentHTML('beforeend', option);
            }
            for(var i = 1 ; i <= coalitions.length;i++){
                var option = '<option value="'+i+'">' + coalitions[i-1] +'</option>';
                select.insertAdjacentHTML('beforeend', option);
            }
        

        });
    },

    pressSend: function() {

        App.contracts["Mayor"].deployed().then(async(instance) =>{
            var sigil = document.forms.form.sigil.value;
            /*console.log(sigil);*/
            var soul = document.forms.form.soul.value;
            /*console.log(soul);*/
            var Index = document.forms.form.select_candidates.selectedIndex;
            var symbol;
            if (Index > -1) {
	            symbol = document.forms.form.select_candidates.options[Index];
	           /*console.log(symbol.text);*/
            }

                var computation = await instance.compute_envelope(sigil,symbol.text,soul); 
                console.log(computation);
            
                console.log( await instance.cast_envelope(computation, {from: App.account}));

        });
    },

    pressOpen: function() {
        App.contracts["Mayor"].deployed().then(async(instance) =>{
                var sigil = document.forms.form.sigil.value;
                var soul = document.forms.form.soul.value;
                var Index = document.forms.form.select_candidates.selectedIndex;
                var symbol;
                if (Index > -1) {
                    symbol = document.forms.form.select_candidates.options[Index];
                }
               
                //1000000000000000000
                await instance.open_envelope(sigil, symbol.text, {from: App.account, value:soul});
                
              
        });
    },

    pressMayorOrSayonara: function() {
        App.contracts["Mayor"].deployed().then(async(instance) =>{
            const candidates = await instance.getCandidates.call();
            const coalitions = await instance.getCoalitions.call();
                await instance.mayor_or_sayonara({from: App.account});
        });
    }

}

// Call init whenever the window loads
$(function() {
    $(window).on('load', function () {

        App.init();
    });
});