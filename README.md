# Purpose of the app

The dapp aims to issue short-term debt on chain with each token pegged to 10^-6 dollar and treat the xtz as the media for value exchange between usd and the debt token.

To know more details, please take a look at the spec on Flexible Loan System.

# Contract Deployment 

Tools: ide.ligolang.org + tezbridge + crontab

A few steps of manual work are required.
1. Deploy the token contract and copy the contract address when it is done
Initialization Code on ligolang website, FYI
```
record [
         owner = ("tz1NBWgCxEGy8U6UA4hRmemt3YmMXbPPe1YH" : address);
         totalSupply = 0n;
         ledger = big_map [("tz1NBWgCxEGy8U6UA4hRmemt3YmMXbPPe1YH" : address) -> record [
                            balance = 0n;
                            allowances = (map [] : map (address , nat));
                         ]];]
```
2. Paste the above address to the ledger contract and deploy it
Initialization Code on ligolang website, FYI
```
record [ debtor = ("tz1NBWgCxEGy8U6UA4hRmemt3YmMXbPPe1YH" : address); 
         totalCredit = 0; 
         capitalAmount = 1000; 
         couponRate_inPerc = 9n; 
         creditorsMap = (map [] : map (address, counter)); ]
```

After we have the two contracts on chain, the deployment part is done;

# Backend Deployment

`checkPoint` in KT_ledger would be set to run for every 15 minutes to make sure expired record would be removed in time and the token would be released.
```
15 * * * * /Home/tezos/tezos-client transfer 0 from alice to KT19kz19131X3D38js91b1pxJWqhmApyFnv5 --entrypoint checkPoint --burn-cap 1 >/var/log/tezos_update.log 2>&1
```
# Webpage Usage

To boot the webpage: `cd client` and run `npm run start`. 

Three functions have been built and put on the frontend for showcase.

"Debt ownership transfer" and "debt token withdrawal" have been released to the public users as `transfer` and `burn` buttons;  "Token mint function" can be used when the token owner account is being connected to the tezbridge.

Spare the coarse design of the webpage as I know too little about frontend especially javescript and react.  Basically I'm mimicing the code mentioned in the reference section.

# Limitations on the built part

1. Lots of errors and warnings under the hood cannot be addressed enough. If you are trying to run the app yourself, please open the browser dev console to make sure the process.
2. CORS policy needs to be overriden when making localhost test, here I would recommend chrome extension adds-on for temporary bypass. An alternative is to use a proxy to fetch value.


# Project Reference
The project is largely based on below materials.  A lot more references have been used, however I cannot recall all of them accurately.

Thanks to the folks on tezos.stackexchange.com and ligolang discorder, and to the GOOGLE, of course.

1. https://hackernoon.com/build-your-first-dapp-on-tezos-rwgl3ymb
2. https://github.com/ecadlabs/token-contract-example
3. https://github.com/ecadlabs/taquito/blob/8d126fbb4bbc213ccd8ea107f918337eb1eadd96/docs/making_transfers.md


# Command line for copy and paste, FYI

```
#add creditor
./tezos-client transfer 0 from alice to KT19kz19131X3D38js91b1pxJWqhmApyFnv5 --entrypoint addCreditor --arg '(Pair (Pair "tz1g4Kw2qhYELxeeHc2yiuLtPdovVckYNc6G" 50000000) (Pair 4 50001800))' --burn-cap 1

#modifyOwnership
./tezos-client transfer 3 from david to KT19kz19131X3D38js91b1pxJWqhmApyFnv5 --entrypoint modifyOwnership --arg '(Pair (Pair "tz1VmUWL8DxseZnPTdhHQkkuk6nK55NVdKCG" "2020-06-21T00:39:07Z") 106)' --burn-cap 1

#checkPoint
./tezos-client transfer 0 from alice to KT19kz19131X3D38js91b1pxJWqhmApyFnv5 --entrypoint checkPoint --burn-cap 1



#mint
./tezos-client transfer 100 from alice to KT1J392py8u2xKVC2dkeJ6T4yVZdG3UXXGMe --entrypoint mint --arg 100000000 --burn-cap 1

#approve
./tezos-client transfer 0 from alice to KT1J392py8u2xKVC2dkeJ6T4yVZdG3UXXGMe --entrypoint approve --arg '(Pair "KT19kz19131X3D38js91b1pxJWqhmApyFnv5" 200000)' --burn-cap 1

```