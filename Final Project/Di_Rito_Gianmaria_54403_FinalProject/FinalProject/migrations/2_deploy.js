var Mayor = artifacts.require("./Mayor.sol");

module.exports = function(deployer,network,address) {
  let list_cand = [[address[0],address[1]],[address[2],address[1]],[address[3],address[4]],[address[5],address[4]]];
  let escrow = address[6];
  let quorum = 3;
  deployer.deploy(Mayor,list_cand,escrow,quorum);
};

