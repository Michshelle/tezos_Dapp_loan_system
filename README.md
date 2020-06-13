# Deployment 

Tools: ide.ligolang.org + tezbridge

A few steps of manual work are required.
1. Deploy the token contract and copy the contract address when it is done
2. Paste the above address to the ledger contract and deploy it
3. A view contract is needed to burn token and withdrawal tezos; Here we use, KT1HeGzCq32DatJDsNHgtmoTiEqMSUrUcnWr; 

After we have the three contracts on chain, the deployment part is done;

# Webpage Usage

Three functions have been built and put on the frontend for showcase.

"Debt ownership transfer" and "debt token withdrawal" have been released to the public usrs;  "Token mint function" can be used when the token owner account is being connected to the tezbridge.

Spare the coarse design of the webpage as I know too little about frontend especially javescript and react.  Basically I'm mimicing the code mentioned in the reference section.


# Project Reference
The project is largely based on below materials.  A lot more references have been used, however I cannot recall all of them accurately.

Thanks to the folks on tezos.stackexchange.com, ligolang discorder and the GOOGLE, of course.

1. https://hackernoon.com/build-your-first-dapp-on-tezos-rwgl3ymb
2. https://github.com/ecadlabs/token-contract-example
3. https://github.com/ecadlabs/taquito/blob/8d126fbb4bbc213ccd8ea107f918337eb1eadd96/docs/making_transfers.md


